import 'package:flutter/material.dart';

import '../theme.dart';
import 'panorama_tree.dart';

// A linha do tempo (épocas, acontecimentos e história da igreja) fica em panorama_timeline.dart.
export 'panorama_timeline.dart' show BibleTimelineScreen;

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
