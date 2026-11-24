"""Gera assets/data/panorama.json do app Bíblia JG: árvore da família de Abraão, reis de Israel e
Judá, profetas e as fichas dos 66 livros (livros_a/b/c.json). Texto próprio do app; datas aproximadas."""
import json, pathlib

here = pathlib.Path(__file__).parent
REPO = pathlib.Path(r"D:\Claude Code\biblia-app-repo\biblia_jg")

# ------------------------------------------------------------------ árvore
COL, X0 = 124, 78          # largura de cada coluna e centro da coluna 0
ROW = {"A": 70, "B": 200, "C": 330, "D": 460, "E": 580, "F": 668}
nodes, edges = [], []


def node(i, nome, tipo, col, row, texto, refs, sub=""):
    y = ROW[row] if isinstance(row, str) else row
    nodes.append({"id": i, "nome": nome, "tipo": tipo, "x": round(X0 + col * COL), "y": y, "sub": sub,
                  "texto": texto, "refs": refs})


node("agar", "Agar", "mae", 1.5, "A", "Serva egípcia de Sara. Deu a Abraão o filho Ismael. No deserto, Deus a viu e a socorreu.",
     ["Gn 16:1-4", "Gn 16:13", "Gn 21:17-19"], "serva de Sara")
node("abraao", "Abraão", "patriarca", 3.5, "A",
     "Chamado por Deus, creu na promessa de uma terra e de uma descendência. Tinha cem anos quando Isaque nasceu e viveu cento e setenta e cinco.",
     ["Gn 12:1-3", "Gn 15:5-6", "Gn 21:5", "Gn 25:7"], "o pai da fé")
node("sara", "Sara", "mae", 5.5, "A", "Esposa de Abraão. Era estéril e riu ao ouvir a promessa, mas deu à luz Isaque aos noventa anos.",
     ["Gn 17:15-17", "Gn 21:1-3"], "esposa")
node("quetura", "Quetura", "mae", 8.5, "A", "Mulher que Abraão tomou depois. Dela nasceram seis filhos, entre eles Midiã.",
     ["Gn 25:1-2"], "esposa, depois de Sara")
node("ismael", "Ismael", "filho", 1.5, "B", "Filho de Abraão e Agar. Deus prometeu fazer dele uma grande nação; dele vieram doze príncipes.",
     ["Gn 17:20", "Gn 25:12-16"], "doze príncipes")
node("isaque", "Isaque", "patriarca", 3.5, "B",
     "O filho da promessa. Seu nome lembra o riso de Abraão e de Sara. Foi poupado no monte Moriá e herdou a aliança.",
     ["Gn 21:3-6", "Gn 22:9-12", "Gn 26:3-4"], "o filho da promessa")
node("rebeca", "Rebeca", "mae", 5.5, "B", "Esposa de Isaque, trazida de Harã. Mãe dos gêmeos Esaú e Jacó.",
     ["Gn 24:67", "Gn 25:21-24"], "esposa")
node("midia", "Midiã e irmãos", "filho", 8.5, "B",
     "Os filhos de Quetura receberam presentes e foram enviados para o Oriente. Dos midianitas veio Jetro, sogro de Moisés.",
     ["Gn 25:5-6", "Êx 3:1"], "povos do Oriente")
node("esau", "Esaú", "filho", 2.0, "C", "O gêmeo mais velho. Vendeu o direito de primogenitura por um prato de lentilhas. Dele vieram os edomitas.",
     ["Gn 25:29-34", "Gn 36:9"], "Edom")
node("jaco", "Jacó", "patriarca", 5.5, "C",
     "O gêmeo mais novo. Recebeu a bênção, lutou com Deus em Peniel e teve o nome mudado para Israel. Seus doze filhos deram origem às doze tribos.",
     ["Gn 28:13-15", "Gn 32:28", "Gn 35:22-26"], "Israel")
node("lia", "Lia", "mae", 2.5, "D", "Primeira esposa de Jacó, filha de Labão. Mãe de seis filhos e de Diná.",
     ["Gn 29:31-35", "Gn 30:17-21"], "esposa")
node("zilpa", "Zilpa", "mae", 6.5, "D", "Serva de Lia. Mãe de Gade e Aser.", ["Gn 30:9-13"], "serva de Lia")
node("bila", "Bila", "mae", 8.5, "D", "Serva de Raquel. Mãe de Dã e Naftali.", ["Gn 30:3-8"], "serva de Raquel")
node("raquel", "Raquel", "mae", 10.5, "D",
     "A esposa amada de Jacó. Mãe de José e de Benjamim; morreu no parto de Benjamim, perto de Belém.",
     ["Gn 30:22-24", "Gn 35:16-19"], "esposa")

SONS = [  # (id, nome, ordem de nascimento, mãe, texto, refs, descendentes)
    ("ruben", "Rúben", 1, "lia", "O primogênito de Jacó. Por causa do seu pecado, perdeu a primazia entre os irmãos.",
     ["Gn 29:32", "Gn 49:3-4"], []),
    ("simeao", "Simeão", 2, "lia", "Segundo filho de Lia. Sua tribo recebeu herança no meio do território de Judá.",
     ["Gn 29:33", "Js 19:1"], []),
    ("levi", "Levi", 3, "lia", "A tribo separada para o sacerdócio e para o serviço do tabernáculo. Não recebeu território: o Senhor é a sua herança.",
     ["Gn 29:34", "Nm 3:5-9", "Js 13:33"],
     [("Moisés", "Libertador de Israel e mediador da lei.", "Êx 2:1-10"), ("Arão", "Irmão de Moisés, o primeiro sumo sacerdote.", "Êx 28:1"),
      ("Samuel", "Profeta e juiz; ungiu Saul e Davi.", "1Cr 6:33-34"), ("Esdras", "Sacerdote e escriba que ensinou a lei depois do exílio.", "Ed 7:1-6"),
      ("João Batista", "Filho do sacerdote Zacarias; preparou o caminho do Senhor.", "Lc 1:5"),
      ("Barnabé", "Levita de Chipre, companheiro de Paulo.", "At 4:36")]),
    ("juda", "Judá", 4, "lia", "Recebeu de Jacó a promessa do cetro: de Judá viriam os reis e o Messias.",
     ["Gn 29:35", "Gn 49:10"],
     [("Calebe", "Um dos dois espias que confiaram em Deus.", "Nm 13:6"), ("Boaz", "Resgatador de Rute, bisavô de Davi.", "Rt 4:18-22"),
      ("Davi", "O rei segundo o coração de Deus.", "1Sm 17:12"), ("Salomão", "Filho de Davi; construiu o templo.", "2Sm 12:24"),
      ("Daniel", "Levado jovem para a Babilônia, dos filhos de Judá.", "Dn 1:6"),
      ("Jesus", "O Leão da tribo de Judá, filho de Davi.", "Mt 1:1-3")]),
    ("gade", "Gade", 7, "zilpa", "Primeiro filho de Zilpa. A tribo ficou a leste do Jordão.", ["Gn 30:11", "Nm 32:33"], []),
    ("aser", "Aser", 8, "zilpa", "Segundo filho de Zilpa. A tribo recebeu a faixa do litoral ao norte.",
     ["Gn 30:13", "Js 19:24"], [("Ana", "Profetisa que viu o menino Jesus no templo.", "Lc 2:36")]),
    ("da", "Dã", 5, "bila", "Primeiro filho de Bila. A tribo migrou para o extremo norte.",
     ["Gn 30:6", "Jz 18:29"], [("Sansão", "Juiz de força extraordinária.", "Jz 13:24")]),
    ("naftali", "Naftali", 6, "bila", "Segundo filho de Bila. Sua terra, na Galileia, veria uma grande luz.",
     ["Gn 30:8", "Mt 4:13-16"], [("Baraque", "Venceu Sísera com a profetisa Débora.", "Jz 4:6")]),
    ("issacar", "Issacar", 9, "lia", "Quinto filho de Lia. A tribo ficou no vale de Jezreel.",
     ["Gn 30:18", "Js 19:17"], [("Tola", "Juiz de Israel por vinte e três anos.", "Jz 10:1")]),
    ("zebulom", "Zebulom", 10, "lia", "Sexto filho de Lia. A tribo ficou na baixa Galileia.",
     ["Gn 30:20", "Js 19:10"], [("Elom", "Juiz de Israel por dez anos.", "Jz 12:11")]),
    ("jose", "José", 11, "raquel",
     "Vendido pelos irmãos, tornou-se governador do Egito e salvou a família. Seus filhos Efraim e Manassés foram contados como duas tribos.",
     ["Gn 30:24", "Gn 41:41", "Gn 48:5"],
     [("Manassés", "Filho mais velho de José; meia tribo de cada lado do Jordão.", "Gn 41:51"),
      ("Gideão", "Juiz, da tribo de Manassés.", "Jz 6:15"), ("Efraim", "Filho mais novo de José, abençoado na frente do irmão.", "Gn 48:19-20"),
      ("Josué", "Sucessor de Moisés, da tribo de Efraim.", "Nm 13:8"),
      ("Jeroboão I", "Primeiro rei do reino do norte, efraimita.", "1Rs 11:26")]),
    ("benjamim", "Benjamim", 12, "raquel", "O caçula, nascido perto de Belém. Sua tribo ficou ao lado de Judá.",
     ["Gn 35:18", "Js 18:11"],
     [("Saul", "O primeiro rei de Israel.", "1Sm 9:1-2"), ("Jônatas", "Filho de Saul e amigo de Davi.", "1Sm 14:1"),
      ("Mardoqueu", "Primo de Ester, benjamita.", "Et 2:5"), ("Ester", "A rainha que intercedeu pelo seu povo.", "Et 2:7"),
      ("Paulo", "O apóstolo dos gentios, da tribo de Benjamim.", "Fp 3:5")]),
]
# Colunas: os seis de Lia, os dois de Zilpa, os dois de Bila, os dois de Raquel.
ORDER = ["ruben", "simeao", "levi", "juda", "issacar", "zebulom", "gade", "aser", "da", "naftali", "jose", "benjamim"]
by_id = {s[0]: s for s in SONS}
for col, sid in enumerate(ORDER):
    _, nome, ordem, mae, texto, refs, desc = by_id[sid]
    node(sid, nome, "tribo", col, "E", texto, refs, f"{ordem}º filho")
    edges.append({"de": [mae], "para": sid})
    for k, (dn, dt, dr) in enumerate(desc):
        did = f"{sid}-{k}"
        node(did, dn, "descendente", col, ROW["F"] + k * 36, dt, [dr])
    if desc:
        edges.append({"de": [sid], "para": f"{sid}-0", "lista": len(desc)})

edges += [
    {"de": ["abraao", "agar"], "para": "ismael"},
    {"de": ["abraao", "sara"], "para": "isaque"},
    {"de": ["quetura"], "para": "midia"},
    {"de": ["isaque", "rebeca"], "para": "esau"},
    {"de": ["isaque", "rebeca"], "para": "jaco"},
    {"de": ["jaco"], "para": "lia"}, {"de": ["jaco"], "para": "zilpa"},
    {"de": ["jaco"], "para": "bila"}, {"de": ["jaco"], "para": "raquel"},
]
casais = [["agar", "abraao"], ["abraao", "sara"], ["isaque", "rebeca"]]

tour = [
    (["abraao"], "Tudo começa com um chamado. Deus manda Abraão sair da sua terra e promete fazer dele uma grande nação.", "Gn 12:1-3"),
    (["abraao", "sara"], "Sara era estéril e já idosa. Mesmo assim, Deus prometeu que dela nasceria o herdeiro.", "Gn 17:15-17"),
    (["agar", "ismael"], "Antes de a promessa se cumprir, Sara deu a Abraão a serva Agar. Nasceu Ismael, que Deus também abençoou.", "Gn 16:15"),
    (["isaque"], "Aos cem anos de Abraão, nasceu Isaque, o filho da promessa.", "Gn 21:1-5"),
    (["isaque", "rebeca"], "Isaque casou-se com Rebeca. Depois de vinte anos de espera, ela teve gêmeos.", "Gn 25:21-26"),
    (["esau"], "Esaú, o mais velho, desprezou a primogenitura. Dele vieram os edomitas.", "Gn 25:29-34"),
    (["jaco"], "Jacó herdou a promessa. Deus mudou o seu nome para Israel.", "Gn 32:28"),
    (["lia", "ruben", "simeao", "levi", "juda", "issacar", "zebulom"], "Lia deu a Jacó seis filhos: Rúben, Simeão, Levi, Judá, Issacar e Zebulom.", "Gn 29:31-35"),
    (["zilpa", "gade", "aser", "bila", "da", "naftali"], "Das servas Bila e Zilpa nasceram Dã, Naftali, Gade e Aser.", "Gn 30:3-13"),
    (["raquel", "jose", "benjamim"], "De Raquel, a esposa amada, nasceram José e, por último, Benjamim.", "Gn 35:16-18"),
    (ORDER, "São os doze filhos de Jacó. Deles vieram as doze tribos de Israel.", "Gn 35:22-26"),
    (["levi", "levi-0", "levi-1", "levi-2", "levi-3", "levi-4", "levi-5"], "De Levi vieram Moisés, Arão e os sacerdotes, até João Batista.", "Êx 6:16-20"),
    (["juda", "juda-0", "juda-1", "juda-2", "juda-3", "juda-4", "juda-5"], "De Judá vieram Davi, os reis e, no tempo certo, Jesus, o Cristo.", "Mt 1:1-3"),
    (["abraao", "juda-5"], "A promessa feita a Abraão se cumpre em Jesus: nele são benditas todas as famílias da terra.", "Gl 3:16"),
]
arvore = {
    "largura": X0 * 2 + 11 * COL, "altura": ROW["F"] + 6 * 36 + 30,
    "nos": nodes, "ligacoes": edges, "casais": casais,
    "passos": [{"nos": n, "texto": t, "ref": r} for n, t, r in tour],
}

# ------------------------------------------------------------------ reis


def R(nome, ini, fim, anos, aval, nota, ref, profetas=""):
    return {"nome": nome, "ini": ini, "fim": fim, "anos": anos, "aval": aval, "nota": nota, "ref": ref, "profetas": profetas}


unido = [
    R("Saul", 1050, 1010, "40 anos", "misto", "O primeiro rei. Começou bem, mas desobedeceu e foi rejeitado.", "1Sm 15:22-23", "Samuel"),
    R("Davi", 1010, 970, "40 anos", "bom", "Uniu as tribos, tomou Jerusalém e recebeu a promessa de um trono eterno.", "2Sm 7:12-16", "Samuel, Natã e Gade"),
    R("Salomão", 970, 930, "40 anos", "misto", "Sabedoria, riqueza e o templo. No fim, o coração se desviou.", "1Rs 11:4", "Natã e Aías"),
]
israel = [
    R("Jeroboão I", 930, 909, "22 anos", "mau", "Fez dois bezerros de ouro, em Betel e em Dã.", "1Rs 12:28-30", "Aías"),
    R("Nadabe", 909, 908, "2 anos", "mau", "Andou no caminho do pai; foi morto por Baasa.", "1Rs 15:25-28"),
    R("Baasa", 908, 886, "24 anos", "mau", "Exterminou a casa de Jeroboão e repetiu os seus pecados.", "1Rs 15:33-34", "Jeú, filho de Hanani"),
    R("Elá", 886, 885, "2 anos", "mau", "Assassinado por Zinri enquanto se embriagava.", "1Rs 16:8-10"),
    R("Zinri", 885, 885, "7 dias", "mau", "Reinou sete dias e morreu no palácio em chamas.", "1Rs 16:15-19"),
    R("Onri", 885, 874, "12 anos", "mau", "Comprou o monte e fundou Samaria, a nova capital.", "1Rs 16:23-26"),
    R("Acabe", 874, 853, "22 anos", "mau", "Com Jezabel, levou Israel ao culto de Baal.", "1Rs 16:29-33", "Elias e Micaías"),
    R("Acazias", 853, 852, "2 anos", "mau", "Consultou Baal-Zebube e morreu sem filhos.", "2Rs 1:2-4", "Elias"),
    R("Jorão", 852, 841, "12 anos", "mau", "Irmão de Acazias; morto por Jeú.", "2Rs 3:1-3", "Eliseu"),
    R("Jeú", 841, 814, "28 anos", "misto", "Destruiu o culto a Baal, mas manteve os bezerros de ouro.", "2Rs 10:28-31", "Eliseu"),
    R("Jeoacaz", 814, 798, "17 anos", "mau", "Oprimido pela Síria; clamou e Deus deu alívio.", "2Rs 13:1-5"),
    R("Jeoás", 798, 782, "16 anos", "mau", "Visitou Eliseu antes da morte do profeta.", "2Rs 13:10-14", "Eliseu"),
    R("Jeroboão II", 793, 753, "41 anos", "mau", "Tempo de prosperidade e de injustiça.", "2Rs 14:23-27", "Jonas, Amós e Oseias"),
    R("Zacarias", 753, 752, "6 meses", "mau", "Último da casa de Jeú; assassinado.", "2Rs 15:8-12"),
    R("Salum", 752, 752, "1 mês", "mau", "Reinou um mês e foi morto por Menaém.", "2Rs 15:13-15"),
    R("Menaém", 752, 742, "10 anos", "mau", "Pagou tributo ao rei da Assíria.", "2Rs 15:17-20", "Oseias"),
    R("Pecaías", 742, 740, "2 anos", "mau", "Morto por seu oficial Peca.", "2Rs 15:23-25"),
    R("Peca", 740, 732, "20 anos", "mau", "No seu tempo a Assíria levou parte do povo. Os vinte anos são contados desde 752.", "2Rs 15:27-29", "Oseias"),
    R("Oseias", 732, 722, "9 anos", "mau", "O último rei. A Assíria tomou Samaria e levou Israel cativo.", "2Rs 17:1-6"),
]
juda = [
    R("Roboão", 930, 913, "17 anos", "mau", "Recusou aliviar o jugo e perdeu dez tribos.", "1Rs 12:13-16", "Semaías"),
    R("Abias", 913, 910, "3 anos", "mau", "Andou nos pecados do pai.", "1Rs 15:1-3"),
    R("Asa", 910, 869, "41 anos", "bom", "Tirou os ídolos e buscou o Senhor.", "1Rs 15:9-14", "Azarias e Hanani"),
    R("Josafá", 872, 848, "25 anos", "bom", "Mandou ensinar a lei em todas as cidades.", "2Cr 17:3-9", "Jeú e Jaaziel"),
    R("Jeorão", 853, 841, "8 anos", "mau", "Casou-se com a filha de Acabe e matou os irmãos.", "2Rs 8:16-18"),
    R("Acazias", 841, 841, "1 ano", "mau", "Seguiu os conselhos da casa de Acabe.", "2Rs 8:25-27"),
    R("Atalia", 841, 835, "6 anos", "mau", "Usurpou o trono e tentou acabar com a descendência real.", "2Rs 11:1-3"),
    R("Joás", 835, 796, "40 anos", "misto", "Reparou o templo. Depois da morte do sacerdote Joiada, desviou-se.", "2Rs 12:1-2", "Zacarias, filho de Joiada"),
    R("Amazias", 796, 767, "29 anos", "misto", "Fez o que era reto, mas não de coração inteiro.", "2Cr 25:1-2"),
    R("Uzias", 792, 740, "52 anos", "bom", "Também chamado Azarias. Prosperou enquanto buscou o Senhor; o orgulho o levou à lepra.", "2Cr 26:3-5", "Isaías e Amós"),
    R("Jotão", 750, 732, "16 anos", "bom", "Firmou os seus caminhos diante do Senhor.", "2Cr 27:1-6", "Isaías e Miqueias"),
    R("Acaz", 735, 716, "16 anos", "mau", "Fechou o templo e fez altares por toda parte.", "2Rs 16:1-4", "Isaías e Miqueias"),
    R("Ezequias", 716, 687, "29 anos", "bom", "Confiou no Senhor; Deus livrou Jerusalém dos assírios.", "2Rs 18:1-7", "Isaías"),
    R("Manassés", 697, 643, "55 anos", "mau", "O reinado mais longo e mais idólatra. Preso, humilhou-se e Deus o ouviu.", "2Cr 33:10-13"),
    R("Amom", 643, 641, "2 anos", "mau", "Não se humilhou como o pai.", "2Rs 21:19-22"),
    R("Josias", 641, 609, "31 anos", "bom", "Achou o livro da lei e fez a maior reforma.", "2Rs 22:1-2", "Jeremias, Sofonias e Hulda"),
    R("Jeoacaz", 609, 609, "3 meses", "mau", "Levado preso para o Egito.", "2Rs 23:31-34"),
    R("Jeoaquim", 609, 598, "11 anos", "mau", "Queimou o rolo de Jeremias.", "2Rs 23:36-37", "Jeremias e Habacuque"),
    R("Joaquim", 598, 597, "3 meses", "mau", "Levado para a Babilônia com dez mil cativos.", "2Rs 24:8-15"),
    R("Zedequias", 597, 586, "11 anos", "mau", "O último rei. Jerusalém e o templo foram destruídos.", "2Rs 24:18-20", "Jeremias e Ezequiel"),
]
marcos = [
    {"ano": 930, "titulo": "O reino se divide", "ref": "1Rs 12:16-20"},
    {"ano": 722, "titulo": "Samaria cai: Israel vai para a Assíria", "ref": "2Rs 17:6"},
    {"ano": 701, "titulo": "Senaqueribe cerca Jerusalém", "ref": "2Rs 19:35-36"},
    {"ano": 622, "titulo": "O livro da lei é achado", "ref": "2Rs 22:8"},
    {"ano": 605, "titulo": "Primeiros cativos: Daniel", "ref": "Dn 1:1-6"},
    {"ano": 586, "titulo": "Jerusalém cai: Judá vai para a Babilônia", "ref": "2Rs 25:8-11"},
]
reis = {"unido": unido, "israel": israel, "juda": juda, "marcos": marcos}

# ------------------------------------------------------------------ profetas


def P(nome, livro, data, ano, periodo, para, reis_, msg, ref):
    return {"nome": nome, "livro": livro, "data": data, "ano": ano, "periodo": periodo, "para": para, "reis": reis_,
            "mensagem": msg, "ref": ref}


profetas = [
    P("Obadias", 30, "c. 845 a.C. (data debatida)", 845, "pre", ["Edom"], "talvez Jeorão de Judá",
      "Juízo sobre Edom pelo orgulho e pela violência contra o irmão Jacó. O reino será do Senhor.", "Ob 1:15"),
    P("Joel", 28, "c. 835 a.C. (data debatida)", 835, "pre", ["Judá"], "talvez Joás",
      "Uma praga de gafanhotos anuncia o Dia do Senhor. Deus chama ao arrependimento e promete derramar o seu Espírito.", "Jl 2:28-29"),
    P("Jonas", 31, "c. 780–760 a.C.", 770, "pre", ["Nínive"], "Jeroboão II",
      "Enviado a uma cidade inimiga, descobre que a misericórdia de Deus alcança as nações.", "Jn 4:10-11"),
    P("Amós", 29, "c. 760 a.C.", 760, "pre", ["Israel"], "Jeroboão II e Uzias",
      "Um pastor de Tecoa denuncia a injustiça em tempo de fartura e anuncia o juízo.", "Am 5:24"),
    P("Oseias", 27, "c. 755–715 a.C.", 750, "pre", ["Israel"], "de Jeroboão II até a queda; de Uzias a Ezequias",
      "O casamento do profeta mostra o amor fiel de Deus por um povo infiel.", "Os 6:6"),
    P("Isaías", 22, "c. 740–681 a.C.", 740, "pre", ["Judá"], "Uzias, Jotão, Acaz e Ezequias",
      "O Santo de Israel julga e consola. Anuncia o Emanuel e o Servo que sofre pelos pecados do povo.", "Is 53:5"),
    P("Miqueias", 32, "c. 735–700 a.C.", 735, "pre", ["Judá", "Israel"], "Jotão, Acaz e Ezequias",
      "Juízo sobre os líderes corruptos e a promessa do governante que nasceria em Belém.", "Mq 6:8"),
    P("Naum", 33, "c. 660–630 a.C.", 650, "pre", ["Nínive"], "Manassés ou Josias",
      "Cerca de um século depois de Jonas, anuncia a queda definitiva de Nínive.", "Na 1:7"),
    P("Sofonias", 35, "c. 640–625 a.C.", 630, "pre", ["Judá"], "Josias",
      "O Dia do Senhor está perto, mas um remanescente humilde será salvo.", "Sf 3:17"),
    P("Jeremias", 23, "c. 627–580 a.C.", 627, "pre", ["Judá"], "de Josias a Zedequias",
      "Por quarenta anos chama Judá ao arrependimento, vê Jerusalém cair e anuncia a nova aliança.", "Jr 31:31-33"),
    P("Habacuque", 34, "c. 609–605 a.C.", 607, "pre", ["Judá"], "Jeoaquim",
      "Pergunta a Deus por que o mal prospera e ouve a resposta: o justo viverá pela sua fé.", "Hc 2:4"),
    P("Daniel", 26, "c. 605–535 a.C.", 605, "exilio", ["Exilados", "Nações"], "Nabucodonosor, Belsazar, Dario e Ciro",
      "Fiel na corte da Babilônia, mostra que o Deus do céu governa os reinos dos homens.", "Dn 2:44"),
    P("Ezequiel", 25, "c. 593–571 a.C.", 593, "exilio", ["Exilados"], "cativeiro de Joaquim",
      "Entre os cativos, vê a glória de Deus sair do templo e promete um coração novo.", "Ez 36:26-27"),
    P("Ageu", 36, "520 a.C.", 520, "pos", ["Judá"], "Dario; governador Zorobabel",
      "Chama os que voltaram a pôr a casa de Deus em primeiro lugar e reconstruir o templo.", "Ag 1:7-8"),
    P("Zacarias", 37, "c. 520–480 a.C.", 518, "pos", ["Judá"], "Dario; governador Zorobabel",
      "Visões de encorajamento e a promessa do Rei que vem montado num jumento.", "Zc 9:9"),
    P("Malaquias", 38, "c. 430 a.C.", 430, "pos", ["Judá"], "tempo de Neemias",
      "Repreende um povo frio e anuncia o mensageiro que prepararia o caminho do Senhor.", "Ml 3:1"),
]

# ------------------------------------------------------------------ livros
GRUPOS = [  # (nome, primeiro, último, cor)
    ("Lei", 1, 5, "FF5C6BC0"), ("Históricos", 6, 17, "FF8D6E63"), ("Poéticos", 18, 22, "FFD4A017"),
    ("Profetas maiores", 23, 27, "FFC0392B"), ("Profetas menores", 28, 39, "FFE67E22"),
    ("Evangelhos", 40, 43, "FF00897B"), ("História da igreja", 44, 44, "FF43A047"),
    ("Cartas de Paulo", 45, 57, "FF1E88E5"), ("Cartas gerais", 58, 65, "FF8E24AA"), ("Profecia", 66, 66, "FF6D4C41"),
]
livros, faltam = [], []
for part in "abc":
    p = here / f"livros_{part}.json"
    if p.exists():
        livros += json.loads(p.read_text(encoding="utf-8"))
    else:
        faltam.append(p.name)
livros.sort(key=lambda b: b["n"])

out = {"arvore": arvore, "reis": reis, "profetas": profetas,
       "grupos": [{"nome": n, "de": a, "ate": b, "cor": c} for n, a, b, c in GRUPOS], "livros": livros}
dest = REPO / "assets" / "data" / "panorama.json"
dest.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
print(f"árvore {len(nodes)} nós; reis {len(unido)}+{len(israel)}+{len(juda)}; profetas {len(profetas)}; livros {len(livros)}/66; "
      f"{dest.stat().st_size // 1024} KB" + (f"; faltam {faltam}" if faltam else ""))
