# Bíblia · JG Company

App de Bíblia offline para Android, pensado para tablet. Feito em Flutter.

## O que já tem (etapa 1)

- Layout de tablet: livros e capítulos à esquerda, texto à direita (no celular vira uma página)
- Leitura offline com todas as configurações de leitura:
  - tamanho, tipo de fonte (Normal, Monospace, Sans Serif, Serif) e alinhamento
  - espaço entre versículos e entre linhas (0,7x a 3,0x)
  - cor da página (branco, sépia, verde, escuro, preto), modo noturno e cor do tema
  - layout clássico ou versículo por versículo, número do versículo pequeno ou normal
  - remover espaço inicial, remover títulos
  - palavras de Jesus em cor, com 7 opções de cor
  - ocultar menus ao rolar, manter a tela ligada, tela cheia
- Painel rápido de ajustes (botão de texto na barra de cima)
- Tocar nos versículos para marcar com 6 cores, favoritar, anotar, copiar e compartilhar
- Pesquisa sem acento, ou com "frase exata", na Bíblia toda, só no AT, só no NT ou no livro atual
- Favoritos e marcações, anotações, histórico
- "Marcar capítulo como lido" e progresso de leitura por livro
- Versículo do dia (com horário) e passagem do domingo por notificação
- Backup: salvar, enviar e restaurar
- Várias versões da Bíblia: as que vêm dentro do app e as que você importar

## Próximas etapas

- Login com a conta Google e sincronização dos dados na nuvem
- Músicas de fundo
- Leitor de PDF com anotações à mão (caneta/stylus)
- Planos de leitura, devocionais, histórias, hinários, dicionário, perguntas
- Mapas 3D

## Versões da Bíblia (arquivos .json)

Coloque os arquivos em `assets/bibles/` para que venham dentro do app, ou importe pelo próprio app (Menu → Versões → Importar).

```json
{
  "id": "acf",
  "name": "Almeida Corrigida Fiel",
  "abbrev": "ACF",
  "copyright": "Copyright © ... Todos os direitos reservados.",
  "books": [
    {
      "abbrev": "gn",
      "name": "Gênesis",
      "titles": { "1:1": "A criação" },
      "chapters": [["No princípio criou Deus os céus e a terra.", "..."]]
    }
  ]
}
```

- `books` segue a ordem canônica de 66 livros. `name` e `titles` são opcionais.
- As palavras de Jesus podem ser marcadas com `<J>...</J>` no texto.
- Também aceita o formato de lista simples `[{"abbrev": "gn", "chapters": [[...]]}, ...]`.

## Gerar o APK

Todo push que muda `biblia_jg/` dispara o workflow **Bíblia JG — gerar APK** no GitHub Actions. Ele roda as verificações e os testes, gera o APK e publica na página **Releases** do repositório.

Assinatura fixa (necessária para atualizar o app sem desinstalar): crie os secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` e `ANDROID_KEY_PASSWORD`.

## Desenvolvimento

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```
