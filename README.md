# Roam — il tuo compagno di viaggio

Prototipo nativo **SwiftUI per iOS 17+**, con backend **FastAPI + SQLite** e interfaccia in italiano.

## Avvio

Un solo comando avvia il backend e ricompila l’app sull’iPhone:

```sh
./w.sh                  # backend + reinstalla l'app su tutti gli iPhone associati (cavo o stessa Wi-Fi)
./start.sh              # backend + build e installazione sull'iPhone
./start.sh --sim        # backend + build e avvio sul simulatore
./start.sh --no-ios     # solo backend
./start.sh --ios-only   # solo build e installazione
./start.sh --test       # esegue prima i test del backend (si combina con le altre)
./start.sh --stop       # ferma il backend
```

Il backend riparte sempre con il codice aggiornato; lo script attende fino a 120 secondi (`ROAM_START_TIMEOUT`) e verifica `/health` senza proxy. Log: `backend/server.log` e `ios/install.log`. La build iOS parte da una copia in `/tmp/roam-src-ios`, perché sulla Scrivania sincronizzata con iCloud `actool` non legge gli asset; se iCloud ha tolto dal Mac il contenuto dei file (“Ottimizza spazio”), lo script li riscarica prima di partire. Per evitarlo del tutto: Finder → tasto destro sulla cartella del progetto → **Mantieni scaricato**.

Installazione manuale, dal terminale nella cartella del progetto:

```sh
python3 -m venv backend/.venv
backend/.venv/bin/pip install -r backend/requirements.txt
cd backend
.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Apri `ios/Roam.xcodeproj` in Xcode, seleziona lo schema **Roam**, scegli un simulatore iPhone e premi Run. Nel simulatore l’URL predefinito `http://127.0.0.1:8000` punta al Mac.

Su un iPhone fisico seleziona un Team in Signing & Capabilities e imposta in **Profilo → Connessione al backend** `http://IP-DEL-MAC:8000`. Mac e iPhone devono essere sulla stessa rete. Consenti l'accesso alla rete locale quando richiesto.

Documentazione API interattiva: `http://127.0.0.1:8000/docs`.

## Cosa puoi usare

- **Esplora:** avatar, luogo, ora locale del dispositivo, meteo da Open-Meteo, filtri per attrazioni/caffè/negozi, distanza e dettaglio con mappa MapKit.
- **Viaggi:** creazione e cancellazione con swipe, destinazione, partenza, ritorno e note per tappe e idee. Validazione delle date sia nel client sia sul server.
- **Assistente:** chat con suggerimenti dal catalogo, selezionati per categoria e ordinati per distanza. Condivisione della posizione disattivabile nelle impostazioni.
- **Profilo:** nome, bio e foto selezionabile con PhotosPicker, ridimensionata e salvata premendo Salva profilo. Statistiche effettive sui viaggi pianificati, destinazioni distinte e commenti.
- **Luoghi:** commenti persistenti con valutazione da 1 a 5 stelle.

## Dati e servizi

La posizione viene richiesta all’apertura e aggiornata quando l’app torna attiva. iOS richiede il consenso “Mentre usi l’app”; in caso di diniego viene proposto il collegamento alle Impostazioni. Non viene tracciata in background. Senza posizione non vengono usati luoghi o meteo di una città predefinita.

`GET /places` richiede latitudine e longitudine e cerca luoghi reali entro 5 km tramite Overpass/OpenStreetMap. Restituisce fino a 30 risultati per categoria (attrazioni, caffè e negozi), ordinati per distanza in linea d’aria. La cache dura 10 minuti; i luoghi vengono registrati nel database per mantenere i commenti. I dati dipendono dalla copertura OpenStreetMap e non certificano apertura o disponibilità. Attribuzione presente nell’app.

Il meteo richiede Internet e usa Open-Meteo sulla posizione dell’iPhone. Se il servizio non risponde viene mostrato “Meteo non disponibile”. La posizione viene inviata a Open-Meteo per il meteo e, tramite il backend, a Overpass per i luoghi, come autorizzato dall’utente. L’ora segue il fuso del dispositivo.

Senza chiave la chat seleziona suggerimenti dal catalogo locale. Con GEMINI_API_KEY usa Gemini mantenendo la chiave sul server. Il toggle del profilo permette di non condividere le coordinate con la chat; in quel caso l’assistente non assume una posizione predefinita.

SQLite conserva i dati in `backend/roam.db`, creato automaticamente. La variabile `ROAM_DB` permette di cambiare percorso. Le foto sono JPEG in base64 nel profilo, massimo 4 milioni di caratteri.

Questo prototipo usa **un unico profilo condiviso, senza autenticazione**. Prima dell’uso pubblico aggiungere account, autorizzazioni per utente, moderazione dei commenti, HTTPS e storage immagini dedicato. L’eccezione ATS in Info.plist permette il backend HTTP locale durante lo sviluppo e va limitata in produzione.

## Test

```sh
cd backend
.venv/bin/python -m pytest -q
```

I test usano un database temporaneo e verificano persistenza del profilo, ciclo creazione/cancellazione viaggio, date non valide, commenti, valutazioni, luoghi mancanti, ordinamento per distanza e suggerimenti chat.

Compilazione senza firma:

```sh
xcodebuild -project ios/Roam.xcodeproj -scheme Roam \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/roam-build CODE_SIGNING_ALLOWED=NO build
```

## Ollama locale (predefinito)

La chat usa Ollama sul Mac, senza chiavi API. Avvia `ollama serve` e configura in `backend/.env`:

```dotenv
CHAT_PROVIDER=ollama
OLLAMA_BASE_URL=http://127.0.0.1:11434
OLLAMA_MODEL=qwen3:4b
```

Usa il nome esatto di un modello installato (`ollama list`); per scaricare quello dell'esempio: `ollama pull qwen3:4b`.
Il telefono comunica con il backend, che contatta Ollama: non esporre la porta 11434 sulla rete.
Messaggi e contesto della chat vengono elaborati dal servizio configurato. Le ricerche dei luoghi e delle immagini continuano a usare i rispettivi servizi web.
Se Ollama non risponde, la chat mostra un errore senza passare a un provider esterno. `CHAT_PROVIDER=local` abilita i suggerimenti senza modello.

## Gemini

Per riattivare Gemini imposta `CHAT_PROVIDER=gemini`. Inserisci la chiave in `backend/.env`, nel campo `GEMINI_API_KEY`, e riavvia il server. `GEMINI_MODEL` è configurabile (default `gemini-flash-latest`). La chiave rimane nel backend e il file `.env` è escluso da Git. Con la chiave configurata la chat invia a Google il messaggio, le coordinate selezionate e il catalogo demo con le distanze. Senza chiave resta attiva la modalità locale. Errori del provider non causano un passaggio silenzioso alla demo.

La build per l'iPhone usa come URL iniziale `http://100.90.158.14:8000`, indirizzo Tailscale del Mac: attiva Tailscale anche sull'iPhone. Il Mac e il backend devono restare accesi. Puoi cambiare URL dal profilo per usare la rete Wi-Fi locale.

Per installare sul dispositivo già associato: `./start.sh --ios-only` (o `ios/install.sh`). Richiede un account Apple attivo in Xcode → Settings → Accounts, un profilo di provisioning valido e iPhone raggiungibile e sbloccato.

## Ricerca alternativa con Mappe Apple

Se Overpass non risponde, la home mostra un messaggio nella pagina e permette di attivare Mappe Apple. Il pulsante spiega che le coordinate vengono inviate ad Apple; prima dell'attivazione non viene eseguita alcuna ricerca MapKit. La scelta viene ricordata ed è disattivabile nel profilo.

La ricerca Apple avviene sull'iPhone per attrazioni, caffè e negozi, filtra i risultati entro 5 km e non dipende dal backend per mostrare i luoghi. Il backend serve ancora per commenti, viaggi, profilo e chat. I luoghi Apple vengono registrati al caricamento dei commenti. Quando la posizione è condivisa con la chat, i luoghi visualizzati vengono passati al backend senza ripetere la ricerca Overpass.

Errori della ricerca e della sincronizzazione sono separati: un disservizio dei luoghi non apre più un avviso globale né impedisce di vedere gli altri dati. Le risposte tardive delle ricerche precedenti non sostituiscono i risultati più recenti.

## Guardati intorno: immagini e community

La sezione sotto la mappa si chiama “Guardati intorno”. Ogni luogo ha una scheda con anteprima, categoria, distanza, conteggio commenti e media delle valutazioni effettive. Toccandola si apre il dettaglio con commenti e valutazione da 1 a 5 stelle.

Le anteprime sono immagini Apple Look Around della zona del punto, dove la copertura è disponibile; in alternativa viene usata una copertina AI illustrativa di categoria (attrazione, caffè o negozio), etichettata come tale. Le mappe non sono usate come immagini delle schede. Le etichette distinguono chiaramente viste della zona, illustrazioni AI generiche e foto della community. Non vengono usate foto generiche spacciate per il luogo reale. L'utente ha autorizzato l'invio ad Apple delle coordinate dei luoghi per queste anteprime. La cache delle immagini è solo in memoria.

Nel dettaglio, “Aggiungi una foto del luogo” seleziona un'immagine dalla libreria e la salva sul backend come copertina condivisa del posto (JPEG ridimensionato a massimo 1200 px). La foto precedente viene sostituita. La demo ha un solo profilo condiviso; non dispone di moderazione o account distinti.

API aggiunte: `GET /places/{id}/activity` (numero commenti, media, foto) e `PUT /places/{id}/photo` (foto base64). I dati sono conservati in SQLite e separati per identificativo luogo.

Il blocco “Bentornato” e le statistiche sono ora nella sezione Viaggi.

## Profilo ed editor

Il riepilogo “Bentornato, esploratore” con le statistiche è nel Profilo. “Modifica profilo” apre una pagina dedicata per nome, bio e foto; i campi lavorano su una bozza locale. Salva invia la bozza al backend e aggiorna il profilo solo dopo una risposta riuscita. Annulla chiude senza salvare. Gli errori restano nell'editor per permettere di riprovare senza perdere la bozza. È possibile sostituire o rimuovere la foto; nome e bio rispettano i limiti di 80 e 500 caratteri.

## Zoom progressivo e immagini web

La mappa cerca luoghi nell'area visibile dopo 900 ms senza cambiamenti significativi. Con zoom più ampio suddivide la ricerca in quattro sottoaree, con deduplicazione dei risultati. Le ricerche e la cache sono limitate (20 aree, 10 minuti) e le richieste obsolete vengono annullate. I risultati dipendono dalla copertura e dai limiti MapKit; non è uno scaricamento completo di tutti i POI del mondo. L'area interrogata è limitata a 2° di latitudine e 3° di longitudine attorno al centro per controllare carico e densità. I gruppi numerati si aprono con uno zoom quando toccati.

La ricerca durante zoom e spostamenti è stata autorizzata esplicitamente e può essere disattivata nel Profilo. L'area della mappa è inviata ad Apple. I risultati nell'area sono separati dal catalogo locale entro 5 km; sono commentabili anche quando lontani dall'utente.

Le copertine danno priorità alle foto della community, poi alle foto trovate su Wikimedia Commons. La ricerca invia a Wikimedia solo il nome pubblico del luogo, senza coordinate. Il backend seleziona URL HTTPS di upload.wikimedia.org con licenza libera e conserva fonte, autore e licenza. Nel dettaglio è disponibile il collegamento alla pagina della foto. Le risposte vengono memorizzate per 24 ore. La disponibilità di fotografie, soprattutto per piccoli esercizi commerciali, non è garantita: quando manca una foto viene mostrato uno stato esplicito, senza mappe o immagini AI sostitutive. Le precedenti copertine AI restano nel progetto ma non sono più usate dall'app.

## Feed e profilo in stile Instagram

Ogni post è sempre collegato a un luogo: il composer richiede foto, didascalia e luogo (scelto con ricerca tra i luoghi vicini e quelli dell'ultima area esplorata). Il backend rifiuta luoghi sconosciuti e non restituisce mai post il cui luogo non è più nel catalogo.

Il Feed mostra post a tutta larghezza: autore e luogo in alto, foto 4:5, azioni (commenta, condividi, Portami qui, salva), valutazione, didascalia espandibile, conteggio commenti e data relativa. Il doppio tocco sulla foto salva il post. Lo scorrimento carica automaticamente altri post.

Dal menu ⋯ di un tuo post puoi eliminarlo, previa conferma: il post e i suoi commenti vengono rimossi da Feed e Profilo. Le recensioni importate dai commenti dei luoghi non sono tuoi post e non sono eliminabili da qui.

In cima al Feed due schede, **Post** e **Trip**. Un *trip* è una vacanza completa raccontata come raccolta dei tuoi post: titolo, destinazione, date, racconto e almeno due post scelti dalla griglia (le date seguono i post finché non le modifichi). Nel feed appare come copertina a mosaico con giorni, post e luoghi; il dettaglio mostra la mappa del viaggio e le tappe giorno per giorno. Filtri: Seguiti, Tutti, I miei. Eliminare un trip toglie solo la raccolta, i post restano; un trip rimasto con un solo post scompare. API: `GET/POST /feed/trips`, `GET/DELETE /feed/trips/{id}`. Viaggi demo: `.venv/bin/python seed.py --trips` (non distruttivo, fa un backup).

Il Profilo mostra foto, contatori (post, viaggi, mete), bio, “Modifica profilo”, “Nuovo post” e la griglia 3 colonne dei tuoi post; toccandone uno si scorre tra tutti i tuoi post. Privacy, posizione e connessione al backend sono nell'icona ingranaggio.

API: `GET /feed/mine` (i tuoi post), `DELETE /feed/posts/{id}` (solo post propri, 403 altrimenti); `/stats` include `posts`.

## Foto automatiche da Google Immagini senza costi

`IMAGE_PROVIDER=google_auto` cerca gratuitamente su Google Immagini con nome, descrizione/indirizzo e coordinate. Non usa chiavi né API a pagamento. Assegna una foto soltanto se la pagina sorgente associa quella stessa immagine a un'entità con nome identico e coordinate entro 150 metri dal luogo. Non basta che il nome o la città compaiano da qualche parte nella pagina. Per gli omonimi o le fonti senza metadati sufficienti rimane la copertina predefinita. Il controllo riduce gli errori ma dipende dall'accuratezza dei metadati pubblicati dalla fonte.

Google può richiedere JavaScript, consenso o CAPTCHA, oppure cambiare formato: in questi casi nessuna foto viene assegnata, senza aggirare i blocchi. La ricerca non è un'API ufficiale e non garantisce disponibilità. I risultati verificati sono memorizzati per 24 ore, quelli vuoti per 15 minuti; la cache precedente di Wikimedia non viene usata. L'interfaccia mostra Google Immagini e il collegamento alla fonte, senza attribuire una licenza libera non verificata.

Il comando manuale nel dettaglio rimane disponibile. `IMAGE_PROVIDER=google_manual` disattiva l'assegnazione automatica; `IMAGE_PROVIDER=commons` ripristina la ricerca Wikimedia.

## Personalizzazione AI

Schema in `backend/models.py` (SQLAlchemy), connessione e `init_db()` in `backend/database.py`: al primo avvio `create_all` crea le tabelle mancanti senza toccare i dati esistenti e aggiunge eventuali colonne nuove.

`backend/personalization.py` impara da like (post salvati), recensioni (1★ insegna cosa non piace), commenti, post pubblicati, luoghi aperti, ricerche di persone, profili visitati, viaggi e domande in chat. Tre livelli, dal grezzo al compresso:

- `user_events`: ultime 100 azioni per utente (solo per la recency)
- `user_affinities`: punteggi per categoria, luogo, autore, meta, ricerca, con dimezzamento a 30 giorni e al massimo 40 voci per dimensione
- `user_memory`: sintesi testuale di max 700 caratteri (~175 token), l'unica cosa inviata al modello

L'onboarding (`PUT /me/preferences`) dà un avvio a caldo. `GET /me/memory` mostra cosa sa l'AI, `DELETE /me/memory` lo dimentica (le preferenze restano). La chat riceve la sintesi e i 30 luoghi più rilevanti per l'utente.

## Account

`backend/auth.py`: registrazione e login con email e password (scrypt), Accedi con Apple e Google. Ogni route tranne `/health` e `/auth/*` richiede `Authorization: Bearer <token>`; il token è opaco, dura 90 giorni e il server ne salva solo l'hash SHA-256. L'app lo conserva nel Portachiavi.

- Il primo account creato eredita il profilo precedente (id 1) con viaggi, post, salvati e memoria AI.
- Viaggi, post, salvati, statistiche, preferenze e memoria sono separati per account.
- Apple e Google verificano il token sul server con le chiavi pubbliche dei provider. Un'email verificata collega il nuovo metodo all'account esistente.
- **Google:** crea un client OAuth di tipo iOS (bundle `it.robertolibanora.roam`) nella Google Cloud Console e metti l'ID in `GOOGLE_IOS_CLIENT_ID` in `backend/.env`. Il pulsante compare senza ricompilare l'app.
- **Apple:** richiede un team Apple Developer a pagamento. Imposta `APPLE_SIGNIN_ENABLED=1` e compila con `ROAM_APPLE_SIGNIN=1 ios/install.sh`.

## Segui, Chat e ROAM

- **Segui:** dal profilo di un viaggiatore (o con “Segui” accanto al nome in un post) puoi seguirlo. Il Feed ha la scheda **Seguiti** con i post delle persone che segui e i tuoi. Profili con contatori Post / Follower / Seguiti, toccabili per vedere gli elenchi.
- **Chat in stile Instagram:** la scheda Assistente è diventata **Chat**. In cima, fissata, c’è **ROAM**, l’assistente di viaggio (la cronologia ora è salvata sul server e cancellabile). Sotto, le conversazioni con gli altri viaggiatori: anteprima, tempo trascorso, pallino non letto, badge sulla tab, “Visualizzato”, cuore con doppio tocco sui messaggi ricevuti, separatori orari. L’aeroplanino sotto un post lo invia in chat (“Portami qui” resta nel menu ⋯).
- I profili dimostrativi (autori senza account) si possono seguire e ricevere messaggi, ma non rispondono.

API: `PUT /people/follow`, `GET /people/profile?key=`, `GET /people/connections`, `GET /people/posts?key=`, `POST /feed/query` con `following_only`, `GET|POST /dm/conversations`, `GET|POST /dm/conversations/{id}/messages`, `PUT /dm/messages/{id}/liked`, `GET /dm/unread`, `DELETE /dm/roam`. Una persona è `u:<id>` (account) o `n:<nome>` (autore senza account).
