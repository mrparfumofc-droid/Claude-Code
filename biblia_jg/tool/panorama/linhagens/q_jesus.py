"""Quadro 1: a genealogia de Jesus (Mateus 1 e Lucas 3)."""
from build_linhagens import Quadro, ROXO, MARINHO, OURO, CINZA, TEAL, ROSA

Y0, STEP = 112, 54  # primeira linha de nomes e distância entre elas


def build():
    q = Quadro(
        "jesus", "A genealogia de Jesus",
        "De Abraão a Cristo em três grupos de catorze, e a linha de Lucas até Adão", ROXO, "natal-manjedoura",
        "Mateus abre o Novo Testamento com uma lista de nomes. Ela prova que Jesus é o herdeiro das promessas feitas a "
        "Abraão e a Davi. Lucas traz outra lista, que sobe até Adão. Este quadro mostra as duas, conta quem foi cada "
        "pessoa e explica o que as diferenças ensinam. Toque em qualquer nome ou use o botão Apresentar.")

    xa, xw, xb, xc, xd = 290, 115, 506, 732, 968
    q.faixa(30, 30, 350, 823, "De Abraão a Davi", "Mt 1:2-6 · catorze gerações", MARINHO)
    q.faixa(406, 30, 200, 823, "De Davi ao exílio", "Mt 1:6-11 · os reis de Judá", OURO)
    q.faixa(632, 30, 200, 661, "Do exílio a Cristo", "Mt 1:12-16", CINZA)
    q.faixa(858, 30, 220, 661, "A linha de Lucas", "Lc 3:23-38 · por Natã", TEAL)

    def y(k):
        return Y0 + STEP * k

    # ---------------- De Abraão a Davi ----------------
    a = [
        ("abraao", "Abraão", "destaque", "pai da fé", True, "abraao-estrelas",
         "A lista começa com ele. Deus prometeu que na sua descendência seriam abençoadas todas as nações da terra. "
         "Mateus chama Jesus de filho de Abraão: nele a promessa se cumpre e a bênção alcança judeus e gentios.",
         ["Gn 12:1-3", "Gn 22:18", "Mt 1:1-2", "Gl 3:16"]),
        ("isaque", "Isaque", "pessoa", "filho da promessa", True, "moria-sacrificio",
         "Nasceu quando Abraão tinha cem anos e Sara já não podia ter filhos. Foi levado ao monte Moriá e poupado: "
         "Deus proveu o cordeiro. A promessa feita ao pai foi repetida a ele.",
         ["Gn 21:1-3", "Gn 22:13-14", "Gn 26:3-4"]),
        ("jaco", "Jacó", "pessoa", "chamado Israel", True, "jaco-gosen",
         "Filho mais novo de Isaque, recebeu a bênção e, em Betel, a mesma promessa. Deus mudou o seu nome para "
         "Israel. Dos seus doze filhos vieram as doze tribos; a linha do Messias segue por Judá.",
         ["Gn 28:13-14", "Gn 35:10-12", "Mt 1:2"]),
        ("juda", "Judá", "pessoa", "o cetro é dele", "Judá", "lin-jaco-bencao",
         "Quarto filho de Jacó e Lia. Não era o primogênito, e a sua história tem falhas graves. Mesmo assim o pai "
         "profetizou: o cetro não se apartará de Judá. É da sua tribo que vêm Davi e Jesus, o Leão da tribo de Judá.",
         ["Gn 49:8-10", "Gn 44:33", "Hb 7:14", "Ap 5:5"]),
        ("perez", "Perez", "pessoa", "filho de Tamar", None, None,
         "Um dos gêmeos de Judá e Tamar; o outro foi Zerá. Em algumas traduções aparece como Farés. Nasceu de uma "
         "história vergonhosa e, ainda assim, é dele que a linha continua. O livro de Rute começa a contar a família "
         "de Davi a partir dele.",
         ["Gn 38:29", "Rt 4:18", "Mt 1:3"]),
        ("esrom", "Esrom", "pessoa", "desceu ao Egito", None, None,
         "Filho de Perez. Está na lista dos que desceram com Jacó para o Egito. Dele em diante a família vive os "
         "longos anos de escravidão, sem que a promessa se perca.",
         ["Gn 46:12", "Rt 4:18-19"]),
        ("rao", "Rão", "pessoa", "Arão em Mt 1:3", None, None,
         "Nasceu nos anos do Egito. Em Mateus o nome costuma aparecer como Arão, mas não é o irmão de Moisés. Dele "
         "só conhecemos o lugar na lista: um elo fiel numa geração de escravos.",
         ["Rt 4:19", "1Cr 2:9-10", "Mt 1:3-4"]),
        ("aminadabe", "Aminadabe", "pessoa", "sogro de Arão", None, None,
         "Pai de Naassom e de Eliseba, que se casou com Arão, o sumo sacerdote. Aqui as famílias de Judá e de Levi "
         "se aproximam pela primeira vez.",
         ["Êx 6:23", "Rt 4:19-20"]),
        ("naassom", "Naassom", "pessoa", "príncipe de Judá", None, "deserto-mana",
         "Chefe da tribo de Judá no deserto. No acampamento, Judá ficava à frente, do lado do nascer do sol, e foi "
         "Naassom quem levou a primeira oferta quando o altar foi consagrado.",
         ["Nm 1:7", "Nm 2:3", "Nm 7:12"]),
        ("salmom", "Salmom", "pessoa", "marido de Raabe", None, None,
         "Viveu a entrada na terra prometida. Mateus conta que se casou com Raabe, a mulher de Jericó que escondeu "
         "os espias, e que deles nasceu Boaz.",
         ["Rt 4:20-21", "Mt 1:5"]),
        ("boaz", "Boaz", "pessoa", "o resgatador", True, "rute-espigas",
         "Homem rico e bondoso de Belém. Acolheu Rute, a estrangeira que colhia espigas no seu campo, e a resgatou "
         "como parente próximo. É figura de Cristo, o nosso Redentor.",
         ["Rt 2:1", "Rt 4:9-10", "Mt 1:5"]),
        ("obede", "Obede", "pessoa", "avô de Davi", None, "rute-obede",
         "Filho de Boaz e Rute. Quando nasceu, as mulheres de Belém disseram a Noemi: ele será restaurador da tua "
         "vida. Foi pai de Jessé.",
         ["Rt 4:14-17"]),
        ("jesse", "Jessé", "pessoa", "o belemita", None, "davi-uncao",
         "Criador de ovelhas em Belém, pai de oito filhos. Samuel foi à sua casa ungir um rei, e o escolhido foi o "
         "mais novo. Isaías chama o Messias de rebento do tronco de Jessé.",
         ["1Sm 16:1", "1Sm 16:10-13", "Is 11:1"]),
        ("davi", "Davi", "destaque", "o rei", "Rei Davi", "davi-coroado",
         "O único que Mateus chama de rei. Deus lhe prometeu um descendente cujo trono seria firmado para sempre. "
         "Por isso o povo esperava o Filho de Davi, e por isso a genealogia passa por ele: Jesus é o Rei prometido.",
         ["1Sm 16:13", "2Sm 7:12-16", "Mt 1:6", "Rm 1:3"]),
    ]
    for k, (id, nome, tipo, sub, retrato, arte, texto, refs) in enumerate(a):
        q.no(id, nome, tipo, xa, y(k), sub, texto, refs, arte, retrato, MARINHO, h=52 if tipo == "destaque" else None)
    q.cadeia([n[0] for n in a])

    q.no("tamar", "Tamar", "pessoa", xw, y(3), "nora de Judá",
         "Viúva de dois filhos de Judá, foi deixada sem amparo pelo sogro. Por um caminho torto, que a Bíblia conta "
         "sem esconder, tornou-se mãe de Perez e Zerá. O próprio Judá reconheceu: mais justa é ela do que eu. É a "
         "primeira mulher lembrada por Mateus.",
         ["Gn 38:26", "Mt 1:3"], None, None, ROSA)
    q.no("raabe", "Raabe", "pessoa", xw, y(9), "de Jericó",
         "Cananeia de Jericó, de vida reprovada. Creu no Deus de Israel, escondeu os espias e foi salva com a sua "
         "casa quando os muros caíram. Hebreus a põe entre os heróis da fé.",
         ["Js 2:11", "Js 6:25", "Hb 11:31", "Mt 1:5"], "raabe-espias", True, ROSA)
    q.no("rute", "Rute", "pessoa", xw, y(10), "a moabita",
         "Estrangeira de Moabe, viúva, escolheu o povo e o Deus da sogra: o teu povo é o meu povo, o teu Deus é o "
         "meu Deus. Casou com Boaz e se tornou bisavó de Davi.",
         ["Rt 1:16", "Rt 4:13", "Mt 1:5"], "rute-caminho", True, ROSA)
    q.no("bate-seba", "Bate-Seba", "pessoa", xw, y(13), "mulher de Urias",
         "Mateus nem diz o seu nome: escreve a que fora mulher de Urias, para lembrar o pecado de Davi, que tomou a "
         "esposa de um soldado fiel e causou a morte dele. Deus repreendeu o rei, perdoou o arrependido e, dela, "
         "nasceu Salomão.",
         ["2Sm 11:3", "2Sm 12:13", "2Sm 12:24", "Mt 1:6"], "lin-bate-seba-salomao", "Bate-Seba", ROSA)
    q.casal("tamar", "juda")
    q.casal("raabe", "salmom")
    q.casal("rute", "boaz")
    q.casal("bate-seba", "davi")

    # ---------------- De Davi ao exílio ----------------
    b = [
        ("salomao", "Salomão", "construiu o templo", "Rei Salomão", "templo-salomao",
         "Filho de Davi e Bate-Seba. Pediu sabedoria, construiu o templo e levou o reino ao auge. No fim, o coração "
         "se desviou atrás de outros deuses, e o reino se partiu depois dele.",
         ["1Rs 3:9", "1Rs 8:27-30", "1Rs 11:4"]),
        ("roboao", "Roboão", "o reino se divide", "Rei Roboão", "lin-siquem-divisao",
         "Recusou o conselho dos anciãos e respondeu com dureza ao povo. Dez tribos o abandonaram. Ficou com Judá e "
         "Benjamim: nasce o reino do sul, onde a linha de Davi continua.",
         ["1Rs 12:13-16", "1Rs 14:21"]),
        ("abias", "Abias", "reinou três anos", None, None,
         "Em Reis é chamado Abião. Andou nos pecados do pai, mas Deus manteve acesa a lâmpada de Davi em Jerusalém "
         "por amor da promessa.",
         ["1Rs 15:1-4", "2Cr 13:10"]),
        ("asa", "Asa", "rei reformador", None, None,
         "Fez o que era reto, tirou os ídolos e clamou a Deus diante de um exército imenso. No fim da vida confiou "
         "mais em alianças e em médicos do que no Senhor.",
         ["1Rs 15:11", "2Cr 14:11", "2Cr 16:9"]),
        ("josafa", "Josafá", "buscou ao Senhor", None, None,
         "Mandou ensinar a lei pelas cidades de Judá. Cercado por inimigos, orou: não sabemos o que fazer, mas os "
         "nossos olhos estão postos em ti. Venceu cantando louvores.",
         ["2Cr 17:3-6", "2Cr 20:12", "2Cr 20:21-22"]),
        ("jorao", "Jorão", "genro de Acabe", None, None,
         "Casou com Atalia, filha de Acabe, e levou Judá à idolatria. Depois dele Mateus salta três reis (Acazias, "
         "Joás e Amazias) e segue para Uzias. Era costume resumir genealogias: gerou também pode indicar um "
         "descendente mais distante.",
         ["2Rs 8:16-19", "2Cr 21:6", "Mt 1:8"]),
        ("uzias", "Uzias", "também Azarias", None, None,
         "Reinou cinquenta e dois anos e prosperou enquanto buscou a Deus. Quando ficou forte, o coração se exaltou: "
         "entrou no templo para queimar incenso e ficou leproso. Isaías teve a sua visão no ano em que ele morreu.",
         ["2Rs 15:1-3", "2Cr 26:16", "Is 6:1"]),
        ("jotao", "Jotão", "rei reto", None, None,
         "Governou bem e se fortaleceu porque dirigiu os seus caminhos diante do Senhor. O povo, porém, continuou "
         "se corrompendo.",
         ["2Rs 15:32-34", "2Cr 27:6"]),
        ("acaz", "Acaz", "rei idólatra", None, None,
         "Um dos piores reis de Judá: fechou as portas do templo e copiou altares pagãos. Foi a ele, que não quis "
         "pedir sinal, que Isaías anunciou: a virgem conceberá e dará à luz um filho, Emanuel.",
         ["2Rs 16:2-4", "Is 7:14", "Mt 1:23"]),
        ("ezequias", "Ezequias", "confiou no Senhor", "Rei Ezequias", "lin-ezequias-oracao",
         "Reabriu o templo e celebrou a Páscoa. Quando a Assíria cercou Jerusalém, estendeu a carta de ameaça "
         "diante do Senhor e orou; a cidade foi livrada. Doente, recebeu mais quinze anos de vida.",
         ["2Rs 18:5", "2Rs 19:14-19", "Is 38:5"]),
        ("manasses", "Manassés", "mau, arrependido", None, None,
         "O reinado mais longo e mais sombrio de Judá: idolatria, feitiçaria e sangue inocente. Preso e humilhado, "
         "orou, e Deus o ouviu. Mostra até onde a graça alcança.",
         ["2Rs 21:1-2", "2Cr 33:12-13"]),
        ("amom", "Amom", "reinou dois anos", None, None,
         "Repetiu os pecados do pai, sem o arrependimento dele. Foi morto pelos próprios servos, e o povo pôs no "
         "trono o seu filho Josias, de oito anos.",
         ["2Rs 21:19-24"]),
        ("josias", "Josias", "o livro da lei", "Rei Josias", "lin-josias-livro",
         "Rei aos oito anos. Mandou reparar o templo, e ali foi achado o livro da lei. Ao ouvir a leitura, rasgou "
         "as vestes e conduziu a maior reforma de Judá. Não houve rei como ele, que se convertesse ao Senhor de todo "
         "o coração.",
         ["2Rs 22:1-2", "2Rs 22:11", "2Rs 23:25"]),
        ("jeconias", "Jeconias", "levado à Babilônia", None, "babilonia-portao",
         "Em Reis é chamado Joaquim; Jeremias o chama de Conias. Reinou três meses e foi levado cativo em 597 a.C. "
         "Com ele a lista de reis vira lista de exilados. Anos depois foi tirado do cárcere: um sinal de que a "
         "casa de Davi não tinha acabado.",
         ["2Rs 24:12-15", "2Rs 25:27-30", "Mt 1:11-12"]),
    ]
    for k, (id, nome, sub, retrato, arte, texto, refs) in enumerate(b):
        q.no(id, nome, "pessoa", xb, y(k), sub, texto, refs, arte, retrato, OURO, link="reis" if id == "roboao" else None)
    q.cadeia([n[0] for n in b])
    q.liga("davi", "salomao", h=True)

    # ---------------- Do exílio a Cristo ----------------
    c = [
        ("salatiel", "Salatiel", "nascido no exílio", None, None,
         "Filho de Jeconias, nascido na Babilônia. Também chamado Sealtiel. Não reinou: é o primeiro da casa de "
         "Davi a viver sem trono, guardando só a promessa.",
         ["1Cr 3:17", "Mt 1:12"]),
        ("zorobabel", "Zorobabel", "governador", "Zorobabel", "templo-reconstrucao",
         "Liderou a primeira volta do exílio e lançou os alicerces do novo templo. Era herdeiro de Davi, mas foi só "
         "governador de uma província persa. A ele Deus disse: não por força nem por violência, mas pelo meu "
         "Espírito.",
         ["Ed 3:8", "Ag 2:23", "Zc 4:6-9"]),
        ("abiude", "Abiúde", "filho de Zorobabel", None, None,
         "O Antigo Testamento não o menciona. Daqui em diante Mateus usa registros de família guardados depois do "
         "exílio. O nome quer dizer meu pai é majestade.",
         ["Mt 1:13"]),
        ("eliaquim", "Eliaquim", "Deus estabelece", None, None,
         "Só o nome ficou. Viveu, provavelmente, quando Judá era uma pequena província do império persa, sem rei e "
         "sem profeta, sustentada pela lei e pelo templo reconstruído.",
         ["Mt 1:13"]),
        ("azor", "Azor", "ajudador", None, None,
         "Outro nome que só esta lista guarda. Entre Malaquias e João Batista passam cerca de quatrocentos anos sem "
         "voz profética, mas Deus continua contando as gerações.",
         ["Mt 1:13-14"]),
        ("sadoque", "Sadoque", "justo", None, None,
         "Não é o sacerdote Zadoque dos dias de Davi. Viveu, provavelmente, na época em que os gregos de Alexandre "
         "tomaram o Oriente e a língua grega se espalhou pelo mundo.",
         ["Mt 1:14"]),
        ("aquim", "Aquim", "Mt 1:14", None, None,
         "Mais um elo desconhecido. A família de Davi já não mora em palácio: são pessoas comuns de Judá, que "
         "ninguém nota.",
         ["Mt 1:14"]),
        ("eliude", "Eliúde", "Mt 1:14-15", None, None,
         "Viveu, provavelmente, nos dias duros em que reis da Síria proibiram a lei e profanaram o templo, e os "
         "macabeus se levantaram.",
         ["Mt 1:14-15"]),
        ("eleazar", "Eleazar", "Deus ajudou", None, None,
         "Tem o nome do filho de Arão, mas é outra pessoa, da tribo de Judá. A promessa feita a Davi atravessa "
         "impérios dentro de uma família simples.",
         ["Mt 1:15"]),
        ("mata", "Matã", "avô de José", None, None,
         "Avô de José na lista de Mateus. Alguns o identificam com Matate, da lista de Lucas; outros entendem que "
         "são pessoas diferentes.",
         ["Mt 1:15", "Lc 3:24"]),
        ("mt-jaco", "Jacó", "pai de José", None, None,
         "Não é o patriarca. Mateus diz que este Jacó gerou José, marido de Maria. Viveu quando Roma já dominava a "
         "Judeia e Herodes reinava.",
         ["Mt 1:15-16"]),
    ]
    for k, (id, nome, sub, retrato, arte, texto, refs) in enumerate(c):
        q.no(id, nome, "pessoa", xc, y(k), sub, texto, refs, arte, retrato, CINZA)
    q.cadeia([n[0] for n in c])
    q.liga("jeconias", "salatiel", h=True)

    # ---------------- A linha de Lucas ----------------
    q.no("lc-adao", "Adão", "pessoa", xd, y(0), "filho de Deus",
         "Lucas escreve a lista de trás para a frente: sai de Jesus e só para em Adão, filho de Deus. Com isso mostra "
         "que Jesus veio para toda a humanidade, não só para Israel. Ele é o novo Adão, que obedece onde o primeiro "
         "caiu.",
         ["Lc 3:38", "Gn 5:1-3", "Rm 5:18-19"], "eden-casal", "Adão", TEAL, link="quadro:adao")
    q.no("lc-elo1", "Sete … Noé … Sem", "elo", xd, y(1))
    q.no("lc-abraao", "Abraão", "pessoa", xd, y(2), "Lc 3:34",
         "De Abraão a Davi, Lucas e Mateus trazem os mesmos nomes. A diferença é a direção: Mateus desce de Abraão "
         "até Jesus; Lucas sobe de Jesus até Abraão e continua até Adão.",
         ["Lc 3:34"], "abraao-estrelas", "Abraão", TEAL)
    q.no("lc-elo2", "os mesmos nomes de Mateus", "elo", xd, y(3))
    q.no("lc-davi", "Davi", "pessoa", xd, y(4), "Lc 3:31",
         "Em Davi as listas se separam. Mateus segue por Salomão, a linha dos reis. Lucas segue por Natã, outro "
         "filho de Davi e Bate-Seba.",
         ["Lc 3:31", "1Cr 3:5"], "davi-harpa", "Rei Davi", TEAL)
    q.no("lc-nata", "Natã", "pessoa", xd, y(5), "filho de Davi",
         "Não é o profeta Natã: é um dos filhos de Davi nascidos em Jerusalém. Nunca reinou. Por ele a linha de "
         "Lucas corre longe do trono, por gente que a história não registrou.",
         ["2Sm 5:14", "1Cr 3:5", "Lc 3:31"], None, None, TEAL)
    q.no("lc-elo3", "outras gerações (Lc 3:27-31)", "elo", xd, y(6))
    q.no("lc-salatiel", "Salatiel e Zorobabel", "pessoa", xd, y(7), "nas duas listas",
         "Os dois nomes aparecem em Mateus e em Lucas, mas com pais diferentes: Jeconias em Mateus, Neri em Lucas. "
         "Muitos entendem que as linhas se cruzam aqui por adoção ou por casamento de cunhado; outros pensam em "
         "pessoas de mesmo nome. A Bíblia não explica.",
         ["Lc 3:27", "Mt 1:12"], "templo-reconstrucao", None, TEAL, w=190)
    q.no("lc-elo4", "outras gerações (Lc 3:24-26)", "elo", xd, y(8))
    q.no("lc-matate", "Matate", "pessoa", xd, y(9), "pai de Heli",
         "Pai de Heli na lista de Lucas. Alguns o identificam com Matã, avô de José na lista de Mateus; outros os "
         "consideram pessoas diferentes.",
         ["Lc 3:24"], None, None, TEAL)
    q.no("heli", "Heli", "pessoa", xd, y(10), "Lc 3:23",
         "Lucas diz que Jesus era, como se cuidava, filho de José, filho de Heli. Mateus diz que o pai de José foi "
         "Jacó. As duas leituras mais comuns: Lucas dá a família de Maria, e Heli seria sogro de José; ou as duas "
         "listas são de José, uma pela sucessão legal ao trono e outra pelo sangue. A Bíblia não resolve, e as duas "
         "chegam a Davi.",
         ["Lc 3:23", "Mt 1:16"], None, None, TEAL)
    q.liga("lc-adao", "lc-elo1", tracejada=True)
    q.liga("lc-elo1", "lc-abraao", tracejada=True)
    q.liga("lc-abraao", "lc-elo2", tracejada=True)
    q.liga("lc-elo2", "lc-davi", tracejada=True)
    q.liga("lc-davi", "lc-nata")
    q.liga("lc-nata", "lc-elo3", tracejada=True)
    q.liga("lc-elo3", "lc-salatiel", tracejada=True)
    q.liga("lc-salatiel", "lc-elo4", tracejada=True)
    q.liga("lc-elo4", "lc-matate", tracejada=True)
    q.liga("lc-matate", "heli")

    # ---------------- José, Maria e Jesus ----------------
    q.no("jose", "José", "pessoa", xc, 792, "marido de Maria",
         "Carpinteiro de Nazaré, descendente de Davi. Um anjo lhe disse em sonho: José, filho de Davi, não temas "
         "receber Maria. Não foi o pai de sangue de Jesus; foi o pai legal, e por ele Jesus é herdeiro do trono de "
         "Davi.",
         ["Mt 1:16", "Mt 1:20-21", "Lc 2:4"], "nazare-carpintaria", "José, marido de Maria", CINZA)
    q.no("maria", "Maria", "pessoa", 902, 792, "mãe de Jesus",
         "Jovem de Nazaré, desposada com José. Mateus muda a frase de propósito: não diz que José gerou Jesus, e sim "
         "que José era marido de Maria, da qual nasceu Jesus. O menino foi concebido pelo Espírito Santo.",
         ["Mt 1:16", "Lc 1:30-35", "Gl 4:4"], "anunciacao", True, ROSA)
    q.no("jesus", "Jesus", "destaque", 902, 880, "o Cristo",
         "O fim de todas as listas. Filho de Abraão: nele todas as nações são abençoadas. Filho de Davi: o Rei cujo "
         "reino não terá fim. Filho de Deus: concebido pelo Espírito Santo. O seu nome quer dizer o Senhor salva, "
         "porque ele salvará o seu povo dos pecados deles.",
         ["Mt 1:1", "Mt 1:21", "Lc 1:32-33", "Ap 22:16"], "natal-manjedoura", True, ROXO)
    q.liga("mt-jaco", "jose")
    q.liga("heli", "jose", tracejada=True)
    q.casal("jose", "maria")
    q.liga("maria", "jesus")

    # ---------------- Apresentação ----------------
    q.passo(["abraao", "davi", "jesus"], "Um livro que começa com nomes",
            "O Novo Testamento abre assim: livro da genealogia de Jesus Cristo, filho de Davi, filho de Abraão. Para "
            "um judeu, isso dizia tudo. A Abraão Deus prometeu abençoar todas as nações; a Davi, um trono para "
            "sempre. Mateus vai provar, nome por nome, que Jesus é o herdeiro das duas promessas.",
            "Mt 1:1", "natal-manjedoura")
    q.passo(["abraao", "isaque", "jaco", "juda"], "Os patriarcas",
            "A promessa passa de pai para filho: Abraão, Isaque, Jacó. Entre os doze filhos de Jacó, a linha não "
            "segue pelo mais velho, e sim por Judá. Antes de morrer, Jacó profetiza que o cetro não se apartará de "
            "Judá. O Messias será um rei, e virá dessa tribo.",
            "Gn 49:10", "abraao-estrelas")
    q.passo(["tamar", "perez", "esrom", "rao", "aminadabe", "naassom"], "Tamar e os anos do Egito",
            "Mateus cita mulheres, o que não era costume. A primeira é Tamar, de uma história que a Bíblia conta sem "
            "esconder. Depois vêm as gerações do Egito e do deserto: Esrom, Rão, Aminadabe e Naassom, chefe de Judá "
            "nos dias de Moisés. Mesmo na escravidão, Deus não perde a linha de vista.",
            "Mt 1:3-4", "deserto-mana")
    q.passo(["salmom", "raabe", "boaz", "rute", "obede"], "Duas estrangeiras",
            "Raabe era cananeia, de Jericó. Rute era moabita. As duas vieram de fora, creram no Deus de Israel e "
            "entraram na família do Messias. Boaz resgata Rute em Belém, e deles nasce Obede. Desde o começo a "
            "genealogia anuncia que o Salvador é para todos os povos.",
            "Rt 4:13-17", "rute-espigas")
    q.passo(["jesse", "davi"], "De Belém, um rei",
            "Obede gera Jessé, e Jessé gera o rei Davi. O pastor mais novo da casa é ungido por Samuel e recebe a "
            "grande promessa: um descendente dele reinará para sempre. Fecha-se o primeiro grupo de catorze "
            "gerações, de Abraão até Davi.",
            "2Sm 7:12-16", "davi-uncao")
    q.passo(["davi", "bate-seba", "salomao"], "A que fora mulher de Urias",
            "Mateus não disfarça o pecado do maior rei de Israel. Davi tomou a esposa de Urias e causou a morte "
            "dele. Repreendido, confessou, e Deus o perdoou. Dessa mesma mulher nasceu Salomão. A linha do Messias "
            "não é feita de gente perfeita, e sim de pecadores alcançados pela graça.",
            "2Sm 12:24", "lin-bate-seba-salomao")
    q.passo(["salomao", "roboao", "asa", "josafa", "ezequias", "manasses", "josias"], "Os reis de Judá",
            "De Salomão em diante a lista é a dos reis de Judá. Há reis bons, como Asa, Josafá, Ezequias e Josias, e "
            "reis terríveis, como Acaz e Manassés. O trono balança, mas não cai: Deus guarda a casa de Davi por "
            "amor da promessa, não por mérito dos reis.",
            "Mt 1:7-10", "lin-ezequias-oracao")
    q.passo(["josias", "jeconias", "salatiel", "zorobabel"], "O exílio",
            "O segundo grupo termina em tragédia. Jeconias é levado para a Babilônia, e o trono de Davi fica vazio. "
            "Parece o fim. Mas a lista continua: Salatiel nasce no cativeiro, e Zorobabel conduz o povo de volta e "
            "reconstrói o templo. A promessa sobrevive sem coroa.",
            "Mt 1:11-12", "babilonia-portao")
    q.passo(["abiude", "eliaquim", "azor", "sadoque", "aquim", "eliude", "eleazar", "mata", "mt-jaco"], "Os anos de silêncio",
            "Depois de Zorobabel vêm nove nomes de quem não sabemos quase nada. Viveram sob persas, gregos e "
            "romanos, sem rei e sem profeta. A família real virou família de trabalhadores. Ninguém mais contava com "
            "ela, mas o céu continuava contando as gerações.",
            "Mt 1:13-15", "templo-reconstrucao")
    q.passo(["mt-jaco", "jose", "maria", "jesus"], "Da qual nasceu Jesus",
            "No último elo a frase muda. Mateus não escreve que José gerou Jesus. Escreve: José, marido de Maria, da "
            "qual nasceu Jesus, que se chama o Cristo. José dá ao menino o nome e o direito ao trono de Davi; a "
            "concepção é obra do Espírito Santo. Completa-se o terceiro grupo.",
            "Mt 1:16-17", "anunciacao")
    q.passo(["lc-adao", "lc-abraao", "lc-davi", "lc-nata", "lc-salatiel", "lc-matate", "heli"], "A lista de Lucas",
            "Lucas põe a genealogia logo depois do batismo de Jesus e a escreve ao contrário: de Jesus para trás, "
            "até Adão, filho de Deus. De Abraão a Davi os nomes são os mesmos de Mateus. Depois de Davi, Lucas segue "
            "por Natã, e não por Salomão.",
            "Lc 3:23-38", "batismo-jesus")
    q.passo(["mt-jaco", "heli", "jose", "maria"], "Por que as listas são diferentes",
            "Mateus diz que o pai de José era Jacó; Lucas diz Heli. Há duas explicações antigas. Uma: Lucas registra "
            "a família de Maria. Outra: as duas são de José, uma pela sucessão legal e outra pelo sangue. A Bíblia "
            "não explica. O certo é que, por qualquer caminho, Jesus é descendente de Davi.",
            "Lc 3:23", "maria-jose-viagem")
    q.passo(["abraao", "davi", "jesus", "lc-adao"], "O que a genealogia ensina",
            "Deus cumpre o que promete, mesmo que leve séculos. Ele usa gente falha, estrangeiros e desconhecidos. E "
            "toda a história caminha para uma pessoa. Jesus é o descendente de Abraão que abençoa as nações, o Filho "
            "de Davi que reina para sempre e o novo Adão que dá vida.",
            "Gl 3:16", "magos")
    return q
