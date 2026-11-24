# Bíblia JG: resumo para continuar o trabalho

Atualizado em 24/11/2026. Branch de trabalho: `ccr-bd8c0120-93hpn2` (repo `mrparfumofc-droid/Claude-Code`, pasta `biblia_jg/`).

## O que é
App Flutter de Bíblia para tablet Android, de uso pessoal do dono (JG Company). Interface em português.

## Estado atual (build 17, publicado e assinado)
- **Leitura:** layout de tablet com livros à esquerda e texto à direita, todas as configurações de leitura, cor da página independente do modo noturno (que vale só para o app), seleção de versículo sublinhada com fundo opaco.
- **22 versões.** As 18 em português vêm de `damarals/biblias` (releases). Ave-Maria, KJV, NIV e RVR1960 vêm de `thiagobodruk/bible`. São baixadas na hora do build por `tool/fetch_bibles.py`, com SHA-256 conferido e cache no Actions. Os textos **não** ficam no repositório.
- **Títulos de seção** (3.016) e **palavras de Jesus** (2.045 versículos) a partir da Berean Standard Bible, que é domínio público. Ficam em `tool/enrichment/` e são aplicados por `tool/enrich.py`. Os títulos foram traduzidos com o Gemini por `tool/build_enrichment.py`.
- **Ações do versículo:** marcar com cores, favoritar, anotar, copiar, compartilhar, Estudo bíblico (IA), Imagem (editor de cartão), Ouvir (TTS que acompanha o versículo lido), Referências (OpenBible, CC-BY, em `assets/data/xrefs.json`).
- **Menu:** Assistente IA, Planos de leitura (9), Devocional diário (IA, guardado por dia), Histórias bíblicas (56, IA), Perguntas bíblicas (IA, JSON), Anotações, Favoritos, Progresso, Pesquisa, Versões, Histórico, Backup, Configurações, Sobre (com a logo).
- **"Ir para referência"** (ex.: "Jo 3:16") em `lib/models/reference_parser.dart`.
- **Atualização automática:** o app lê `releases/latest` do GitHub e oferece o APK novo (`lib/services/updater.dart`). Só builds assinados com a chave fixa viram "latest"; os outros saem como pré-versão.

## Infraestrutura
- **Build:** `.github/workflows/biblia-apk.yml`. Roda a cada push em `biblia_jg/**`, a menos que o commit tenha `[skip ci]`. Faz analyze, testes, baixa as Bíblias, assina e publica o release `biblia-build-N`.
- **Assinatura:** 4 secrets no repositório (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`). O workflow tolera espaços e texto extra colado junto. O backup da chave está no Google Drive do dono: `chave-assinatura-biblia-jg.txt`. Impressão digital: `0E:F3:62:0F:…:D3:18`.
- **Supabase:** projeto `biblia-jg` (id `ayjsoixzroxkrnkpkkip`, São Paulo, plano gratuito).
  - Edge Function `ai-verse` (código em `supabase/functions/ai-verse/`) faz o proxy para o Gemini. Usa o secret `GEMINI_API_KEY`, já salvo no Supabase.
  - Aceita usuário logado **ou** o app, com `x-app-key` (o hash fica na tabela `ai_config`) e `x-device-id`.
  - Limites: 80 pedidos por dia por aparelho, 400 por dia no total.
  - Tarefas: `explain`, `commentary`, `term`, `devotional`, `story`, `quiz`, `sermon`, `chat`.
  - Perfis: `assembleiano` (padrão), `geral`, `batista`, `reformado`, `academico`, `catolico`.
- **IA no app:** `lib/services/ai_service.dart` (chave do app e chave anon do Supabase) e `lib/screens/ai_chat_screen.dart`.

## Pendências
1. **Músicas de fundo.** O dono precisa enviar as MP3 (estão em `D:\Claude Code\musicas` no PC) para `biblia_jg/assets/music/` pelo upload web do GitHub. O Remote Control do PC (DESKTOP-VN235BA) aparece, mas a pasta fica "indisponível"; provavelmente o Claude Desktop precisa ser atualizado no Windows. Depois disso, criar um player com play/pausa, próxima, repetir e volume, tocando junto com a leitura.
2. **Livros (PDF) + EBD.** Leitor de PDF com pastas, anotação à mão (caneta, marca-texto, borracha, cores, desfazer), salvo por página. O módulo EBD: revista em PDF por ano e trimestre, lições marcadas (à mão ou pela IA), Bíblia ao lado, referências clicáveis, lembrete de domingo.
3. **Hinário.** Só hinos de domínio público, mais importação de hinário próprio. A Harpa Cristã é da CPAD.
4. **Mapas.** Usar o OpenBible geodata (CC-BY, 1.293 lugares) com flutter_map/OSM, mais os lugares do versículo e jornadas (Êxodo, viagens de Paulo). "Vídeos 3D" só se o dono fornecer os vídeos.
5. **Dicionário.** Domínio público: Strong, Easton, Smith, ISBE 1915, traduzidos com o Gemini. Mais um importador de módulos MyBible/MySword e conversão de PDFs de dicionário que o dono tenha legitimamente, entregues de forma privada e não pelo repositório.
6. **Login Google + sincronização** (Supabase Auth). Exige criar um cliente OAuth no Google Cloud (projeto 703427545959).
7. **Repositório privado.** O dono quer o repositório privado. **Antes de mudar**, levar a atualização automática para o Supabase Storage (secret `SUPABASE_SERVICE_ROLE_KEY` no GitHub para o upload) e apontar `updater.dart` para lá. Senão o app para de achar as atualizações.

## Regras de conteúdo
Não usar dados com direito autoral de terceiros sem licença: os módulos do repositório `welitonevoc/biblia-codex` (Merrill, Vine Pro, Quem é Quem, Strong AMG/CPAD, revistas CPAD, devocionais Lucado/Hernandes/Bullón), os dicionários Wycliffe, Tyndale e Vine, e a Harpa Cristã. Esse repositório serve só como referência de funções. O inventário completo das funções dele foi feito nesta sessão; a ordem sugerida está acima.

## Desenvolvimento
```bash
cd biblia_jg
python3 tool/fetch_bibles.py          # baixa e monta as 22 versões em assets/bibles/
flutter pub get && flutter analyze && flutter test   # 21 testes
```
O Flutter usado é o 3.47.9. O APK só é gerado no GitHub Actions (o ambiente da nuvem não tem o Android SDK).
