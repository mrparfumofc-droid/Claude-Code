"""Quadro 2: de Adão a Abraão (Gênesis 4, 5, 10 e 11)."""
from build_linhagens import Quadro, VERDE, MARINHO, CINZA, TEAL, ROSA, MARROM, VERMELHO, LARANJA

STEP = 54


def build():
    q = Quadro(
        "adao", "De Adão a Abraão",
        "As primeiras gerações, o dilúvio, os povos e a linha de Sem", VERDE, "noe-arcoiris",
        "Gênesis liga a criação a Abraão por duas listas de nomes: dez gerações de Adão a Noé e dez de Sem a Abrão. "
        "Entre elas ficam o dilúvio, os três filhos de Noé e a origem dos povos. Este quadro mostra quem gerou quem, "
        "as idades que a Bíblia registra e como a promessa foi passando de mão em mão.")

    q.faixa(30, 30, 460, 585, "De Adão a Noé", "Gn 4–5 · antes do dilúvio", VERDE)
    q.faixa(516, 30, 500, 420, "Noé e os povos", "Gn 6–11 · os três filhos e Babel", TEAL)
    q.faixa(1042, 30, 460, 630, "De Sem a Abrão", "Gn 11:10-32 · a linha da promessa", MARINHO)

    # ---------------- De Adão a Noé ----------------
    q.no("adao", "Adão", "destaque", 200, 112, "viveu 930 anos",
         "O primeiro homem, formado do pó da terra à imagem de Deus. Desobedeceu, e por ele o pecado e a morte "
         "entraram no mundo. No mesmo dia Deus prometeu um descendente da mulher que esmagaria a cabeça da serpente: "
         "é o primeiro anúncio do evangelho.",
         ["Gn 1:27", "Gn 2:7", "Gn 3:15", "Gn 5:5", "Rm 5:12"], "eden-casal", "Adão", VERDE,
         fatos=[("Idade", "930 anos (Gn 5:5)")])
    q.no("eva", "Eva", "pessoa", 375, 112, "mãe dos viventes",
         "Formada por Deus do lado de Adão. Enganada pela serpente, comeu do fruto e deu ao marido. Recebeu o nome de "
         "Eva porque seria mãe de todos os viventes, e a promessa do Salvador foi feita à sua descendência.",
         ["Gn 2:21-23", "Gn 3:20", "Gn 4:1", "Gn 4:25"], "eden-serpente", "Adão e Eva", ROSA)
    q.casal("adao", "eva")
    q.no("caim", "Caim", "mini", 108, 196, "",
         "O primeiro filho. Lavrador, ofereceu a Deus do fruto da terra, mas sem fé. Com inveja, matou o irmão Abel. "
         "Tornou-se errante, e mesmo assim Deus pôs nele um sinal para que ninguém o matasse.",
         ["Gn 4:1-8", "Gn 4:15", "1Jo 3:12"], "eden-expulsao", None, CINZA)
    q.no("abel", "Abel", "mini", 250, 196, "",
         "Pastor de ovelhas. Ofereceu das primícias do rebanho, e Deus se agradou dele e da sua oferta. Foi morto "
         "pelo irmão: o primeiro mártir. Pela fé, mesmo depois de morto, ainda fala.",
         ["Gn 4:4", "Hb 11:4", "Mt 23:35"], None, None, CINZA)
    q.no("sete", "Sete", "pessoa", 400, 196, "viveu 912 anos",
         "Nasceu depois da morte de Abel. Eva disse: Deus me deu outro descendente em lugar de Abel. É por Sete que a "
         "linha da promessa continua, até Noé e, muito depois, até Cristo.",
         ["Gn 4:25", "Gn 5:3", "Gn 5:8", "Lc 3:38"], None, None, VERDE, fatos=[("Idade", "912 anos (Gn 5:8)")])
    for filho in ("caim", "abel", "sete"):
        q.liga(["adao", "eva"], filho, meio=152)

    q.no("c-enoque", "Enoque (de Caim)", "mini", 108, 250, "",
         "Filho de Caim. O pai construiu uma cidade e lhe deu o nome do filho. Não é o Enoque que andou com Deus: "
         "aquele é da linha de Sete.",
         ["Gn 4:17"], None, None, CINZA)
    q.no("c-lameque", "Lameque (de Caim)", "mini", 108, 304, "",
         "Quinta geração depois de Caim. Foi o primeiro a tomar duas esposas e se gabou de matar um homem por uma "
         "ferida. A linha de Caim cresce em técnica e em violência.",
         ["Gn 4:19", "Gn 4:23-24"], None, None, CINZA, w=140)
    q.no("c-filhos", "Jabal, Jubal e Tubalcaim", "grupo", 124, 364, "",
         "Filhos de Lameque, da linha de Caim. Jabal foi pai dos que moram em tendas e criam gado; Jubal, dos que "
         "tocam harpa e flauta; Tubalcaim trabalhava o cobre e o ferro. As artes e os ofícios nascem cedo na "
         "história humana.",
         ["Gn 4:20-22"], None, None, CINZA, w=176, h=40)
    q.liga("caim", "c-enoque")
    q.liga("c-enoque", "c-lameque", tracejada=True)
    q.liga("c-lameque", "c-filhos")

    linha = [
        ("enos", "Enos", 905, "Gn 5:11", None,
         "Filho de Sete. O nome lembra a fraqueza do homem. Nos seus dias se começou a invocar o nome do Senhor: "
         "nasce o culto público a Deus.",
         ["Gn 4:26", "Gn 5:6", "Gn 5:11"]),
        ("caina", "Cainã", 910, "Gn 5:14", None,
         "Filho de Enos. A Bíblia guarda dele o nome, a idade e a frase que se repete em toda a lista: e morreu. É o "
         "salário do pecado, geração após geração.",
         ["Gn 5:9", "Gn 5:14"]),
        ("maalalel", "Maalalel", 895, "Gn 5:17", None,
         "Filho de Cainã. O nome quer dizer louvor de Deus. Mais um elo que recebeu a promessa dos pais e a entregou "
         "aos filhos.",
         ["Gn 5:12", "Gn 5:17"]),
        ("jarede", "Jarede", 962, "Gn 5:20", None,
         "Pai de Enoque. Viveu 962 anos, a segunda vida mais longa da lista.",
         ["Gn 5:15", "Gn 5:20"]),
        ("enoque", "Enoque", 365, "Gn 5:23", "lin-enoque",
         "O sétimo depois de Adão. Andou com Deus e não passou pela morte: Deus o tomou para si. Hebreus diz que, "
         "antes de ser levado, teve o testemunho de ter agradado a Deus. Judas cita uma profecia dele sobre a vinda "
         "do Senhor.",
         ["Gn 5:21-24", "Hb 11:5", "Jd 1:14-15"]),
        ("matusalem", "Matusalém", 969, "Gn 5:27", None,
         "O homem que mais viveu na Bíblia. Pelas idades de Gênesis 5, morreu no ano do dilúvio: a paciência de Deus "
         "esperou uma vida inteira.",
         ["Gn 5:25-27", "1Pe 3:20"]),
        ("lameque", "Lameque", 777, "Gn 5:31", None,
         "Pai de Noé. Ao dar o nome ao filho, profetizou: este nos consolará dos nossos trabalhos, por causa da "
         "terra que o Senhor amaldiçoou. Não confundir com o Lameque da linha de Caim.",
         ["Gn 5:28-31"]),
    ]
    prev = "sete"
    for k, (id, nome, idade, ref, arte, texto, refs) in enumerate(linha):
        q.no(id, nome, "pessoa", 400, 196 + STEP * (k + 1), f"viveu {idade} anos", texto, refs, arte,
             "Enoque" if id == "enoque" else None, VERDE, fatos=[("Idade", f"{idade} anos ({ref})")])
        q.liga(prev, id)
        prev = id

    # ---------------- Noé e os povos ----------------
    q.no("noe", "Noé", "destaque", 766, 112, "viveu 950 anos",
         "Achou graça aos olhos do Senhor num mundo cheio de violência. Homem justo, andava com Deus. Construiu a "
         "arca, e nela se salvaram oito pessoas. Depois do dilúvio Deus fez aliança com ele e deu o arco-íris por "
         "sinal.",
         ["Gn 6:8-9", "Gn 7:6", "Gn 9:12-13", "Gn 9:29", "Hb 11:7"], "noe-arcoiris", "Noé", TEAL,
         fatos=[("Idade", "950 anos (Gn 9:29); tinha 600 quando veio o dilúvio (Gn 7:6)")])
    q.liga("lameque", "noe", h=True, meio=503)
    tres = [
        ("jafe", "Jafé", 600, "povos-jafe", "Povos de Jafé", "norte e ilhas do mar", "Jafé",
         "Noé orou: alargue Deus a Jafé, e habite ele nas tendas de Sem. Os seus descendentes se espalharam para o "
         "norte e para o oeste.",
         ["Gn 9:27", "Gn 10:2"],
         "Gômer, Magogue, Madai (os medos), Javã (os gregos), Tubal, Meseque e Tiras. Deles vieram os povos das "
         "terras do norte e das costas do mar, cada um com a sua língua.",
         ["Gn 10:2-5"]),
        ("cam", "Cam", 766, "povos-cam", "Povos de Cam", "África e Canaã", "Cam",
         "Desrespeitou o pai, e a palavra dura de Noé caiu sobre Canaã, filho de Cam. Dos seus descendentes "
         "vieram os primeiros grandes impérios.",
         ["Gn 9:22-25", "Gn 10:6"],
         "Cuxe (ao sul do Egito), Mizraim (o Egito), Pute (a Líbia) e Canaã, de quem vieram os povos da terra "
         "prometida, como os jebuseus e os amorreus.",
         ["Gn 10:6", "Gn 10:15-19"]),
        ("sem", "Sem", 932, "povos-sem", "Povos de Sem", "Oriente e Arábia", "Sem",
         "Noé disse: bendito seja o Senhor, Deus de Sem. É da sua linha que vêm Héber, Abraão, Israel e, por fim, o "
         "Cristo. Gerou Arfaxade dois anos depois do dilúvio.",
         ["Gn 9:26", "Gn 10:21", "Gn 11:10-11", "Lc 3:36"],
         "Elão, Assur (a Assíria), Arfaxade, Lude e Arã (os arameus, ou sírios). De Arfaxade vem Héber, e de Héber, "
         "Abraão. De Sem vem a palavra semita.",
         ["Gn 10:22", "Gn 10:31"]),
    ]
    for id, nome, x, gid, gnome, gsub, retrato, texto, refs, gtexto, grefs in tres:
        q.no(id, nome, "pessoa", x, 196, "filho de Noé", texto, refs, "lin-noe-filhos", retrato, TEAL)
        q.liga("noe", id, meio=152)
        q.no(gid, gnome, "grupo", x, 264, gsub, gtexto, grefs, None, None, TEAL, w=156)
        q.liga(id, gid)
    q.no("ninrode", "Ninrode", "mini", 766, 320, "",
         "Neto de Cam, filho de Cuxe. Foi poderoso caçador e o primeiro grande conquistador. O começo do seu reino "
         "foi Babel, na terra de Sinar; depois edificou Nínive.",
         ["Gn 10:8-12"], None, None, TEAL)
    q.no("babel", "A torre de Babel", "marco", 766, 400, "Gn 11:1-9",
         "Toda a terra falava uma só língua. Na planície de Sinar os homens resolveram construir uma cidade e uma "
         "torre que chegasse ao céu, para fazer nome e não se espalhar. Deus confundiu a língua deles e os dispersou "
         "por toda a terra. Os povos de Gênesis 10 nascem dessa dispersão.",
         ["Gn 11:4", "Gn 11:7-9", "At 2:6"], "lin-babel", None, MARROM)
    q.liga("povos-cam", "ninrode")
    q.liga("ninrode", "babel", tracejada=True)

    # ---------------- De Sem a Abrão ----------------
    sem = [
        ("arfaxade", "Arfaxade", 35, 403, "Gn 11:12-13",
         "Nasceu dois anos depois do dilúvio. Lucas, que segue a antiga tradução grega, cita um Cainã entre ele e "
         "Salá; o texto hebraico de Gênesis não o traz.",
         ["Gn 11:10-13", "Lc 3:36"]),
        ("sala", "Salá", 30, 403, "Gn 11:14-15",
         "Pai de Héber. Com ele começa a se notar que as vidas vão ficando mais curtas depois do dilúvio.",
         ["Gn 11:14-15"]),
        ("heber", "Héber", 34, 430, "Gn 11:16-17",
         "Sem é chamado pai de todos os filhos de Héber. É provável que a palavra hebreu venha do seu nome: Abrão é "
         "o primeiro a ser chamado assim.",
         ["Gn 10:21", "Gn 11:16-17", "Gn 14:13"]),
        ("pelegue", "Pelegue", 30, 209, "Gn 11:18-19",
         "O nome quer dizer divisão, porque nos seus dias se repartiu a terra. Muitos ligam essa frase à dispersão "
         "de Babel.",
         ["Gn 10:25", "Gn 11:18-19"]),
        ("reu", "Reú", 32, 207, "Gn 11:20-21",
         "Filho de Pelegue. Só o nome e as idades ficaram registrados.",
         ["Gn 11:20-21"]),
        ("serugue", "Serugue", 30, 200, "Gn 11:22-23",
         "Bisavô de Abrão. A família vivia na Mesopotâmia, terra de muitos deuses.",
         ["Gn 11:22-23"]),
        ("naor", "Naor", 29, 119, "Gn 11:24-25",
         "Avô de Abrão. Teve a vida mais curta da lista. Um dos netos recebeu o seu nome.",
         ["Gn 11:24-25"]),
    ]
    prev = None
    for k, (id, nome, pai, mais, ref, texto, refs) in enumerate(sem):
        q.no(id, nome, "pessoa", 1272, 112 + STEP * k, f"pai aos {pai} anos", texto, refs, None, None, MARINHO,
             fatos=[("Idades", f"gerou o filho aos {pai} e viveu mais {mais} anos: {pai + mais} ao todo ({ref})")])
        if prev: q.liga(prev, id)
        prev = id
    q.liga("sem", "arfaxade", h=True, meio=1029)
    q.no("tera", "Terá", "pessoa", 1272, 112 + STEP * 7, "viveu 205 anos",
         "Pai de Abrão, Naor e Harã. Morava em Ur dos caldeus e, como diz Josué, servia a outros deuses. Saiu com a "
         "família rumo a Canaã, mas parou em Harã, onde morreu.",
         ["Gn 11:26", "Gn 11:31-32", "Js 24:2"], "ur-zigurate", None, MARINHO,
         fatos=[("Idade", "205 anos (Gn 11:32)")])
    q.liga("naor", "tera")
    q.no("naor2", "Naor", "mini", 1116, 574, "",
         "Irmão de Abrão. Casou com Milca e ficou na Mesopotâmia. É avô de Rebeca, a esposa de Isaque: por ele a "
         "família se reencontra uma geração depois.",
         ["Gn 11:29", "Gn 22:20-23", "Gn 24:15"], None, None, CINZA)
    q.no("abrao", "Abrão", "destaque", 1272, 574, "depois, Abraão",
         "Na vigésima geração desde Adão, Deus chama um homem de uma terra idólatra: sai da tua terra, e em ti serão "
         "benditas todas as famílias da terra. Abrão creu e partiu. Com ele começa a história de Israel, e a "
         "promessa ganha endereço.",
         ["Gn 11:26", "Gn 12:1-4", "At 7:2-4", "Gl 3:8"], "abraao-caravana", "Abraão", MARINHO, link="abraao")
    q.no("hara", "Harã", "mini", 1428, 574, "",
         "Irmão de Abrão, pai de Ló, de Milca e de Iscá. Morreu em Ur, antes do pai. Não confundir com a cidade de "
         "Harã, onde a família parou.",
         ["Gn 11:27-29"], None, None, CINZA)
    q.no("lo", "Ló", "mini", 1428, 628, "",
         "Sobrinho de Abrão, foi com ele para Canaã. Escolheu as campinas do Jordão e acabou em Sodoma, de onde Deus "
         "o tirou. Dele vêm os moabitas e os amonitas; Rute, bisavó de Davi, era moabita.",
         ["Gn 12:5", "Gn 13:10-12", "Gn 19:29", "Gn 19:36-38"], None, None, CINZA)
    for filho in ("naor2", "abrao", "hara"):
        q.liga("tera", filho, meio=532)
    q.liga("hara", "lo")

    # ---------------- Apresentação ----------------
    q.passo(["adao", "eva"], "O primeiro casal",
            "Deus cria o homem e a mulher à sua imagem e os põe no jardim. Eles desobedecem, e o pecado e a morte "
            "entram no mundo. Mas, antes de expulsá-los, Deus promete: um descendente da mulher esmagará a cabeça da "
            "serpente. Toda genealogia da Bíblia procura por esse descendente.",
            "Gn 3:15", "eden-casal")
    q.passo(["caim", "abel", "sete", "c-enoque", "c-lameque", "c-filhos"], "Dois caminhos",
            "Caim mata Abel e se afasta. A sua linha constrói cidades, cria música e ferramentas, e cresce em "
            "violência, até o canto de vingança de Lameque. No lugar de Abel, Deus dá Sete. São dois caminhos "
            "dentro da mesma família: o progresso sem Deus e a fé que espera a promessa.",
            "Gn 4:25", "eden-expulsao")
    q.passo(["sete", "enos", "caina", "maalalel", "jarede", "enoque"], "De Sete a Enoque",
            "Nos dias de Enos, filho de Sete, começa-se a invocar o nome do Senhor. A lista de Gênesis 5 repete para "
            "cada um: e morreu. Só de um não se diz isso. Enoque andou com Deus, e Deus o tomou para si. No meio da "
            "morte, um sinal de vida.",
            "Gn 5:24", "lin-enoque")
    q.passo(["matusalem", "lameque", "noe"], "Às portas do dilúvio",
            "Matusalém é o homem que mais viveu: 969 anos. Pelas contas do capítulo, morre no ano do dilúvio. O seu "
            "filho Lameque dá ao neto o nome de Noé, que lembra consolo. A terra está cheia de violência, mas Noé "
            "acha graça aos olhos do Senhor.",
            "Gn 6:8", "noe-construindo")
    q.passo(["noe"], "A arca e a aliança",
            "Noé obedece e constrói a arca. Oito pessoas entram, e Deus fecha a porta. Quando as águas baixam, Noé "
            "levanta um altar, e Deus faz aliança com ele e com toda a criação: nunca mais um dilúvio destruirá a "
            "terra. O arco nas nuvens é o sinal.",
            "Gn 9:12-13", "noe-arcoiris")
    q.passo(["noe", "sem", "cam", "jafe"], "Sem, Cam e Jafé",
            "Dos três filhos de Noé se povoou toda a terra. Noé abençoa o Senhor, Deus de Sem, e pede que Jafé seja "
            "alargado e habite nas tendas de Sem. A linha da promessa passa agora por Sem, mas a bênção já olha "
            "para os outros povos.",
            "Gn 9:26-27", "lin-noe-filhos")
    q.passo(["povos-jafe", "povos-cam", "povos-sem", "ninrode", "babel"], "Os povos e Babel",
            "Gênesis 10 é o mapa das nações: cerca de setenta nomes de povos, cada um com a sua terra e a sua língua. O "
            "capítulo 11 explica por quê. Em Babel os homens se unem para fazer um nome para si, e Deus confunde as "
            "línguas e os espalha. No Pentecostes, o Espírito começa a reunir os povos de novo.",
            "Gn 11:9", "lin-babel")
    q.passo(["sem", "arfaxade", "sala", "heber", "pelegue", "reu", "serugue", "naor", "tera"], "A linha de Sem",
            "Agora a lista se estreita: de todos os povos, uma família. Sem, Arfaxade, Salá, Héber, de quem vem o "
            "nome hebreu, Pelegue, Reú, Serugue, Naor e Terá. As vidas vão ficando mais curtas. A família mora em "
            "Ur, na Mesopotâmia, e já serve a outros deuses.",
            "Gn 11:10", "ur-zigurate")
    q.passo(["tera", "abrao", "naor2", "hara", "lo"], "Abrão",
            "Terá tem três filhos: Abrão, Naor e Harã. Harã morre cedo e deixa Ló. Deus fala com Abrão: sai da tua "
            "terra e da tua parentela. Em ti serão benditas todas as famílias da terra. A promessa feita no Éden "
            "ganha um nome, uma família e um rumo.",
            "Gn 12:1-3", "abraao-caravana")
    q.passo(["adao", "sete", "enoque", "noe", "sem", "heber", "abrao"], "A mesma linha chega a Jesus",
            "Lucas usa exatamente estes nomes na genealogia de Jesus, de trás para a frente: Abraão, Terá, Naor, até "
            "Sem, Noé, Enoque, Sete e Adão, filho de Deus. O descendente prometido a Eva veio por essa estrada de "
            "nomes. Nenhuma geração foi esquecida.",
            "Lc 3:34-38", "natal-manjedoura")
    return q
