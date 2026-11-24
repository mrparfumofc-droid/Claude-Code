import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/music_player.dart';

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MusicPlayer>().init();
    });
  }

  Future<void> _confirmRemoveAll(MusicPlayer m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar músicas baixadas?'),
        content: Text(
            'Libera ${_mb(m.downloadedBytes)} do tablet. As músicas continuam na nuvem e tocam online.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apagar')),
        ],
      ),
    );
    if (ok == true) await m.removeAllDownloads();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MusicPlayer>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Músicas de fundo'),
        actions: [
          if (m.downloaded.isNotEmpty)
            IconButton(
              tooltip: 'Apagar músicas baixadas',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _confirmRemoveAll(m),
            ),
          IconButton(
            tooltip: 'Atualizar lista',
            icon: const Icon(Icons.refresh),
            onPressed: m.loading ? null : m.refresh,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(children: [
            if (m.loading) const LinearProgressIndicator(),
            const _NowPlaying(),
            if (m.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(m.error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            const Divider(height: 1),
            Expanded(
              child: m.tracks.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          m.loading
                              ? 'Carregando as músicas da nuvem…'
                              : 'Nenhuma música na nuvem ainda.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: m.tracks.length + 1,
                      itemBuilder: (context, i) {
                        if (i == m.tracks.length) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'As músicas tocam pela internet. Toque em ⤓ para baixar e ouvir sem internet: '
                              'fica só dentro do app e você pode apagar quando quiser.',
                              style: theme.textTheme.bodySmall,
                            ),
                          );
                        }
                        final t = m.tracks[i];
                        final isCurrent = m.current == i;
                        final prog = m.downloading[t.file];
                        final isDown = m.downloaded.contains(t.file);
                        return ListTile(
                          selected: isCurrent,
                          leading: Icon(isCurrent && m.playing
                              ? Icons.graphic_eq
                              : Icons.music_note_outlined),
                          title: Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text([
                            if (t.seconds > 0) formatDuration(Duration(seconds: t.seconds)),
                            if (isDown) 'baixada',
                          ].join(' · ')),
                          trailing: prog != null
                              ? SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(value: prog, strokeWidth: 3),
                                )
                              : isDown
                                  ? IconButton(
                                      tooltip: 'Apagar do tablet',
                                      icon: const Icon(Icons.download_done),
                                      onPressed: () => m.removeDownload(t),
                                    )
                                  : IconButton(
                                      tooltip: 'Baixar (${_mb(t.bytes)})',
                                      icon: const Icon(Icons.download_outlined),
                                      onPressed: () => m.download(t),
                                    ),
                          onTap: () => m.playAt(i),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _NowPlaying extends StatelessWidget {
  const _NowPlaying();

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MusicPlayer>();
    final t = m.currentTrack;
    final theme = Theme.of(context);
    final repeatIcon = switch (m.repeat) {
      MusicRepeat.one => Icons.repeat_one,
      _ => Icons.repeat,
    };
    final repeatLabel = switch (m.repeat) {
      MusicRepeat.off => 'Repetir: desligado',
      MusicRepeat.all => 'Repetir: todas',
      MusicRepeat.one => 'Repetir: esta música',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(children: [
        Text(
          t?.title ?? 'Escolha uma música',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (t != null)
          StreamBuilder<Duration>(
            stream: m.positionStream,
            builder: (context, snap) {
              final pos = snap.data ?? Duration.zero;
              final total = m.duration ?? Duration(seconds: t.seconds);
              final maxMs = total.inMilliseconds.toDouble();
              return Row(children: [
                Text(formatDuration(pos), style: theme.textTheme.bodySmall),
                Expanded(
                  child: Slider(
                    value: maxMs <= 0 ? 0 : pos.inMilliseconds.clamp(0, maxMs).toDouble(),
                    max: maxMs <= 0 ? 1 : maxMs,
                    onChanged: maxMs <= 0
                        ? null
                        : (v) => m.seek(Duration(milliseconds: v.round())),
                  ),
                ),
                Text(formatDuration(total), style: theme.textTheme.bodySmall),
              ]);
            },
          ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
            tooltip: m.shuffle ? 'Aleatório: ligado' : 'Aleatório: desligado',
            isSelected: m.shuffle,
            icon: const Icon(Icons.shuffle),
            color: m.shuffle ? theme.colorScheme.primary : theme.disabledColor,
            onPressed: m.toggleShuffle,
          ),
          IconButton(
            tooltip: 'Anterior',
            iconSize: 36,
            icon: const Icon(Icons.skip_previous),
            onPressed: m.tracks.isEmpty ? null : m.previous,
          ),
          SizedBox(
            width: 72,
            height: 72,
            child: m.buffering
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(),
                  )
                : IconButton.filled(
                    tooltip: m.playing ? 'Pausar' : 'Tocar',
                    iconSize: 40,
                    icon: Icon(m.playing ? Icons.pause : Icons.play_arrow),
                    onPressed: m.tracks.isEmpty ? null : m.toggle,
                  ),
          ),
          IconButton(
            tooltip: 'Próxima',
            iconSize: 36,
            icon: const Icon(Icons.skip_next),
            onPressed: m.tracks.isEmpty ? null : () => m.next(),
          ),
          IconButton(
            tooltip: repeatLabel,
            icon: Icon(repeatIcon),
            color: m.repeat == MusicRepeat.off
                ? theme.disabledColor
                : theme.colorScheme.primary,
            onPressed: m.cycleRepeat,
          ),
        ]),
        Row(children: [
          const Icon(Icons.volume_down),
          Expanded(
            child: Slider(value: m.volume, onChanged: m.setVolume),
          ),
          const Icon(Icons.volume_up),
        ]),
      ]),
    );
  }
}

/// Barrinha embaixo da leitura enquanto uma música está escolhida.
/// Controles de música para a barra lateral do tablet: abrir as músicas, tocar/pausar e próxima.
class RailMusic extends StatelessWidget {
  const RailMusic({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MusicPlayer>();
    final t = m.currentTrack;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        tooltip: t == null ? 'Músicas de fundo' : 'Tocando: ${t.title}',
        icon: Icon(t == null ? Icons.library_music_outlined : Icons.library_music),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MusicScreen())),
      ),
      if (t != null) ...[
        IconButton(
          tooltip: m.playing ? 'Pausar música' : 'Tocar música',
          icon: Icon(m.playing ? Icons.pause_circle_filled : Icons.play_circle_fill),
          onPressed: m.toggle,
        ),
        IconButton(tooltip: 'Próxima música', icon: const Icon(Icons.skip_next), onPressed: () => m.next()),
      ],
    ]);
  }
}

class MiniMusicBar extends StatelessWidget {
  final VoidCallback onOpen;
  const MiniMusicBar({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MusicPlayer>();
    final t = m.currentTrack;
    if (t == null) return const SizedBox.shrink();
    return Material(
      elevation: 4,
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: onOpen,
          child: SizedBox(
            height: 52,
            child: Row(children: [
              const SizedBox(width: 16),
              const Icon(Icons.music_note, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                tooltip: m.playing ? 'Pausar música' : 'Tocar música',
                icon: Icon(m.playing ? Icons.pause : Icons.play_arrow),
                onPressed: m.toggle,
              ),
              IconButton(
                tooltip: 'Próxima música',
                icon: const Icon(Icons.skip_next),
                onPressed: () => m.next(),
              ),
              IconButton(
                tooltip: 'Fechar música',
                icon: const Icon(Icons.close),
                onPressed: m.stop,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
