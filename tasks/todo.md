# Lentà — piano di lavoro

Stato di partenza: il prototipo è stato diviso senza altre modifiche in `index.html`, `font.css`, `dati/mappa.js` (`const MAP`), `dati/banca.js` (`const QS`). `index.html` carica anche `dati/comuni-extra.js`, che il Task B crea.

Regole comuni:
- JavaScript puro, nessuna dipendenza, nessun build. Stile del codice uguale a quello esistente (compatto, pochi commenti).
- Non fare commit.
- `dati/mappa.js` e `dati/banca.js` hanno righe da 85 KB e 26 KB: non leggerle intere con Read. Usa Grep o uno script Node.
- Verifica visiva possibile: server statico (`python -m http.server` nella radice del repo) + screenshot con
  `"C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" --headless --disable-gpu --window-size=1200,900 --virtual-time-budget=6000 --screenshot=<file.png> <url>`,
  poi Read del PNG. Tieni script e screenshot fuori dal repo.

## Task A — Rinomina, fasce, percorso (solo `index.html`)

- [x] A1. Nome "Lentà" al posto di "Lontano": `<title>`, `<h1>` della home, testo di condivisione (`LENTÀ`), badge della schermata campo, prefisso di `localStorage` (`lenta:`). Sottotitolo della home: "Piceno, Fermano e Val Vibrata."
- [x] A2. Nomi delle fasce in `TIERS` e `MISS`, scritti esattamente così:
  indice 0 `ngenò`, indice 1 `Insolito` (provvisorio, l'utente non ha ancora dato il nome), indice 2 `oh...`, indice 3 `OH....`, indice 4 `Ess...`, errata `oh capo...`. I km non cambiano.
- [x] A3. Maiuscole e minuscole dei nomi di fascia devono restare come scritte: `oh...` e `OH....` devono essere distinguibili. Oggi `.stamp` ha `text-transform:uppercase` e la schermata campo usa `.toUpperCase()` sui nomi di fascia. Togli la trasformazione ovunque compare un nome di fascia.
- [x] A4. Nuovo percorso del viaggio. `STOPS`: Piazza del Popolo 0, San Francesco 1, Il Tronto 100, Lago di Pilato 400, Ghiacci del Vettore 500. Lo sprite si muove già in proporzione a km/500 lungo `JPATH`.
  Ridisegna `journeySVG()` e aggiorna `JLAB`, nello stesso stile a tratto del disegno attuale: in basso Piazza del Popolo e la chiesa di San Francesco (partenza), poi il fiume Tronto che il percorso attraversa al 20% della lunghezza, poi colline e monti senza etichetta, poi il Lago di Pilato all'80% con un chirocefalo disegnato accanto (piccolo crostaceo rosso corallo), e in cima i ghiacci del Vettore (arrivo). Ogni tappa ha un'etichetta vicino al punto del percorso che corrisponde alla sua soglia. Verifica il disegno con uno screenshot.
- [x] A5. Testi: `HOWTO` (nome del gioco, nomi delle fasce presi da `TIERS`, nuovo percorso, "60 in tutto: 33 della provincia di Ascoli, 14 del Fermano, 13 del Teramano"). Il resto del testo resta com'è. Souvenir: `lontano` → nome `Ess...`, descrizione "Trova una risposta Ess..."; `vettore` → nome "Al lago", descrizione "Arriva al Lago di Pilato (400 km)"; `perfetta` → descrizione "500 km: i ghiacci del Vettore".
- [x] A6. Le domande della banca dicono "Punta un comune": non toccarle.

## Task B — 14 comuni del Fermano sulla mappa

Crea `strumenti/aggiungi-comuni.mjs` (Node 24, usa `fetch`) e l'output `dati/comuni-extra.js`.

- [x] B1. Fonte dei confini: openpolis `geojson-italy`, per esempio
  `https://raw.githubusercontent.com/openpolis/geojson-italy/master/geojson/limits_P_109_municipalities.geojson` (FM; AP è `P_44`, TE è `P_67`). Verifica i nomi delle proprietà sul file reale.
- [x] B2. Ricava la proiezione usata dal prototipo. `MAP.ap` ha 46 comuni AP/TE con `id` (codice ISTAT a 6 cifre), `d` (path SVG), `bb` (`[minX,minY,maxX,maxY]`), `pin` (`[x,y]`). Confronta con le stesse geometrie openpolis e trova la trasformazione lon/lat → SVG (prova lineare in lon e lat, poi Mercatore se i residui non tornano). Lo script deve calcolare la trasformazione a ogni esecuzione e fermarsi con errore se il residuo massimo supera 1 unità SVG.
- [x] B3. Proietta i 14 comuni FM: Fermo, Pedaso, Porto San Giorgio, Monte San Pietrangeli, Magliano di Tenna, Montegranaro, Montegiorgio, Sant'Elpidio a Mare, Amandola, Montelparo, Santa Vittoria in Matenano, Smerillo, Montefalcone Appennino, Montefortino. La lista dei comuni è una costante in cima allo script. Errore se un nome non si trova.
- [x] B4. Coordinate arrotondate a 1 decimale, senza semplificazione ulteriore (i confini condivisi devono restare coincidenti). `bb` dal contorno. `pin` deve cadere dentro il poligono. Gestisci MultiPolygon.
- [x] B5. Output `dati/comuni-extra.js`, script classico che viene dopo `dati/mappa.js`:
  `MAP.ap.push({id,nome,d,bb,pin},…); MAP.apbb=[…];` con `apbb` = unione dei `bb` di tutti i 60 comuni. Stesso formato dei campi esistenti.
- [x] B6. Verifica: nessun `id` duplicato; tutte le coordinate dentro `0..MAP.W` × `0..MAP.H`; screenshot della home e della schermata "Impara i comuni" per controllare che i 14 comuni combacino con i vicini. La schermata "Impara" oggi va in errore al clic su un comune senza dati in `QS.comuni`: non correggerlo, lo fa il Task C.

## Task C — Lettura del foglio Google (dopo A e B)

- [x] C1. `config.js` con `const FOGLIO_URL='esempi/foglio-esempio.csv';`, caricato da `index.html` prima dello script del gioco. In produzione l'utente mette l'indirizzo gviz del foglio:
  `https://docs.google.com/spreadsheets/d/<ID>/gviz/tq?tqx=out:csv&headers=1&sheet=<scheda>` (verificato: risponde CSV con `Access-Control-Allow-Origin`, se il foglio è condiviso "chiunque abbia il link").
- [x] C2. Formato del foglio: riga di intestazione `data,n,domanda,Farflung,Elusive,Rare,Uncommon,Common` (colonne riconosciute per nome, senza distinzione maiuscole). Una riga per domanda, 5 righe per giorno. `data` in `AAAA-MM-GG` o `GG/MM/AAAA`; se è vuota vale la data della riga sopra. Ogni cella di fascia contiene comuni separati da virgola nel formato `Nome (AP)`.
- [x] C3. `esempi/foglio-esempio.csv`: le 5 domande di `esempi/spedizione-esempio.txt` con data 2026-11-19.
- [x] C4. Parser CSV con campi tra virgolette. Conversione `Nome (SIGLA)` → codice ISTAT con i nomi di `MAP.ap` (prefisso `044` = AP, `109` = FM, `067` = TE), tollerante su maiuscole, spazi e tipo di apostrofo.
- [x] C5. Un giorno è valido se ha 5 domande, ognuna con testo e almeno un comune riconosciuto. Ogni problema (nome non riconosciuto, comune in due fasce della stessa domanda, giorno incompleto) finisce in una lista di errori e in `console.warn`. Aprendo la pagina con `?verifica` la lista compare in un modal.
- [x] C6. Le domande del foglio hanno id stabile `AAAA-MM-GG/n`, vengono aggiunte a `QBY`, hanno risposte `{t}` senza `e` e senza `note`. La scheda risposta e la schermata campo non mostrano il paragrafo di spiegazione o la nota quando mancano.
- [x] C7. `startDaily(i)` aspetta il caricamento del foglio (timeout 4 s). Se il giorno `dateOf(i)` è valido nel foglio usa quelle 5 domande, altrimenti la rotazione della banca interna. Il salvataggio `day:<i>` include `qs`, e una partita iniziata riprende con le sue `qs`.
- [x] C8. Le 33 domande della banca interna valgono solo per i 46 comuni di `QS.comuni`. Quando la domanda viene dalla banca, gli altri comuni non sono selezionabili e hanno un aspetto spento. Con una domanda del foglio tutti i comuni sono selezionabili.
- [x] C9. "Impara i comuni": un comune senza dati in `QS.comuni` mostra solo il nome.
- [x] C10. Aggiorna `CLAUDE.md`: stato attuale, formato del foglio, file del progetto, decisioni aperte risolte.

## Task E — Dominio nuovo e anteprima del risultato nel link condiviso

Contesto: il sito è `https://lendane.tttai.it`. Il vecchio `lenta.tttai.it` non risolve più, quindi oggi il link condiviso e `og:image` sono rotti. L'utente vuole che il link incollato in chat mostri un'immagine del percorso (da Piazza del Popolo ai ghiacci del Vettore) con il punto raggiunto.

- [x] E1. Dominio: `SITO` e i meta `og:url`, `og:image` in `index.html` passano a `https://lendane.tttai.it`.
- [x] E2. Link condiviso: `shareText()` finisce con `${SITO}/?km=<km>` e, in modalità quotidiana, `&n=<numero spedizione>`. Il gioco ignora questi parametri all'apertura.
- [x] E3. Immagini: `strumenti/anteprime-risultato.mjs` (Node 24, nessuna dipendenza, Edge headless via CDP) genera `anteprime/<km>.jpg`, 1200x630, per ogni km multiplo di 5 da 0 a 500 (101 file). L'immagine mostra il disegno del percorso con lo sprite alla posizione dei km, il numero di km, il nome della tappa e il nome "LENTÀ". Il disegno deve venire dal codice del gioco (`journeySVG`, `journeySet`, `stopFor`), non da una copia: lo script apre il gioco da un server locale e costruisce l'immagine dentro la pagina.
- [x] E4. `server.py`: per `/` e `/index.html` con `km` valido (intero, multiplo di 5, 0..500) e `n` facoltativo (intero 1..99999) risponde con `index.html` in cui `og:image` punta a `anteprime/<km>.jpg`, e `og:image:type`, dimensioni, `og:title`, `og:url`, `og:image:alt` sono coerenti. Parametri assenti o non validi: pagina invariata. Il dominio resta scritto solo in `index.html`. La cartella `anteprime/` serve solo file `.jpg`.
- [x] E5. `CLAUDE.md`: sezioni "Pubblicazione" e "Condivisione", elenco dei file, decisione "solo frontend" (il server ora sceglie i meta tag dell'anteprima).
