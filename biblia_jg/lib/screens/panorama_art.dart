// Ilustrações das Histórias bíblicas que acompanham os quadros do Panorama.
// As chaves são as das ilustrações na nuvem (bucket "historias", pasta img/).

/// Ilustração de cada livro (1 a 66) no cabeçalho da ficha. Livro sem entrada fica só com a cor do grupo.
const bookArt = <int, String>{
  1: 'criacao-luz', // Gênesis
  2: 'mar-vermelho', // Êxodo
  3: 'tabernaculo', // Levítico
  4: 'espias-uvas', // Números
  5: 'nebo-vista', // Deuteronômio
  6: 'jerico-muros', // Josué
  8: 'rute-espigas', // Rute
  9: 'davi-golias', // 1 Samuel
  10: 'davi-coroado', // 2 Samuel
  11: 'templo-salomao', // 1 Reis
  12: 'elias-carro', // 2 Reis
  13: 'davi-arca', // 1 Crônicas
  14: 'salomao-altar', // 2 Crônicas
  15: 'ciro-decreto', // Esdras
  16: 'neemias-muros', // Neemias
  17: 'ester-rei', // Ester
  19: 'davi-harpa', // Salmos
  20: 'salomao-julgamento', // Provérbios
  21: 'rainha-saba', // Eclesiastes
  26: 'babilonia-portao', // Ezequiel
  27: 'daniel-leoes', // Daniel
  32: 'jonas-peixe', // Jonas
  34: 'ninive', // Naum
  37: 'templo-reconstrucao', // Ageu
  40: 'sermao-monte', // Mateus
  41: 'jesus-tempestade', // Marcos
  42: 'natal-manjedoura', // Lucas
  43: 'lazaro', // João
  44: 'pentecostes', // Atos
  45: 'roma-cidade', // Romanos
  46: 'corinto-tendas', // 1 Coríntios
  47: 'paulo-cesto', // 2 Coríntios
  48: 'listra-sacrificio', // Gálatas
  49: 'efeso-cidade', // Efésios
  50: 'filipos-prisao', // Filipenses
  51: 'paulo-escrevendo', // Colossenses
  54: 'efeso-escola', // 1 Timóteo
  55: 'paulo-carcere', // 2 Timóteo
  56: 'bons-portos', // Tito
  57: 'roma-casa', // Filemom
  58: 'ascensao', // Hebreus
  59: 'concilio-jerusalem', // Tiago
  60: 'pedro-sermao', // 1 Pedro
  61: 'transfiguracao', // 2 Pedro
  62: 'ultima-ceia', // 1 João
  66: 'nova-jerusalem', // Apocalipse
};

// A ilustração de cada época e de cada acontecimento da linha do tempo vem de assets/data/linha_tempo.json;
// a de cada parte dos livros do Novo Testamento, de assets/data/nt_livros.json.

/// Ilustração de cada quadro na entrada do Panorama, na ordem em que aparecem.
const hubArt = <String>[
  'criacao-luz', // Linha do tempo
  'abraao-estrelas', // A família de Abraão
  'davi-coroado', // Reis de Israel e Judá
  'carmelo-fogo', // Os profetas
  'tabernaculo', // O tabernáculo
  'esdras-lei', // Os 66 livros
];
