"""Quadro 3: a linha real (Judá) e a linha sacerdotal (Levi), até se encontrarem em Cristo."""
from build_linhagens import Quadro, OURO, AZUL, MARINHO, ROSA, CINZA, ROXO, MARROM

XR, XS = 330, 905  # coluna da linha real e da linha sacerdotal


def build():
    q = Quadro(
        "linhas", "O rei e o sacerdote",
        "A linha real de Judá e a linha sacerdotal de Levi, até se encontrarem em Cristo", "FFB8860B", "davi-uncao",
        "Dois filhos de Jacó deram origem às duas funções que sustentaram Israel: de Judá vieram os reis, de Levi "
        "vieram os sacerdotes. Em Israel ninguém podia ser as duas coisas. Este quadro segue as duas famílias, do "
        "Egito ao Novo Testamento, e mostra como só Jesus reúne em si o trono e o altar.")

    q.faixa(30, 170, 530, 731, "A linha real", "tribo de Judá · Gn 49:10", OURO)
    q.faixa(640, 170, 530, 849, "A linha sacerdotal", "tribo de Levi · Êx 28:1", AZUL)

    q.no("jaco", "Jacó", "destaque", 600, 96, "pai das doze tribos",
         "Antes de morrer, Jacó abençoou os doze filhos e disse a cada um o que viria. Para dois deles as palavras "
         "marcaram a história. Judá recebeu a promessa do cetro. Levi ouviu uma repreensão: a sua tribo seria "
         "espalhada por Israel, e isso mais tarde se tornou serviço sagrado.",
         ["Gn 49:1-2", "Gn 49:5-7", "Gn 49:8-10"], "lin-jaco-bencao", "Jacó", MARINHO, link="abraao")

    # ---------------- A linha real ----------------
    q.no("m-cetro", "A bênção de Jacó", "marco", 140, 262, "Gn 49:10",
         "O cetro não se apartará de Judá, nem o bastão de entre os seus pés, até que venha Siló; e a ele obedecerão "
         "os povos. É a primeira vez que a Bíblia diz de que tribo virá o rei, e que o seu reino alcançará as "
         "nações.",
         ["Gn 49:8-10", "Nm 24:17", "Ap 5:5"], "lin-jaco-bencao", None, MARROM, w=200)
    q.no("juda", "Judá", "destaque", XR, 262, "quarto filho de Lia",
         "Foi Judá quem propôs vender José, e foi ele quem, anos depois, se ofereceu para ficar preso no lugar de "
         "Benjamim. Jacó viu nele o líder dos irmãos. A sua tribo ficou com o sul da terra, onde estão Belém, Hebrom "
         "e Jerusalém.",
         ["Gn 37:26-27", "Gn 44:33-34", "Js 15:1", "1Cr 5:2"], "jose-irmaos", "Judá", OURO)
    q.casal("m-cetro", "juda")
    q.no("perez", "Perez", "pessoa", XR, 328, "filho de Tamar",
         "Filho de Judá e Tamar. A família de Davi é contada a partir dele. Em Belém, quando Boaz se casou com "
         "Rute, o povo desejou: seja a tua casa como a casa de Perez.",
         ["Gn 38:29", "Rt 4:12", "Rt 4:18"], None, None, OURO)
    q.no("elo1", "Esrom, Rão, Aminadabe, Naassom, Salmom", "elo", XR, 372, w=300)
    q.no("boaz", "Boaz", "pessoa", XR, 416, "de Belém",
         "Parente de Noemi, homem de posses e de caráter. Resgatou a herança da família e se casou com Rute. A linha "
         "real passa por um casamento de bondade, e não por um palácio.",
         ["Rt 2:1", "Rt 4:9-10", "Rt 4:21"], "rute-espigas", "Boaz", OURO)
    q.no("rute", "Rute", "pessoa", 160, 416, "a moabita",
         "Estrangeira de Moabe. Escolheu o Deus de Israel e entrou na família de onde viria o rei. A lei mantinha "
         "os moabitas longe da assembleia; a graça pôs Rute na linha do Messias.",
         ["Rt 1:16", "Rt 4:13", "Dt 23:3"], "rute-caminho", "Rute", ROSA)
    q.casal("rute", "boaz")
    q.no("obede", "Obede", "pessoa", XR, 470, "filho de Rute",
         "Nasceu em Belém e alegrou a velhice de Noemi. Foi pai de Jessé e avô de Davi.",
         ["Rt 4:16-17"], "rute-obede", None, OURO)
    q.no("jesse", "Jessé", "pessoa", XR, 524, "pai de Davi",
         "Criador de ovelhas em Belém. Dos seus oito filhos, Deus escolheu o mais novo. Séculos depois, com o trono "
         "caído, Isaías prometeu: do tronco de Jessé sairá um rebento.",
         ["1Sm 16:1", "1Sm 17:12", "Is 11:1", "Is 11:10"], "davi-uncao", None, OURO)
    q.no("davi", "Davi", "destaque", XR, 590, "o rei pastor",
         "Ungido por Samuel ainda jovem, reinou quarenta anos: sete em Hebrom, sobre Judá, e trinta e três em "
         "Jerusalém, sobre todo o Israel. Homem segundo o coração de Deus, apesar dos seus pecados. Dele em diante, "
         "esperar o Messias é esperar o Filho de Davi.",
         ["1Sm 16:13", "2Sm 5:4-5", "At 13:22-23"], "davi-coroado", "Rei Davi", OURO)
    q.no("m-alianca", "A aliança com Davi", "marco", 140, 590, "2Sm 7:12-16",
         "Davi quis construir uma casa para Deus. Deus respondeu que ele é quem faria uma casa para Davi: levantarei "
         "o teu descendente e firmarei para sempre o trono do seu reino. Salomão cumpriu a promessa em parte; só "
         "Jesus a cumpre por inteiro.",
         ["2Sm 7:12-16", "Sl 89:3-4", "Lc 1:32-33"], "davi-harpa", None, MARROM, w=200)
    q.casal("m-alianca", "davi")
    q.no("salomao", "Salomão", "pessoa", XR, 656, "filho de Davi",
         "Herdou o trono, pediu sabedoria e construiu o templo. Levou o reino ao auge e, no fim, deixou o coração "
         "se desviar. Depois dele o reino se dividiu, mas Judá continuou com a casa de Davi.",
         ["1Rs 2:12", "1Rs 6:1", "1Rs 11:11-13"], "templo-salomao", "Rei Salomão", OURO)
    q.no("reis", "Os reis de Judá", "grupo", XR, 714, "de Roboão a Zedequias",
         "Dezenove reis, todos da casa de Davi, e uma rainha usurpadora, Atalia, governaram Judá por cerca de 345 "
         "anos. Houve reis fiéis, como Ezequias e Josias, e reis ímpios. Em 586 a.C. a Babilônia destruiu Jerusalém, "
         "e o trono ficou vazio.",
         ["1Rs 12:17", "2Rs 11:1-3", "2Rs 25:7"], "lin-ezequias-oracao", None, OURO, w=220, link="reis")
    q.no("zorobabel", "Zorobabel", "pessoa", XR, 772, "governador",
         "Neto do rei Jeconias. Trouxe o povo de volta da Babilônia e reconstruiu o templo, mas não usou coroa. Deus "
         "o chamou de anel de selar: a promessa feita a Davi continuava de pé.",
         ["Ed 3:8", "Ag 2:23", "Mt 1:12"], "templo-reconstrucao", "Zorobabel", OURO)
    q.no("elo2", "nove gerações (Mt 1:13-15)", "elo", XR, 816)
    q.no("jose-maria", "José e Maria", "pessoa", XR, 860, "da casa de Davi",
         "Mil anos depois de Davi, a família real vive em Nazaré e trabalha com as mãos. O anjo diz a Maria que o "
         "seu filho receberá o trono de Davi, seu pai; José, filho de Davi, dá ao menino o nome e o direito legal.",
         ["Lc 1:26-27", "Lc 1:32-33", "Mt 1:20", "Lc 2:4"], "nazare-carpintaria", "José e Maria", OURO, w=170)
    q.cadeia(["juda", "perez"])
    q.liga("perez", "elo1", tracejada=True)
    q.liga("elo1", "boaz", tracejada=True)
    q.cadeia(["boaz", "obede", "jesse", "davi", "salomao", "reis", "zorobabel"])
    q.liga("zorobabel", "elo2", tracejada=True)
    q.liga("elo2", "jose-maria", tracejada=True)

    # ---------------- A linha sacerdotal ----------------
    q.no("levi", "Levi", "destaque", XS, 262, "terceiro filho de Lia",
         "Com Simeão, vingou a irmã com crueldade em Siquém, e por isso ouviu do pai: eu os espalharei em Israel. No "
         "deserto, quando o povo adorou o bezerro de ouro, os filhos de Levi ficaram do lado do Senhor. A dispersão "
         "virou bênção: sem território próprio, a tribo foi espalhada para servir a Deus em todo o Israel.",
         ["Gn 34:25", "Gn 49:5-7", "Êx 32:26-29", "Dt 10:8-9"], "tabernaculo", "Levi", AZUL)
    q.no("gerson", "Gérson", "mini", 735, 334, "",
         "Primeiro filho de Levi. Os gersonitas cuidavam das cortinas, das cobertas e da tenda do tabernáculo, e as "
         "transportavam nas viagens.",
         ["Êx 6:16-17", "Nm 3:25-26"], None, None, AZUL)
    q.no("coate", "Coate", "pessoa", XS, 334, "avô de Moisés",
         "Segundo filho de Levi. Os coatitas carregavam nos ombros os objetos mais santos: a arca, a mesa, o "
         "candelabro e os altares, depois de cobertos pelos sacerdotes. Da sua casa saíram Arão e Moisés.",
         ["Êx 6:18", "Nm 4:4", "Nm 4:15"], "jordao-arca", None, AZUL)
    q.no("merari", "Merari", "mini", 1075, 334, "",
         "Terceiro filho de Levi. Os meraritas levavam a estrutura do tabernáculo: tábuas, travessas, colunas e "
         "bases.",
         ["Êx 6:19", "Nm 3:36-37"], None, None, AZUL)
    for f in ("gerson", "coate", "merari"):
        q.liga("levi", f, meio=301)
    q.no("levitas", "Os levitas", "grupo", 735, 392, "servos do santuário",
         "Todos os descendentes de Levi que não eram da família de Arão. Não ofereciam sacrifícios: ajudavam os "
         "sacerdotes, cuidavam do santuário, eram porteiros, cantores e músicos e ensinavam a lei ao povo. Não "
         "receberam território. O Senhor era a sua herança: viviam dos dízimos, em quarenta e oito cidades "
         "espalhadas por Israel.",
         ["Nm 3:5-9", "Nm 18:20-21", "Nm 35:7", "Dt 33:10", "1Cr 23:28-30"], "davi-arca", None, AZUL, w=156, h=44)
    q.liga("gerson", "levitas")
    q.no("anrao", "Anrão", "pessoa", XS, 398, "pai de Moisés",
         "Neto de Levi. Casou com Joquebede, também da tribo de Levi, no tempo da escravidão no Egito. Tiveram três "
         "filhos: Miriã, Arão e Moisés.",
         ["Êx 6:20", "Nm 26:59"], None, None, AZUL)
    q.no("joquebede", "Joquebede", "pessoa", 1075, 398, "mãe de Moisés",
         "Escondeu o filho por três meses e depois o pôs num cesto no rio, pela fé, sem temer o decreto do rei. Deus "
         "lhe devolveu o menino para criar, paga pela filha do faraó.",
         ["Êx 2:1-3", "Êx 2:8-9", "Hb 11:23"], "moises-cesto", None, ROSA)
    q.casal("anrao", "joquebede")
    q.liga("coate", "anrao")
    q.no("miria", "Miriã", "mini", 735, 470, "",
         "Irmã de Arão e Moisés, mais velha que Moisés, e profetisa. Vigiou o cesto no Nilo e, depois da travessia do mar, puxou "
         "o cântico das mulheres. Miqueias a cita ao lado dos irmãos como guia do povo.",
         ["Êx 2:4", "Êx 15:20-21", "Mq 6:4"], "mar-vermelho", None, ROSA)
    q.no("arao", "Arão", "destaque", XS, 470, "sumo sacerdote",
         "Irmão mais velho de Moisés e seu porta-voz diante do faraó. Deus o separou, com os seus filhos, para o "
         "sacerdócio: só eles podiam oferecer os sacrifícios e entrar no santuário. Uma vez por ano o sumo sacerdote "
         "entrava no Santo dos Santos com sangue, pelo pecado do povo.",
         ["Êx 4:14-16", "Êx 28:1", "Lv 16:34", "Hb 5:4"], "moises-farao", "Arão", AZUL)
    q.no("moises", "Moisés", "pessoa", 1081, 470, "profeta e mediador",
         "Também era levita, mas não foi sacerdote como Arão: foi o profeta e o mediador da aliança. Consagrou o "
         "irmão e os sobrinhos para o sacerdócio. Os seus próprios filhos ficaram entre os levitas comuns.",
         ["Êx 2:1-2", "Lv 8:6-12", "Dt 34:10", "1Cr 23:14"], "sinai-lei", "Moisés", AZUL)
    for f in ("miria", "arao", "moises"):
        q.liga(["anrao", "joquebede"], f, meio=434)
    q.no("nadabe", "Nadabe e Abiú", "mini", 735, 546, "",
         "Os dois filhos mais velhos de Arão. Ofereceram fogo estranho diante do Senhor e morreram ali mesmo. Não "
         "deixaram filhos.",
         ["Lv 10:1-2", "Nm 3:4"], None, None, CINZA, w=140)
    q.no("eleazar", "Eleazar", "pessoa", XS, 546, "sucessor de Arão",
         "Terceiro filho de Arão. Recebeu as vestes do pai no monte Hor e foi sumo sacerdote ao lado de Josué, na "
         "conquista e na divisão da terra.",
         ["Nm 20:25-28", "Js 14:1", "Nm 3:32"], None, None, AZUL)
    q.no("itamar", "Itamar", "mini", 1075, 546, "",
         "Filho mais novo de Arão. Dirigiu o trabalho dos gersonitas e dos meraritas. Da sua casa vieram, mais "
         "tarde, Eli e Abiatar.",
         ["Êx 38:21", "Nm 4:28", "1Cr 24:3"], None, None, AZUL)
    for f in ("nadabe", "eleazar", "itamar"):
        q.liga("arao", f, meio=510)
    q.no("eli", "Eli e Abiatar", "mini", 1075, 602, "",
         "Eli, sacerdote em Siló nos dias de Samuel, não corrigiu os filhos, e Deus anunciou o fim da sua casa. "
         "Abiatar, seu descendente, serviu a Davi, mas apoiou Adonias, e Salomão o afastou. O sumo sacerdócio ficou "
         "com Zadoque, da linha de Eleazar.",
         ["1Sm 2:30-35", "1Rs 2:26-27", "1Rs 2:35"], None, None, CINZA, w=140)
    q.liga("itamar", "eli", tracejada=True)
    q.no("fineias", "Fineias", "pessoa", XS, 604, "zelo pelo Senhor",
         "Neto de Arão. Quando Israel se entregou à idolatria em Peor, agiu com zelo, e a praga cessou. Deus lhe "
         "deu a sua aliança de paz: um sacerdócio perpétuo para ele e para a sua descendência.",
         ["Nm 25:10-13", "Sl 106:30-31", "Jz 20:28"], None, None, AZUL)
    q.no("elo3", "outras gerações (1Cr 6:4-8)", "elo", XS, 648)
    q.no("zadoque", "Zadoque", "pessoa", XS, 692, "ungiu Salomão",
         "Sacerdote fiel a Davi na revolta de Absalão e na sucessão. Ungiu Salomão em Giom e se tornou o único sumo "
         "sacerdote. Ezequiel elogia os filhos de Zadoque, que guardaram o santuário quando Israel se desviou.",
         ["2Sm 15:24-29", "1Rs 1:39", "1Rs 2:35", "Ez 44:15"], "lin-zadoque-uncao", "Zadoque", AZUL)
    q.no("m-uncao", "O sacerdote unge o rei", "marco", 1075, 692, "1Rs 1:39",
         "Em Giom, Zadoque toma o chifre de azeite e unge Salomão. Em Israel as duas funções eram separadas: o rei "
         "vinha de Judá, o sacerdote vinha de Levi, e nenhum podia tomar o lugar do outro. Quando o rei Uzias "
         "tentou queimar incenso no templo, ficou leproso.",
         ["1Rs 1:39", "2Cr 26:16-19"], "lin-zadoque-uncao", None, MARROM, w=180, h=56)
    q.casal("zadoque", "m-uncao")
    q.no("elo4", "sacerdotes do templo de Salomão", "elo", XS, 736, w=210)
    q.no("hilquias", "Hilquias", "pessoa", XS, 780, "achou o livro",
         "Sumo sacerdote nos dias de Josias. Durante os reparos do templo, achou o livro da lei e o entregou ao "
         "escrivão Safã. A leitura levou o rei e o povo ao arrependimento.",
         ["2Rs 22:8", "2Rs 23:4", "2Cr 34:14-15"], "lin-josias-livro", "Hilquias", AZUL)
    q.no("elo5", "Azarias, Seraías, Jeozadaque", "elo", XS, 824, w=200)
    q.no("josue", "Josué", "pessoa", 820, 884, "sumo sacerdote",
         "Filho de Jeozadaque, que foi levado para a Babilônia. Voltou com Zorobabel e levantou o altar em "
         "Jerusalém. Na visão de Zacarias, as suas vestes sujas são trocadas, e ele recebe uma coroa: figura do "
         "Renovo, que será sacerdote no seu trono.",
         ["1Cr 6:15", "Ed 3:2", "Ag 1:1", "Zc 3:1-5", "Zc 6:11-13"], "templo-reconstrucao", None, AZUL)
    q.no("esdras", "Esdras", "pessoa", 990, 884, "sacerdote e escriba",
         "Descendente de Arão por Zadoque e Hilquias. Escriba versado na lei de Moisés, voltou da Babilônia por "
         "volta de 458 a.C. e ensinou o povo. Tinha preparado o coração para buscar a lei do Senhor, cumpri-la e "
         "ensiná-la.",
         ["Ed 7:1-6", "Ed 7:10", "Ne 8:1-3"], "esdras-lei", "Esdras", AZUL)
    q.no("elo6", "sacerdotes do segundo templo", "elo", XS, 932, w=200)
    q.no("zacarias", "Zacarias e Isabel", "pessoa", XS, 972, "linhagem de Arão",
         "Zacarias era sacerdote do turno de Abias; Isabel, sua mulher, descendia de Arão. Idosos e sem filhos, "
         "eram justos diante de Deus. No templo, enquanto ele oferecia o incenso, o anjo Gabriel anunciou que "
         "teriam um filho.",
         ["Lc 1:5-7", "Lc 1:13", "1Cr 24:10"], None, None, AZUL, w=176)
    q.cadeia(["eleazar", "fineias"])
    q.liga("fineias", "elo3", tracejada=True)
    q.liga("elo3", "zadoque", tracejada=True)
    q.liga("zadoque", "elo4", tracejada=True)
    q.liga("elo4", "hilquias", tracejada=True)
    q.liga("hilquias", "elo5", tracejada=True)
    q.liga("elo5", "josue", tracejada=True, meio=852)
    q.liga("elo5", "esdras", tracejada=True, meio=852)
    q.liga("josue", "elo6", tracejada=True, meio=914)
    q.liga("elo6", "zacarias", tracejada=True)

    # ---------------- O encontro ----------------
    q.no("melquisedeque", "Melquisedeque", "marco", 190, 1150, "rei e sacerdote",
         "Muito antes de Levi e de Judá, Abraão encontra um homem que é as duas coisas: rei de Salém e sacerdote do "
         "Deus Altíssimo. Ele traz pão e vinho, abençoa Abraão e recebe dele o dízimo. Davi profetiza que o Messias "
         "será sacerdote para sempre, segundo a ordem de Melquisedeque.",
         ["Gn 14:18-20", "Sl 110:4", "Hb 7:1-3"], "lin-melquisedeque", None, ROXO)
    q.no("jesus", "Jesus", "destaque", 600, 1150, "Rei e Sacerdote",
         "Jesus nasceu da tribo de Judá, da casa de Davi: é o Rei prometido. Não era da tribo de Levi, e por isso "
         "Hebreus explica que o seu sacerdócio é de outra ordem, a de Melquisedeque, que não depende de genealogia "
         "nem termina com a morte. Ele ofereceu a si mesmo uma vez por todas e vive para interceder por nós. Nele "
         "as duas linhas se encontram.",
         ["Hb 7:14-17", "Hb 7:24-27", "Zc 6:13", "Ap 1:5-6", "Ap 5:5"], "ascensao", "Jesus", ROXO)
    q.no("joao-batista", "João Batista", "pessoa", 960, 1150, "o precursor",
         "Filho de sacerdote, poderia servir no templo. Deus o mandou ao deserto, para preparar o caminho do "
         "Senhor. Apontou para Jesus e disse: eis o Cordeiro de Deus, que tira o pecado do mundo. O último "
         "mensageiro da antiga aliança apresenta o sacrifício definitivo.",
         ["Lc 1:76-77", "Jo 1:29", "Mt 11:11"], "batismo-jesus", "João Batista", AZUL, w=160)
    q.liga("jaco", "juda", meio=150)
    q.liga("jaco", "levi", meio=150)
    q.liga("zacarias", "joao-batista")
    q.liga("jose-maria", "jesus", meio=1062)
    q.liga("melquisedeque", "jesus", tracejada=True, h=True)
    q.liga("joao-batista", "jesus", tracejada=True, h=True)

    # ---------------- Apresentação ----------------
    q.passo(["jaco", "juda", "levi"], "Dois filhos, duas funções",
            "Jacó tem doze filhos, e todos formam o povo de Israel. Dois deles, porém, recebem um papel que os "
            "outros não têm. De Judá virão os reis. De Levi virão os sacerdotes. Durante mais de mil anos essas duas "
            "famílias andarão lado a lado, sem nunca se misturar.",
            "Gn 49:1-2", "lin-jaco-bencao")
    q.passo(["m-cetro", "juda", "perez"], "O cetro em Judá",
            "Judá não era o primogênito. Mesmo assim, Jacó profetiza: o cetro não se apartará de Judá, até que venha "
            "aquele a quem os povos obedecerão. A promessa do rei tem agora uma tribo. Ela segue por Perez, filho de "
            "Judá, e atravessa em silêncio os séculos do Egito e do deserto.",
            "Gn 49:10", "jose-irmaos")
    q.passo(["boaz", "rute", "obede", "jesse"], "Belém",
            "A linha reaparece em Belém, nos dias dos juízes. Boaz resgata Rute, a moabita, e deles nasce Obede, pai "
            "de Jessé. O livro de Rute termina com uma pequena genealogia de dez nomes, de Perez a Davi: o rei já "
            "está a caminho, e ninguém ainda sabe.",
            "Rt 4:18-22", "rute-obede")
    q.passo(["davi", "m-alianca", "salomao"], "A casa de Davi",
            "Samuel unge o filho mais novo de Jessé. Davi reina em Jerusalém e recebe a maior promessa desde "
            "Abraão: um descendente seu terá o trono firmado para sempre. Salomão constrói o templo, mas morre. O "
            "povo passa a esperar outro Filho de Davi, maior que Salomão.",
            "2Sm 7:12-16", "davi-coroado")
    q.passo(["reis", "zorobabel", "jose-maria"], "Um trono vazio",
            "Dezenove reis da casa de Davi governam Judá, até que a Babilônia destrói Jerusalém. Zorobabel, herdeiro "
            "do trono, volta do exílio apenas como governador. Passam mais cinco séculos. Quando o anjo fala com "
            "Maria, a família real é a de um carpinteiro de Nazaré.",
            "Jr 23:5", "templo-reconstrucao")
    q.passo(["levi", "gerson", "coate", "merari", "levitas"], "A tribo separada",
            "Do outro lado está Levi. A sua tribo não recebe território: o Senhor é a sua herança. Os três clãs, de "
            "Gérson, Coate e Merari, carregam e guardam o tabernáculo. Mais tarde os levitas serão porteiros, "
            "cantores e mestres da lei, espalhados por todo o Israel.",
            "Nm 3:5-9", "tabernaculo")
    q.passo(["anrao", "joquebede", "miria", "arao", "moises"], "Arão e Moisés",
            "Da casa de Coate nascem três irmãos: Miriã, Arão e Moisés. Moisés é o profeta que tira o povo do Egito. "
            "Arão é escolhido para o sacerdócio, ele e os seus filhos. Desde então, só os descendentes de Arão "
            "podem se aproximar do altar e oferecer sacrifícios pelo povo.",
            "Êx 28:1", "moises-farao")
    q.passo(["eleazar", "fineias", "zadoque", "m-uncao", "eli"], "De Eleazar a Zadoque",
            "O sumo sacerdócio passa de Arão a Eleazar e a Fineias, que recebe uma aliança de sacerdócio perpétuo. "
            "Séculos depois, a casa de Eli é afastada, e Zadoque, da linha de Eleazar, unge Salomão. Ali as duas "
            "linhas se tocam: o sacerdote de Levi unge o rei de Judá.",
            "1Rs 1:39", "lin-zadoque-uncao")
    q.passo(["hilquias", "josue", "esdras"], "Do templo ao exílio e de volta",
            "Hilquias acha o livro da lei nos dias de Josias. O templo é destruído, e os sacerdotes vão para o "
            "exílio. Na volta, o sumo sacerdote Josué levanta o altar ao lado de Zorobabel, e Esdras, sacerdote e "
            "escriba, ensina a lei. Sem rei, o povo é guiado pelos sacerdotes.",
            "Ed 7:10", "esdras-lei")
    q.passo(["zacarias", "joao-batista"], "O filho do sacerdote",
            "Quatro séculos depois, um sacerdote chamado Zacarias oferece incenso no templo e recebe a notícia de "
            "que terá um filho. João Batista nasce na família de Arão, mas o seu chamado é outro: apresentar a "
            "Israel o Cordeiro de Deus, que tira o pecado do mundo.",
            "Jo 1:29", "batismo-jesus")
    q.passo(["melquisedeque"], "Um rei que era sacerdote",
            "Havia um problema. O Messias seria rei, da tribo de Judá. Como poderia também ser sacerdote, se o "
            "sacerdócio era de Levi? A resposta estava em Gênesis: Melquisedeque, rei de Salém e sacerdote do Deus "
            "Altíssimo, anterior a Levi e maior do que Abraão. O Salmo 110 anuncia um sacerdote dessa ordem.",
            "Sl 110:4", "lin-melquisedeque")
    q.passo(["jose-maria", "joao-batista", "melquisedeque", "jesus"], "Em Cristo, o trono e o altar",
            "Jesus é o Leão da tribo de Judá e a Raiz de Davi: o Rei. E é sacerdote para sempre, segundo a ordem de "
            "Melquisedeque: ofereceu a si mesmo uma única vez e vive para interceder. O que em Israel ninguém podia "
            "unir, ele une. E faz do seu povo um reino de sacerdotes.",
            "Hb 7:14-17", "ascensao")
    return q
