"""Quadro 5: Paulo: origem, conversão, viagens, igrejas, as treze cartas e os companheiros."""
from build_linhagens import Quadro, CIANO, MARINHO, MARROM, ROSA, TEAL, VIOLETA, VERMELHO, LARANJA, CINZA

COLS = [140, 366, 592, 818, 1044, 1270]
YM, YP, YG, YC = 200, 400, 480, 540  # marcos da origem, períodos, grupos, primeira carta


def build():
    q = Quadro(
        "paulo", "Paulo, o apóstolo dos gentios",
        "Origem, conversão, viagens, companheiros, igrejas e as treze cartas", CIANO, "damasco-luz",
        "Nenhuma vida mudou tanto a história da igreja quanto a de Saulo de Tarso. Este quadro põe em ordem o que "
        "Atos e as cartas contam: de onde ele veio, como foi alcançado por Cristo, por onde andou, que igrejas "
        "nasceram, em que momento escreveu cada carta e quem caminhou com ele. As datas são aproximadas.")

    q.faixa(30, 125, 1350, 175, "Origem e conversão", "c. 5–47 d.C.", MARINHO, base=True)
    q.faixa(30, 320, 1350, 390, "Viagens, igrejas e cartas", "c. 46–67 d.C. · cada carta abaixo do momento em que foi escrita", CIANO, base=True)
    q.faixa(30, 730, 1350, 200, "Companheiros de Paulo", "Rm 16; Cl 4; 2Tm 4", TEAL)

    q.no("paulo", "Paulo", "destaque", 140, 75, "Saulo de Tarso",
         "Judeu de nascimento, cidadão romano, fariseu formado em Jerusalém e perseguidor da igreja. Alcançado por "
         "Cristo, tornou-se o maior missionário do primeiro século: percorreu milhares de quilômetros, plantou "
         "igrejas da Síria até a Grécia e escreveu treze cartas do Novo Testamento. Dizia de si mesmo: pela graça de "
         "Deus sou o que sou.",
         ["At 21:39", "Fp 3:5-8", "1Co 15:10", "2Co 11:23-28"], "paulo-escrevendo", "Paulo", MARINHO, link="mapas")

    # ---------------- Origem e conversão ----------------
    origem = [
        ("tarso", "Nasce em Tarso", "c. 5 d.C.", "corinto-tendas", None,
         "Tarso, na Cilícia, sul da atual Turquia, era cidade grande e culta. Saulo nasceu ali, numa família judaica "
         "da tribo de Benjamim, e recebeu o nome do primeiro rei de Israel. Tinha cidadania romana de nascimento e "
         "aprendeu o ofício de fazer tendas, com o qual mais tarde se sustentou.",
         ["At 21:39", "At 22:27-28", "Fp 3:5", "At 18:3"], [("Nomes", "Saulo, em hebraico; Paulo, em latim (At 13:9)")]),
        ("gamaliel", "Aos pés de Gamaliel", "juventude", "saulo-gamaliel", None,
         "Ainda jovem foi para Jerusalém estudar com Gamaliel, o mestre mais respeitado dos fariseus. Aprendeu a lei "
         "com todo o rigor e avançava no judaísmo mais do que os da sua idade. Todo esse preparo Deus usaria depois "
         "para explicar o evangelho a partir das Escrituras.",
         ["At 22:3", "At 5:34", "Gl 1:14", "Fp 3:5-6"], []),
        ("perseguidor", "Perseguidor da igreja", "c. 33–34 d.C.", "estevao-martir", None,
         "Guardou as capas dos que apedrejaram Estêvão e aprovou a sua morte. Depois entrou pelas casas, arrastando "
         "homens e mulheres para a prisão, e pediu cartas para prender os discípulos em Damasco. Nunca se esqueceu "
         "disso: não sou digno de ser chamado apóstolo, pois persegui a igreja de Deus.",
         ["At 7:58", "At 8:1-3", "At 9:1-2", "1Co 15:9", "1Tm 1:13"], []),
        ("damasco", "A conversão", "c. 34 d.C.", "damasco-luz", "historias",
         "Perto de Damasco, uma luz do céu o derrubou, e ele ouviu: Saulo, Saulo, por que me persegues? Eu sou "
         "Jesus. Ficou três dias cego, até que Ananias orou por ele. Foi batizado, cheio do Espírito Santo, e logo "
         "começou a pregar que Jesus é o Filho de Deus.",
         ["At 9:3-6", "At 9:17-20", "At 26:16-18", "Gl 1:15-16"], []),
        ("preparo", "Anos de preparo", "c. 34–43 d.C.", "paulo-cesto", None,
         "Foi à Arábia e voltou a Damasco, de onde fugiu num cesto pela muralha. Três anos depois subiu a Jerusalém; "
         "os discípulos tinham medo dele, e Barnabé o apresentou aos apóstolos. Ameaçado de morte, foi enviado a "
         "Tarso, onde passou vários anos de que quase nada sabemos.",
         ["Gl 1:17-18", "At 9:23-27", "At 9:30", "2Co 11:32-33"], []),
        ("antioquia", "Antioquia", "c. 43–47 d.C.", "antioquia-igreja", None,
         "Barnabé foi buscá-lo em Tarso e o levou para Antioquia da Síria, a primeira grande igreja de gentios. "
         "Ensinaram ali um ano inteiro, e foi em Antioquia que os discípulos foram chamados cristãos pela primeira "
         "vez. Dessa igreja saíram as viagens missionárias.",
         ["At 11:25-26", "At 11:29-30", "At 13:1-3"], []),
    ]
    for x, (id, nome, sub, arte, link, texto, refs, fatos) in zip(COLS, origem):
        q.no(id, nome, "marco", x, YM, sub, texto, refs, arte, None, MARINHO, fatos=fatos, link=link, w=206)
    q.liga("paulo", "tarso")
    q.cadeia([o[0] for o in origem], h=True)

    # ---------------- Viagens e prisões ----------------
    periodos = [
        ("v1", "1ª viagem", "c. 46–48 d.C.", "antioquia-envio", "mapas",
         "O Espírito Santo disse: separai-me Barnabé e Saulo. Passaram por Chipre e subiram à Galácia, no interior "
         "da atual Turquia: Antioquia da Pisídia, Icônio, Listra e Derbe. Em Listra Paulo foi apedrejado e dado "
         "por morto. Na volta, constituíram presbíteros em cada igreja.",
         ["At 13:2-4", "At 14:19-23", "At 14:26-27"]),
        ("concilio", "Concílio de Jerusalém", "c. 49 d.C.", "concilio-jerusalem", None,
         "Alguns diziam que os gentios precisavam se circuncidar e guardar a lei de Moisés para serem salvos. Paulo "
         "e Barnabé subiram a Jerusalém, e os apóstolos e presbíteros examinaram a questão. Pedro declarou: cremos "
         "que somos salvos pela graça do Senhor Jesus, do mesmo modo que eles.",
         ["At 15:1-2", "At 15:6-11", "At 15:19-20", "Gl 2:9"]),
        ("v2", "2ª viagem", "c. 49–52 d.C.", "troade-visao", "mapas",
         "Com Silas, e depois com Timóteo e Lucas, Paulo revisitou a Galácia. Impedido pelo Espírito de seguir para "
         "a Ásia, teve em Trôade a visão do homem macedônio: passa e ajuda-nos. O evangelho entrou na Europa por "
         "Filipos, Tessalônica, Bereia, Atenas e Corinto, onde ele ficou um ano e meio.",
         ["At 15:40-41", "At 16:9-10", "At 17:22-23", "At 18:9-11"]),
        ("v3", "3ª viagem", "c. 53–57 d.C.", "efeso-escola", "mapas",
         "Paulo passou cerca de três anos em Éfeso, ensinando todos os dias na escola de Tirano, e toda a província "
         "da Ásia ouviu a palavra. Depois do tumulto dos ourives, percorreu a Macedônia e a Grécia, recolheu a "
         "oferta para os pobres de Jerusalém e se despediu dos presbíteros em Mileto.",
         ["At 19:8-10", "At 19:20", "At 20:17-21", "At 20:31"]),
        ("preso", "Preso, até Roma", "c. 57–62 d.C.", "naufragio", "historias",
         "Em Jerusalém foi agarrado no templo por uma multidão e salvo pelos soldados romanos. Ficou dois anos preso "
         "em Cesareia, diante de Félix, Festo e Agripa, e apelou para César. A viagem terminou em naufrágio na ilha "
         "de Malta. Em Roma passou dois anos em prisão domiciliar, pregando o reino de Deus sem impedimento.",
         ["At 21:30-33", "At 23:11", "At 25:11", "At 27:41-44", "At 28:30-31"]),
        ("final", "Últimos anos", "c. 62–67 d.C.", "paulo-carcere", None,
         "O livro de Atos termina com Paulo preso em Roma. Pelas cartas a Timóteo e a Tito, entende-se que ele foi "
         "solto, voltou a viajar e depois foi preso de novo. Na última carta escreve: combati o bom combate, acabei "
         "a carreira, guardei a fé. Segundo a tradição, foi decapitado em Roma no tempo de Nero.",
         ["1Tm 1:3", "Tt 1:5", "2Tm 4:6-8", "2Tm 4:16-17"]),
    ]
    for x, (id, nome, sub, arte, link, texto, refs) in zip(COLS, periodos):
        q.no(id, nome, "marco", x, YP, sub, texto, refs, arte, None, CIANO, link=link, w=206)
    q.liga("antioquia", "v1", meio=310)
    q.cadeia([p[0] for p in periodos], h=True)

    grupos = [
        ("v1", "ig1", "Igrejas da Galácia", "Antioquia, Icônio, Listra, Derbe",
         "As primeiras igrejas plantadas por Paulo, em cidades da província romana da Galácia. Nasceram em meio a "
         "perseguição, e a elas ele voltou nas viagens seguintes. De Listra saiu Timóteo.",
         ["At 13:48-49", "At 14:21-23", "At 16:1-2"]),
        ("concilio", "decisao", "A carta aos gentios", "At 15:23-29",
         "A decisão foi enviada por escrito às igrejas: não impor aos gentios o peso da lei, apenas pedir que se "
         "afastassem da idolatria, da imoralidade e de práticas que impediam a convivência com os irmãos judeus. As "
         "igrejas se alegraram com a consolação.",
         ["At 15:23-29", "At 15:30-31"]),
        ("v2", "ig2", "Macedônia e Acaia", "Filipos, Tessalônica, Bereia, Corinto",
         "As primeiras igrejas da Europa. Em Filipos, a casa de Lídia e a do carcereiro; em Tessalônica, uma igreja "
         "que virou exemplo em meio à tribulação; em Bereia, gente que examinava as Escrituras todos os dias; em "
         "Corinto, um povo numeroso numa cidade corrompida.",
         ["At 16:14-15", "At 17:4", "At 17:11", "At 18:8", "1Ts 1:6-8"]),
        ("v3", "ig3", "Éfeso e a Ásia", "Éfeso, Colossos, Laodiceia",
         "Éfeso se tornou o centro da missão na Ásia. Dali, cooperadores como Epafras levaram o evangelho a Colossos, "
         "Laodiceia e Hierápolis, cidades que Paulo talvez nunca tenha visitado. As sete igrejas do Apocalipse ficam "
         "nessa região.",
         ["At 19:10", "Cl 1:7", "Cl 2:1", "Cl 4:13"]),
        ("preso", "ig5", "Cartas da prisão", "escritas em cadeias",
         "Efésios, Filipenses, Colossenses e Filemom falam das cadeias de Paulo. A maioria dos estudiosos as situa "
         "na prisão em Roma, entre 60 e 62 d.C.; alguns propõem Cesareia ou Éfeso. Tíquico e Onésimo levaram três "
         "delas juntos para a Ásia.",
         ["Ef 3:1", "Fp 1:12-14", "Cl 4:7-9", "Fm 1:9-10"]),
        ("final", "ig6", "Cartas pastorais", "a Timóteo e a Tito",
         "Três cartas a dois filhos na fé que cuidavam de igrejas: Timóteo em Éfeso e Tito em Creta. Tratam de "
         "doutrina sã, de quem pode liderar e de como a igreja deve se conduzir. São o testamento de um pastor para "
         "a geração seguinte.",
         ["1Tm 3:14-15", "2Tm 2:1-2", "Tt 2:1"]),
    ]
    xof = {p[0]: x for x, p in zip(COLS, periodos)}
    for pai, id, nome, sub, texto, refs in grupos:
        q.no(id, nome, "grupo", xof[pai], YG, sub, texto, refs, None, None, CIANO, w=206)
        q.liga(pai, id)

    cartas = {
        "ig1": [("gl", "Gálatas", LARANJA, "c. 48–49 d.C.", "provavelmente de Antioquia da Síria",
                 "Escrita às igrejas da Galácia, provavelmente logo depois da primeira viagem; há quem a date alguns "
                 "anos mais tarde. Falsos mestres exigiam a circuncisão dos gentios. Paulo responde com vigor: o "
                 "homem é justificado pela fé em Cristo, e não por obras da lei. Para a liberdade Cristo nos "
                 "libertou.",
                 ["Gl 1:6-7", "Gl 2:16", "Gl 5:1", "Gl 5:22-23"])],
        "ig2": [("ts1", "1 Tessalonicenses", LARANJA, "c. 50–51 d.C.", "de Corinto",
                 "Uma das primeiras cartas de Paulo, escrita poucos meses depois de fundar a igreja. Anima os novos "
                 "convertidos perseguidos e ensina sobre a volta de Cristo: os mortos em Cristo ressuscitarão "
                 "primeiro, e estaremos para sempre com o Senhor.",
                 ["1Ts 1:9-10", "1Ts 4:16-17", "1Ts 5:16-18"]),
                ("ts2", "2 Tessalonicenses", LARANJA, "c. 51 d.C.", "de Corinto",
                 "Escrita pouco depois da primeira. Alguns pensavam que o dia do Senhor já tinha chegado e largaram "
                 "o trabalho. Paulo corrige: antes virá a apostasia e será revelado o homem do pecado. Enquanto "
                 "isso, firmeza e trabalho.",
                 ["2Ts 2:1-3", "2Ts 2:15", "2Ts 3:10-13"])],
        "ig3": [("co1", "1 Coríntios", VERMELHO, "c. 55 d.C.", "de Éfeso (1Co 16:8)",
                 "A igreja de Corinto estava dividida em partidos e tolerava pecados graves. Paulo trata de "
                 "casamento, ceia, dons espirituais e ressurreição, e põe no centro o caminho mais excelente: o "
                 "amor.",
                 ["1Co 1:10", "1Co 12:4-7", "1Co 13:13", "1Co 15:3-4"]),
                ("co2", "2 Coríntios", VERMELHO, "c. 56 d.C.", "da Macedônia",
                 "Escrita depois de uma visita dolorosa e de uma carta severa. É a carta mais pessoal de Paulo: "
                 "defende o seu ministério, fala de consolo no sofrimento e do tesouro em vasos de barro. A minha "
                 "graça te basta, porque o poder se aperfeiçoa na fraqueza.",
                 ["2Co 1:3-4", "2Co 4:7", "2Co 5:17", "2Co 12:9"]),
                ("rm", "Romanos", VERMELHO, "c. 57 d.C.", "de Corinto",
                 "Escrita a uma igreja que Paulo ainda não conhecia. É a exposição mais completa do evangelho: todos "
                 "pecaram, e a justiça de Deus se recebe pela fé em Cristo. Trata também de Israel e da vida nova "
                 "no Espírito. Foi levada, ao que parece, por Febe.",
                 ["Rm 1:16-17", "Rm 3:23-24", "Rm 8:1", "Rm 12:1-2", "Rm 16:1-2"])],
        "ig5": [("ef", "Efésios", VIOLETA, "c. 60–62 d.C.", "da prisão, provavelmente em Roma",
                 "A carta mais ampla: o plano eterno de Deus de reunir todas as coisas em Cristo. Judeus e gentios "
                 "formam um só corpo, a igreja. Pela graça sois salvos, mediante a fé. A segunda metade ensina a "
                 "andar de modo digno, em casa, no trabalho e na luta espiritual.",
                 ["Ef 1:9-10", "Ef 2:8-10", "Ef 4:1-6", "Ef 6:10-11"]),
                ("fp", "Filipenses", VIOLETA, "c. 61–62 d.C.", "da prisão, provavelmente em Roma",
                 "Carta de gratidão à igreja de Filipos, que lhe mandou uma oferta por Epafrodito. Mesmo preso, Paulo "
                 "fala de alegria do começo ao fim. Para mim o viver é Cristo, e o morrer é lucro. No centro, o hino "
                 "de Cristo, que se esvaziou e foi exaltado.",
                 ["Fp 1:21", "Fp 2:5-11", "Fp 4:4-7", "Fp 4:13"]),
                ("cl", "Colossenses", VIOLETA, "c. 60–62 d.C.", "da prisão, provavelmente em Roma",
                 "Falsos mestres misturavam o evangelho com filosofias, regras e culto a anjos. Paulo responde "
                 "mostrando a supremacia de Cristo: ele é a imagem do Deus invisível, nele habita toda a plenitude, "
                 "e nele estamos completos.",
                 ["Cl 1:15-18", "Cl 2:9-10", "Cl 3:1-2"]),
                ("fm", "Filemom", VIOLETA, "c. 60–62 d.C.", "da prisão, com a carta aos colossenses",
                 "Bilhete pessoal a um irmão de Colossos. Onésimo, escravo dele, tinha fugido, encontrou Paulo e se "
                 "converteu. Paulo o manda de volta e pede: recebe-o não mais como escravo, mas como irmão amado. O "
                 "evangelho muda as relações por dentro.",
                 ["Fm 1:10-12", "Fm 1:15-16", "Fm 1:18"])],
        "ig6": [("tm1", "1 Timóteo", TEAL, "c. 63–65 d.C.", "provavelmente da Macedônia",
                 "Timóteo ficou em Éfeso para corrigir falsos ensinos. Paulo orienta sobre oração, liderança e "
                 "cuidado com viúvas e anciãos, e resume o evangelho: há um só Deus e um só Mediador entre Deus e os "
                 "homens, Cristo Jesus.",
                 ["1Tm 1:15", "1Tm 2:5", "1Tm 3:15", "1Tm 4:12"]),
                ("tt", "Tito", TEAL, "c. 63–65 d.C.", "lugar incerto",
                 "Tito ficou em Creta para pôr em ordem o que faltava e constituir presbíteros em cada cidade. A "
                 "carta liga a doutrina à vida: a graça de Deus se manifestou trazendo salvação e nos ensina a viver "
                 "de modo sensato, justo e piedoso.",
                 ["Tt 1:5", "Tt 2:11-14", "Tt 3:4-7"]),
                ("tm2", "2 Timóteo", TEAL, "c. 66–67 d.C.", "da última prisão, em Roma",
                 "A última carta, escrita à espera da execução. Paulo pede que Timóteo venha depressa e traga a capa "
                 "e os pergaminhos. Passa o bastão: prega a palavra. Toda a Escritura é inspirada por Deus.",
                 ["2Tm 1:6-8", "2Tm 3:16-17", "2Tm 4:2", "2Tm 4:7-8"])],
    }
    xg = {g[1]: xof[g[0]] for g in grupos}
    for gid, lista in cartas.items():
        prev = gid
        for k, (id, nome, cor, quando, onde, texto, refs) in enumerate(lista):
            q.no(id, nome, "mini", xg[gid], YC + 38 * k, "", texto, refs, "paulo-escrevendo", None, cor,
                 fatos=[("Quando", quando), ("De onde", onde)], w=190)
            q.liga(prev, id)
            prev = id

    # ---------------- Companheiros ----------------
    comp = [
        ("barnabe", "Barnabé", "filho da consolação", "Barnabé", "barnabe-paulo", None,
         "Levita de Chipre, generoso e conciliador. Foi quem acreditou em Saulo quando todos tinham medo dele, quem "
         "o buscou em Tarso e quem partiu com ele na primeira viagem. Separaram-se por causa de Marcos; mais tarde "
         "Paulo fala dele com respeito.",
         ["At 4:36-37", "At 9:27", "At 11:25-26", "At 15:36-39", "1Co 9:6"]),
        ("marcos", "Marcos", "João Marcos", "Marcos", "lin-marcos-barnabe", None,
         "Primo de Barnabé, de uma família de Jerusalém em cuja casa a igreja orava. Abandonou a primeira viagem no "
         "meio, e Paulo não quis levá-lo na segunda. Anos depois estava de novo ao lado do apóstolo, que escreveu: "
         "ele me é útil para o ministério. A tradição o liga a Pedro e ao segundo Evangelho.",
         ["At 12:12", "At 13:13", "Cl 4:10", "2Tm 4:11", "1Pe 5:13"]),
        ("silas", "Silas", "Silvano", "Silas", "filipos-prisao", None,
         "Profeta e líder da igreja de Jerusalém, levou a carta do concílio a Antioquia. Foi o companheiro de Paulo "
         "na segunda viagem: açoitados e presos em Filipos, cantaram hinos à meia-noite. Aparece no cabeçalho das "
         "cartas aos tessalonicenses e, depois, ao lado de Pedro.",
         ["At 15:22", "At 15:40", "At 16:25", "1Ts 1:1", "1Pe 5:12"]),
        ("timoteo", "Timóteo", "filho na fé", "Timóteo", "timoteo", None,
         "De Listra, filho de mãe judia e pai grego, criado nas Escrituras pela mãe, Eunice, e pela avó, Loide. "
         "Juntou-se a Paulo na segunda viagem e nunca mais o deixou. Foi enviado em missões difíceis e cuidou da "
         "igreja de Éfeso. Paulo dizia: não tenho ninguém de igual sentimento.",
         ["At 16:1-3", "2Tm 1:5", "Fp 2:19-22", "1Tm 1:2"]),
        ("lucas", "Lucas", "o médico amado", "Lucas", "lin-lucas-medico", None,
         "Médico, provavelmente gentio, autor do Evangelho de Lucas e de Atos. Entra na história em Trôade: a partir "
         "dali o relato de Atos passa a dizer nós. Acompanhou Paulo até Roma e ficou com ele até o fim: só Lucas "
         "está comigo.",
         ["Cl 4:14", "At 16:10", "At 27:1", "2Tm 4:11", "Fm 1:24"]),
        ("priscila", "Priscila e Áquila", "fazedores de tendas", "Priscila e Áquila", "corinto-tendas", None,
         "Casal judeu expulso de Roma pelo imperador Cláudio. Em Corinto deram a Paulo trabalho e teto. Foram com "
         "ele para Éfeso, onde ensinaram Apolo com mais exatidão, e abriram a casa para a igreja. Paulo diz que "
         "arriscaram a própria vida por ele.",
         ["At 18:1-3", "At 18:26", "Rm 16:3-5", "1Co 16:19"]),
        ("apolo", "Apolo", "de Alexandria", "Apolo", "lin-apolo-efeso", None,
         "Judeu de Alexandria, eloquente e poderoso nas Escrituras. Conhecia só o batismo de João, até ser instruído "
         "por Priscila e Áquila. Em Corinto ajudou muito os que creram. Alguns quiseram fazer dele um partido; Paulo "
         "respondeu: eu plantei, Apolo regou, mas Deus deu o crescimento.",
         ["At 18:24-28", "1Co 1:12", "1Co 3:5-6", "Tt 3:13"]),
        ("tito", "Tito", "grego, filho na fé", "Tito", "lin-tito-creta", None,
         "Grego convertido, que Paulo levou a Jerusalém sem que fosse obrigado a se circuncidar: prova viva do "
         "evangelho da graça. Resolveu a crise de Corinto e organizou a coleta para os pobres. Mais tarde ficou em "
         "Creta, para constituir presbíteros.",
         ["Gl 2:1-3", "2Co 7:6-7", "2Co 8:23", "Tt 1:4-5"]),
        ("epafrodito", "Epafrodito", "enviado de Filipos", None, "roma-casa", None,
         "Levou a Paulo, preso, a oferta da igreja de Filipos e ficou para servi-lo. Adoeceu e quase morreu. Paulo o "
         "chama de irmão, cooperador e companheiro de lutas, e o manda de volta com a carta aos filipenses.",
         ["Fp 2:25-30", "Fp 4:18"]),
        ("onesimo", "Onésimo", "de escravo a irmão", "Onésimo", "lin-onesimo-filemom", None,
         "Escravo de Filemom, em Colossos. Fugiu, encontrou Paulo na prisão e se converteu. O nome quer dizer útil, "
         "e Paulo brinca com isso: antes te foi inútil, agora é útil a ti e a mim. Voltou para casa com Tíquico, "
         "levando a carta.",
         ["Fm 1:10-16", "Cl 4:9"]),
        ("febe", "Febe", "serva da igreja", None, "navio-partida", ROSA,
         "Servia à igreja de Cencreia, o porto de Corinto, e tinha ajudado muita gente, inclusive Paulo. É a "
         "primeira pessoa recomendada em Romanos 16, e por isso se entende que foi ela quem levou a carta a Roma.",
         ["Rm 16:1-2"]),
        ("lidia", "Lídia", "vendedora de púrpura", "Lídia", "lidia-rio", ROSA,
         "Comerciante de Tiatira que morava em Filipos e adorava a Deus. À beira do rio, o Senhor lhe abriu o "
         "coração para ouvir Paulo. Foi batizada com a sua casa, a primeira convertida conhecida na Europa, e "
         "insistiu em hospedar os missionários. Ali nasceu a igreja de Filipos.",
         ["At 16:13-15", "At 16:40"]),
        ("aristarco", "Aristarco", "de Tessalônica", None, "efeso-tumulto", None,
         "Macedônio de Tessalônica. Foi arrastado pela multidão no tumulto de Éfeso, acompanhou Paulo na ida a "
         "Jerusalém e embarcou com ele para Roma. Paulo o chama de companheiro de prisão.",
         ["At 19:29", "At 20:4", "At 27:2", "Cl 4:10"]),
        ("tiquico", "Tíquico", "o mensageiro fiel", None, "mileto-adeus", None,
         "Da província da Ásia. Era o portador de confiança de Paulo: levou as cartas aos efésios e aos colossenses "
         "e contou pessoalmente como o apóstolo estava. Irmão amado e fiel ministro no Senhor.",
         ["At 20:4", "Ef 6:21-22", "Cl 4:7-8", "2Tm 4:12"]),
    ]
    for k, (id, nome, sub, retrato, arte, cor, texto, refs) in enumerate(comp):
        q.no(id, nome, "pessoa", 135 + 190 * (k % 7), 822 + 64 * (k // 7), sub, texto, refs, arte, retrato, cor or TEAL,
             w=176, h=50)

    # ---------------- Apresentação ----------------
    q.passo(["paulo", "tarso", "gamaliel"], "Saulo de Tarso",
            "Ele nasce em Tarso, cidade de cultura grega na Cilícia, numa família judaica da tribo de Benjamim. É cidadão "
            "romano e aprende a fazer tendas. Jovem, vai para Jerusalém e estuda com Gamaliel. Hebreu de hebreus, "
            "fariseu, irrepreensível quanto à lei: tudo o que um judeu podia querer ser.",
            "Fp 3:5", "saulo-gamaliel")
    q.passo(["perseguidor"], "O perseguidor",
            "Para Saulo, um Messias crucificado era blasfêmia. Ele guarda as capas dos que apedrejam Estêvão e "
            "aprova a morte. Depois assola a igreja: entra nas casas, arrasta homens e mulheres e os entrega à "
            "prisão. Com cartas do sumo sacerdote, parte para Damasco, respirando ameaças.",
            "At 8:3", "saulo-perseguidor")
    q.passo(["damasco"], "O caminho de Damasco",
            "Perto da cidade, uma luz mais forte que o sol o derruba. Saulo, Saulo, por que me persegues? Quem és "
            "tu, Senhor? Eu sou Jesus, a quem tu persegues. Cego por três dias, é visitado por Ananias, recupera a "
            "vista, é batizado e cheio do Espírito. O perseguidor vira pregador.",
            "At 9:3-6", "damasco-luz")
    q.passo(["preparo", "antioquia"], "Anos escondidos",
            "Deus não tem pressa. Saulo passa pela Arábia, foge de Damasco num cesto e, em Jerusalém, só é aceito "
            "porque Barnabé o apresenta. Depois some por anos em Tarso. É Barnabé de novo quem o busca e o leva a "
            "Antioquia, onde os discípulos são chamados cristãos pela primeira vez.",
            "Gl 1:17-18", "antioquia-igreja")
    q.passo(["v1", "ig1", "gl"], "A primeira viagem e Gálatas",
            "A igreja de Antioquia ora, jejua e envia Barnabé e Saulo. Eles atravessam Chipre e plantam igrejas na "
            "Galácia, entre pedradas e milagres. Pouco depois, mestres dizem a esses convertidos que precisam da "
            "lei para se salvar. Paulo escreve Gálatas: a justificação é pela fé em Cristo.",
            "At 13:2-3", "listra-sacrificio")
    q.passo(["concilio", "decisao"], "Salvos pela graça",
            "A questão vai a Jerusalém. Apóstolos e presbíteros ouvem Pedro, Barnabé, Paulo e Tiago e concluem que "
            "não se deve pôr sobre os gentios o jugo da lei. Judeus e gentios são salvos do mesmo modo: pela graça "
            "do Senhor Jesus. A decisão segue por carta e alegra as igrejas.",
            "At 15:11", "concilio-jerusalem")
    q.passo(["v2", "ig2", "ts1", "ts2"], "A Europa",
            "Na segunda viagem, com Silas, Timóteo e Lucas, Paulo tem em Trôade a visão do homem macedônio. O "
            "evangelho entra na Europa: Filipos, Tessalônica, Bereia, Atenas e Corinto. De Corinto ele escreve as "
            "duas cartas aos tessalonicenses, para consolar uma igreja jovem e ensinar sobre a volta de Cristo.",
            "At 16:9-10", "troade-visao")
    q.passo(["v3", "ig3", "co1", "co2", "rm"], "Éfeso e as grandes cartas",
            "Na terceira viagem Paulo fica cerca de três anos em Éfeso, e toda a Ásia ouve a palavra. Dali escreve "
            "aos coríntios, para corrigir uma igreja dividida. Da Macedônia manda a segunda carta. De Corinto, antes "
            "de subir a Jerusalém, escreve Romanos, a exposição mais completa do evangelho.",
            "At 19:10", "efeso-escola")
    q.passo(["preso", "ig5", "ef", "fp", "cl", "fm"], "Embaixador em cadeias",
            "Preso em Jerusalém, Paulo ouve do Senhor: importa que dês testemunho também em Roma. Passa por "
            "tribunais, dois anos em Cesareia e um naufrágio. Em Roma, vigiado por um soldado, escreve Efésios, "
            "Filipenses, Colossenses e Filemom. As cadeias serviram para o progresso do evangelho.",
            "At 23:11", "roma-casa")
    q.passo(["final", "ig6", "tm1", "tt", "tm2"], "Combati o bom combate",
            "Solto, ao que tudo indica, Paulo ainda viaja e deixa Timóteo em Éfeso e Tito em Creta, com cartas de "
            "orientação. Preso outra vez, no tempo de Nero, escreve a segunda carta a Timóteo: combati o bom "
            "combate, acabei a carreira, guardei a fé. Segundo a tradição, foi decapitado em Roma.",
            "2Tm 4:7-8", "paulo-carcere")
    q.passo(["barnabe", "silas", "timoteo", "lucas", "priscila", "tito"], "Nunca sozinho",
            "Paulo quase nunca aparece sozinho. Barnabé abre as portas, Silas canta com ele na prisão, Timóteo e "
            "Tito são filhos na fé, Lucas fica até o fim, Priscila e Áquila arriscam a vida. Romanos 16 saúda mais "
            "de vinte e cinco pessoas pelo nome. A missão é trabalho de equipe.",
            "Rm 16:3-4", "corinto-tendas")
    q.passo(["paulo", "gl", "rm", "tm2"], "O que ele deixou",
            "Em cerca de trinta anos de ministério, Paulo plantou igrejas em quatro províncias romanas e escreveu "
            "treze cartas, quase metade dos livros do Novo Testamento. Nunca se gloriou disso: pela graça de Deus "
            "sou o que sou; trabalhei mais do que todos, não eu, mas a graça de Deus comigo.",
            "1Co 15:10", "paulo-escrevendo")
    return q
