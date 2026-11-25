import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/parallax_image.dart' show StoryThumb;
import '../widgets/portrait.dart';
import 'panorama_art.dart';
import 'panorama_kings.dart';
import 'panorama_tree.dart';
import 'stories_screen.dart';

// ======================================================================
// Linha do tempo da Bíblia
// ======================================================================

class _Era {
  final String title;
  final String dates;
  final IconData icon;
  final Color color;
  final String text;
  final List<String> people;
  final List<String> refs;
  final String books;
  final (String, Widget)? link;
  const _Era(this.title, this.dates, this.icon, this.color, this.text, this.people, this.refs, this.books, [this.link]);
}

const _eras = <_Era>[
  _Era('Os começos', 'antes de 2100 a.C.', Icons.public, Color(0xFF2E7D32),
      'Deus cria os céus, a terra e o homem à sua imagem. O pecado entra no mundo, vem o dilúvio e, em Babel, os povos se espalham. Já aqui Deus promete um Salvador.',
      ['Adão e Eva', 'Noé'], ['Gn 1:1', 'Gn 3:15', 'Gn 9:12-13'], 'Gênesis 1–11'),
  _Era('Os patriarcas', 'c. 2100–1800 a.C.', Icons.groups_2, Color(0xFF1B2A4A),
      'Deus chama Abraão e promete abençoar todas as famílias da terra por meio dele. A promessa passa a Isaque e a Jacó, e José leva a família ao Egito.',
      ['Abraão', 'Isaque', 'Jacó', 'José'], ['Gn 12:1-3', 'Gn 28:13-15', 'Gn 50:20'], 'Gênesis 12–50; Jó',
      ('Ver a família de Abraão', FamilyTreeScreen())),
  _Era('Egito e Êxodo', 'c. 1800–1400 a.C.', Icons.landscape, Color(0xFFC0392B),
      'A família vira um povo, escravo no Egito. Deus levanta Moisés, abre o mar, dá a lei no Sinai e manda fazer o tabernáculo. Uma geração inteira anda quarenta anos no deserto.',
      ['Moisés', 'Arão', 'Miriã'], ['Êx 3:7-10', 'Êx 14:21-22', 'Êx 20:1-3'], 'Êxodo, Levítico, Números e Deuteronômio',
      ('Ver o tabernáculo', TabernacleScreen())),
  _Era('Conquista e juízes', 'c. 1400–1050 a.C.', Icons.shield, Color(0xFF8D6E63),
      'Josué conduz o povo à terra prometida e a reparte entre as tribos. Depois, por séculos, o povo se afasta, sofre, clama, e Deus levanta juízes para livrá-lo.',
      ['Josué', 'Débora', 'Gideão', 'Sansão', 'Rute', 'Samuel'], ['Js 1:8-9', 'Jz 2:16-19', 'Rt 1:16'], 'Josué, Juízes e Rute'),
  _Era('O reino unido', 'c. 1050–930 a.C.', Icons.account_balance, Color(0xFFD4A017),
      'Israel pede um rei. Saul começa bem e cai; Davi une as tribos e recebe a promessa de um trono eterno; Salomão constrói o templo.',
      ['Saul', 'Davi', 'Salomão'], ['1Sm 16:7', '2Sm 7:12-16', '1Rs 8:27-30'], '1 e 2 Samuel, 1 Reis 1–11, Salmos, Provérbios',
      ('Ver os reis', KingsScreen())),
  _Era('O reino dividido', '930–586 a.C.', Icons.call_split, Color(0xFF6A1B9A),
      'O reino se parte: Israel ao norte, Judá ao sul. Os profetas chamam ao arrependimento. Israel cai diante da Assíria em 722 a.C.; Judá resiste até 586 a.C.',
      ['Elias', 'Eliseu', 'Isaías', 'Ezequias', 'Josias', 'Jeremias'], ['1Rs 12:16-20', '2Rs 17:6', '2Rs 25:8-11'],
      '1 Reis 12 – 2 Reis; profetas antes do exílio', ('Ver a linha dos reis', KingsScreen())),
  _Era('O exílio', '586–538 a.C.', Icons.lock_clock, Color(0xFF455A64),
      'Jerusalém e o templo são destruídos e o povo é levado para a Babilônia. Longe de casa, Deus guarda os seus e promete um coração novo.',
      ['Daniel', 'Ezequiel'], ['Sl 137:1', 'Dn 2:44', 'Ez 36:26-27'], 'Daniel, Ezequiel, Lamentações'),
  _Era('A volta', '538–430 a.C.', Icons.home_work, Color(0xFF00897B),
      'Ciro deixa os judeus voltarem. Eles reconstroem o altar, o templo e os muros de Jerusalém, e Esdras ensina a lei ao povo.',
      ['Zorobabel', 'Esdras', 'Neemias', 'Ester'], ['Ed 1:1-3', 'Ne 6:15-16', 'Ml 3:1'], 'Esdras, Neemias, Ester, Ageu, Zacarias, Malaquias'),
  _Era('Entre os testamentos', 'c. 430–5 a.C.', Icons.hourglass_bottom, Color(0xFF9E9E9E),
      'Cerca de quatrocentos anos sem profeta em Israel. Persas, gregos e romanos dominam a terra; surgem as sinagogas, os fariseus e os saduceus. O palco fica pronto para o Messias.',
      [], ['Ml 4:5-6', 'Gl 4:4'], 'Período que a Bíblia não narra'),
  _Era('A vida de Jesus', 'c. 5 a.C.–30 d.C.', Icons.wb_sunny, Color(0xFFEF6C00),
      'O Filho de Deus nasce em Belém, anuncia o Reino, morre na cruz pelos nossos pecados, ressuscita ao terceiro dia e sobe aos céus.',
      ['Jesus', 'Maria', 'João Batista', 'os doze'], ['Jo 1:14', 'Mc 10:45', 'Lc 24:46-47'], 'Mateus, Marcos, Lucas e João',
      ('Ver as histórias', StoriesScreen())),
  _Era('A igreja primitiva', 'c. 30–95 d.C.', Icons.local_fire_department, Color(0xFF1E88E5),
      'O Espírito Santo desce em Pentecostes e o evangelho vai de Jerusalém até Roma. Os apóstolos escrevem às igrejas, e João vê em Patmos o fim da história: Cristo volta e faz novas todas as coisas.',
      ['Pedro', 'Estêvão', 'Paulo', 'João'], ['At 1:8', 'Rm 1:16', 'Ap 21:5'], 'Atos, as cartas e o Apocalipse',
      ('Ver as histórias', StoriesScreen())),
];

/// Linha do tempo da Bíblia: onze épocas, da criação à igreja primitiva.
class BibleTimelineScreen extends StatelessWidget {
  const BibleTimelineScreen({super.key});

  void _open(BuildContext context, _Era e) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (ctx) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 210,
                  width: double.infinity,
                  child: StoryThumb(imageKey: eraArt[_eras.indexOf(e)], tint: e.color, large: true, cacheWidth: 1200),
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                CircleAvatar(backgroundColor: e.color, child: Icon(e.icon, color: Colors.white)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.title, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontFamily: 'serif')),
                    Text(e.dates, style: TextStyle(color: e.color, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              Text(e.text, style: const TextStyle(fontSize: 16, height: 1.45)),
              if (e.people.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final p in e.people)
                    PersonChip(p,
                        background: e.color.withValues(alpha: 0.16),
                        foreground: Theme.of(ctx).colorScheme.onSurface,
                        radius: 17),
                ]),
              ],
              const SizedBox(height: 10),
              Text('Onde ler: ${e.books}', style: Theme.of(ctx).textTheme.bodyMedium),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 4, children: [for (final r in e.refs) RefChip(r, color: e.color)]),
              if (e.link != null) ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(e.link!.$1),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => e.link!.$2));
                  },
                ),
              ],
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Linha do tempo da Bíblia')),
      body: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 760;
        Widget card(_Era e) => Material(
              color: e.color,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _open(context, e),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Ilustração da época, esmaecendo para a cor do cartão.
                  SizedBox(
                    height: 132,
                    width: double.infinity,
                    child: Stack(fit: StackFit.expand, children: [
                      StoryThumb(imageKey: eraArt[_eras.indexOf(e)], tint: e.color, large: true, cacheWidth: 900),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.45, 1],
                            colors: [e.color.withValues(alpha: 0), e.color],
                          ),
                        ),
                      ),
                    ]),
                  ),
                  Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(e.icon, color: Colors.white, size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(e.title,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'serif')),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    Text(e.dates, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(e.text, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.35)),
                    if (e.people.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(spacing: 6, runSpacing: 6, children: [for (final p in e.people) PersonChip(p)]),
                    ],
                  ]),
                  ),
                ]),
              ),
            );
        Widget dot(_Era e) => Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: e.color, shape: BoxShape.circle, border: Border.all(color: theme.scaffoldBackgroundColor, width: 3)),
            );
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          itemCount: _eras.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Da criação à igreja primitiva em onze épocas. Toque numa época para ver o resumo e onde ler. As datas são aproximadas.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              );
            }
            final e = _eras[i - 1];
            final line = Container(width: 3, color: theme.colorScheme.outlineVariant);
            if (!wide) {
              return IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(
                    width: 30,
                    child: Stack(alignment: Alignment.topCenter, children: [
                      Positioned.fill(child: Center(child: line)),
                      Padding(padding: const EdgeInsets.only(top: 18), child: dot(e)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 12), child: card(e))),
                ]),
              );
            }
            // Tela larga: cartões alternando dos dois lados da linha.
            final left = i.isOdd;
            return IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: left ? Padding(padding: const EdgeInsets.only(bottom: 14), child: card(e)) : const SizedBox()),
                SizedBox(
                  width: 56,
                  child: Stack(alignment: Alignment.topCenter, children: [
                    Positioned.fill(child: Center(child: line)),
                    Padding(padding: const EdgeInsets.only(top: 20), child: dot(e)),
                  ]),
                ),
                Expanded(child: left ? const SizedBox() : Padding(padding: const EdgeInsets.only(bottom: 14), child: card(e))),
              ]),
            );
          },
        );
      }),
    );
  }
}

// ======================================================================
// O tabernáculo
// ======================================================================

class _Piece {
  final String name;
  final IconData icon;
  final Color color;
  final Rect box; // posição no desenho, em frações (0..1) da largura e da altura
  final String text;
  final String christ;
  final List<String> refs;
  const _Piece(this.name, this.icon, this.color, this.box, this.text, this.christ, this.refs);
}

const _pieces = <_Piece>[
  _Piece('Porta do átrio', Icons.door_sliding, Color(0xFF3949AB), Rect.fromLTWH(0.925, 0.36, 0.06, 0.28),
      'A única entrada, voltada para o leste: uma cortina de azul, púrpura e carmesim, com vinte côvados de largura.',
      'Jesus disse: Eu sou a porta; se alguém entrar por mim, será salvo.', ['Êx 27:16', 'Jo 10:9']),
  _Piece('Altar do holocausto', Icons.local_fire_department, Color(0xFFBF5B17), Rect.fromLTWH(0.70, 0.38, 0.13, 0.24),
      'De madeira de acácia coberta de bronze. Era a primeira coisa que se via ao entrar: ali os sacrifícios eram oferecidos todos os dias.',
      'Cristo ofereceu um único sacrifício pelos pecados, de uma vez por todas.', ['Êx 27:1-8', 'Hb 10:11-12']),
  _Piece('Pia de bronze', Icons.water_drop, Color(0xFF00838F), Rect.fromLTWH(0.56, 0.42, 0.08, 0.16),
      'Feita com os espelhos das mulheres. Os sacerdotes lavavam as mãos e os pés antes de servir.',
      'Somos lavados pela Palavra e pelo sangue de Jesus.', ['Êx 30:17-21', 'Êx 38:8', 'Ef 5:26']),
  _Piece('Mesa dos pães', Icons.bakery_dining, Color(0xFF8D6E63), Rect.fromLTWH(0.33, 0.30, 0.10, 0.11),
      'No lado norte do Lugar Santo: doze pães, um por tribo, sempre diante do Senhor, trocados a cada sábado.',
      'Jesus é o pão da vida: quem vem a ele não terá fome.', ['Êx 25:23-30', 'Lv 24:5-9', 'Jo 6:35']),
  _Piece('Candelabro', Icons.wb_incandescent, Color(0xFFD4A017), Rect.fromLTWH(0.33, 0.59, 0.10, 0.11),
      'De ouro puro batido, com sete lâmpadas, no lado sul. Era a única luz da tenda e nunca devia se apagar.',
      'Jesus é a luz do mundo.', ['Êx 25:31-40', 'Lv 24:1-4', 'Jo 8:12']),
  _Piece('Altar do incenso', Icons.cloud, Color(0xFF7B1FA2), Rect.fromLTWH(0.235, 0.445, 0.065, 0.11),
      'De ouro, diante do véu. O incenso subia de manhã e à tarde, na hora da oração.',
      'As orações dos santos sobem como incenso, e Cristo intercede por nós.', ['Êx 30:1-10', 'Sl 141:2', 'Ap 8:3-4']),
  _Piece('Véu', Icons.vertical_split, Color(0xFFC2185B), Rect.fromLTWH(0.195, 0.27, 0.022, 0.46),
      'Separava o Lugar Santo do Santo dos Santos. Só o sumo sacerdote passava por ele, uma vez por ano, com sangue.',
      'Quando Jesus morreu, o véu do templo se rasgou de alto a baixo: o caminho até Deus está aberto.',
      ['Êx 26:31-33', 'Mt 27:51', 'Hb 10:19-20']),
  _Piece('Arca da aliança', Icons.inventory_2, Color(0xFFB8860B), Rect.fromLTWH(0.075, 0.40, 0.09, 0.20),
      'No Santo dos Santos: uma arca coberta de ouro com as tábuas da lei, e sobre ela o propiciatório com dois querubins. Ali Deus falava com Moisés.',
      'Jesus é a propiciação pelos nossos pecados: nele encontramos misericórdia.', ['Êx 25:10-22', 'Hb 9:3-5', 'Rm 3:25']),
];

/// O tabernáculo visto de cima: toque em cada peça para ver o que era e para onde aponta.
class TabernacleScreen extends StatelessWidget {
  const TabernacleScreen({super.key});

  void _open(BuildContext context, _Piece p) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(backgroundColor: p.color, child: Icon(p.icon, color: Colors.white)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(p.name, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontFamily: 'serif')),
                ),
              ]),
              const SizedBox(height: 12),
              Text(p.text, style: const TextStyle(fontSize: 16, height: 1.45)),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: jgGold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: jgGold.withValues(alpha: 0.6)),
                ),
                child: Text(p.christ, style: const TextStyle(fontSize: 15.5, height: 1.4)),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 4, children: [for (final r in p.refs) RefChip(r, color: p.color)]),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('O tabernáculo')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), children: [
        Text('A tenda onde Deus habitava no meio do povo, vista de cima. Toque em cada peça.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: AspectRatio(
              aspectRatio: 2,
              child: LayoutBuilder(builder: (context, box) {
                final w = box.maxWidth, h = box.maxHeight;
                Widget area(Rect r, Color fill, Color border, String label, {double radius = 6, Alignment at = Alignment.topCenter}) => Positioned(
                      left: r.left * w,
                      top: r.top * h,
                      width: r.width * w,
                      height: r.height * h,
                      child: Container(
                        alignment: at,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(radius), border: Border.all(color: border, width: 2)),
                        child: Text(label,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: (w / 62).clamp(9, 15).toDouble(), fontWeight: FontWeight.w700, color: const Color(0xFF3E2C1C))),
                      ),
                    );
                return Stack(children: [
                  // Átrio (cercado de linho), a tenda e os dois ambientes.
                  area(const Rect.fromLTWH(0, 0, 1, 1), const Color(0xFFF4E7CF), const Color(0xFFBFA77A), 'ÁTRIO · 100 × 50 côvados',
                      radius: 10, at: Alignment.topRight),
                  area(const Rect.fromLTWH(0.05, 0.25, 0.45, 0.50), const Color(0xFFE2C9A1), const Color(0xFF7A5C2E), '', radius: 4),
                  area(const Rect.fromLTWH(0.205, 0.25, 0.295, 0.50), const Color(0x00000000), const Color(0x00000000), 'LUGAR SANTO'),
                  area(const Rect.fromLTWH(0.05, 0.25, 0.15, 0.50), const Color(0x33B8860B), const Color(0x00000000), 'SANTO DOS SANTOS'),
                  for (final p in _pieces)
                    Positioned(
                      left: p.box.left * w,
                      top: p.box.top * h,
                      width: p.box.width * w,
                      height: p.box.height * h,
                      child: Tooltip(
                        message: p.name,
                        child: Material(
                          color: p.color,
                          elevation: 3,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _open(context, p),
                            child: Center(
                              child: Icon(p.icon, color: Colors.white, size: (p.box.width * w * 0.6).clamp(10, 34).toDouble()),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Pontos cardeais: a entrada fica a leste.
                  Positioned(left: 8, bottom: 6, child: Text('OESTE', style: TextStyle(fontSize: (w / 70).clamp(9, 13).toDouble(), color: const Color(0xFF7A5C2E)))),
                  Positioned(right: 8, bottom: 6, child: Text('LESTE (entrada)', style: TextStyle(fontSize: (w / 70).clamp(9, 13).toDouble(), color: const Color(0xFF7A5C2E)))),
                ]);
              }),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('As peças', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in _pieces)
            ActionChip(
              avatar: CircleAvatar(backgroundColor: p.color, child: Icon(p.icon, size: 14, color: Colors.white)),
              label: Text(p.name),
              onPressed: () => _open(context, p),
            ),
        ]),
        const SizedBox(height: 14),
        Text(
          'Medidas e posições conforme Êxodo 25–27 e 30 (um côvado tem cerca de 45 cm). O desenho é um esquema, não está em escala exata. '
          '“O Verbo se fez carne e habitou entre nós” (João 1:14): tudo aqui aponta para Jesus.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ]),
    );
  }
}
