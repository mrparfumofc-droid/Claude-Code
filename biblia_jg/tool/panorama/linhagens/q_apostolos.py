"""Quadro 4: os doze apóstolos (mais Matias, Paulo e Tiago, irmão do Senhor)."""
from build_linhagens import Quadro, AZUL, TEAL, MARINHO, CINZA, ROXO, MARROM

G3 = "FF5E35B1"
TRAD = "segundo a tradição"


def build():
    q = Quadro(
        "apostolos", "Os doze apóstolos",
        "Quem é quem, de onde vieram, o que fizeram e o que escreveram", AZUL, "pescadores-chamado",
        "Jesus escolheu doze homens comuns para estarem com ele e serem enviados. Este quadro mostra os doze na "
        "ordem das listas dos Evangelhos, em três grupos de quatro, com a origem, o ofício e os momentos marcantes "
        "de cada um. O que a Bíblia não conta, como a morte da maioria deles, vem indicado como tradição.")

    q.no("jesus", "Jesus", "destaque", 616, 90, "o Mestre",
         "Passou a noite em oração no monte e, pela manhã, chamou os discípulos e escolheu doze, a quem deu o nome "
         "de apóstolos, isto é, enviados. Escolheu-os para estarem com ele e para mandá-los pregar. Doze, como as "
         "tribos de Israel: Jesus estava formando o povo da nova aliança.",
         ["Lc 6:12-13", "Mc 3:13-15", "Mt 19:28", "Jo 15:16"], "sermao-monte", "Jesus", ROXO)

    grupos = [
        ("g1", 220, "Primeiro grupo", "Pedro vem sempre primeiro", AZUL,
         "As quatro listas dos doze (Mateus 10, Marcos 3, Lucas 6 e Atos 1) seguem o mesmo desenho: três grupos de "
         "quatro, e o primeiro nome de cada grupo nunca muda. O primeiro grupo reúne dois pares de irmãos, "
         "pescadores do mar da Galileia. Pedro, Tiago e João formam o círculo mais próximo de Jesus.",
         ["Mt 10:2-4", "Mc 3:16-19", "Lc 6:14-16", "At 1:13"]),
        ("g2", 616, "Segundo grupo", "Filipe vem primeiro", TEAL,
         "Filipe, Bartolomeu, Tomé e Mateus. São os que mais fazem perguntas no Evangelho de João: Filipe quer ver "
         "o Pai, Tomé quer saber o caminho. Mateus é o cobrador de impostos que largou a coletoria.",
         ["Mt 10:3", "Jo 14:5", "Jo 14:8"]),
        ("g3", 1012, "Terceiro grupo", "Tiago, filho de Alfeu, primeiro", G3,
         "Tiago, filho de Alfeu, Tadeu, Simão, o zelote, e Judas Iscariotes. São os menos conhecidos: de três deles "
         "a Bíblia quase não guarda palavras. O último nome é sempre o do traidor.",
         ["Mt 10:3-4", "Lc 6:15-16"]),
    ]
    for id, x, nome, sub, cor, texto, refs in grupos:
        q.no(id, nome, "grupo", x, 190, sub, texto, refs, "ultima-ceia", None, cor, w=250, h=48)
        q.liga("jesus", id, meio=142)
        q.faixa(x - 190, 226, 380, 170, "", "", cor)

    def ap(id, nome, sub, col, row, cor, retrato, arte, fatos, texto, refs):
        x = (220, 616, 1012)[col // 2] + (-95 if col % 2 == 0 else 95)
        q.no(id, nome, "pessoa", x, 272 + 68 * row, sub, texto, refs, arte, retrato, cor, fatos=fatos, w=170, h=50)

    ap("pedro", "Pedro", "Simão, Cefas", 0, 0, AZUL, "Pedro", "pedro-sermao",
       [("Também chamado", "Simão, filho de Jonas; Cefas, que quer dizer pedra"),
        ("Origem", "Betsaida; morava em Cafarnaum"), ("Ofício", "pescador"), ("Escreveu", "1 e 2 Pedro"),
        ("Fim", f"{TRAD}, crucificado em Roma no tempo de Nero, entre 64 e 67 d.C.")],
       "O primeiro em todas as listas e o porta-voz do grupo. Confessou: tu és o Cristo, o Filho do Deus vivo. "
       "Andou sobre as águas, negou o Mestre três vezes e foi restaurado à beira do mar. No Pentecostes pregou, e "
       "quase três mil se converteram; depois abriu a porta do evangelho aos gentios, na casa de Cornélio.",
       ["Jo 1:40-42", "Mt 16:16-18", "Lc 22:61-62", "Jo 21:15-17", "At 2:14", "At 10:34-35"])
    ap("andre", "André", "irmão de Pedro", 1, 0, AZUL, "André", "lin-andre-pedro",
       [("Origem", "Betsaida"), ("Ofício", "pescador; antes, discípulo de João Batista"),
        ("Fim", f"{TRAD}, pregou na Grécia e foi crucificado em Patras, numa cruz em forma de X")],
       "Um dos dois primeiros a seguir Jesus. A primeira coisa que fez foi procurar o irmão: achamos o Messias. "
       "Aparece sempre levando alguém a Jesus: Pedro, o menino dos pães e dos peixes, os gregos que queriam ver o "
       "Mestre.",
       ["Jo 1:35-42", "Mc 1:16-18", "Jo 6:8-9", "Jo 12:20-22"])
    ap("tiago", "Tiago", "filho de Zebedeu", 0, 1, AZUL, "Tiago, filho de Zebedeu", "lin-tiago-joao-barco",
       [("Também chamado", "Tiago, o maior; com João, Boanerges, isto é, filhos do trovão"),
        ("Origem", "margens do mar da Galileia"), ("Ofício", "pescador, sócio de Pedro"),
        ("Fim", "morto à espada por ordem de Herodes Agripa I, por volta de 44 d.C. (At 12:2)")],
       "Com Pedro e João, formava o círculo mais próximo de Jesus: viu a filha de Jairo ressuscitar, a "
       "transfiguração e a agonia no Getsêmani. Foi o primeiro dos doze a morrer pela fé. É o único apóstolo cujo "
       "martírio o Novo Testamento registra.",
       ["Mc 1:19-20", "Mc 3:17", "Mc 5:37", "Mc 9:2", "At 12:1-2"])
    ap("joao", "João", "o discípulo amado", 1, 1, AZUL, "João", "patmos-joao",
       [("Origem", "margens do mar da Galileia; filho de Zebedeu"), ("Ofício", "pescador"),
        ("Escreveu", "o Evangelho de João, 1, 2 e 3 João e o Apocalipse"),
        ("Fim", f"{TRAD}, morreu idoso em Éfeso, perto do ano 100")],
       "Irmão de Tiago. Reclinou-se ao lado de Jesus na ceia, ficou ao pé da cruz e recebeu o cuidado de Maria. "
       "Foi coluna da igreja em Jerusalém, com Pedro e Tiago. Exilado na ilha de Patmos por causa da Palavra, "
       "recebeu a revelação de Jesus Cristo.",
       ["Jo 13:23", "Jo 19:26-27", "At 3:1", "Gl 2:9", "Ap 1:9"])
    q.casal("pedro", "andre")
    q.casal("tiago", "joao")

    ap("filipe", "Filipe", "de Betsaida", 2, 0, TEAL, "Filipe, o apóstolo", "lin-filipe-natanael",
       [("Origem", "Betsaida, a cidade de André e de Pedro"),
        ("Fim", f"{TRAD}, pregou na Frígia e morreu em Hierápolis")],
       "Jesus o encontrou e disse: segue-me. Ele logo foi buscar Natanael: vem e vê. Na multiplicação dos pães fez "
       "as contas e achou impossível; na ceia pediu: Senhor, mostra-nos o Pai. Não confundir com Filipe, o "
       "evangelista, um dos sete de Atos 6.",
       ["Jo 1:43-46", "Jo 6:5-7", "Jo 12:21-22", "Jo 14:8-9"])
    ap("bartolomeu", "Bartolomeu", "Natanael", 3, 0, TEAL, "Bartolomeu", "lin-filipe-natanael",
       [("Também chamado", "muito provavelmente é o Natanael do Evangelho de João"), ("Origem", "Caná da Galileia"),
        ("Fim", f"{TRAD}, pregou na Armênia e na Índia e morreu mártir")],
       "Nas listas aparece sempre ao lado de Filipe, que levou Natanael a Jesus; por isso se entende que são a "
       "mesma pessoa. Duvidou: de Nazaré pode sair alguma coisa boa? Jesus o chamou de verdadeiro israelita, em "
       "quem não há dolo, e ele confessou: tu és o Filho de Deus, tu és o Rei de Israel.",
       ["Mt 10:3", "Jo 1:45-49", "Jo 21:2"])
    ap("tome", "Tomé", "Dídimo", 2, 1, TEAL, "Tomé", "tome",
       [("Também chamado", "Dídimo, que quer dizer gêmeo"),
        ("Fim", f"{TRAD}, levou o evangelho até a Índia, onde morreu mártir")],
       "É lembrado pela dúvida, mas era corajoso: vamos também nós, para morrermos com ele. Perguntou o caminho e "
       "ouviu: eu sou o caminho, a verdade e a vida. Só creu na ressurreição quando viu, e então fez a confissão "
       "mais alta dos Evangelhos: Senhor meu e Deus meu.",
       ["Jo 11:16", "Jo 14:5-6", "Jo 20:24-29"])
    ap("mateus", "Mateus", "Levi, o publicano", 3, 1, TEAL, "Mateus", "lin-mateus-coletoria",
       [("Também chamado", "Levi, filho de Alfeu"), ("Origem", "Cafarnaum"),
        ("Ofício", "cobrador de impostos (publicano)"), ("Escreveu", "o Evangelho de Mateus"),
        ("Fim", "as tradições divergem: Etiópia ou Pérsia")],
       "Trabalhava para os romanos, na coletoria, e era malvisto pelo povo. Jesus passou e disse: segue-me. Ele "
       "deixou tudo e deu um banquete em casa, cheio de publicanos e pecadores. O seu Evangelho mostra Jesus como "
       "o Messias prometido nas Escrituras.",
       ["Mt 9:9-13", "Mc 2:14", "Lc 5:27-29"])

    ap("tiago-alfeu", "Tiago", "filho de Alfeu", 4, 0, G3, "Tiago, filho de Alfeu", "lin-tiago-tadeu-simao",
       [("Também chamado", "talvez seja Tiago, o menor (Mc 15:40)"), ("Fim", "as tradições são incertas")],
       "Encabeça o terceiro grupo em todas as listas. A Bíblia não registra nenhuma palavra sua: serviu sem "
       "aparecer. Não confundir com Tiago, filho de Zebedeu, nem com Tiago, irmão do Senhor, que escreveu a carta.",
       ["Mt 10:3", "Mc 3:18", "Mc 15:40", "At 1:13"])
    ap("tadeu", "Tadeu", "Judas, filho de Tiago", 5, 0, G3, "Tadeu", "lin-tiago-tadeu-simao",
       [("Também chamado", "Judas, filho de Tiago, em Lucas e Atos; Lebeu, em alguns manuscritos"),
        ("Fim", f"{TRAD}, pregou na Síria e na Pérsia")],
       "Mateus e Marcos o chamam de Tadeu; Lucas, de Judas, filho de Tiago. João faz questão de avisar: Judas, não "
       "o Iscariotes. Na ceia perguntou por que Jesus se manifestaria a eles e não ao mundo, e ouviu: se alguém me "
       "ama, guardará a minha palavra.",
       ["Mt 10:3", "Lc 6:16", "Jo 14:22-23", "At 1:13"])
    ap("simao-zelote", "Simão", "o zelote", 4, 1, G3, "Simão, o zelote", "lin-tiago-tadeu-simao",
       [("Também chamado", "Simão, o cananeu: palavra aramaica para zeloso, sem ligação com Canaã"),
        ("Fim", f"{TRAD}, pregou na Pérsia e morreu mártir")],
       "O apelido indica zelo pela lei e, talvez, ligação com os que queriam expulsar os romanos pela força. Jesus "
       "pôs entre os doze um zelote e um cobrador de impostos a serviço de Roma: só o evangelho faz dois inimigos "
       "se sentarem à mesma mesa.",
       ["Lc 6:15", "Mt 10:4", "At 1:13"])
    ap("judas", "Judas Iscariotes", "o que o traiu", 5, 1, CINZA, "Judas Iscariotes", "lin-judas-moedas",
       [("Origem", "Iscariotes provavelmente quer dizer homem de Queriote, vila de Judá; seria o único dos doze "
                   "que não era galileu"),
        ("No grupo", "guardava a bolsa do dinheiro"), ("Fim", "enforcou-se depois de devolver as moedas (Mt 27:5)")],
       "Sempre o último das listas. Andou com Jesus, ouviu tudo, viu os milagres, e era ladrão. Combinou a entrega "
       "por trinta moedas de prata e apontou o Mestre com um beijo. Tomado de remorso, devolveu o dinheiro e se "
       "matou. Remorso não é arrependimento: Pedro também caiu, mas voltou.",
       ["Jo 12:4-6", "Mt 26:14-16", "Mt 26:47-50", "Mt 27:3-5", "At 1:16-18"])

    # ---------------- Depois da ressurreição ----------------
    q.faixa(30, 430, 1172, 138, "Depois da ressurreição", "At 1–2; 1Co 15:5-9", MARINHO)
    q.no("paulo", "Paulo", "destaque", 132, 522, "aos gentios",
         "Não era dos doze e tinha perseguido a igreja. O Cristo ressuscitado lhe apareceu no caminho de Damasco e "
         "o enviou às nações. Ele mesmo se dizia o menor dos apóstolos, como um nascido fora do tempo. Pedro, Tiago "
         "e João reconheceram a graça que lhe foi dada e lhe estenderam a mão direita da comunhão.",
         ["At 9:15", "1Co 15:8-10", "Gl 2:7-9", "Rm 11:13"], "damasco-luz", "Paulo", MARINHO, link="quadro:paulo")
    q.no("tiago-senhor", "Tiago", "pessoa", 352, 522, "irmão do Senhor",
         "Um dos irmãos de Jesus citados em Marcos 6:3. Não creu durante o ministério. Jesus ressuscitado lhe "
         "apareceu, e ele se tornou o principal líder da igreja em Jerusalém: conduziu o concílio de Atos 15. Paulo "
         "o chama de apóstolo e de coluna. Escreveu a carta de Tiago; Judas, autor de outra carta, era seu irmão.",
         ["Mc 6:3", "Jo 7:5", "1Co 15:7", "At 15:13", "Gl 1:19", "Tg 1:1"], "concilio-jerusalem", None, MARINHO,
         fatos=[("Escreveu", "a carta de Tiago"),
                ("Fim", "segundo o historiador Josefo, apedrejado em Jerusalém por volta de 62 d.C.")], w=176, h=50)
    q.no("m-pentecostes", "Cheios do Espírito", "marco", 600, 522, "At 2:1-4",
         "Antes da cruz, eles discutiam quem era o maior, dormiram no Getsêmani e fugiram. Jesus ressuscitado os "
         "reuniu, e no dia de Pentecostes todos foram cheios do Espírito Santo. Os mesmos homens passaram a anunciar "
         "a ressurreição diante das autoridades: não podemos deixar de falar do que vimos e ouvimos.",
         ["Mc 14:50", "At 1:8", "At 2:1-4", "At 4:19-20", "At 4:33"], "pentecostes", None, MARROM, w=230)
    q.no("m-fundamentos", "Doze fundamentos", "marco", 850, 522, "Ap 21:14",
         "A igreja está edificada sobre o fundamento dos apóstolos e dos profetas, e Jesus Cristo é a pedra "
         "angular. Na visão de João, o muro da nova Jerusalém tem doze fundamentos, com os nomes dos doze apóstolos "
         "do Cordeiro. O ensino deles, guardado no Novo Testamento, continua sendo a base da fé.",
         ["Ef 2:20", "At 2:42", "Ap 21:14", "Mt 19:28"], "nova-jerusalem", None, MARROM, w=230)
    q.no("matias", "Matias", "pessoa", 1107, 522, "no lugar de Judas",
         "Depois da ascensão, cerca de cento e vinte discípulos oravam em Jerusalém. Pedro explicou que alguém devia "
         "tomar o lugar de Judas: um homem que tivesse acompanhado Jesus desde o batismo de João até a ascensão, "
         "para ser testemunha da ressurreição. Apresentaram dois, oraram e lançaram sortes. A sorte caiu sobre "
         "Matias.",
         ["At 1:15", "At 1:21-26"], "lin-matias-sortes", "Matias", G3, w=170, h=50)
    q.liga("judas", "matias", tracejada=True)

    # ---------------- Apresentação ----------------
    q.passo(["jesus", "g1", "g2", "g3"], "Uma noite de oração e doze nomes",
            "Antes de escolher, Jesus sobe ao monte e passa a noite orando. Pela manhã chama os discípulos e separa "
            "doze, para estarem com ele e para enviá-los a pregar. São pescadores, um cobrador de impostos, um "
            "zelote. Nenhum doutor da lei. Doze, como as tribos de Israel.",
            "Lc 6:12-13", "sermao-monte")
    q.passo(["g1", "g2", "g3"], "Três grupos de quatro",
            "O Novo Testamento traz quatro listas dos doze. A ordem dos nomes muda um pouco, mas o desenho é sempre "
            "o mesmo: três grupos de quatro. Pedro abre o primeiro, Filipe o segundo, e Tiago, filho de Alfeu, o "
            "terceiro. Judas Iscariotes fecha todas as listas.",
            "Mt 10:2-4", "ultima-ceia")
    q.passo(["pedro", "andre"], "Pedro e André",
            "Dois irmãos de Betsaida, pescadores. André ouve João Batista apontar o Cordeiro de Deus, segue Jesus e "
            "corre para buscar o irmão. Jesus olha para Simão e lhe dá um nome novo: Pedro, pedra. Impulsivo e "
            "sincero, ele será o primeiro a confessar: tu és o Cristo.",
            "Jo 1:40-42", "lin-andre-pedro")
    q.passo(["tiago", "joao"], "Os filhos do trovão",
            "Tiago e João consertavam as redes com o pai, Zebedeu, quando Jesus os chamou. Eram de gênio forte: "
            "quiseram pedir fogo do céu sobre uma aldeia. Jesus os apelidou de filhos do trovão. Tiago será o "
            "primeiro apóstolo mártir; João, segundo a tradição o último a morrer, é lembrado como o apóstolo do amor.",
            "Mc 3:17", "lin-tiago-joao-barco")
    q.passo(["filipe", "bartolomeu"], "Vem e vê",
            "Filipe encontra Natanael debaixo da figueira e anuncia: achamos aquele de quem Moisés escreveu. "
            "Natanael desconfia de Nazaré. Filipe não discute: vem e vê. Jesus recebe o desconfiado com um elogio, e "
            "ele se rende. Natanael é, muito provavelmente, o Bartolomeu das listas.",
            "Jo 1:45-46", "lin-filipe-natanael")
    q.passo(["tome", "mateus"], "O que duvidou e o cobrador",
            "Tomé queria ver para crer, e Jesus o atendeu: põe aqui o teu dedo. Ele respondeu: Senhor meu e Deus "
            "meu. Mateus cobrava impostos para Roma quando ouviu: segue-me. Levantou-se, deixou tudo e abriu a casa "
            "para Jesus. Anos depois escreveu o primeiro Evangelho da nossa Bíblia.",
            "Mt 9:9", "lin-mateus-coletoria")
    q.passo(["tiago-alfeu", "tadeu", "simao-zelote"], "Os três discretos",
            "De Tiago, filho de Alfeu, não ficou nenhuma palavra. De Tadeu, uma pergunta na última ceia. De Simão, "
            "só o apelido: o zelote. A Bíblia quase não fala deles, e mesmo assim foram escolhidos, enviados e "
            "cheios do Espírito. No reino de Deus, ser fiel vale mais que ser conhecido.",
            "Lc 6:15-16", "lin-tiago-tadeu-simao")
    q.passo(["judas", "matias"], "O lugar vazio",
            "Judas andou cerca de três anos com Jesus e o entregou por trinta moedas de prata. Depois da ascensão, os "
            "discípulos oram e escolhem alguém que esteve com eles desde o batismo de João, para ser testemunha da "
            "ressurreição. A sorte cai sobre Matias, e os doze estão completos para o Pentecostes.",
            "At 1:24-26", "lin-matias-sortes")
    q.passo(["m-pentecostes", "pedro", "joao"], "De medrosos a testemunhas",
            "Na noite da prisão de Jesus, todos fugiram. Cinquenta dias depois da Páscoa, o Espírito Santo desce "
            "sobre eles, e Pedro prega diante da multidão em Jerusalém. Presos e ameaçados, respondem: não podemos "
            "deixar de falar do que vimos e ouvimos. A diferença foi a ressurreição e o poder do alto.",
            "At 1:8", "pentecostes")
    q.passo(["paulo", "tiago-senhor"], "Outros chamados de apóstolos",
            "O Novo Testamento chama de apóstolos alguns que não eram dos doze. Tiago, irmão do Senhor, viu o "
            "Ressuscitado e guiou a igreja de Jerusalém. Paulo, o perseguidor, foi alcançado no caminho de Damasco "
            "e enviado aos gentios. Ele mesmo se dizia o menor dos apóstolos.",
            "Gl 2:9", "concilio-jerusalem")
    q.passo(["m-fundamentos", "mateus", "joao", "pedro"], "O que eles deixaram",
            "Três dos doze escreveram livros do Novo Testamento: Mateus, João e Pedro. A Bíblia só registra a morte "
            "de Tiago; dos outros, a tradição antiga conta que quase todos morreram longe de casa, anunciando "
            "Cristo. Na nova Jerusalém, os nomes dos doze estão nos fundamentos da cidade.",
            "Ap 21:14", "nova-jerusalem")
    return q
