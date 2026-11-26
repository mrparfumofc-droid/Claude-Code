"""Quadro 6: Israel e Judá, os dois povos, do mesmo tronco até os dias de hoje."""
from build_linhagens import Quadro, VIOLETA, MARINHO, VERMELHO, OURO, ROXO

XN, XC, XS = 200, 560, 920  # norte, tronco, sul
ARDOSIA = "FF37474F"


def build():
    q = Quadro(
        "povos", "Israel e Judá: os dois povos",
        "Do mesmo tronco aos dois reinos, o exílio, a dispersão e os dias de hoje", VIOLETA, "josue-alianca",
        "Israel e Judá começam como uma só família, a de Jacó. Depois de Salomão viram dois reinos, com capitais, "
        "reis e destinos diferentes. Este quadro acompanha os dois ramos: o norte, que caiu diante da Assíria, e o "
        "sul, de onde vêm o nome judeu e o Messias, até a dispersão e os dias de hoje. A parte recente é contada de "
        "modo breve, só com os fatos.")

    q.faixa(420, 30, 280, 519, "Um só povo", "de Jacó a Salomão", MARINHO)
    q.faixa(60, 680, 280, 403, "", "", VERMELHO)
    q.faixa(780, 680, 280, 479, "", "", OURO)
    q.faixa(420, 1215, 280, 636, "", "", ARDOSIA)

    # ---------------- Um só povo ----------------
    tronco = [
        ("jaco", "Jacó recebe o nome Israel", "c. 1900 a.C.", "jaco-gosen", "abraao",
         "Jacó, neto de Abraão, lutou com Deus no vau do Jaboque e saiu de lá com um nome novo: Israel. É o nome de "
         "um homem antes de ser o nome de um povo. Tudo o que vem depois, as tribos, os dois reinos e os judeus de "
         "hoje, sai deste tronco.",
         ["Gn 32:27-28", "Gn 35:9-12"]),
        ("doze", "Doze filhos, doze tribos", "Gn 35 e 49", "lin-jaco-bencao", None,
         "De Lia, Raquel, Bila e Zilpa, Jacó teve doze filhos. Cada um se tornou pai de uma tribo. No leito de "
         "morte, no Egito, abençoou todos e anunciou o futuro de cada um: a Judá, o cetro; a José, a porção dobrada.",
         ["Gn 35:22-26", "Gn 49:1-2", "Gn 49:28"]),
        ("egito", "No Egito, a família vira um povo", "c. 1800–1450 a.C.", "exodo-saida", None,
         "Setenta pessoas desceram ao Egito nos dias de José. Séculos depois eram uma multidão, escravizada pelo "
         "faraó. Deus ouviu o clamor, levantou Moisés e tirou o povo com mão forte. Pela primeira vez Israel é "
         "chamado de meu povo.",
         ["Gn 46:27", "Êx 1:7", "Êx 3:7-10", "Êx 12:40-41"]),
        ("sinai", "Do Sinai à terra prometida", "c. 1450–1050 a.C.", "josue-alianca", None,
         "No Sinai Deus fez aliança com Israel: sereis reino de sacerdotes e nação santa. Depois de quarenta anos no "
         "deserto, Josué repartiu Canaã entre as tribos. No tempo dos juízes cada tribo cuidava de si, e o povo só "
         "se unia quando um libertador se levantava.",
         ["Êx 19:5-6", "Js 21:43-45", "Jz 21:25"]),
        ("unido", "O reino unido", "c. 1050–931 a.C.", "davi-coroado", "reis",
         "As tribos pediram um rei. Saul, de Benjamim, foi o primeiro. Davi, de Judá, reinou sete anos só sobre a "
         "sua tribo, em Hebrom, e depois uniu todo o Israel, com capital em Jerusalém. Salomão construiu o templo. "
         "Foram cerca de cento e vinte anos com um só trono, e a rivalidade entre o norte e Judá já aparecia.",
         ["1Sm 8:19-20", "2Sm 2:4", "2Sm 5:1-5", "2Sm 19:41-43"]),
        ("divisao", "A divisão do reino", "c. 931 a.C.", "lin-siquem-divisao", None,
         "Salomão sobrecarregou o povo e se desviou. Quando morreu, as tribos do norte pediram alívio ao seu filho "
         "Roboão, em Siquém. Ele respondeu com dureza, e elas gritaram: que parte temos nós com Davi? O reino se "
         "partiu em dois, como o profeta Aías tinha anunciado, e nunca mais voltou a ser um só.",
         ["1Rs 11:29-32", "1Rs 12:13-16", "1Rs 12:19-20"]),
    ]
    for k, (id, nome, sub, arte, link, texto, refs) in enumerate(tronco):
        q.no(id, nome, "marco", XC, 120 + 76 * k, sub, texto, refs, arte, None, MARINHO, link=link)
    q.cadeia([t[0] for t in tronco])
    q.no("tribos", "As doze tribos", "grupo", XN, 196, "José vale por duas",
         "Rúben, Simeão, Levi, Judá, Dã, Naftali, Gade, Aser, Issacar, Zebulom, José e Benjamim. Na divisão da "
         "terra, José conta como duas tribos, Efraim e Manassés, e Levi não recebe território, porque serve no "
         "santuário. Por isso a lista continua com doze.",
         ["Gn 48:5", "Js 14:3-4", "Nm 1:47-50"], None, None, MARINHO, w=250, h=50, link="abraao")
    q.no("nomes", "Hebreu, israelita, judeu", "grupo", XS, 196, "três nomes, uma história",
         "Hebreu é o nome mais antigo: Abrão, o hebreu, talvez por causa do antepassado Héber. Israelita vem de "
         "Israel, o nome de Jacó, e indica o povo das doze tribos. Judeu vem de Judá: primeiro o habitante do reino "
         "do sul; depois, a partir do exílio, todo o povo. Paulo usa os três para falar de si mesmo.",
         ["Gn 14:13", "Êx 3:18", "2Rs 16:6", "Et 2:5", "Fp 3:5", "2Co 11:22"], None, None, MARINHO, w=250, h=50)
    q.liga("doze", "tribos", tracejada=True, h=True)
    q.liga("doze", "nomes", tracejada=True, h=True)

    # ---------------- Os dois reinos ----------------
    q.no("hn", "Israel, o reino do norte", "grupo", XN, 640, "dez tribos · capital Samaria",
         "Depois da divisão, o nome Israel passou a indicar só o reino do norte, formado por dez tribos. Os profetas "
         "também o chamam de Efraim, a tribo mais forte, ou de Samaria, a capital. Durou cerca de 210 anos e teve "
         "dezenove reis, de várias famílias que se derrubaram umas às outras.",
         ["1Rs 12:20", "1Rs 16:24", "Os 5:3"], None, None, VERMELHO, w=264, h=52)
    q.no("hs", "Judá, o reino do sul", "grupo", XS, 640, "Judá e Benjamim · Jerusalém",
         "O reino do sul ficou com a tribo de Judá, com Benjamim e com os sacerdotes e levitas, que deixaram o norte "
         "para servir no templo. Tinha Jerusalém, o templo e a casa de Davi. Durou cerca de 345 anos, com dezenove "
         "reis de uma só família e uma rainha usurpadora.",
         ["1Rs 12:21-23", "2Cr 11:13-14", "1Rs 15:4"], None, None, OURO, w=264, h=52)
    q.liga("divisao", "hn", meio=585)
    q.liga("divisao", "hs", meio=585)
    q.no("reis2", "Dois reinos, lado a lado", "grupo", XC, 730, "ver a linha dos reis",
         "Por dois séculos os dois reinos viveram lado a lado, ora em guerra, ora aliados. Os livros de Reis contam "
         "as duas histórias em paralelo e medem cada rei por uma pergunta: fez o que era reto diante do Senhor?",
         ["1Rs 14:30", "1Rs 22:2-4", "2Rs 17:13"], None, None, MARINHO, w=220, h=50, link="reis")

    norte = [
        ("n-bezerros", "Os bezerros de Jeroboão", "931 a.C. em diante", "carmelo-fogo",
         "Para que o povo não subisse a Jerusalém, Jeroboão pôs bezerros de ouro em Betel e em Dã e criou sacerdotes "
         "e festas próprias. Esse foi o pecado que acompanhou o norte até o fim. Nenhum dos seus dezenove reis é "
         "aprovado pela Bíblia; Acabe e Jezabel trouxeram o culto a Baal.",
         ["1Rs 12:26-30", "1Rs 16:30-33", "2Rs 17:21-22"]),
        ("n-profetas", "Profetas no norte", "séculos IX e VIII a.C.", "elias-horebe",
         "Deus não desistiu de Israel. Mandou Elias e Eliseu, que enfrentaram Baal com poder; depois Amós, que "
         "denunciou a injustiça, e Oseias, que falou do amor ferido de Deus: como te deixaria, ó Efraim? Jonas, "
         "também do norte, foi enviado a Nínive.",
         ["1Rs 18:21", "Am 5:24", "Os 11:8", "2Rs 14:25"]),
        ("n-queda", "A queda de Samaria", "722 a.C.", "lin-samaria-queda",
         "Depois de três anos de cerco, a Assíria tomou Samaria e levou o povo para longe, para terras da "
         "Mesopotâmia e da Média. O reino do norte acabou. A Bíblia dá o motivo: pecaram contra o Senhor, andaram "
         "nos costumes das nações e não deram ouvidos aos profetas.",
         ["2Rs 17:5-8", "2Rs 17:13-14", "2Rs 17:22-23"]),
        ("n-samaritanos", "Os samaritanos", "722 a.C. em diante", "bom-samaritano",
         "A Assíria trouxe gente de outros povos para morar em Samaria. Eles se misturaram com os israelitas que "
         "ficaram e juntaram o culto ao Senhor com o dos seus deuses. Daí vieram os samaritanos, que mais tarde "
         "tiveram um templo no monte Gerizim. Judeus e samaritanos não se davam; Jesus atravessou essa barreira, e "
         "Samaria recebeu o evangelho. Ainda hoje existe uma pequena comunidade samaritana, com menos de mil "
         "pessoas.",
         ["2Rs 17:24", "2Rs 17:33", "Ed 4:1-3", "Jo 4:9", "Jo 4:20-22", "At 8:5-8"]),
        ("n-remanescente", "As dez tribos se perderam?", "o remanescente do norte", "templo-salomao",
         "Não por inteiro. Desde a divisão, muita gente do norte passou para Judá para adorar em Jerusalém, e depois "
         "da queda de Samaria outros atenderam ao convite de Ezequias. No Novo Testamento, Ana é da tribo de Aser, "
         "Paulo fala das nossas doze tribos, e Tiago escreve às doze tribos da dispersão. A maior parte dos "
         "deportados, porém, se perdeu entre as nações.",
         ["2Cr 11:16", "2Cr 15:9", "2Cr 30:10-11", "Lc 2:36", "At 26:7", "Tg 1:1"]),
    ]
    sul = [
        ("s-davi", "A casa de Davi em Jerusalém", "931 a.C. em diante", "templo-salomao", "reis",
         "Judá guardou o que o norte perdeu: o templo, o sacerdócio de Arão e a linha de Davi. Mesmo assim, muitos "
         "dos seus reis fizeram o que era mau. Alguns são aprovados pela Bíblia, como Asa, Josafá, Ezequias e "
         "Josias. Por amor de Davi, Deus manteve uma lâmpada acesa em Jerusalém.",
         ["1Rs 15:4", "1Rs 15:11", "2Rs 8:19"]),
        ("s-reformas", "Reformas e avisos", "séculos VIII e VII a.C.", "lin-josias-livro", None,
         "Cerca de vinte anos depois da queda de Samaria, a Assíria cercou Jerusalém; Ezequias orou, e a cidade foi "
         "livrada. Josias achou o livro da lei e reformou o culto. Isaías, Miqueias, Sofonias e Jeremias pregaram "
         "arrependimento. Mas Judá não aprendeu com o que aconteceu à sua irmã do norte.",
         ["2Rs 18:5-7", "2Rs 19:35", "2Rs 23:25", "Jr 3:8"]),
        ("s-queda", "A queda de Jerusalém", "586 a.C.", "lin-jerusalem-586", None,
         "Nabucodonosor, rei da Babilônia, levou cativos em três ocasiões: em 605 a.C., com Daniel; em 597, com o "
         "rei Joaquim e Ezequiel; e em 586, quando queimou o templo, derrubou os muros e levou o resto do povo. Só "
         "os mais pobres ficaram na terra. O trono de Davi ficou vazio.",
         ["Dn 1:1-3", "2Rs 24:14-16", "2Rs 25:8-12", "2Cr 36:15-19"]),
        ("s-exilio", "Setenta anos na Babilônia", "605–538 a.C.", "daniel-jovens", None,
         "Jeremias avisou que o cativeiro duraria setenta anos e mandou os exilados construírem casas e orarem pela "
         "cidade. Sem templo, o povo se reuniu em torno das Escrituras; muitos veem aí o começo das sinagogas. "
         "Daniel e Ezequiel serviram a Deus em terra estranha. O exílio curou Judá da idolatria.",
         ["Jr 25:11-12", "Jr 29:4-7", "Jr 29:10", "Sl 137:1", "Ez 11:16"]),
        ("s-volta", "A volta para a terra", "538–445 a.C.", "neemias-muros", None,
         "Ciro, rei da Pérsia, conquistou a Babilônia e deixou os judeus voltarem. Vieram em três grupos: com "
         "Zorobabel, que reconstruiu o templo, pronto em 516 a.C.; com Esdras, que ensinou a lei; e com Neemias, "
         "que levantou os muros. Voltaram principalmente pessoas de Judá, de Benjamim e de Levi. Muitos ficaram na "
         "Babilônia e na Pérsia, como Ester e Mardoqueu.",
         ["Ed 1:1-5", "Ed 6:14-16", "Ne 6:15-16", "Et 2:5-6"]),
        ("s-judeu", "De Judá, o nome judeu", "depois do exílio", "mardoqueu-porta", None,
         "A palavra judeu vem de Judá. No começo indicava o homem do reino do sul. Como foi Judá que sobreviveu, "
         "voltou e guardou a lei, o nome passou a valer para todo o povo de Israel, de qualquer tribo: Mardoqueu é "
         "chamado judeu e é de Benjamim; Paulo também. Judaísmo é, ao pé da letra, a fé de Judá.",
         ["2Rs 25:25", "Et 2:5", "Zc 8:23", "At 21:39", "Rm 11:1"]),
    ]
    prev = "hn"
    for k, (id, nome, sub, arte, texto, refs) in enumerate(norte):
        q.no(id, nome, "marco", XN, 730 + 76 * k, sub, texto, refs, arte, None, VERMELHO)
        q.liga(prev, id)
        prev = id
    prev = "hs"
    for k, (id, nome, sub, arte, link, texto, refs) in enumerate(sul):
        q.no(id, nome, "marco", XS, 730 + 76 * k, sub, texto, refs, arte, None, OURO, link=link)
        q.liga(prev, id)
        prev = id
    q.liga("n-bezerros", "reis2", tracejada=True, h=True)
    q.liga("s-davi", "reis2", tracejada=True, h=True)

    # ---------------- Do exílio aos dias de hoje ----------------
    depois = [
        ("j-imperios", "Sob persas, gregos e romanos", "538–4 a.C.", "lin-macabeus-templo", ARDOSIA,
         "Os judeus viveram dois séculos sob a Pérsia. Em 332 a.C. chegou Alexandre, o Grande, e com ele a língua "
         "grega. Quando um rei da Síria profanou o templo, os macabeus se revoltaram e o purificaram, em 164 a.C.: é "
         "a origem da festa da Dedicação. Em 63 a.C. Roma tomou Jerusalém e, mais tarde, pôs Herodes no trono. Nesse "
         "período surgiram as sinagogas, os fariseus e os saduceus.",
         ["Dn 8:20-21", "Jo 10:22", "Lc 2:1", "Gl 4:4"]),
        ("j-jesus", "Nos dias de Jesus", "c. 5 a.C.–30 d.C.", "entrada-triunfal", ARDOSIA,
         "A terra estava dividida em Judeia, Samaria e Galileia, sob governo romano, e havia judeus espalhados por "
         "todo o império. Jesus nasceu judeu, da tribo de Judá e da casa de Davi, em Belém da Judeia. Disse à "
         "samaritana: a salvação vem dos judeus. Escolheu doze apóstolos, como as doze tribos, e chorou sobre "
         "Jerusalém.",
         ["Mt 2:1", "Jo 4:22", "Mt 15:24", "Lc 19:41-44", "Hb 7:14"]),
        ("j-igreja", "A igreja nasce em Jerusalém", "c. 30 d.C.", "pentecostes", ARDOSIA,
         "No Pentecostes, judeus de todas as nações ouviram o evangelho, e cerca de três mil creram. A primeira "
         "igreja era toda de judeus. Depois o evangelho alcançou os samaritanos e os gentios, e Paulo ensinou que em "
         "Cristo os dois povos se tornam um só. Ele usa a figura de uma oliveira: os gentios que creem são "
         "enxertados entre os ramos naturais.",
         ["At 2:5", "At 2:41", "At 8:14", "Ef 2:14-16", "Rm 11:17-18"]),
        ("j-70", "O templo destruído", "70 d.C.", "lin-templo-70", ARDOSIA,
         "Em 66 d.C. os judeus se revoltaram contra Roma. No ano 70, as legiões do general Tito cercaram Jerusalém, "
         "tomaram a cidade e queimaram o templo, como Jesus tinha dito: não ficará pedra sobre pedra. Segundo o "
         "historiador Josefo, a matança foi enorme. Sem templo, acabaram os sacrifícios; o judaísmo passou a girar "
         "em torno da sinagoga e do estudo da lei.",
         ["Mt 24:1-2", "Lc 19:43-44", "Lc 21:20-24"]),
        ("j-diaspora", "A dispersão entre as nações", "135 d.C. ao século XIX", "lin-diaspora-sinagoga", ARDOSIA,
         "Depois de outra revolta, em 132–135 d.C., o imperador Adriano proibiu os judeus de entrar em Jerusalém e "
         "mudou o nome da província para Síria Palestina. Por dezoito séculos o povo viveu espalhado, da Babilônia à "
         "Espanha, da Europa ao norte da África, quase sempre como minoria, muitas vezes perseguido e expulso. "
         "Conservou a língua das Escrituras, o sábado, as festas e a oração voltada para Jerusalém.",
         ["Dt 28:64-65", "Lc 21:24", "Jr 31:35-37"]),
        ("j-1948", "O retorno e o Estado de Israel", "1897–1948", "lin-retorno-1948", ARDOSIA,
         "No fim do século XIX nasceu o movimento sionista, que propunha um lar nacional para os judeus na terra dos "
         "seus antepassados, então parte do Império Otomano e, depois de 1917, sob administração britânica. A "
         "imigração cresceu. Na Segunda Guerra Mundial, o regime nazista assassinou cerca de seis milhões de judeus. "
         "Em 1947 a ONU aprovou a partilha do território em um Estado judeu e um Estado árabe; em 14 de maio de 1948 "
         "foi proclamado o Estado de Israel, e começou a primeira de várias guerras com os vizinhos árabes. Muitos "
         "cristãos veem nesse retorno um sinal ligado às promessas dos profetas; outros são mais cautelosos.",
         ["Ez 36:24", "Ez 37:21-22"]),
        ("j-hoje", "Hoje", "século XXI", "lin-jerusalem-hoje", ARDOSIA,
         "Israel tem hoje cerca de dez milhões de habitantes: uns sete milhões são judeus e cerca de dois milhões "
         "são árabes. Quase metade dos judeus do mundo vive no país; os demais continuam na dispersão, sobretudo nos "
         "Estados Unidos. O hebraico voltou a ser língua do dia a dia. O conflito entre israelenses e palestinos "
         "pela terra continua sem solução, com sofrimento dos dois lados. A Bíblia manda orar pela paz de Jerusalém.",
         ["Sl 122:6", "1Tm 2:1-2"]),
        ("j-futuro", "O futuro de Israel na Bíblia", "Rm 9–11", "lin-oliveira-enxerto", ROXO,
         "Paulo, judeu, trata do assunto em Romanos 9 a 11. Deus não rejeitou o seu povo. Há um remanescente que "
         "crê. Os gentios foram enxertados na oliveira e não devem se orgulhar. E virá o dia em que todo o Israel "
         "será salvo, porque os dons e a vocação de Deus são irrevogáveis. Ezequiel viu dois pedaços de madeira, "
         "Judá e Efraim, virarem um só na mão de Deus. Os cristãos entendem os detalhes de maneiras diferentes; o "
         "texto pede humildade e esperança.",
         ["Rm 11:1-2", "Rm 11:5", "Rm 11:17-18", "Rm 11:25-29", "Ez 37:16-22", "Jr 31:31", "Zc 12:10"]),
    ]
    for k, (id, nome, sub, arte, cor, texto, refs) in enumerate(depois):
        q.no(id, nome, "marco", XC, 1270 + 76 * k, sub, texto, refs, arte, None, cor)
    q.cadeia([d[0] for d in depois])
    q.liga("s-judeu", "j-imperios", meio=1185)
    q.liga("n-remanescente", "j-imperios", tracejada=True, meio=1185)

    # ---------------- Apresentação ----------------
    q.passo(["jaco"], "Um homem chamado Israel",
            "Antes de ser nome de povo ou de país, Israel é o nome que Deus deu a um homem. Jacó, neto de Abraão, "
            "lutou com Deus e saiu abençoado e com outro nome. Tudo o que este quadro mostra, os dois reinos, os "
            "judeus, a dispersão, começa nesta família.",
            "Gn 32:28", "jaco-gosen")
    q.passo(["doze", "tribos", "nomes"], "Doze filhos, doze tribos",
            "Jacó tem doze filhos, e cada um dá origem a uma tribo. José vale por duas, Efraim e Manassés; Levi fica "
            "sem território, para servir no santuário. Enquanto estão juntos, todos são filhos de Israel. Os nomes "
            "hebreu, israelita e judeu aparecem em momentos diferentes da mesma história.",
            "Gn 49:28", "lin-jaco-bencao")
    q.passo(["egito", "sinai"], "Um povo com aliança",
            "No Egito, setenta pessoas viram uma multidão. Deus tira o povo da escravidão e, no Sinai, faz aliança "
            "com ele: sereis a minha propriedade peculiar, reino de sacerdotes e nação santa. Josué reparte a terra, "
            "e por séculos as tribos vivem lado a lado, sem rei.",
            "Êx 19:5-6", "sinai-lei")
    q.passo(["unido"], "Um só trono",
            "Com Saul, Davi e Salomão, as doze tribos têm um só rei. Davi, da tribo de Judá, faz de Jerusalém a "
            "capital e recebe a promessa de um trono para sempre. É o auge. Mas a costura entre o norte e Judá é "
            "frágil, e os impostos e trabalhos de Salomão a desgastam.",
            "2Sm 5:1-5", "davi-coroado")
    q.passo(["divisao", "hn", "hs"], "O reino se parte",
            "Por volta de 931 a.C., em Siquém, o povo pede alívio ao rei Roboão. Ele responde com dureza, e dez "
            "tribos o abandonam e coroam Jeroboão. Agora há dois reinos: Israel, ao norte, com capital em Samaria; "
            "e Judá, ao sul, com Jerusalém, o templo e a casa de Davi.",
            "1Rs 12:16-20", "lin-siquem-divisao")
    q.passo(["hn", "n-bezerros", "n-profetas", "reis2"], "Israel, o norte",
            "Para afastar o povo de Jerusalém, Jeroboão levanta bezerros de ouro em Betel e em Dã. O norte tem "
            "dezenove reis, e nenhum é aprovado. Deus manda profetas: Elias, Eliseu, Amós e Oseias. O chamado é "
            "sempre o mesmo: voltem para o Senhor. O reino dura pouco mais de dois séculos.",
            "1Rs 12:28-30", "carmelo-fogo")
    q.passo(["n-queda", "n-samaritanos"], "Samaria cai",
            "Em 722 a.C. a Assíria toma Samaria e deporta o povo. Outros povos são trazidos para o lugar, misturam-se "
            "com os que ficaram e misturam também os cultos. Deles vêm os samaritanos, com quem os judeus não se "
            "davam. Jesus conversa com uma samaritana, e Samaria ouve o evangelho.",
            "2Rs 17:6", "lin-samaria-queda")
    q.passo(["hs", "s-davi", "s-reformas"], "Judá, o sul",
            "Judá tem o templo e a linha de Davi, e todos os seus reis são da mesma família. Há reis fiéis, como "
            "Ezequias e Josias, que fazem reformas, e profetas como Isaías e Jeremias. Mas Judá vê a queda do norte "
            "e não aprende: confia no templo e segue no mesmo pecado.",
            "Jr 3:8", "lin-josias-livro")
    q.passo(["s-queda", "s-exilio"], "Jerusalém cai",
            "Em 586 a.C. Nabucodonosor queima o templo, derruba os muros e leva o povo para a Babilônia. Parece o "
            "fim da promessa. Mas Jeremias tinha avisado: serão setenta anos. No exílio, Judá larga os ídolos, "
            "apega-se às Escrituras e aprende a orar voltado para Jerusalém.",
            "2Rs 25:8-11", "lin-jerusalem-586")
    q.passo(["s-volta", "s-judeu"], "A volta e um nome novo",
            "Ciro deixa o povo voltar. Com Zorobabel, Esdras e Neemias, levantam-se o templo, a lei e os muros. Quem "
            "volta é, na maioria, gente de Judá, Benjamim e Levi. Do nome Judá vem a palavra judeu, que desde então "
            "passa a indicar todo o povo de Israel.",
            "Ed 1:1-3", "neemias-muros")
    q.passo(["n-remanescente", "s-judeu", "j-imperios"], "E as dez tribos?",
            "Fala-se das dez tribos perdidas, e a maior parte dos deportados do norte de fato sumiu entre as nações. "
            "Mas muitos tinham passado para Judá antes e depois da queda de Samaria. Por isso o Novo Testamento "
            "ainda fala em doze tribos: o povo que volta do exílio guarda um resto de todas.",
            "2Cr 11:16", "templo-salomao")
    q.passo(["j-imperios"], "Entre os dois Testamentos",
            "Por quatro séculos os judeus vivem sob impérios: persas, gregos e romanos. Os macabeus purificam o "
            "templo profanado. Surgem as sinagogas, os fariseus e os saduceus, e o grego vira língua comum. Quando "
            "tudo está pronto, na plenitude do tempo, Deus envia o seu Filho.",
            "Gl 4:4", "lin-macabeus-templo")
    q.passo(["j-jesus", "j-igreja"], "O Messias de Israel",
            "Jesus nasce judeu, da tribo de Judá, em Belém. Ele diz que a salvação vem dos judeus e escolhe doze "
            "apóstolos. A igreja nasce em Jerusalém, entre judeus, e logo alcança samaritanos e gentios. Em Cristo, "
            "ensina Paulo, o muro de separação caiu, e dos dois povos Deus faz um só.",
            "Jo 4:22", "pentecostes")
    q.passo(["j-70", "j-diaspora"], "O templo cai outra vez",
            "No ano 70 as legiões romanas destroem Jerusalém e o templo, como Jesus havia anunciado. Depois de outra "
            "revolta, em 135, os judeus são proibidos de entrar na cidade. Começam dezoito séculos de dispersão, com "
            "perseguições e expulsões. Mesmo sem terra e sem templo, o povo não desaparece.",
            "Lc 21:20-24", "lin-templo-70")
    q.passo(["j-1948", "j-hoje"], "O retorno e os dias de hoje",
            "No século XIX começa o retorno à terra. Depois do Holocausto, em que morreram cerca de seis milhões de "
            "judeus, é proclamado em 1948 o Estado de Israel. Hoje vivem ali cerca de sete milhões de judeus e dois "
            "milhões de árabes. O conflito pela terra continua, e a Bíblia manda orar pela paz de Jerusalém.",
            "Sl 122:6", "lin-jerusalem-hoje")
    q.passo(["j-futuro"], "O que a Bíblia diz do futuro",
            "Em Romanos 11, Paulo afirma que Deus não rejeitou o seu povo. Os gentios foram enxertados na oliveira "
            "de Israel, e os ramos naturais podem ser enxertados de novo. Os dons e a vocação de Deus são "
            "irrevogáveis. Os cristãos divergem nos detalhes, mas o texto termina em adoração: ó profundidade da "
            "riqueza de Deus!",
            "Rm 11:25-29", "lin-oliveira-enxerto")
    return q
