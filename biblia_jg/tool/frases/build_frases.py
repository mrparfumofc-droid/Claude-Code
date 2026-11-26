"""Gera assets/data/frases.json: frases de autores cristãos em domínio público.

Regras:
- Só autores mortos há mais de 70 anos (ou documentos históricos). Autores recentes (Tozer, Lewis,
  Stott, Ravenhill, Wilkerson, Billy Graham...) ficam de fora: o dono pode acrescentar em "Minhas frases".
- Tradução própria para o português, a partir do texto original ou de tradução em domínio público.
- "x": 1 = frase que a tradição atribui ao autor, sem fonte escrita segura (o app mostra "atribuída").
- Cada frase: (texto, autor, vida, grupo, fonte, atribuída).

Uso: python build_frases.py   (grava ../../assets/data/frases.json)
"""
import json
import pathlib

GRUPOS = [
    ("antiga", "Igreja antiga e medieval"),
    ("reforma", "Reformadores"),
    ("anglicana", "Anglicanos"),
    ("puritana", "Puritanos e reformados"),
    ("avivamento", "Metodistas e avivamentos"),
    ("missoes", "Missionários e pregadores"),
    ("pentecostal", "Pentecostais"),
    ("outros", "Outros clássicos"),
]

F = [
    # ---------------- Igreja antiga e medieval ----------------
    ("Fizeste-nos para ti, e o nosso coração anda inquieto enquanto não descansa em ti.",
     "Agostinho de Hipona", "354–430", "antiga", "Confissões, I, 1", 0),
    ("Tarde te amei, ó beleza tão antiga e tão nova, tarde te amei!",
     "Agostinho de Hipona", "354–430", "antiga", "Confissões, X, 27", 0),
    ("Dá o que ordenas e ordena o que quiseres.",
     "Agostinho de Hipona", "354–430", "antiga", "Confissões, X, 29", 0),
    ("O Novo Testamento está escondido no Antigo, e o Antigo se revela no Novo.",
     "Agostinho de Hipona", "354–430", "antiga", "Questões sobre o Heptateuco, II, 73", 0),
    ("Ignorar as Escrituras é ignorar a Cristo.",
     "Jerônimo", "c. 347–420", "antiga", "Comentário a Isaías, prólogo", 0),
    ("O sangue dos cristãos é semente.",
     "Tertuliano", "c. 160–220", "antiga", "Apologético, 50", 0),
    ("Há oitenta e seis anos eu o sirvo, e ele nunca me fez mal. Como eu poderia blasfemar contra o meu Rei, que me salvou?",
     "Policarpo de Esmirna", "c. 69–155", "antiga", "Martírio de Policarpo, 9", 0),
    ("Sou trigo de Deus e serei moído pelos dentes das feras, para me tornar pão puro de Cristo.",
     "Inácio de Antioquia", "m. c. 107", "antiga", "Carta aos Romanos, 4", 0),
    ("A glória de Deus é o homem vivo, e a vida do homem é ver a Deus.",
     "Irineu de Lião", "c. 130–202", "antiga", "Contra as Heresias, IV, 20, 7", 0),
    ("Não procuro entender para crer; creio para entender.",
     "Anselmo de Cantuária", "1033–1109", "antiga", "Proslógio, 1", 0),
    ("Sem o Caminho não se anda, sem a Verdade não se conhece, sem a Vida não se vive.",
     "Tomás de Kempis", "c. 1380–1471", "antiga", "Imitação de Cristo, III, 56", 0),

    # ---------------- Reformadores ----------------
    ("Creio que, no fim, a verdade vencerá.",
     "John Wycliffe", "c. 1328–1384", "reforma", "", 1),
    ("Procura a verdade, ouve a verdade, aprende a verdade, ama a verdade, fala a verdade, guarda a verdade e defende a verdade até a morte.",
     "Jan Hus", "c. 1370–1415", "reforma", "Exposição da Fé (1412)", 0),
    ("Ao dizer “Arrependei-vos”, nosso Senhor e Mestre Jesus Cristo quis que toda a vida dos que creem fosse arrependimento.",
     "Martinho Lutero", "1483–1546", "reforma", "95 Teses (1517), tese 1", 0),
    ("O verdadeiro tesouro da igreja é o santíssimo evangelho da glória e da graça de Deus.",
     "Martinho Lutero", "1483–1546", "reforma", "95 Teses (1517), tese 62", 0),
    ("A minha consciência está presa à Palavra de Deus. Não posso nem quero me retratar de nada, porque não é seguro nem correto agir contra a consciência.",
     "Martinho Lutero", "1483–1546", "reforma", "diante da Dieta de Worms (1521)", 0),
    ("O cristão é senhor de todas as coisas, inteiramente livre, e não está sujeito a ninguém. O cristão é servo de todos, pronto para servir, e está sujeito a todos.",
     "Martinho Lutero", "1483–1546", "reforma", "Da Liberdade Cristã (1520)", 0),
    ("A fé é uma confiança viva e ousada na graça de Deus, tão certa que por ela a pessoa morreria mil vezes.",
     "Martinho Lutero", "1483–1546", "reforma", "Prefácio à Carta aos Romanos (1522)", 0),
    ("Aquilo a que prendes o teu coração e em que confias, isso é, de fato, o teu deus.",
     "Martinho Lutero", "1483–1546", "reforma", "Catecismo Maior (1529)", 0),
    ("Devemos temer e amar a Deus e confiar nele acima de todas as coisas.",
     "Martinho Lutero", "1483–1546", "reforma", "Catecismo Menor (1529)", 0),
    ("Castelo forte é o nosso Deus, boa defesa e boa arma.",
     "Martinho Lutero", "1483–1546", "reforma", "hino Castelo Forte (c. 1529)", 0),
    ("Conhecer a Cristo é conhecer os seus benefícios.",
     "Filipe Melâncton", "1497–1560", "reforma", "Loci Communes (1521)", 0),
    ("O resumo do evangelho é que nosso Senhor Jesus Cristo, verdadeiro Filho de Deus, nos revelou a vontade do Pai celestial e, com a sua inocência, nos livrou da morte e nos reconciliou com Deus.",
     "Ulrico Zuínglio", "1484–1531", "reforma", "67 Artigos (1523), artigo 2", 0),
    ("Quase toda a sabedoria que temos, a verdadeira e sólida, tem duas partes: o conhecimento de Deus e o conhecimento de nós mesmos.",
     "João Calvino", "1509–1564", "reforma", "Institutas, I, 1, 1", 0),
    ("A mente do homem é uma fábrica perpétua de ídolos.",
     "João Calvino", "1509–1564", "reforma", "Institutas, I, 11, 8", 0),
    ("A oração é o principal exercício da fé; por ela recebemos todos os dias os benefícios de Deus.",
     "João Calvino", "1509–1564", "reforma", "Institutas, III, 20", 0),
    ("O meu coração eu te ofereço, Senhor, pronto e sincero.",
     "João Calvino", "1509–1564", "reforma", "lema pessoal", 0),
    ("Costumo chamar o livro dos Salmos de anatomia de todas as partes da alma.",
     "João Calvino", "1509–1564", "reforma", "Comentário aos Salmos (1557), prefácio", 0),
    ("Se Deus me poupar a vida, em poucos anos farei que o rapaz que conduz o arado conheça mais das Escrituras do que tu.",
     "William Tyndale", "c. 1494–1536", "reforma", "relatado por John Foxe", 0),
    ("Senhor, abre os olhos do rei da Inglaterra!",
     "William Tyndale", "c. 1494–1536", "reforma", "últimas palavras, relatadas por John Foxe", 0),
    ("Evangelho é uma palavra grega que quer dizer notícia boa, alegre e feliz, que alegra o coração do homem e o faz cantar, dançar e saltar de alegria.",
     "William Tyndale", "c. 1494–1536", "reforma", "prólogo ao Novo Testamento (1525)", 0),
    ("Dá-me a Escócia, ou eu morro!",
     "John Knox", "c. 1514–1572", "reforma", "oração", 1),
    ("A verdadeira fé evangélica não consegue ficar parada: veste os nus, alimenta os famintos, consola os tristes e abriga os desamparados.",
     "Menno Simons", "1496–1561", "reforma", "escrito de 1539", 0),
    ("Qual é o teu único consolo na vida e na morte? Que não pertenço a mim mesmo, mas, de corpo e alma, na vida e na morte, pertenço ao meu fiel Salvador Jesus Cristo.",
     "Catecismo de Heidelberg", "1563", "reforma", "pergunta 1", 0),
    ("O fim principal do homem é glorificar a Deus e alegrar-se nele para sempre.",
     "Breve Catecismo de Westminster", "1647", "reforma", "pergunta 1", 0),
    ("A regra infalível para interpretar a Escritura é a própria Escritura.",
     "Confissão de Fé de Westminster", "1646", "reforma", "capítulo I, 9", 0),

    # ---------------- Anglicanos ----------------
    ("Bendito Senhor, que fizeste escrever todas as Sagradas Escrituras para o nosso ensino: concede que as ouçamos, leiamos, guardemos, aprendamos e as assimilemos de coração.",
     "Thomas Cranmer", "1489–1556", "anglicana", "Livro de Oração Comum (1549)", 0),
    ("Erramos e nos desviamos dos teus caminhos como ovelhas perdidas. Seguimos demais os planos e os desejos do nosso próprio coração.",
     "Thomas Cranmer", "1489–1556", "anglicana", "Livro de Oração Comum (1552), confissão geral", 0),
    ("Tenha bom ânimo, mestre Ridley! Hoje, pela graça de Deus, acenderemos na Inglaterra uma vela que, eu confio, nunca se apagará.",
     "Hugh Latimer", "c. 1487–1555", "anglicana", "na fogueira, relatado por John Foxe", 0),
    ("Há mais misericórdia em Cristo do que pecado em nós.",
     "Richard Sibbes", "1577–1635", "anglicana", "A Cana Quebrada (1630)", 0),
    ("Nenhum homem é uma ilha, inteiro em si mesmo; cada homem é um pedaço do continente, uma parte do todo.",
     "John Donne", "1572–1631", "anglicana", "Meditação XVII (1624)", 0),
    ("Sete dias inteiros, e não um em sete, eu te louvarei.",
     "George Herbert", "1593–1633", "anglicana", "O Templo (1633)", 0),
    ("Tudo o que enfraquece a tua razão, endurece a tua consciência, escurece a tua visão de Deus ou tira o teu gosto pelas coisas espirituais, isso é pecado para ti.",
     "Susanna Wesley", "1669–1742", "anglicana", "carta ao filho John (1725)", 0),
    ("Maravilhosa graça! Como é doce o som que salvou um perdido como eu. Eu estava perdido e fui achado; era cego e agora vejo.",
     "John Newton", "1725–1807", "anglicana", "hino Amazing Grace (1779)", 0),
    ("A minha memória quase se foi, mas de duas coisas eu me lembro: sou um grande pecador, e Cristo é um grande Salvador.",
     "John Newton", "1725–1807", "anglicana", "", 1),
    ("Não sou o que deveria ser, não sou o que gostaria de ser, não sou o que espero ser; mas, pela graça de Deus, já não sou o que eu era.",
     "John Newton", "1725–1807", "anglicana", "", 1),
    ("Deus age de modo misterioso para realizar as suas maravilhas.",
     "William Cowper", "1731–1800", "anglicana", "hino (1773)", 0),
    ("Senhor Jesus, estou cansado na tua obra, mas não da tua obra.",
     "George Whitefield", "1714–1770", "anglicana", "oração antes do último sermão (1770)", 0),
    ("Prefiro gastar-me a enferrujar.",
     "George Whitefield", "1714–1770", "anglicana", "", 1),
    ("Sem santidade na terra, nunca estaremos preparados para desfrutar o céu.",
     "J. C. Ryle", "1816–1900", "anglicana", "Santidade (1877)", 0),
    ("A oração é o próprio fôlego de vida da verdadeira religião.",
     "J. C. Ryle", "1816–1900", "anglicana", "Um Chamado à Oração", 0),

    # ---------------- Puritanos e reformados ----------------
    ("Mate o pecado, ou ele matará você.",
     "John Owen", "1616–1683", "puritana", "A Mortificação do Pecado (1656)", 0),
    ("Preguei como quem não sabia se pregaria outra vez, como um homem que morre a homens que morrem.",
     "Richard Baxter", "1615–1691", "puritana", "poema de 1681", 0),
    ("Na oração, é melhor ter um coração sem palavras do que palavras sem coração.",
     "John Bunyan", "1628–1688", "puritana", "", 1),
    ("Quando Cristão chegou à cruz, o fardo se soltou dos seus ombros, caiu das suas costas e rolou até a boca do sepulcro; e eu não o vi mais.",
     "John Bunyan", "1628–1688", "puritana", "O Peregrino (1678)", 0),
    ("Enquanto o pecado não for amargo, Cristo não será doce.",
     "Thomas Watson", "c. 1620–1686", "puritana", "A Doutrina do Arrependimento (1668)", 0),
    ("Quando me encontro na adega da aflição, procuro os melhores vinhos do Senhor.",
     "Samuel Rutherford", "1600–1661", "puritana", "Cartas", 1),
    ("A mulher não foi tirada da cabeça do homem, para dominá-lo, nem dos pés, para ser pisada por ele, mas do seu lado, para ser igual a ele; debaixo do braço, para ser protegida, e perto do coração, para ser amada.",
     "Matthew Henry", "1662–1714", "puritana", "Comentário Bíblico, Gênesis 2", 0),
    ("Amor tão maravilhoso, tão divino, pede a minha alma, a minha vida, tudo o que sou.",
     "Isaac Watts", "1674–1748", "puritana", "hino (1707)", 0),
    ("Para cada olhar para si mesmo, dê dez olhares para Cristo.",
     "Robert Murray M'Cheyne", "1813–1843", "puritana", "carta", 0),
    ("O que o meu povo mais precisa é da minha santidade pessoal.",
     "Robert Murray M'Cheyne", "1813–1843", "puritana", "", 1),
    ("Se os pecadores hão de se perder, que ao menos saltem para o inferno por cima dos nossos corpos; que ninguém vá para lá sem ser avisado e sem que se ore por ele.",
     "Charles H. Spurgeon", "1834–1892", "puritana", "sermão de 1860", 0),
    ("A Palavra de Deus é como um leão. Não é preciso defender um leão: basta soltá-lo, e ele se defende sozinho.",
     "Charles H. Spurgeon", "1834–1892", "puritana", "resumo de um sermão de 1886", 0),
    ("Visite muitos livros bons, mas more na Bíblia.",
     "Charles H. Spurgeon", "1834–1892", "puritana", "", 1),
    ("Tenho uma grande necessidade de Cristo; tenho um grande Cristo para a minha necessidade.",
     "Charles H. Spurgeon", "1834–1892", "puritana", "", 1),
    ("Foi pela perseverança que o caracol chegou à arca.",
     "Charles H. Spurgeon", "1834–1892", "puritana", "", 1),
    ("Não há um só centímetro quadrado, em todos os domínios da vida humana, sobre o qual Cristo, soberano de tudo, não diga: é meu!",
     "Abraham Kuyper", "1837–1920", "puritana", "discurso de 1880", 0),

    # ---------------- Metodistas e avivamentos ----------------
    ("Senti o meu coração estranhamente aquecido. Senti que confiava em Cristo, somente em Cristo, para a salvação.",
     "John Wesley", "1703–1791", "avivamento", "Diário, 24 de maio de 1738", 0),
    ("Considero o mundo inteiro a minha paróquia.",
     "John Wesley", "1703–1791", "avivamento", "Diário, 11 de junho de 1739", 0),
    ("Deem-me cem pregadores que não temam nada além do pecado e não desejem nada além de Deus: eles abalarão as portas do inferno e estabelecerão o reino dos céus na terra.",
     "John Wesley", "1703–1791", "avivamento", "carta a Alexander Mather (1777)", 0),
    ("O melhor de tudo é que Deus está conosco.",
     "John Wesley", "1703–1791", "avivamento", "últimas palavras (1791)", 0),
    ("Ah, se eu tivesse mil línguas para cantar o louvor do meu grande Redentor!",
     "Charles Wesley", "1707–1788", "avivamento", "hino (1739)", 0),
    ("Resolvi viver com todas as minhas forças enquanto eu viver.",
     "Jonathan Edwards", "1703–1758", "avivamento", "Resoluções, nº 6", 0),
    ("Resolvi estudar as Escrituras com tanta constância e frequência que eu perceba claramente que estou crescendo no conhecimento delas.",
     "Jonathan Edwards", "1703–1758", "avivamento", "Resoluções, nº 28", 0),
    ("Tenho uma só paixão: é Ele, somente Ele.",
     "Conde Zinzendorf", "1700–1760", "avivamento", "", 1),
    ("Avivamento não é outra coisa senão um novo começo de obediência a Deus.",
     "Charles Finney", "1792–1875", "avivamento", "Lições sobre Avivamentos (1835)", 0),
    ("A igreja procura métodos melhores; Deus procura homens melhores.",
     "E. M. Bounds", "1835–1913", "avivamento", "Poder pela Oração", 0),
    ("O Espírito Santo não flui por métodos, mas por homens. Ele não unge planos, mas homens: homens de oração.",
     "E. M. Bounds", "1835–1913", "avivamento", "Poder pela Oração", 0),
    ("A oração não é monólogo, mas diálogo; a voz de Deus, em resposta à minha, é a sua parte mais essencial.",
     "Andrew Murray", "1828–1917", "avivamento", "Com Cristo na Escola da Oração", 0),
    ("A oração é a chave que abre todos os depósitos da graça e do poder infinitos de Deus.",
     "R. A. Torrey", "1856–1928", "avivamento", "Como Orar (1900)", 0),
    ("Antes era a bênção, agora é o Senhor; antes era o sentimento, agora é a sua Palavra.",
     "A. B. Simpson", "1843–1919", "avivamento", "hino Ele Mesmo", 0),
    ("A oração não nos prepara para obras maiores; a oração é a obra maior.",
     "Oswald Chambers", "1874–1917", "avivamento", "Tudo para Ele", 0),
    ("Que segurança: Jesus é meu! Que antegozo da glória de Deus!",
     "Fanny Crosby", "1820–1915", "avivamento", "hino (1873)", 0),
    ("Seja qual for a minha sorte, tu me ensinaste a dizer: está tudo bem com a minha alma.",
     "Horatio Spafford", "1828–1888", "avivamento", "hino (1873)", 0),

    # ---------------- Missionários e pregadores ----------------
    ("Espere grandes coisas de Deus; empreenda grandes coisas para Deus.",
     "William Carey", "1761–1834", "missoes", "sermão de 1792", 0),
    ("O futuro é tão brilhante quanto as promessas de Deus.",
     "Adoniram Judson", "1788–1850", "missoes", "", 1),
    ("A obra de Deus, feita do jeito de Deus, nunca ficará sem o sustento de Deus.",
     "Hudson Taylor", "1832–1905", "missoes", "", 1),
    ("A fé não age no campo do possível. Ela começa onde o poder do homem termina.",
     "George Müller", "1805–1898", "missoes", "", 1),
    ("Não darei valor a nada do que tenho ou possa vir a ter, a não ser em relação ao reino de Cristo.",
     "David Livingstone", "1813–1873", "missoes", "diário", 0),
    ("Se Jesus Cristo é Deus e morreu por mim, nenhum sacrifício que eu faça por ele pode ser grande demais.",
     "C. T. Studd", "1860–1931", "missoes", "lema missionário", 0),
    ("É possível dar sem amar, mas não é possível amar sem dar.",
     "Amy Carmichael", "1867–1951", "missoes", "", 1),
    ("O caráter é aquilo que você é no escuro.",
     "D. L. Moody", "1837–1899", "missoes", "", 1),
    ("Este livro vai afastar você do pecado, ou o pecado vai afastar você deste livro.",
     "D. L. Moody", "1837–1899", "missoes", "anotação na sua Bíblia", 1),
    ("A grande tragédia da vida não é a oração sem resposta, mas a oração que não foi feita.",
     "F. B. Meyer", "1847–1929", "missoes", "", 1),
    ("Ir à igreja não faz de ninguém um cristão, assim como entrar numa garagem não faz de ninguém um automóvel.",
     "Billy Sunday", "1862–1935", "missoes", "", 1),

    # ---------------- Pentecostais ----------------
    ("O poder pentecostal, no fim das contas, é simplesmente mais do amor de Deus. Se não produz mais amor, é só uma imitação.",
     "William J. Seymour", "1870–1922", "pentecostal", "jornal A Fé Apostólica, Rua Azusa (1908)", 0),
    ("Não saiam daqui falando de línguas: falem de Jesus e procurem ganhar pessoas para ele.",
     "William J. Seymour", "1870–1922", "pentecostal", "relatado por quem esteve na Rua Azusa", 1),
    ("Los Angeles está sendo visitada por um avivamento de salvação bíblica e de Pentecostes, como está registrado no livro de Atos.",
     "A Fé Apostólica", "1906", "pentecostal", "primeira edição do jornal da Rua Azusa", 0),
    ("A barreira da cor foi lavada no sangue.",
     "Frank Bartleman", "1871–1936", "pentecostal", "Como o Pentecostes Chegou a Los Angeles (1925)", 0),
    ("Confesse todo pecado conhecido. Abandone todo hábito duvidoso. Obedeça logo ao Espírito Santo. Confesse a Cristo publicamente.",
     "Evan Roberts", "1878–1951", "pentecostal", "os quatro pontos do avivamento do País de Gales (1904)", 0),
    ("Dobra-me, Senhor!",
     "Evan Roberts", "1878–1951", "pentecostal", "oração do avivamento do País de Gales (1904)", 0),
    ("Somente creia!",
     "Smith Wigglesworth", "1859–1947", "pentecostal", "lema das suas pregações", 0),
    ("Não me movo pelo que vejo nem pelo que sinto; eu me movo pelo que creio.",
     "Smith Wigglesworth", "1859–1947", "pentecostal", "", 1),
    ("Grande fé nasce de grandes lutas. Grandes testemunhos vêm de grandes provas. Grandes vitórias só saem de grandes batalhas.",
     "Smith Wigglesworth", "1859–1947", "pentecostal", "", 1),
    ("Para Deus nada é impossível. Toda a impossibilidade está em nós, quando medimos Deus pelos limites da nossa incredulidade.",
     "Smith Wigglesworth", "1859–1947", "pentecostal", "", 1),

    # ---------------- Outros clássicos ----------------
    ("O coração tem razões que a razão desconhece.",
     "Blaise Pascal", "1623–1662", "outros", "Pensamentos", 0),
    ("Somente a Deus a glória.",
     "Johann Sebastian Bach", "1685–1750", "outros", "assinatura no fim das suas partituras", 0),
    ("A oração não muda a Deus, mas muda quem ora.",
     "Søren Kierkegaard", "1813–1855", "outros", "", 1),
    ("O ideal cristão não foi experimentado e reprovado; foi considerado difícil e deixado de lado.",
     "G. K. Chesterton", "1874–1936", "outros", "O Que Há de Errado com o Mundo (1910)", 0),
    ("Quando Cristo chama um homem, ele o chama para vir e morrer.",
     "Dietrich Bonhoeffer", "1906–1945", "outros", "Discipulado (1937)", 0),
    ("Graça barata é graça sem discipulado, graça sem cruz, graça sem Jesus Cristo vivo e encarnado.",
     "Dietrich Bonhoeffer", "1906–1945", "outros", "Discipulado (1937)", 0),
]


def main() -> None:
    ids = {g for g, _ in GRUPOS}
    seen = set()
    frases = []
    for t, a, v, g, f, x in F:
        assert g in ids, g
        assert t not in seen, t
        seen.add(t)
        assert t[-1] in ".!?", t
        row = {"t": t, "a": a, "v": v, "g": g}
        if f:
            row["f"] = f
        if x:
            row["x"] = 1
        frases.append(row)
    out = pathlib.Path(__file__).resolve().parents[2] / "assets" / "data" / "frases.json"
    data = {"versao": 1, "grupos": [{"id": g, "nome": n} for g, n in GRUPOS], "frases": frases}
    out.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8", newline="\n")
    por = {g: sum(1 for r in frases if r["g"] == g) for g, _ in GRUPOS}
    print(len(frases), "frases;", por, "; atribuídas:", sum(1 for r in frases if r.get("x")))


if __name__ == "__main__":
    main()
