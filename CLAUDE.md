# Lentà

Gioco quotidiano di geografia sul Piceno, il Fermano e la Val Vibrata.
"Lentà" significa "lontano" in dialetto ascolano.
Il repo si chiama `Picchio_Flung`. Il nome pubblico del gioco è solo "Lentà".

Le regole generali di lavoro sono in `C:\Users\pisel\.claude\CLAUDE.md`. Questo file contiene solo i fatti del progetto.

## Decisioni prese

- Il gioco è solo frontend. Non esistono account. Il server non riceve né salva dati dei giocatori.
- `server.py` serve file statici. L'unica eccezione: sceglie i meta tag dell'anteprima del link in base a `km` e `n`. Vedi "Condivisione".
- L'hosting è un PC Windows 11 di casa (homeserver) che serve file statici. Vedi "Pubblicazione".
- Un foglio Google contiene, per ogni giorno, le 5 domande con i comuni validi.
- Il browser legge il foglio direttamente, come CSV dall'indirizzo gviz. Vedi "Foglio Google".
- L'utente assegna a mano la fascia di ogni comune nel foglio. Nessuna regola automatica.
- Le domande usano comuni di tre province: Ascoli Piceno (AP), Fermo (FM), Teramo (TE).
- La mappa include tutti i 40 comuni della provincia di Fermo.
- I confini dei comuni FM vengono da openpolis `geojson-italy`, con la stessa proiezione di `dati/mappa.js`.
- La banca interna di 33 domande resta. Vale per i giorni che il foglio non contiene e per la modalità illimitata.
- Lingua dell'interfaccia: italiano. I nomi delle fasce sono in dialetto ascolano.

## File del progetto

- `index.html`: HTML, CSS e codice del gioco (ultimo `<script>`).
- `font.css`: i font (Courier Prime, Special Elite, Bowlby One SC) in base64.
- `config.js`: `FOGLIO_URL`, l'indirizzo gviz del foglio Google di produzione (ID `1YAElF7vVaW4vuYidjoyHX77r3uYjYv_6I5LuK3XZ4Pg`, prima scheda). Per provare senza foglio si può puntare a `esempi/foglio-esempio.csv`.
- `dati/mappa.js`: `const MAP` con i 46 comuni AP/TE e lo sfondo.
- `dati/comuni-extra.js`: aggiunge a `MAP.ap` i 40 comuni FM e ricalcola `MAP.apbb`. È generato: non modificarlo a mano.
- `dati/banca.js`: `const QS` con i dati dei comuni e la banca interna di domande.
- `strumenti/aggiungi-comuni.mjs`: genera `dati/comuni-extra.js`.
- `anteprima.png`: immagine 1200x630 dell'anteprima del link nei messaggi. La genera `strumenti/anteprima.html` (comando nel file).
- `anteprime/<km>.jpg`: 101 immagini 1200x630 dell'anteprima del link con il risultato, una per ogni multiplo di 5 da 0 a 500. Le genera `strumenti/anteprime-risultato.mjs`.
- `esempi/spedizione-esempio.txt`: una spedizione nel testo originale dell'utente, con due correzioni confermate. Carassai è AP. Il nome corretto è "Montefalcone Appennino".
- `esempi/foglio-esempio.csv`: la stessa spedizione nel formato del foglio, data 2026-11-19. Si può importare in Google Sheets.
- `index.html` carica gli script in questo ordine: `dati/mappa.js`, `dati/comuni-extra.js`, `dati/banca.js`, `config.js`, gioco.
- `dati/mappa.js` e `dati/banca.js` hanno righe molto lunghe. Leggili con uno script, non con un editor.
- Gli script che hanno generato `dati/mappa.js` e `dati/banca.js` non sono nel repo.
- Non esistono build né dipendenze. Il codice è JavaScript puro.
- `tests/test_server.py` controlla solo `server.py`. Comando dalla radice: `python -m unittest discover tests`.
- `server.py`, `RIAVVIA.bat`, `FERMA.bat`, `INSTALLA.bat`, `servizio/`: il servizio Windows che pubblica il gioco. Vedi "Pubblicazione".

## Pubblicazione

- `server.py` (Python 3.12, solo libreria standard) serve il gioco su `127.0.0.1:8795`. `GET /healthz` risponde `ok`.
- `server.py` serve solo i file in `PUBBLICI`, i `.js` di `dati/` e i `.jpg` di `anteprime/`. Tutto il resto del repo risponde 404.
- Un nuovo file pubblico (immagine, suono, altro script) va aggiunto a `PUBBLICI` o `CARTELLE_PUBBLICHE`, altrimenti risponde 404.
- Indirizzo pubblico: `https://lendane.tttai.it`. Da Internet si arriva solo tramite il tunnel cloudflared del PC, che punta a `http://127.0.0.1:8795`.
- Il gioco si apre senza login di Cloudflare Access. Anche i lettori delle anteprime (WhatsApp, Telegram) ricevono la pagina.
- Il vecchio indirizzo `lenta.tttai.it` non risolve più.
- Il server gira come attività pianificata `PicchioFlung` con l'account dedicato `picchioflung-svc`, che può scrivere solo in `logs/`.
- `INSTALLA.bat` installa il servizio. `RIAVVIA.bat` fa `git pull --ff-only` e riavvia. `FERMA.bat` ferma. La configurazione è `servizio/servizio.json`.
- A ogni push su `main` AutoDeploy lancia `RIAVVIA.bat` nella copia `C:\Users\Giulio\Desktop\Guloi\Picchio_Flung`. Quella copia deve restare sul branch `main`.
- Log: `logs/server.log`.

## Condivisione

- Il testo condiviso finisce con il link del risultato: `https://lendane.tttai.it/?km=295&n=2`.
- `n` è il numero della spedizione. C'è solo in modalità quotidiana e archivio. In modalità illimitata il link ha solo `km`.
- L'indirizzo base è `SITO`, costante in `index.html`. Il gioco ignora `km` e `n` all'apertura.
- Sul telefono il bottone Condividi apre il foglio di condivisione del sistema (`navigator.share`). Sul computer copia il testo negli appunti.
- I meta tag Open Graph in `<head>` danno l'anteprima del link: titolo, descrizione, `anteprima.png`. `og:url` e `og:image` hanno l'indirizzo completo.
- WhatsApp e Telegram leggono i meta tag dall'HTML. Non eseguono JavaScript.
- Con `km` valido `server.py` risponde con `index.html` con questi meta tag cambiati: `og:url`, `og:title`, `og:image`, `og:image:type`, `og:image:width`, `og:image:height`, `og:image:alt`.
- `og:image` diventa `anteprime/<km>.jpg`. `og:title` diventa `Lentà #2 — 295 km`, o `Lentà — 295 km` senza `n`. `og:description` non cambia.
- `km` valido: da 1 a 3 cifre, multiplo di 5, da 0 a 500. `n` valido: da 1 a 5 cifre, da 1 a 99999. Gli altri parametri sono ignorati.
- Con `km` o `n` non validi `server.py` risponde con `index.html` invariato.
- `server.py` ricava gli indirizzi dai meta tag `og:url` e `og:image` di `index.html`. Il dominio è scritto solo in `index.html`.
- Se un meta tag atteso manca o è doppio, `server.py` risponde con `index.html` invariato e scrive una riga nel log. Il test `tests/test_server.py` lo controlla.
- Se cambia il dominio vanno aggiornati `SITO` e i meta tag `og:url` e `og:image`.
- WhatsApp e Telegram tengono in cache l'anteprima di un link per giorni.

### Rigenerare `anteprime/`

- Comando: `node strumenti/anteprime-risultato.mjs` dalla radice del repo. Servono Node 24, Python ed Edge.
- Rigenera le immagini quando cambiano il disegno del percorso (`journeySVG`, `JPATH`, `JLAB`) o `STOPS`.
- Lo script avvia `server.py` su una porta libera e apre il gioco in Edge headless.
- Lo script disegna l'immagine dentro la pagina con `journeySVG`, `journeySet` e `stopFor` del gioco.
- Lo script ferma Edge e il server alla fine, anche dopo un errore.
- Ogni immagine deve restare sotto 100 KB. Lo script si ferma con un errore se un file la supera.

### Rigenerare `dati/comuni-extra.js`

- Comando: `node strumenti/aggiungi-comuni.mjs` dalla radice del repo. Serve Node 24 e la rete.
- La lista dei comuni da aggiungere è la costante `COMUNI` in cima allo script.
- Lo script scarica i confini openpolis delle tre province.
- Lo script ricava la proiezione dai 46 comuni di `dati/mappa.js` a ogni esecuzione.
- Lo script si ferma con un errore se il residuo massimo supera 1 unità SVG o se un nome non esiste.

## Fasce

Scrivi i nomi mostrati esattamente come in tabella, con la stessa punteggiatura e le stesse maiuscole.

| Colonna nel foglio | Indice `t` | Nome mostrato | km |
|---|---|---|---|
| Common | 0 | ngenò | 40 |
| Rare | 1 | oh... | 70 |
| Elusive | 2 | OH.... | 85 |
| Farflung | 3 | Ess... | 100 |
| risposta errata (Miss) | -1 | oh capo... | 0 |

- Le fasce sono 4. La fascia Uncommon non esiste.
- I nomi sono in `TIERS` e `MISS`. I km sono quelli del prototipo.
- Nessun CSS e nessun codice cambia maiuscole e minuscole dei nomi di fascia.

## Contenuto di una spedizione

Una spedizione ha 5 domande. Ogni domanda ha:

- un numero da 1 a 5;
- il testo della domanda;
- per ogni fascia, la lista dei comuni validi. Ogni comune ha la sigla della provincia: `Nome (AP)`, `Nome (FM)`, `Nome (TE)`.

- Una fascia può avere più comuni. Il numero di comuni per fascia non è fisso.
- Il foglio identifica i comuni per nome, non per codice ISTAT.
- Il foglio non contiene spiegazioni per comune né note per domanda.
- Un nome che non corrisponde a un comune della mappa è un errore di dati. Il gioco lo segnala.

## Foglio Google

- Indirizzo da mettere in `config.js`: `https://docs.google.com/spreadsheets/d/<ID>/gviz/tq?tqx=out:csv&headers=1&sheet=<scheda>`.
- Il foglio deve essere condiviso con "chiunque abbia il link". Così l'indirizzo gviz risponde con CSV e con `Access-Control-Allow-Origin`.
- Riga di intestazione: `data,n,domanda,Farflung,Elusive,Rare,Common`.
- Il gioco riconosce le colonne per nome, senza distinzione tra maiuscole e minuscole. L'ordine delle colonne è libero.
- La colonna `n` è facoltativa. Ordina le domande del giorno. Senza `n` vale l'ordine delle righe.
- Una riga per domanda. 5 righe per giorno.
- `data` è in formato `AAAA-MM-GG` o `GG/MM/AAAA`. Se la cella è vuota vale la data della riga sopra.
- Il valore della cella `data` mostrato nel foglio deve avere uno di questi due formati.
- Ogni cella di fascia contiene comuni separati da virgola, nel formato `Nome (SIGLA)`.
- Il confronto dei nomi ignora maiuscole, spazi in più e tipo di apostrofo.
- Il codice ISTAT viene dai nomi di `MAP.ap`: prefisso `044` = AP, `109` = FM, `067` = TE.
- Un giorno è valido se ha 5 domande, ognuna con testo e almeno un comune riconosciuto.
- Errori segnalati: colonne mancanti, data non valida, nome non riconosciuto, comune in due fasce della stessa domanda, giorno senza 5 domande, domanda senza testo o senza comuni.
- Un comune in due fasce resta nella prima fascia letta, nell'ordine Farflung → Common.
- Gli errori vanno in `console.warn`. Il giocatore non vede messaggi.
- Aprendo la pagina con `?verifica` un modal mostra la fonte, i giorni validi e gli errori.
- Le domande del foglio hanno id `AAAA-MM-GG/n` (n = posizione da 1 a 5) e vanno in `QBY`. Le risposte sono `{t}`, senza `e`. Le domande non hanno `note`.
- Il gioco legge il foglio una volta all'apertura della pagina, con un limite di 4 secondi.

## Scelta delle domande del giorno

- La chiave del giorno è la data locale di `dateOf(i)` in formato `AAAA-MM-GG`.
- Se il foglio ha quel giorno valido, il gioco usa le sue 5 domande.
- Altrimenti il gioco usa la rotazione della banca interna (`dailyQuestions(i)`). Vale anche per foglio irraggiungibile o lento.
- Una partita iniziata riprende con le domande salvate in `qs`, anche se nel frattempo il foglio è cambiato.
- Se le domande salvate di un giorno del foglio non sono più disponibili, il gioco torna alla home con un avviso.
- La modalità illimitata usa solo la banca interna (`randomQuestions`).

## Regola dei 46 comuni

- Le 33 domande della banca interna valgono solo per i 46 comuni di `QS.comuni` (33 AP, 13 TE).
- Con una domanda della banca i 40 comuni FM restano disegnati ma sono spenti e non selezionabili.
- Con una domanda del foglio tutti gli 86 comuni sono selezionabili.
- La regola vale solo per la mappa della partita. Home, campo e "Impara i comuni" mostrano tutti i comuni normali.
- In "Impara i comuni" un comune senza dati in `QS.comuni` mostra solo il nome.

## Regole di gioco

- Per ogni domanda il giocatore punta un comune sulla mappa e conferma.
- Un comune valido dà i km della sua fascia. Un comune non valido dà 0 km.
- Il massimo è 500 km.
- I km spostano uno sprite lungo un percorso disegnato (pannello "journey").
- Modalità: quotidiana, archivio dei giorni passati, illimitata (5 domande casuali), "Impara i comuni".
- La spedizione #1 è il 18 novembre 2026 (`EPOCH`). Il giorno cambia alla mezzanotte del dispositivo.
- La scheda risposta e la schermata campo omettono la spiegazione e la nota quando mancano.

## Percorso del viaggio

| Tappa | km |
|---|---|
| Piazza del Popolo | 0 |
| San Francesco | 1 |
| Il Tronto | 100 |
| Lago di Pilato | 400 |
| Ghiacci del Vettore | 500 |

- Le tappe sono in `STOPS`. Il tracciato è `JPATH`, le etichette sono `JLAB`, il disegno è `journeySVG()`.
- Lo sprite si muove in proporzione a km/500 lungo `JPATH`.
- Il disegno ha il fiume Tronto al 20% del tracciato e il Lago di Pilato con il chirocefalo all'80%.
- Il nome della tappa compare anche nell'intestazione, nel testo di condivisione e nel testo "Come si gioca".

## Dati

- `MAP`: `W`, `H`, `ap` (86 comuni: `id`, `nome`, `d`, `bb`, `pin`), `bg` (373 tracciati di sfondo), `sea`, `apbb`.
- `QS.comuni`: per codice ISTAT, `nome`, `pop`, `km2`, `alt`. Contiene solo i 46 comuni AP/TE.
- `QS.domande`: 33 domande. Ogni domanda ha `id`, `q` (testo), `note`, `a`.
- `a` è una mappa codice ISTAT → `{t, e}`. `e` è la spiegazione mostrata dopo la risposta.
- Nel file `t` è ancora la fascia 0-4 del vecchio schema a 5 fasce. Il gioco la rimappa al caricamento, subito dopo `QBY`: 0→0, 1→1, 2→1, 3→2, 4→3.
- Gli ex Uncommon della banca (vecchio `t` 1) diventano Rare.
- L'id di un comune è sempre il codice ISTAT a 6 cifre, come stringa.

## Stato nel browser (`localStorage`)

Tutte le chiavi hanno il prefisso `lenta:`.

- `day:<indice>` → `{res, km, qs}`. Ogni elemento di `res` è `{q, c, t}`: id domanda, id comune, fascia (-1 se errata). `qs` sono gli id delle 5 domande.
- Un `day:<indice>` senza `qs` è un salvataggio vecchio. Il gioco lo riapre con la banca interna.
- `stats` → `{passport, souv, last, streak, best}`.
- `muted` → booleano.

## Vincoli da rispettare

- I tracciati `MAP.bg` hanno solo la forma (`d`). Non hanno nome né codice.
- I comuni FM sulla mappa sono tutti i 40 della provincia di Fermo, elencati in `COMUNI` in `strumenti/aggiungi-comuni.mjs`.
- La mappa ha 86 comuni giocabili: 33 AP, 13 TE, 40 FM.
- I risultati salvati contengono gli id delle domande. L'archivio riapre un giorno del foglio solo se il foglio contiene ancora quel giorno.
- Il souvenir "Lupo di mare" legge `QBY.mare`. Si rompe se la domanda con id `mare` sparisce dalla banca.
- Il testo "Come si gioca" (`HOWTO`) contiene numeri e fonti scritti a mano. Aggiornalo quando cambiano i dati.
- La mappa mostra l'attribuzione "Confini © ISTAT / openpolis". Non rimuoverla.
- Tutte le risposte sono leggibili nel browser. Con un gioco solo frontend non si possono nascondere.
- Chi conosce l'indirizzo del foglio può leggere anche i giorni futuri.
- Non mettere chiavi API o credenziali nel codice o nel repo.

## Fonti dei dati

- Confini: ISTAT / openpolis.
- Popolazione, superficie, altitudine: ISTAT al 1/1/2026.
- Zone climatiche: DPR 412/1993.
- Bandiere Arancioni TCI 2025, Bandiere Blu FEE 2026, club "I Borghi più belli d'Italia".

## Decisioni aperte

Chiedi all'utente prima di implementare la parte collegata. Non scegliere una risposta plausibile.

1. Giorno calcolato con l'orologio del dispositivo o con l'ora italiana.
2. Dati di "Impara i comuni" (popolazione, superficie, altitudine) per i 40 comuni FM.
3. Etichette del percorso illeggibili su schermo stretto.
