"""Popola roam.db con dati dimostrativi realistici.

Uso (dalla cartella backend):
    .venv/bin/python seed.py            # inserisce/aggiorna i dati demo
    .venv/bin/python seed.py --remove   # rimuove solo i dati demo
    .venv/bin/python seed.py --trips    # aggiunge solo i viaggi demo del feed e le loro tappe

Tutte le righe create hanno id con prefisso "seed-": lo script è idempotente
e non tocca i dati reali (viaggi, profilo, post pubblicati dall'app).
Le recensioni vanno nella tabella comments; il backend le trasforma in post
del feed (id "review-seed-…") alla prima chiamata a /feed/query.
I post e i profili demo usano immagini AI locali in demo_assets/.
Le immagini sono illustrative, non fotografie documentarie dei luoghi.
"""
import base64
import json
import random
import sqlite3
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from uuid import NAMESPACE_URL, uuid5

import os

DB_PATH = Path(os.environ.get('ROAM_DB', Path(__file__).with_name('roam.db')))
NOW = datetime.now(timezone.utc)
rng = random.Random(42)


def sid(*parts):
    return 'seed-' + str(uuid5(NAMESPACE_URL, '/'.join(parts)))


def ago(days, hour=None):
    base = NOW - timedelta(days=days)
    h = hour if hour is not None else rng.choice([9, 10, 11, 12, 13, 17, 18, 19, 20, 21])
    return base.replace(hour=h, minute=rng.randrange(60), second=rng.randrange(60), microsecond=rng.randrange(10**6)).isoformat()


# --- Viaggi -----------------------------------------------------------------
TRIPS = [
    ('Venezia', '2026-11-21', '2026-11-23', "Ven: arrivo a Santa Lucia, cicchetti in Fondamenta della Misericordia.\nSab: Gallerie dell'Accademia la mattina (prenotare), Rialto al tramonto.\nDom: vaporetto 12 da Fondamente Nove per Burano, rientro entro le 17."),
    ('Lisbona', '2026-12-05', '2026-12-09', "Volo TAP da Venezia alle 6:40.\nAlloggio ad Alfama.\nIdee: tram 28 presto la mattina, LX Factory, pastéis a Belém, Sintra in giornata (treno da Rossio)."),
    ('Trento e mercatini', '2026-12-13', '2026-12-14', "Mercatino in piazza Fiera, Castello del Buonconsiglio.\nTreno regionale da Venezia via Verona, circa 2h40."),
    ('Copenaghen', '2027-01-29', '2027-02-02', "Cercare biglietti Louisiana Museum.\nNyhavn, Christiania, sauna sul porto a Islands Brygge.\nBudget cibo ~60€/giorno."),
    ('Napoli', '2027-03-19', '2027-03-22', "Pizza da provare: Starita, Sorbillo, Concettina ai Tre Santi.\nCappella Sansevero (prenotare!), Rione Sanità, giro a Procida se il mare è calmo."),
    ('Dolomiti – Val di Funes', '2027-06-26', '2027-06-29', "Rifugio Genova, sentiero Adolf Munkel.\nPortare scarponi e giacca anche a fine giugno."),
    ('Torino', '2026-09-12', '2026-09-14', "Fatto: Museo Egizio, bicerin al Caffè Al Bicerin, Mole al tramonto. Da rifare con più calma il Lingotto."),
]

# --- Recensioni per luogo ------------------------------------------------------
REVIEWS = {
    'Scuola Grande di Santa Maria della Misericordia': [
        ('Giulia Bertoldi', 5, "Il salone al primo piano è enorme, non te lo aspetti da fuori. Ci sono stata per una mostra e lo spazio da solo valeva la visita."),
        ('Marco Zanin', 4, "Edificio del Sansovino restaurato benissimo. Aperto solo per eventi o visite guidate, conviene controllare il calendario prima di andare."),
        ('Hannah Vogel', 5, "Beautiful quiet corner of Cannaregio, far from the crowds. Went for a concert in the evening, acoustics were great."),
    ],
    'Fondamenta della Misericordia': [
        ('Luca Furlan', 5, "La fondamenta dove vanno i veneziani per lo spritz. Al tramonto è piena ma l'atmosfera è autentica, cicchetti a 2-3 euro."),
        ('Sara Pellizzari', 4, "Bella passeggiata lungo il rio, tanti bacari uno dopo l'altro. Il venerdì sera c'è parecchia gente seduta sul bordo del canale."),
        ('Tommaso Rigo', 4, "Ottima per un'ombra e due cicchetti prima di cena. Evitate i locali con il menù fotografico, gli altri sono tutti validi."),
        ('Chloé Martin', 5, "Our favourite spot in Venice. Locals, students, dogs, boats passing by. Get a Select spritz and sit by the water."),
    ],
    'Palazzo Morosini Brandolin': [
        ('Paolo De Rossi', 4, "Facciata gotica sul Canal Grande, si ammira meglio dal vaporetto linea 1. Non è visitabile ma merita la foto."),
        ('Elena Marchiori', 3, "Bello da fuori, però non c'è molto da fare: è un palazzo privato. Da vedere passando, non come meta."),
    ],
    'LOVE Pizza & Cocktail': [
        ('Davide Trevisan', 4, "Pizza con impasto leggero e cornicione alto, buona la diavola. Cocktail fatti bene, il Negroni era giusto."),
        ('Martina Gallo', 4, "Comoda dopo una giornata a H-FARM. Il sabato sera meglio prenotare, si riempie verso le 20:30."),
        ('Andrea Basso', 3, "Pizza buona, servizio un po' lento quando c'è pieno. Prezzi nella media della zona."),
    ],
    'Approdo Motonavi Burano': [
        ('Francesca Lazzarin', 4, "Linea 12 da Fondamente Nove, circa 45 minuti. In alta stagione la coda per il ritorno verso le 17 è lunga, meglio partire prima."),
        ('Riccardo Vianello', 3, "Funzionale ma affollato. Consiglio di prendere il primo battello della mattina, Burano senza gente è un'altra cosa."),
        ('Emma Clarke', 5, "The colours of Burano right as you step off the boat! Tip: walk five minutes away from the main street and it gets quiet."),
    ],
    'Palazzo Albrizzi': [
        ('Chiara Dal Ben', 5, "Gli stucchi barocchi delle sale sono incredibili. Ci sono stata per un concerto organizzato dall'associazione italo-tedesca, esperienza speciale."),
        ('Giovanni Pavan', 4, "Poco conosciuto e proprio per questo bellissimo. Aperture limitate, informarsi prima."),
    ],
    'Palazzo Bonvicini – Fondation Valmont': [
        ('Alice Moretto', 4, "Mostra d'arte contemporanea divertente e un po' surreale. Visita di circa un'ora, ingresso libero quando ci sono stata."),
        ('Nicola Scarpa', 4, "Allestimenti curiosi in un palazzo sul canale, bello anche per chi non è appassionato di arte contemporanea."),
        ('Lena Schmidt', 3, "Interesting but small. Nice if you're in Santa Croce anyway."),
    ],
    "All'Arco": [
        ('Matteo Boscolo', 5, "Il miglior bacaro vicino a Rialto. Cicchetti fatti al momento con il pesce del mercato, si mangia in piedi fuori. Chiude presto, andare a pranzo."),
        ('Valentina Toffolo', 5, "Crostino con baccalà mantecato e un'ombra di bianco: perfetto. Piccolissimo, coda veloce."),
        ('Simone Carraro', 4, "Ottimi cicchetti, prezzi giusti. Unico difetto: dopo le 12:30 è pieno e si fa fatica a trovare posto anche fuori."),
        ('James Porter', 5, "Worth every minute of the queue. Ask what's fresh today and trust them."),
    ],
    '8 Vintage Venezia': [
        ('Irene Busato', 4, "Selezione curata di borse e accessori vintage, qualche pezzo firmato. Prezzi non bassissimi ma i capi sono in ottimo stato."),
        ('Laura Venturini', 4, "Ho trovato un foulard anni '70 bellissimo. Negozio piccolo, la titolare è gentile e racconta la storia dei pezzi."),
    ],
    'Palazzo Papadopoli': [
        ('Stefano Carnielli', 4, "Uno dei palazzi più eleganti sul Canal Grande, oggi è un hotel di lusso. Si vede bene dal traghetto di Rialto."),
        ('Anna Fregonese', 3, "Bello ma non visitabile se non si è ospiti. Il giardino dall'acqua è la parte più scenografica."),
    ],
    'Palazzo Cavalli': [
        ('Federica Zorzi', 5, "Ci siamo sposati qui a settembre: la sala affacciata sul Canal Grande è un sogno. Organizzazione del Comune impeccabile."),
        ('Massimo Bellotto', 4, "Palazzo gotico molto bello, sede di uffici comunali. Dal campo Sant'Angelo vale la deviazione per vederlo dall'acqua."),
    ],
    'Tezenis': [
        ('Giorgia Molin', 3, "Il solito Tezenis, utile se hai bisogno di qualcosa al volo. Camerini pochi e spesso occupati."),
        ('Elisa Fantin', 4, "Commesse gentili e saldi buoni a fine stagione. Comodo perché è sul percorso tra Rialto e San Marco."),
    ],
    "Gallerie dell'Accademia": [
        ('Alessandro Gobbo', 5, "La Tempesta di Giorgione da sola vale il biglietto. Bellini, Tiziano, Carpaccio: calcolate almeno due ore e mezza."),
        ('Beatrice Rossetto', 5, "Collezione straordinaria di pittura veneziana. Il ciclo di Sant'Orsola di Carpaccio mi ha lasciata senza parole."),
        ('Pietro Dalla Valle', 4, "Museo bellissimo, segnaletica migliorabile. Il lunedì chiude all'ora di pranzo, controllate gli orari."),
        ('Sophie Laurent', 5, "Less crowded than San Marco and far more rewarding. Book online to skip the line at the entrance."),
    ],
    'Ponte di Rialto': [
        ('Roberto Dal Corso', 4, "Iconico, ma di giorno è una calca. Alle 7 di mattina o dopo le 22 è un'altra esperienza."),
        ('Camilla Pizzolato', 5, "Il tramonto sul Canal Grande dalla balaustra è uno dei momenti più belli di Venezia."),
        ('Fabio Callegaro', 3, "Bellissimo ponte, negozi sul ponte molto turistici. Andate al mercato di Rialto lì vicino la mattina."),
    ],
    "Dersut D'Caffé": [
        ('Michela Sartor', 4, "Caffè buono e brioche fresche la mattina. Personale veloce anche quando c'è il pienone delle 8."),
        ('Ivan Bortolato', 4, "Bar di paese come si deve: spritz a prezzo onesto e tramezzini fatti in casa."),
    ],
    'Al Pescatore': [
        ('Lorenza Vio', 5, "Pesce freschissimo, il fritto misto è leggero e croccante. Un classico della zona per le occasioni."),
        ('Gianni Mazzon', 4, "Ottimo il risotto di pesce. Conto adeguato alla qualità, sul pesce crudo un po' caro."),
        ('Serena Cester', 4, "Ambiente familiare e porzioni abbondanti. La domenica a pranzo prenotare con qualche giorno di anticipo."),
    ],
    'Sol&luna': [
        ('Diego Marangon', 4, "Pizzeria affidabile, impasto ben lievitato e ingredienti buoni. Bene anche per famiglie con bambini."),
        ('Arianna Scomparin', 3, "Pizza discreta, servizio cordiale. Nel weekend tempi di attesa lunghi per l'asporto."),
    ],
    'Al Vecio Stampo': [
        ('Ottavio Bergamin', 5, "Trattoria vera: bigoli in salsa, baccalà con polenta e vino della casa. Prezzi onesti."),
        ('Rita Zamengo', 4, "Cucina veneta casalinga, ambiente semplice. Il martedì c'è il menù del giorno a buon prezzo."),
    ],
    'Local Impact': [
        ('Giacomo Pertile', 4, "Negozio piccolo con prodotti di produttori locali e oggetti di design sostenibile. Bello per un regalo."),
        ('Noemi Granzotto', 4, "Selezione interessante, prezzi un po' alti ma si sa da dove arriva ogni cosa."),
    ],
    'H-FARM - La Serra': [
        ('Edoardo Pivato', 5, "Pranzare nella serra in mezzo al verde del campus è bellissimo, soprattutto d'inverno con il sole. Cappuccino ottimo."),
        ('Caterina Bolzon', 4, "Ottimo posto per lavorare un'ora con il portatile tra una riunione e l'altra. A mezzogiorno c'è un po' di coda."),
        ('Filippo Tonon', 4, "Menù piccolo ma fatto bene, buona l'insalata con cereali. Prezzi da campus."),
    ],
}

# --- Post del feed con foto (alcuni dell'utente) ----------------------------
# (luogo, autore o None = profilo, voto, testo, giorni fa, salvato)
POSTS = [
    ('Ponte di Rialto', None, 5, "Sveglia alle 6:30 per avere il ponte tutto per me. Luce rosa sul Canal Grande e solo le barche del mercato. Rifarei tutto.", 2, False),
    ("All'Arco", None, 5, "Pranzo in piedi da All'Arco: baccalà mantecato, polpetta e un'ombra di Soave. Venezia è anche questo.", 2, False),
    ("Gallerie dell'Accademia", None, 4, "Finalmente davanti alla Tempesta. Più piccola di quanto pensassi ma ipnotica. Prossima volta audioguida.", 3, True),
    ('H-FARM - La Serra', None, 4, "Ufficio di oggi: la serra di H-FARM con un cappuccino e il sole di novembre che entra dalle vetrate.", 6, False),
    ('Fondamenta della Misericordia', 'Luca Furlan', 5, "Spritz Select, rio della Misericordia e la luce delle sei. Venerdì perfetto.", 1, True),
    ('Approdo Motonavi Burano', 'Emma Clarke', 5, "First boat of the morning to Burano. Empty streets, wet laundry and every colour you can imagine.", 4, True),
    ('Scuola Grande di Santa Maria della Misericordia', 'Giulia Bertoldi', 5, "Concerto d'archi nel salone del Sansovino. Il soffitto a cassettoni illuminato è uno spettacolo.", 5, False),
    ('Palazzo Albrizzi', 'Chiara Dal Ben', 5, "Questi stucchi sembrano pizzo. Uno dei segreti meglio custoditi di Cannaregio.", 9, True),
    ('Al Pescatore', 'Lorenza Vio', 5, "Fritto misto della domenica con la famiglia. Calamari tenerissimi, polenta bianca come da tradizione.", 7, False),
    ('Palazzo Bonvicini – Fondation Valmont', 'Alice Moretto', 4, "Una mostra che sembra un sogno: stanze piene di oggetti fuori scala. Ingresso libero, merita un'ora.", 11, False),
    ('8 Vintage Venezia', 'Laura Venturini', 4, "Bottino di oggi: foulard di seta anni '70 e una borsa in pelle intrecciata. Il vintage a Venezia ha un altro fascino.", 12, False),
    ("Gallerie dell'Accademia", 'Alessandro Gobbo', 5, "Mezz'ora davanti al ciclo di Sant'Orsola del Carpaccio. Ogni volta noto un dettaglio nuovo.", 14, False),
    ('Ponte di Rialto', 'Camilla Pizzolato', 5, "Tramonto dalla balaustra lato San Polo. Arrivate 20 minuti prima per trovare posto.", 15, True),
    ('LOVE Pizza & Cocktail', 'Davide Trevisan', 4, "Diavola e un Negroni dopo la giornata in campus. Cornicione alto e leggero, approvata.", 16, False),
    ('Al Vecio Stampo', 'Ottavio Bergamin', 5, "Bigoli in salsa come li faceva mia nonna. Trattoria vera, niente fronzoli.", 19, False),
    ('Palazzo Cavalli', 'Federica Zorzi', 5, "Un mese fa ci dicevamo sì in questa sala sul Canal Grande. Ancora emozionata a riguardare le foto.", 24, False),
    ('Fondamenta della Misericordia', None, 4, "Giro di bacari in Fondamenta con gli amici dell'università. Tre tappe, troppi cicchetti, zero rimpianti.", 27, False),
    ('Dersut D\'Caffé', 'Michela Sartor', 4, "Colazione prima di andare al lavoro: brioche alla crema appena sfornata e caffè fatto bene.", 30, False),
    ('Approdo Motonavi Burano', None, 4, "Ritorno da Burano con il battello delle 16. Consiglio: sedetevi a poppa per vedere la laguna che si allontana.", 34, True),
    ('Local Impact', 'Giacomo Pertile', 4, "Regali di Natale anticipati: miele del Sile e taccuini in carta riciclata fatti a mano.", 38, False),
    # Tappe dei viaggi demo (TRIP_STORIES): in coda, così gli id dei post precedenti non cambiano.
    ('Ponte di Rialto', 'Emma Clarke', 5, "Day one: dropped the bags and walked straight to Rialto. The Grand Canal never gets old.", 6, False),
    ("All'Arco", 'Emma Clarke', 5, "Cicchetti crawl, stop one. Baccalà on polenta and a glass of white standing at the counter.", 5, False),
    ("Gallerie dell'Accademia", 'Emma Clarke', 4, "Rainy afternoon well spent. Bellini, Giorgione and almost nobody in the rooms.", 5, False),
    ('Fondamenta della Misericordia', 'Giulia Bertoldi', 5, "Prima sera del weekend: spritz sul rio e chiacchiere fino a tardi.", 8, False),
    ('Palazzo Albrizzi', 'Giulia Bertoldi', 5, "Visita guidata agli stucchi di Palazzo Albrizzi: meraviglia pura.", 7, False),
]

# --- Viaggi nel feed: raccolte di post ------------------------------------------
# (autore o None per l'utente 1, titolo, destinazione, racconto, indici in POSTS)
TRIP_STORIES = [
    (None, 'Weekend a Venezia', 'Venezia', "Tre giorni tra ponti all'alba, bacari e musei. La laguna con calma, senza correre.", [2, 1, 0]),
    ('Emma Clarke', 'A week in the lagoon', 'Venezia e Burano', "My first long stay in Venice: early ferries, slow lunches and every colour of Burano.", [20, 21, 22, 5]),
    ('Giulia Bertoldi', 'Cannaregio da vivere', 'Venezia', "Un weekend tutto in Cannaregio, tra musica, palazzi e la Fondamenta al tramonto.", [23, 24, 6]),
]

# --- Commenti ai post ---------------------------------------------------------
COMMENT_POOL = [
    ('Sara Pellizzari', "Che luce! A che ora l'hai scattata?"),
    ('Tommaso Rigo', "Segnato per il prossimo weekend, grazie del consiglio."),
    ('Giulia Bertoldi', "Ci sono stata la settimana scorsa, confermo tutto."),
    ('Marco Zanin', "Bellissima, sembra un quadro."),
    ('Hannah Vogel', "Adding this to my list for December!"),
    ('Valentina Toffolo', "Invidia pura 😍"),
    ('Simone Carraro', "C'era molta gente?"),
    ('Martina Gallo', "Ci andiamo insieme la prossima volta?"),
    ('Riccardo Vianello', "Il posto giusto, hai scelto bene."),
    ('Elena Marchiori', "Grazie per la dritta sugli orari, utilissima."),
    ('Chloé Martin', "So beautiful, I miss Venice already."),
    ('Luca Furlan', "Uno dei miei preferiti in assoluto."),
]

# --- Asset dimostrativi generati con AI ---------------------------------------
ASSETS = Path(__file__).with_name('demo_assets')
PHOTO_BY_PLACE = {
    'Ponte di Rialto': 'rialto', "All'Arco": 'cicchetti',
    "Gallerie dell'Accademia": 'gallery', 'H-FARM - La Serra': 'cafe',
    'Fondamenta della Misericordia': 'cicchetti', 'Approdo Motonavi Burano': 'burano',
    'Scuola Grande di Santa Maria della Misericordia': 'palace',
    'Palazzo Albrizzi': 'palace', 'Al Pescatore': 'seafood',
    'Palazzo Bonvicini – Fondation Valmont': 'gallery', '8 Vintage Venezia': 'vintage',
    'LOVE Pizza & Cocktail': 'pizza', 'Al Vecio Stampo': 'pasta',
    'Palazzo Cavalli': 'palace', "Dersut D'Caffé": 'cafe', 'Local Impact': 'gifts',
}
AUTHOR_BIOS = [
    'Vivo tra calli e bacari. Cerco angoli tranquilli e tramonti sulla laguna.',
    'Based in Venice for a season. Early ferries, colourful streets and slow travel.',
    'Arte, concerti e architettura. Venezia si scopre una sala alla volta.',
    'Stucchi, palazzi e dettagli nascosti: il mio taccuino veneziano.',
    'La domenica a tavola con la famiglia. Cucina veneta e passeggiate sul mare.',
    'Mostre piccole e idee grandi. Appassionata di fotografia e arte contemporanea.',
    'Vintage, artigianato e oggetti con una storia da raccontare.',
    'Una passione per la pittura veneziana e i musei da visitare con calma.',
    'Inseguo la luce del tramonto con la macchina fotografica nello zaino.',
    'Studio, campus e nuove pizzerie da provare con gli amici.',
    'Ricette di casa, trattorie sincere e gite senza fretta.',
    'Ricordi sul Canal Grande. Amo i luoghi che diventano parte della nostra storia.',
    'Prima un buon caffè, poi si parte. Piccole scoperte ogni giorno.',
    'Produttori locali, design sostenibile e percorsi lungo il Sile.',
]


def asset_photo(name):
    data = (ASSETS / (name + '.jpg')).read_bytes()
    if not data.startswith(b'\xff\xd8\xff'):
        raise ValueError(f'JPEG non valido: {name}')
    return base64.b64encode(data).decode()


def remove(c):
    c.execute("DELETE FROM author_profiles WHERE id LIKE 'seed-%' AND is_demo=1")
    c.execute("DELETE FROM social_comments WHERE id LIKE 'seed-%' OR post_id LIKE 'seed-%' OR post_id LIKE 'review-seed-%'")
    c.execute("DELETE FROM post_saves WHERE post_id LIKE 'seed-%' OR post_id LIKE 'review-seed-%'")
    c.execute("DELETE FROM social_posts WHERE id LIKE 'seed-%' OR id LIKE 'review-seed-%'")
    c.execute("DELETE FROM comments WHERE id LIKE 'seed-%'")
    c.execute("DELETE FROM trips WHERE id LIKE 'seed-%'")
    c.execute("DELETE FROM trip_story_posts WHERE story_id LIKE 'seed-%'")
    c.execute("DELETE FROM trip_stories WHERE id LIKE 'seed-%'")


def seed_trip_stories(c, me):
    """Demo trips in the feed, built from demo posts (only those present in the database)."""
    n = 0
    for author, title, destination, body, indexes in TRIP_STORIES:
        ids = [sid('post', POSTS[i][0], str(i)) for i in indexes]
        rows = c.execute(f"SELECT id, created_at FROM social_posts WHERE id IN ({','.join('?' * len(ids))})", ids).fetchall()
        if len(rows) < 2:
            continue
        days = sorted(r['created_at'][:10] for r in rows)
        story = sid('story', title)
        c.execute('INSERT OR REPLACE INTO trip_stories(id,user_id,author,title,destination,start_date,end_date,body,created_at) VALUES(?,?,?,?,?,?,?,?,?)',
                  (story, 1 if author is None else None, author or me, title, destination, days[0], days[-1], body, max(r['created_at'] for r in rows)))
        c.execute('DELETE FROM trip_story_posts WHERE story_id=?', (story,))
        c.executemany('INSERT INTO trip_story_posts(story_id,post_id) VALUES(?,?)', [(story, r['id']) for r in rows])
        n += 1
    return n


def main():
    os.environ['ROAM_DB'] = str(DB_PATH)
    from database import init_db
    init_db()  # same schema as the API (models.py)
    c = sqlite3.connect(DB_PATH)
    c.row_factory = sqlite3.Row
    # Validate all assets before touching existing demo rows.
    photos = {}
    authors = list(dict.fromkeys(p[1] for p in POSTS if p[1]))
    portraits = {}
    if '--remove' not in sys.argv:
        photos = {name: asset_photo(name) for name in set(PHOTO_BY_PLACE.values())}
        portraits = {author: asset_photo(f'avatar-{i+1:02}') for i, author in enumerate(authors)}
    backup = DB_PATH.with_name(DB_PATH.name + '.bak-demo-' + datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
    with sqlite3.connect(backup) as target:
        c.backup(target)
    print(f'Backup: {backup}')
    with c:
        if '--remove' in sys.argv:
            remove(c)
            print('Dati demo rimossi.')
            return
        if '--trips' in sys.argv:
            # Non distruttivo: aggiunge le tappe mancanti e ricrea solo i viaggi demo.
            me = c.execute('SELECT name FROM profile WHERE id=1').fetchone()['name']
            known = {json.loads(r['payload'])['name']: json.loads(r['payload']) for r in c.execute('SELECT payload FROM place_catalog')}
            for author, *_ in TRIP_STORIES:
                if author:
                    c.execute('INSERT OR IGNORE INTO author_profiles VALUES(?,?,?,?,1)', (sid('author', author), author, AUTHOR_BIOS[authors.index(author)], portraits[author]))
            for i in sorted({i for *_, idx in TRIP_STORIES for i in idx}):
                name, author, rating, body, days, _ = POSTS[i]
                if name in known:
                    c.execute('INSERT OR IGNORE INTO social_posts(id,place_id,author,body,rating,photo,created_at,saved,mine,user_id) VALUES(?,?,?,?,?,?,?,0,?,?)',
                              (sid('post', name, str(i)), known[name]['id'], author or me, body, rating, photos[PHOTO_BY_PLACE[name]], ago(days),
                               int(author is None), 1 if author is None else None))
            print(f'Viaggi demo nel feed: {seed_trip_stories(c, me)}.')
            return

        places = {}
        for r in c.execute('SELECT id, payload FROM place_catalog'):
            p = json.loads(r['payload'])
            places[p['name']] = p
        missing = [n for n in list(REVIEWS) + [p[0] for p in POSTS] if n not in places]
        if missing:
            sys.exit(f'Luoghi non presenti nel catalogo: {sorted(set(missing))}')
        remove(c)
        for i, author in enumerate(authors):
            c.execute('INSERT INTO author_profiles VALUES(?,?,?,?,1)', (sid('author', author), author, AUTHOR_BIOS[i], portraits[author]))
        me = c.execute('SELECT name FROM profile WHERE id=1').fetchone()['name']

        for dest, start, end, notes in TRIPS:
            c.execute('INSERT INTO trips(id,destination,start_date,end_date,notes,user_id) VALUES(?,?,?,?,?,1)', (sid('trip', dest, start), dest, start, end, notes))

        n_reviews = 0
        for name, reviews in REVIEWS.items():
            for author, rating, body in reviews:
                c.execute('INSERT INTO comments(id,place_id,author,body,rating,created_at) VALUES(?,?,?,?,?,?)',
                          (sid('review', name, author), places[name]['id'], author, body, rating, ago(rng.randint(3, 75))))
                n_reviews += 1

        n_comments = 0
        for i, (name, author, rating, body, days, saved) in enumerate(POSTS):
            place = places[name]
            photo = photos[PHOTO_BY_PLACE[name]]
            post_id = sid('post', name, str(i))
            created = ago(days)
            c.execute('INSERT INTO social_posts(id,place_id,author,body,rating,photo,created_at,saved,mine,user_id) VALUES(?,?,?,?,?,?,?,?,?,?)',
                      (post_id, place['id'], author or me, body, rating, photo, created, int(saved), int(author is None), 1 if author is None else None))
            if saved:
                c.execute('INSERT OR IGNORE INTO post_saves(user_id,post_id,created_at) VALUES(1,?,?)', (post_id, created))
            for j, (c_author, c_body) in enumerate(rng.sample(COMMENT_POOL, rng.randint(0, 4))):
                if c_author == author:
                    continue
                when = min(datetime.fromisoformat(created) + timedelta(minutes=rng.randint(10, 60 * 30)), NOW - timedelta(minutes=rng.randint(5, 90))).isoformat()
                c.execute('INSERT INTO social_comments(id,post_id,author,body,created_at) VALUES(?,?,?,?,?)', (sid('pc', post_id, str(j)), post_id, c_author, c_body, when))
                n_comments += 1

        n_stories = seed_trip_stories(c, me)

    print(f'Profili demo: {len(authors)}. Inseriti: {len(TRIPS)} viaggi, {n_reviews} recensioni, {len(POSTS)} post con foto, {n_comments} commenti ai post, {n_stories} viaggi nel feed.')


if __name__ == '__main__':
    main()
