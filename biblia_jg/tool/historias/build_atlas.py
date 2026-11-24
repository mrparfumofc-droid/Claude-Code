"""Gera assets/data/map_stories.json (Atlas bíblico): mantém "Reinos e impérios" e acrescenta
os mapas de Paulo, das tribos, do reino dividido, da terra de Jesus, de Jerusalém e dos exílios.
Coordenadas e limites são aproximados (reconstituição didática)."""
import json, pathlib

REPO = pathlib.Path(r"D:\Claude Code\biblia-app-repo\biblia_jg")
path = REPO / "assets" / "data" / "map_stories.json"
old = json.loads(path.read_text(encoding="utf-8"))
imperios = next(s for s in old if s["id"] == "imperios")


def P(pt, lat, lon, z, t, d, r=""):
    return {"pt": pt, "c": [lat, lon], "z": z, "t": t, "d": d, "r": r}


ANTIOQUIA = [36.202, 36.160]
JERUSALEM = [31.778, 35.235]
CESAREIA = [32.500, 34.892]
EFESO = [37.939, 27.341]
TROADE = [39.752, 26.158]
FILIPOS = [41.013, 24.286]
TESSALONICA = [40.640, 22.944]
BEREIA = [40.524, 22.203]
CORINTO = [37.906, 22.879]

viagem1 = [ANTIOQUIA, [36.124, 35.922], [35.185, 33.902], [34.757, 32.407], [36.961, 30.854], [38.306, 31.189],
           [37.872, 32.492], [37.578, 32.453], [37.349, 33.362], [37.578, 32.453], [37.872, 32.492], [38.306, 31.189],
           [36.961, 30.854], [36.885, 30.703], [35.90, 33.00], [36.124, 35.922], ANTIOQUIA]
viagem2 = [ANTIOQUIA, [36.917, 34.892], [37.349, 33.362], [37.578, 32.453], [37.872, 32.492], [38.75, 30.55],
           [39.55, 28.20], TROADE, [40.45, 25.58], [40.939, 24.412], FILIPOS, [40.82, 23.85], TESSALONICA, BEREIA,
           [40.27, 22.62], [39.20, 23.55], [38.05, 24.25], [37.972, 23.726], CORINTO, [37.885, 22.993],
           [37.55, 25.40], EFESO, [36.44, 28.22], [34.55, 32.00], CESAREIA, JERUSALEM, ANTIOQUIA]
viagem3 = [ANTIOQUIA, [36.917, 34.892], [37.872, 32.492], [38.306, 31.189], [37.836, 29.108], EFESO, [38.9, 26.9],
           TROADE, [40.939, 24.412], FILIPOS, TESSALONICA, BEREIA, [39.36, 22.40], [38.25, 22.60], CORINTO,
           [38.25, 22.60], [39.36, 22.40], BEREIA, TESSALONICA, FILIPOS, [40.939, 24.412], TROADE, [39.490, 26.337],
           [39.105, 26.555], [37.75, 26.98], [37.530, 27.278], [36.89, 27.29], [36.44, 28.22], [36.260, 29.314],
           [34.30, 32.40], [33.270, 35.196], [32.927, 35.082], CESAREIA, JERUSALEM]
viagem_roma = [CESAREIA, [33.560, 35.371], [35.85, 34.60], [36.05, 32.40], [36.259, 29.985], [36.686, 27.374],
               [35.30, 26.32], [34.928, 24.800], [34.84, 24.08], [35.10, 20.00], [35.95, 14.40], [37.075, 15.287],
               [38.111, 15.647], [40.823, 14.122], [41.892, 12.485]]

paulo = {
    "id": "paulo-todas", "titulo": "As viagens de Paulo", "subtitulo": "As quatro rotas num só mapa",
    "cor": "FFFFD54F", "rota": False,
    "linhas": [
        {"nome": "1ª viagem", "cor": "FF4FC3F7", "pontos": viagem1},
        {"nome": "2ª viagem", "cor": "FFBA68C8", "pontos": viagem2},
        {"nome": "3ª viagem", "cor": "FF81C784", "pontos": viagem3},
        {"nome": "Viagem a Roma", "cor": "FFFF8A65", "pontos": viagem_roma},
    ],
    "passos": [
        P("Antioquia da Síria", 36.202, 36.160, 5.0, "O ponto de partida",
          "As três viagens missionárias saíram da igreja de Antioquia. Em cerca de dez anos, Paulo percorreu perto de quinze mil quilômetros a pé e de navio.",
          "At 13:1-3"),
        P("Chipre e Galácia", 37.0, 32.6, 6.3, "1ª viagem (azul)",
          "Com Barnabé: Chipre, Perge, Antioquia da Pisídia, Icônio, Listra e Derbe. Na volta, visitaram cada igreja e escolheram presbíteros.",
          "At 14:21-23"),
        P("Macedônia e Grécia", 39.3, 24.2, 6.0, "2ª viagem (roxo)",
          "Com Silas e Timóteo: da Ásia Menor à Europa. Filipos, Tessalônica, Bereia, Atenas e um ano e meio em Corinto.",
          "At 16:9-10"),
        P("Éfeso", 37.939, 27.341, 6.5, "3ª viagem (verde)",
          "Quase três anos em Éfeso, de onde a palavra se espalhou por toda a Ásia. Depois Macedônia, Grécia e a despedida em Mileto.",
          "At 19:10"),
        P("Malta", 35.95, 14.40, 5.5, "Viagem a Roma (laranja)",
          "Preso, Paulo embarcou em Cesareia. Depois da tempestade e do naufrágio em Malta, chegou a Roma e pregou ali por dois anos.",
          "At 28:30-31"),
        P("Roma", 41.892, 12.485, 4.6, "Do Oriente à capital do império",
          "De Jerusalém até o Ilírico, e depois em Roma: o evangelho chegou ao centro do mundo da época.",
          "Rm 15:19"),
    ],
}

cartas = {
    "id": "cartas-paulo", "titulo": "As cartas de Paulo", "subtitulo": "Para quem cada carta foi escrita",
    "cor": "FFD4A017", "rota": False,
    "passos": [
        P("Roma", 41.892, 12.485, 5.5, "Romanos",
          "Escrita provavelmente de Corinto, antes de Paulo conhecer a igreja de Roma. O evangelho é o poder de Deus para a salvação de todo aquele que crê.",
          "Rm 1:16-17"),
        P("Corinto", 37.906, 22.879, 7.0, "1 e 2 Coríntios",
          "Uma igreja cheia de dons e de problemas. Paulo trata de divisões, do culto, da ceia, do amor e da ressurreição.",
          "1Co 13:13"),
        P("Galácia", 38.0, 32.4, 6.5, "Gálatas",
          "Às igrejas da Galácia, como Icônio, Listra e Derbe: o homem é justificado pela fé em Cristo, e não pelas obras da lei.",
          "Gl 2:16"),
        P("Éfeso", 37.939, 27.341, 7.5, "Efésios; 1 e 2 Timóteo",
          "Efésios fala da igreja como corpo de Cristo. Timóteo cuidava da igreja de Éfeso quando recebeu as duas cartas de seu pai na fé.",
          "Ef 2:8-9"),
        P("Filipos", 41.013, 24.286, 7.5, "Filipenses",
          "A carta da alegria, escrita na prisão para a primeira igreja da Europa, nascida na casa de Lídia.",
          "Fp 4:4"),
        P("Colossos", 37.787, 29.262, 7.5, "Colossenses e Filemom",
          "Cristo é a cabeça de todas as coisas. Filemom, morador de Colossos, é chamado a receber Onésimo como irmão amado.",
          "Cl 1:18"),
        P("Tessalônica", 40.640, 22.944, 7.5, "1 e 2 Tessalonicenses",
          "Entre as primeiras cartas de Paulo: consolo na perseguição e esperança na vinda do Senhor.",
          "1Ts 4:16-17"),
        P("Creta", 35.24, 24.90, 7.0, "Tito",
          "Tito ficou em Creta para pôr em ordem o que faltava e estabelecer presbíteros em cada cidade.",
          "Tt 1:5"),
    ],
}

tribos = {
    "id": "doze-tribos", "titulo": "As doze tribos de Israel", "subtitulo": "A divisão da terra nos dias de Josué",
    "cor": "FFAED581", "rota": False,
    "regioes": [
        {"nome": "ASER", "cor": "FF4DB6AC", "pontos": [[33.30, 35.15], [33.30, 35.40], [33.00, 35.38], [32.82, 35.25], [32.70, 35.10], [32.72, 34.95], [32.90, 35.05], [33.10, 35.10]]},
        {"nome": "NAFTALI", "cor": "FFFFB74D", "pontos": [[33.30, 35.40], [33.30, 35.63], [32.88, 35.62], [32.72, 35.56], [32.74, 35.42], [32.86, 35.40], [33.00, 35.38]]},
        {"nome": "ZEBULOM", "cor": "FFBA68C8", "pontos": [[32.86, 35.40], [32.74, 35.42], [32.66, 35.36], [32.64, 35.16], [32.70, 35.10], [32.82, 35.25]]},
        {"nome": "ISSACAR", "cor": "FF90CAF9", "pontos": [[32.74, 35.42], [32.72, 35.56], [32.50, 35.57], [32.45, 35.40], [32.52, 35.22], [32.64, 35.16], [32.66, 35.36]]},
        {"nome": "MANASSÉS", "cor": "FFE57373", "pontos": [[32.70, 35.10], [32.64, 35.16], [32.52, 35.22], [32.45, 35.40], [32.50, 35.57], [32.20, 35.55], [32.18, 35.20], [32.20, 34.85], [32.55, 34.90], [32.72, 34.95]]},
        {"nome": "EFRAIM", "cor": "FFFFF176", "pontos": [[32.20, 34.85], [32.18, 35.20], [32.20, 35.55], [31.95, 35.52], [31.93, 35.25], [31.95, 34.95], [32.10, 34.80]]},
        {"nome": "DÃ", "cor": "FFA1887F", "pontos": [[32.10, 34.80], [31.95, 34.95], [31.85, 35.00], [31.78, 34.65]]},
        {"nome": "BENJAMIM", "cor": "FFF48FB1", "pontos": [[31.95, 34.98], [31.93, 35.25], [31.95, 35.52], [31.78, 35.50], [31.76, 35.22], [31.80, 35.03]]},
        {"nome": "JUDÁ", "cor": "FF7986CB", "pontos": [[31.85, 35.00], [31.80, 35.03], [31.76, 35.22], [31.78, 35.50], [31.30, 35.40], [31.05, 35.35], [30.90, 34.95], [31.25, 34.35], [31.60, 34.50], [31.78, 34.65]], "rotulo": [31.55, 35.10]},
        {"nome": "SIMEÃO", "cor": "FF80CBC4", "pontos": [[31.38, 34.55], [31.42, 34.98], [31.10, 35.00], [31.05, 34.60]]},
        {"nome": "RÚBEN", "cor": "FFFFAB91", "pontos": [[31.80, 35.57], [31.80, 35.95], [31.45, 35.95], [31.45, 35.58]]},
        {"nome": "GADE", "cor": "FFC5E1A5", "pontos": [[32.55, 35.60], [32.55, 36.00], [31.80, 35.95], [31.80, 35.57]]},
        {"nome": "MANASSÉS (LESTE)", "cor": "FFEF9A9A", "pontos": [[33.20, 35.66], [33.20, 36.30], [32.55, 36.30], [32.55, 35.60], [32.85, 35.66]]},
    ],
    "passos": [
        P("Canaã", 32.2, 35.5, 7.2, "A herança das tribos",
          "Depois da conquista, Josué repartiu a terra por sortes entre as tribos, em Siló. Os limites deste mapa são aproximados.",
          "Js 18:10"),
        P("Galileia", 32.95, 35.40, 8.6, "As tribos do norte",
          "Aser junto ao mar, Naftali e Zebulom na Galileia e Issacar no vale de Jezreel. Séculos depois, Jesus cresceria em terras de Zebulom e Naftali.",
          "Mt 4:13-16"),
        P("Siquém", 32.213, 35.282, 8.6, "Os filhos de José",
          "Efraim e Manassés, filhos de José, receberam a região montanhosa do centro, com Siquém e Siló.",
          "Js 16:4"),
        P("Jerusalém", 31.80, 35.15, 8.8, "Benjamim e Dã",
          "Benjamim ficou com uma faixa pequena entre Efraim e Judá, onde estão Jericó e Gibeá. Dã recebeu a planície perto de Jope e depois migrou para o extremo norte.",
          "Js 18:11"),
        P("Hebrom", 31.532, 35.098, 8.3, "Judá e Simeão",
          "Judá recebeu o sul, com Hebrom e Belém; a herança de Simeão ficou no meio da herança de Judá, ao redor de Berseba.",
          "Js 19:1"),
        P("Além do Jordão", 32.2, 35.85, 8.0, "As tribos do outro lado do rio",
          "Rúben, Gade e metade de Manassés pediram as terras de pasto a leste do Jordão, e mesmo assim ajudaram os irmãos na conquista.",
          "Js 22:1-4"),
        P("Siló", 32.056, 35.290, 9.5, "Levi: o Senhor é a sua herança",
          "A tribo de Levi não recebeu território. Os levitas ganharam quarenta e oito cidades espalhadas por todas as tribos.",
          "Js 13:33"),
    ],
}

reino = {
    "id": "reino-dividido", "titulo": "O reino dividido", "subtitulo": "Israel ao norte, Judá ao sul",
    "cor": "FF9575CD", "rota": False,
    "regioes": [
        {"nome": "ISRAEL", "cor": "FF4FC3F7", "pontos": [[33.30, 35.15], [33.30, 35.65], [32.60, 35.62], [32.55, 36.00], [31.95, 35.95], [31.95, 35.52], [31.95, 34.98], [32.10, 34.78], [32.70, 34.93], [33.10, 35.08]], "rotulo": [32.45, 35.30]},
        {"nome": "JUDÁ", "cor": "FFFFD54F", "pontos": [[31.95, 34.98], [31.95, 35.52], [31.30, 35.42], [31.00, 35.35], [30.90, 34.95], [31.25, 34.45], [31.75, 34.75]], "rotulo": [31.45, 35.05]},
        {"nome": "FILÍSTIA", "cor": "FFA1887F", "pontos": [[31.95, 34.62], [31.95, 34.80], [31.60, 34.68], [31.25, 34.45], [31.28, 34.22]]},
        {"nome": "FENÍCIA", "cor": "FFBA68C8", "pontos": [[33.30, 35.12], [33.30, 35.38], [33.95, 35.65], [33.95, 35.45]]},
        {"nome": "SÍRIA", "cor": "FFE57373", "pontos": [[33.30, 35.85], [33.85, 36.00], [33.85, 36.70], [33.20, 36.70]]},
        {"nome": "AMOM", "cor": "FF81C784", "pontos": [[32.15, 36.02], [32.15, 36.35], [31.80, 36.35], [31.80, 35.98]]},
        {"nome": "MOABE", "cor": "FFFFB74D", "pontos": [[31.45, 35.58], [31.45, 35.98], [31.00, 35.92], [31.00, 35.50]]},
        {"nome": "EDOM", "cor": "FFEF9A9A", "pontos": [[30.98, 35.42], [30.98, 35.90], [30.20, 35.75], [30.20, 35.20]]},
    ],
    "passos": [
        P("Siquém", 32.213, 35.282, 7.5, "O reino se divide",
          "Depois de Salomão, Roboão recusou aliviar o jugo do povo. Dez tribos seguiram Jeroboão; só Judá e Benjamim ficaram com a casa de Davi.",
          "1Rs 12:16-20"),
        P("Betel", 31.923, 35.241, 9.0, "Os bezerros de ouro",
          "Para que o povo não subisse a Jerusalém, Jeroboão pôs um bezerro de ouro em Betel e outro em Dã.",
          "1Rs 12:28-30"),
        P("Samaria", 32.276, 35.190, 9.0, "Samaria, capital do norte",
          "O rei Onri comprou o monte de Samaria e ali edificou a capital de Israel. Elias e Eliseu profetizaram neste reino.",
          "1Rs 16:24"),
        P("Jerusalém", 31.778, 35.235, 9.0, "Jerusalém, capital de Judá",
          "No sul, os descendentes de Davi continuaram reinando em Jerusalém, onde estava o templo. Isaías e Jeremias profetizaram aqui.",
          "1Rs 14:21"),
        P("Samaria", 32.276, 35.190, 7.0, "A queda de Israel",
          "No ano 722 antes de Cristo, a Assíria tomou Samaria e levou o povo do norte para o cativeiro.",
          "2Rs 17:6"),
        P("Jerusalém", 31.778, 35.235, 7.0, "A queda de Judá",
          "Em 586 antes de Cristo, Nabucodonosor queimou o templo e levou Judá para a Babilônia.",
          "2Rs 25:8-11"),
    ],
}

terra = {
    "id": "terra-jesus", "titulo": "A terra nos dias de Jesus", "subtitulo": "Galileia, Samaria, Judeia e as regiões vizinhas",
    "cor": "FF4DD0E1", "rota": False,
    "regioes": [
        {"nome": "GALILEIA", "cor": "FF81C784", "pontos": [[33.10, 35.20], [33.10, 35.62], [32.70, 35.58], [32.55, 35.40], [32.62, 35.12], [32.85, 35.10]]},
        {"nome": "SAMARIA", "cor": "FFFFB74D", "pontos": [[32.62, 35.12], [32.55, 35.40], [32.45, 35.55], [32.00, 35.50], [32.00, 34.95], [32.45, 34.90]]},
        {"nome": "JUDEIA", "cor": "FF7986CB", "pontos": [[32.00, 34.95], [32.00, 35.50], [31.30, 35.42], [31.20, 34.85], [31.60, 34.55], [31.95, 34.72]]},
        {"nome": "PEREIA", "cor": "FFF48FB1", "pontos": [[32.35, 35.58], [32.35, 35.85], [31.45, 35.80], [31.45, 35.58]]},
        {"nome": "DECÁPOLIS", "cor": "FFCE93D8", "pontos": [[32.85, 35.66], [32.85, 36.20], [32.35, 36.10], [32.35, 35.58], [32.60, 35.60]]},
        {"nome": "FENÍCIA", "cor": "FF4FC3F7", "pontos": [[33.10, 35.08], [33.10, 35.22], [33.70, 35.50], [33.70, 35.33]]},
        {"nome": "ITUREIA", "cor": "FFA1887F", "pontos": [[33.35, 35.64], [33.35, 36.30], [32.87, 36.22], [32.87, 35.68]]},
        {"nome": "IDUMEIA", "cor": "FFEF9A9A", "pontos": [[31.20, 34.85], [31.30, 35.42], [30.90, 35.30], [30.90, 34.70]]},
    ],
    "passos": [
        P("Galileia", 32.85, 35.40, 8.3, "Galileia",
          "Nazaré, Caná e Cafarnaum. Aqui Jesus cresceu, chamou os discípulos e fez a maior parte dos seus milagres.",
          "Mt 4:23"),
        P("Sicar", 32.209, 35.285, 8.8, "Samaria",
          "Judeus e samaritanos não se davam. Mesmo assim, Jesus passou por Samaria e conversou com uma mulher junto ao poço de Jacó.",
          "Jo 4:4-9"),
        P("Jerusalém", 31.778, 35.235, 8.5, "Judeia",
          "Belém, Betânia, Jericó e Jerusalém, com o templo. Aqui Jesus nasceu, foi crucificado e ressuscitou.",
          "Mt 2:1"),
        P("Além do Jordão", 31.95, 35.70, 8.5, "Pereia",
          "A região além do Jordão, onde João batizava e por onde Jesus passou ensinando no caminho para Jerusalém.",
          "Mt 19:1-2"),
        P("Decápolis", 32.60, 35.90, 8.5, "Decápolis",
          "Dez cidades de cultura grega. Ali o homem liberto dos demônios anunciou o que Jesus lhe tinha feito.",
          "Mc 5:20"),
        P("Tiro", 33.270, 35.196, 8.3, "Tiro e Sidom",
          "Na Fenícia, terra de gentios, Jesus atendeu ao pedido de uma mãe siro-fenícia de grande fé.",
          "Mc 7:24-30"),
        P("Cesareia de Filipe", 33.248, 35.694, 8.8, "Cesareia de Filipe",
          "Ao pé do monte Hermom, Pedro declarou: Tu és o Cristo, o Filho do Deus vivo.",
          "Mt 16:13-16"),
    ],
}

jerusalem = {
    "id": "jerusalem-jesus", "titulo": "Jerusalém nos dias de Jesus", "subtitulo": "Os lugares da última semana",
    "cor": "FFFFB300", "rota": False,
    "passos": [
        P("Templo", 31.7780, 35.2354, 15.0, "O templo",
          "O centro da vida de Israel, ampliado por Herodes. Jesus ensinou em seus pátios e expulsou os cambistas. Os locais deste mapa seguem a tradição e a arqueologia; alguns são aproximados.",
          "Mt 21:12-14"),
        P("Tanque de Betesda", 31.7814, 35.2365, 15.5, "O tanque de Betesda",
          "Junto à Porta das Ovelhas, Jesus curou um homem enfermo havia trinta e oito anos.",
          "Jo 5:2-9"),
        P("Tanque de Siloé", 31.7707, 35.2350, 15.5, "O tanque de Siloé",
          "O cego de nascença lavou-se aqui, como Jesus mandou, e voltou vendo.",
          "Jo 9:7"),
        P("Cenáculo", 31.7717, 35.2290, 15.5, "O cenáculo",
          "Num grande cenáculo mobiliado, Jesus comeu a Páscoa com os discípulos e instituiu a ceia.",
          "Lc 22:12-20"),
        P("Getsêmani", 31.7794, 35.2397, 15.5, "O Getsêmani",
          "Do outro lado do ribeiro de Cedrom, no monte das Oliveiras, Jesus orou em agonia e foi preso.",
          "Mt 26:36"),
        P("Casa de Caifás", 31.7713, 35.2312, 15.5, "A casa do sumo sacerdote",
          "Jesus foi interrogado de noite, e Pedro o negou três vezes no pátio.",
          "Mt 26:57-58"),
        P("Pretório", 31.7802, 35.2340, 15.5, "O pretório de Pilatos",
          "Diante do governador romano, Jesus foi açoitado e entregue para ser crucificado.",
          "Jo 19:13-16"),
        P("Gólgota", 31.7785, 35.2296, 15.5, "O Gólgota e o sepulcro",
          "Fora dos muros da cidade naquele tempo, o lugar da Caveira. Ali perto havia um jardim com um sepulcro novo.",
          "Jo 19:17-18"),
        P("Monte das Oliveiras", 31.7780, 35.2450, 14.5, "O monte das Oliveiras",
          "Quarenta dias depois da ressurreição, Jesus subiu aos céus à vista dos discípulos.",
          "At 1:9-12"),
    ],
}

exilios = {
    "id": "exilios", "titulo": "Os exílios e a volta", "subtitulo": "Da Terra Prometida à Assíria e à Babilônia",
    "cor": "FF8D6E63", "rota": False,
    "linhas": [
        {"nome": "Israel para a Assíria (722 a.C.)", "cor": "FFCE93D8",
         "pontos": [[32.276, 35.190], [33.513, 36.292], [34.46, 36.55], [35.13, 36.75], [36.20, 37.16], [36.84, 40.07], [36.359, 43.153]]},
        {"nome": "Judá para a Babilônia (586 a.C.) e a volta", "cor": "FF90CAF9",
         "pontos": [JERUSALEM, [33.20, 35.90], [34.40, 36.45], [35.05, 36.85], [35.95, 38.90], [34.75, 40.73], [33.60, 42.80], [32.542, 44.421]]},
    ],
    "passos": [
        P("Samaria", 32.276, 35.190, 6.0, "O norte é levado",
          "O rei da Assíria tomou Samaria e transportou Israel para Hala, Habor e as cidades dos medos.",
          "2Rs 17:6"),
        P("Nínive", 36.359, 43.153, 5.8, "A Assíria",
          "Um império temido pela crueldade. Para a sua capital, Nínive, Deus havia enviado Jonas com um chamado ao arrependimento.",
          "Jn 3:1-5"),
        P("Jerusalém", 31.778, 35.235, 6.0, "Jerusalém cai",
          "Nabucodonosor queimou o templo, derrubou os muros e levou o povo. Jeremias havia avisado por anos.",
          "2Rs 25:8-11"),
        P("Babilônia", 32.542, 44.421, 5.8, "Junto aos rios da Babilônia",
          "Setenta anos longe de casa. Ali viveram Daniel e Ezequiel, e o povo aprendeu a cantar e orar em terra estranha.",
          "Sl 137:1"),
        P("Susã", 32.190, 48.258, 5.8, "Sob os persas",
          "A Pérsia venceu a Babilônia. Em Susã viveram Ester e Mardoqueu, e Neemias serviu como copeiro do rei.",
          "Ne 1:1"),
        P("Jerusalém", 31.778, 35.235, 5.2, "A volta",
          "Ciro deixou os judeus voltarem. Eles reconstruíram o altar, o templo e, com Neemias, os muros.",
          "Ed 1:1-3"),
    ],
}

out = [paulo, cartas, jerusalem, terra, tribos, reino, exilios, imperios]
path.write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
print(len(out), "mapas no atlas;", path.stat().st_size // 1024, "KB")
