import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_service.dart' show supabaseAnonKey, supabaseUrl, appKey;

enum MusicRepeat { off, all, one }

class Track {
  final String file;
  final String title;
  final int seconds;
  final int bytes;
  final String? url;
  const Track({
    required this.file,
    required this.title,
    this.seconds = 0,
    this.bytes = 0,
    this.url,
  });

  factory Track.fromJson(Map<String, dynamic> j) => Track(
        file: j['file'] as String,
        title: j['title'] as String? ?? j['file'] as String,
        seconds: (j['seconds'] as num?)?.toInt() ?? 0,
        bytes: (j['bytes'] as num?)?.toInt() ?? 0,
        url: j['url'] as String?,
      );

  Map<String, dynamic> toJson() =>
      {'file': file, 'title': title, 'seconds': seconds, 'bytes': bytes};
}

/// Músicas de fundo tocadas da nuvem (Supabase Storage, bucket privado).
///
/// Por padrão tocam online. Cada música pode ser baixada para ouvir sem
/// internet: o arquivo fica só dentro da área do app (não aparece na pasta de
/// músicas do tablet) e pode ser apagado a qualquer momento.
class MusicPlayer extends ChangeNotifier {
  static const _listUrl = '$supabaseUrl/functions/v1/music';

  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _stateSub;
  SharedPreferences? _prefs;
  Directory? _dir;
  final _rand = Random();

  List<Track> tracks = const [];
  DateTime? _linksAt;
  int? current;
  bool playing = false;
  bool buffering = false;
  bool loading = false;
  bool loaded = false;
  String? error;
  double volume = 0.5;
  MusicRepeat repeat = MusicRepeat.all;
  bool shuffle = false;

  /// Arquivos já baixados (nome do arquivo).
  final Set<String> downloaded = {};

  /// Downloads em andamento: arquivo -> progresso (0..1).
  final Map<String, double> downloading = {};

  Track? get currentTrack =>
      current != null && current! < tracks.length ? tracks[current!] : null;

  Stream<Duration> get positionStream =>
      _player?.positionStream ?? const Stream<Duration>.empty();
  Duration? get duration => _player?.duration;
  Duration get position => _player?.position ?? Duration.zero;

  int get downloadedBytes => tracks
      .where((t) => downloaded.contains(t.file))
      .fold(0, (sum, t) => sum + t.bytes);

  AudioPlayer get _p => _player ??= _create();

  AudioPlayer _create() {
    final player = AudioPlayer();
    _stateSub = player.playerStateStream.listen((s) {
      final done = s.processingState == ProcessingState.completed;
      final now = s.playing && !done;
      final buf = s.processingState == ProcessingState.loading ||
          s.processingState == ProcessingState.buffering;
      if (now != playing || buf != buffering) {
        playing = now;
        buffering = buf;
        notifyListeners();
      }
      if (done) _onCompleted();
    });
    return player;
  }

  Future<Directory> _musicDir() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationSupportDirectory();
    final d = Directory(p.join(base.path, 'musicas'));
    if (!await d.exists()) await d.create(recursive: true);
    return _dir = d;
  }

  File _localFile(Directory dir, Track t) => File(p.join(dir.path, t.file));

  /// Carrega preferências e a lista de músicas (só na primeira vez).
  Future<void> init() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
      volume = _prefs!.getDouble('music.volume') ?? volume;
      repeat = MusicRepeat.values[(_prefs!.getInt('music.repeat') ?? repeat.index)
          .clamp(0, MusicRepeat.values.length - 1)];
      shuffle = _prefs!.getBool('music.shuffle') ?? shuffle;
      // Lista guardada da última vez (para mostrar e tocar as baixadas sem internet).
      final cached = _prefs!.getString('music.list');
      if (cached != null && tracks.isEmpty) {
        try {
          tracks = (jsonDecode(cached) as List)
              .map((e) => Track.fromJson(e as Map<String, dynamic>))
              .toList();
        } catch (_) {}
      }
    }
    if (!loaded) await refresh();
  }

  /// Busca a lista no servidor (links assinados valem 12 horas).
  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await http.get(Uri.parse(_listUrl), headers: {
        'Authorization': 'Bearer $supabaseAnonKey',
        'apikey': supabaseAnonKey,
        'x-app-key': appKey,
      }).timeout(const Duration(seconds: 30));
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (res.statusCode != 200 || data['tracks'] is! List) {
        throw (data['error'] ?? 'erro ${res.statusCode}').toString();
      }
      final list = (data['tracks'] as List)
          .map((e) => Track.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      final keep = currentTrack?.file;
      tracks = list;
      _linksAt = DateTime.now();
      final idx = keep == null ? -1 : list.indexWhere((t) => t.file == keep);
      current = idx >= 0 ? idx : null;
      await _prefs?.setString(
          'music.list', jsonEncode(list.map((t) => t.toJson()).toList()));
    } on TimeoutException {
      error = 'Sem conexão. Só as músicas baixadas tocam sem internet.';
    } on SocketException {
      error = 'Sem conexão. Só as músicas baixadas tocam sem internet.';
    } catch (e) {
      error = 'Não consegui carregar as músicas: $e';
    } finally {
      await _scanDownloaded();
      loading = false;
      loaded = true;
      notifyListeners();
    }
  }

  Future<void> _scanDownloaded() async {
    try {
      final dir = await _musicDir();
      downloaded
        ..clear()
        ..addAll(tracks.where((t) => _localFile(dir, t).existsSync()).map((t) => t.file));
    } catch (_) {}
  }

  bool get _linksOld =>
      _linksAt == null || DateTime.now().difference(_linksAt!) > const Duration(hours: 11);

  Future<void> playAt(int i) async {
    if (i < 0 || i >= tracks.length) return;
    current = i;
    error = null;
    notifyListeners();
    final t = tracks[i];
    try {
      final player = _p;
      await player.setVolume(volume);
      await player.setLoopMode(repeat == MusicRepeat.one ? LoopMode.one : LoopMode.off);
      if (downloaded.contains(t.file)) {
        await player.setFilePath(_localFile(await _musicDir(), t).path);
      } else {
        if (_linksOld) await refresh();
        final url = current != null ? tracks[current!].url : null;
        if (url == null) throw 'sem link';
        await player.setUrl(url);
      }
      unawaited(player.play());
    } catch (e) {
      error = downloaded.contains(t.file)
          ? 'Não consegui tocar "${t.title}".'
          : 'Não consegui tocar "${t.title}". Confira a internet.';
      notifyListeners();
    }
  }

  Future<void> toggle() async {
    if (tracks.isEmpty) return;
    if (current == null || _player == null) {
      await playAt(current ?? (shuffle ? _rand.nextInt(tracks.length) : 0));
    } else if (playing) {
      await _p.pause();
    } else {
      unawaited(_p.play());
    }
  }

  int _randomOther(int from) {
    if (tracks.length < 2) return max(from, 0);
    var n = from;
    while (n == from) {
      n = _rand.nextInt(tracks.length);
    }
    return n;
  }

  Future<void> next({bool auto = false}) async {
    if (tracks.isEmpty) return;
    final i = current ?? -1;
    if (shuffle) return playAt(_randomOther(i));
    if (i + 1 < tracks.length) return playAt(i + 1);
    if (auto && repeat == MusicRepeat.off) {
      await _p.pause();
      await _p.seek(Duration.zero);
      playing = false;
      notifyListeners();
      return;
    }
    return playAt(0);
  }

  Future<void> previous() async {
    if (tracks.isEmpty) return;
    if (_player != null && position > const Duration(seconds: 3)) {
      await _p.seek(Duration.zero);
      return;
    }
    final i = current ?? 0;
    await playAt(i > 0 ? i - 1 : tracks.length - 1);
  }

  void _onCompleted() {
    if (repeat == MusicRepeat.one) return; // o próprio player repete
    next(auto: true);
  }

  Future<void> seek(Duration d) async => _player?.seek(d);

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _player?.setVolume(volume);
    await _prefs?.setDouble('music.volume', volume);
  }

  Future<void> cycleRepeat() async {
    repeat = MusicRepeat.values[(repeat.index + 1) % MusicRepeat.values.length];
    notifyListeners();
    await _player?.setLoopMode(repeat == MusicRepeat.one ? LoopMode.one : LoopMode.off);
    await _prefs?.setInt('music.repeat', repeat.index);
  }

  Future<void> toggleShuffle() async {
    shuffle = !shuffle;
    notifyListeners();
    await _prefs?.setBool('music.shuffle', shuffle);
  }

  /// Baixa a música para tocar sem internet (fica só dentro do app).
  Future<void> download(Track t) async {
    if (downloading.containsKey(t.file) || downloaded.contains(t.file)) return;
    downloading[t.file] = 0;
    error = null;
    notifyListeners();
    final client = http.Client();
    File? part;
    try {
      if (_linksOld || t.url == null) await refresh();
      final url = tracks.firstWhere((x) => x.file == t.file, orElse: () => t).url;
      if (url == null) throw 'sem link';
      final dir = await _musicDir();
      part = File('${_localFile(dir, t).path}.part');
      final res = await client.send(http.Request('GET', Uri.parse(url)));
      if (res.statusCode != 200) throw 'erro ${res.statusCode}';
      final total = res.contentLength ?? t.bytes;
      final sink = part.openWrite();
      var got = 0;
      var lastNotify = 0.0;
      await for (final chunk in res.stream) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) {
          final prog = got / total;
          if (prog - lastNotify > 0.02) {
            lastNotify = prog;
            downloading[t.file] = prog;
            notifyListeners();
          }
        }
      }
      await sink.close();
      await part.rename(_localFile(dir, t).path);
      downloaded.add(t.file);
    } catch (e) {
      error = 'Não consegui baixar "${t.title}". Confira a internet.';
      try {
        if (part != null && await part.exists()) await part.delete();
      } catch (_) {}
    } finally {
      client.close();
      downloading.remove(t.file);
      notifyListeners();
    }
  }

  /// Apaga a cópia baixada (a música continua tocando online).
  Future<void> removeDownload(Track t) async {
    try {
      final f = _localFile(await _musicDir(), t);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    downloaded.remove(t.file);
    notifyListeners();
  }

  Future<void> removeAllDownloads() async {
    for (final t in tracks.where((t) => downloaded.contains(t.file)).toList()) {
      await removeDownload(t);
    }
  }

  Future<void> stop() async {
    await _player?.stop();
    current = null;
    playing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _player?.dispose();
    super.dispose();
  }
}
