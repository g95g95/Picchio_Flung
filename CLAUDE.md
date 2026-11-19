# Lentà

Gioco quotidiano di geografia sul Piceno, il Fermano e la Val Vibrata.
"Lentà" significa "lontano" in dialetto ascolano.
Il repo si chiama `Picchio_Flung`. Il nome pubblico del gioco è solo "Lentà".

Le regole generali di lavoro sono in `C:\Users\pisel\.claude\CLAUDE.md`. Questo file contiene solo i fatti del progetto.

## Decisioni prese

- Il gioco è solo frontend. Non esiste backend, non esistono script lato server, non esistono account.
- L'hosting è un PC Windows 11 di casa (homeserver) che serve file statici.
- Un foglio Google contiene, per ogni giorno, le 5 domande con i comuni validi.
- Il browser legge il foglio direttamente.
- L'utente assegna a mano la fascia di ogni comune nel foglio. Nessuna regola automatica.
- Le domande usano comuni di tre province: Ascoli Piceno (AP), Fermo (FM), Teramo (TE).
- Per ora la mappa non include tutta la provincia di Fermo. Include solo i 14 comuni FM elencati sotto.
- Lingua dell'interfaccia: italiano. I nomi delle fasce sono in dialetto ascolano.

## Fasce

Scrivi i nomi mostrati esattamente come in tabella, con la stessa punteggiatura.

| Etichetta nel foglio | Indice `t` | Nome mostrato | km |
|---|---|---|---|
| Common | 0 | ngenò | 40 |
| Uncommon | 1 | da definire | 55 |
| Rare | 2 | oh... | 70 |
| Elusive | 3 | OH.... | 85 |
| Farflung | 4 | Ess... | 100 |
| risposta errata (Miss) | -1 | oh capo... | 0 |

I km sono quelli del prototipo. L'utente non li ha cambiati.

## Contenuto di una spedizione nel foglio

Una spedizione ha 5 domande. Ogni domanda ha:

- un numero da 1 a 5;
- il testo della domanda;
- per ogni fascia, la lista dei comuni validi. Ogni comune ha la sigla della provincia: `Nome (AP)`, `Nome (FM)`, `Nome (TE)`.

Esempio di una domanda:

```
3.Seleziona un comune il cui territorio è attraversato dal fiume Tronto
Farflung: Sant'Egidio alla Vibrata (TE)
Elusive: Maltignano (AP)
Rare: Monsampolo del Tronto (AP), Controguerra (TE), Ancarano (TE)
Uncommon: Monteprandone (AP), Spinetoli (AP), Colli del Tronto (AP), Martinsicuro (TE), Colonnella (TE), Acquasanta Terme (AP), Arquata del Tronto (AP)
Common: Ascoli Piceno (AP), San Benedetto del Tronto (AP)
```

- Una spedizione completa di esempio è in `esempi/spedizione-esempio.txt`. È il testo dell'utente con due correzioni confermate: Carassai è AP, e il nome corretto è "Montefalcone Appennino".
- Una fascia può avere più comuni. Il numero di comuni per fascia non è fisso.
- Il foglio identifica i comuni per nome, non per codice ISTAT. Il codice deve convertire nome + sigla in codice ISTAT.
- Il foglio non contiene spiegazioni per comune né note per domanda. Il prototipo le mostra (`a.e`, `q.note`). Il codice deve funzionare senza.
- Un nome che non corrisponde a un comune della mappa è un errore di dati. Segnalalo. Non scartarlo in silenzio.

## Stato attuale

- Il prototipo è un solo file HTML, `lontano.html` (303 KB). Non è ancora nel repo.
- Il prototipo usa ancora il nome "Lontano" in: `<title>`, titolo in home, testo di condivisione, prefisso `lontano:` di `localStorage`, fascia più alta, souvenir "Lontano!".
- Il prototipo usa i nomi di fascia Banale, Insolito, Raro, Introvabile, Lontano, Mancato. Vanno sostituiti con la tabella sopra.
- Il prototipo non legge alcun foglio. Sceglie 5 domande da una banca interna di 33, con una rotazione automatica.
- La mappa del prototipo ha 46 comuni giocabili: 33 AP (codici ISTAT `044…`) e 13 TE (`067…`). Non ha comuni FM.
- Non esistono build, dipendenze, test o comandi. Il codice è JavaScript puro in un tag `<script>`.

## Regole di gioco

- Per ogni domanda il giocatore punta un comune sulla mappa e conferma.
- Un comune valido dà i km della sua fascia. Un comune non valido dà 0 km.
- Il massimo è 500 km.
- Tappe del viaggio: Campo base 0, Il Tronto 1, Le Colline 100, La Laga 200, I Sibillini 300, Il Vettore 400.
- Modalità del prototipo: quotidiana, archivio dei giorni passati, illimitata (5 domande casuali), "Impara i comuni".
- La spedizione #1 è il 18 novembre 2026 (`EPOCH`). Il giorno cambia alla mezzanotte del dispositivo.

## Dati incorporati nel prototipo

- `MAP`: `W`, `H`, `ap` (46 comuni: `id`, `nome`, `d`, `bb`, `pin`), `bg` (373 tracciati di sfondo), `sea`, `apbb`.
- `QS.comuni`: per codice ISTAT, `nome`, `pop`, `km2`, `alt`.
- `QS.domande`: 33 domande. Ogni domanda ha `id`, `q` (testo), `note`, `a`.
- `a` è una mappa codice ISTAT → `{t, e}`. `t` è la fascia 0-4. `e` è la spiegazione mostrata dopo la risposta.
- L'id di un comune è sempre il codice ISTAT a 6 cifre, come stringa.
- I font (Courier Prime, Special Elite, Bowlby One SC) sono in base64 dentro il CSS.

## Stato nel browser (`localStorage`)

- `day:<indice>` → `{res, km}`. Ogni elemento di `res` è `{q, c, t}`: id domanda, id comune, fascia (-1 se errata).
- `stats` → `{passport, souv, last, streak, best}`.
- `muted` → booleano.

## Vincoli da rispettare

- I tracciati `MAP.bg` hanno solo la forma (`d`). Non hanno nome né codice. I comuni FM non si possono rendere giocabili con i dati attuali: servono nuovi confini.
- I 14 comuni FM da aggiungere sono: Fermo, Pedaso, Porto San Giorgio, Monte San Pietrangeli, Magliano di Tenna, Montegranaro, Montegiorgio, Sant'Elpidio a Mare, Amandola, Montelparo, Santa Vittoria in Matenano, Smerillo, Montefalcone Appennino, Montefortino.
- Con questi comuni la mappa avrà 60 comuni giocabili: 33 AP, 13 TE, 14 FM.
- I risultati salvati contengono gli id delle domande. Archivio e schermata "campo" funzionano solo se i dati dei giorni passati restano leggibili.
- Il souvenir "Lupo di mare" legge `QBY.mare`. Si rompe se la domanda con id `mare` non esiste.
- Il testo "Come si gioca" contiene numeri, nomi di fascia e fonti scritti a mano. Aggiornalo quando cambiano i dati.
- La mappa mostra l'attribuzione "Confini © ISTAT / openpolis". Non rimuoverla.
- Tutte le risposte sono leggibili nel browser. Con un gioco solo frontend non si possono nascondere.
- Il browser legge il foglio direttamente. Chi conosce l'indirizzo del foglio può leggere anche i giorni futuri.
- Non mettere chiavi API o credenziali nel codice o nel repo.

## Fonti dei dati del prototipo

- Confini: ISTAT / openpolis.
- Popolazione, superficie, altitudine: ISTAT al 1/1/2026.
- Zone climatiche: DPR 412/1993.
- Bandiere Arancioni TCI 2025, Bandiere Blu FEE 2026, club "I Borghi più belli d'Italia".

## Decisioni aperte

Chiedi all'utente prima di implementare la parte collegata. Non scegliere una risposta plausibile.

1. Nome mostrato per la fascia Uncommon.
2. Fonte dei confini per i 14 comuni FM. Devono avere la stessa proiezione e scala di `MAP.ap`.
3. Disposizione del foglio: righe, colonne, formato della data. Il contenuto è definito sopra.
4. Metodo di lettura del foglio dal browser (foglio pubblicato come CSV o altro). Verifica la documentazione Google e il comportamento CORS prima di scegliere.
5. Comportamento se un giorno manca nel foglio o una riga non è valida.
6. Destino della banca interna di 33 domande e origine delle domande nella modalità illimitata.
7. Dati di "Impara i comuni" (popolazione, superficie, altitudine) per i comuni nuovi.
8. Web server sul PC Windows 11, dominio, HTTPS, metodo di deploy.
9. Giorno calcolato con l'orologio del dispositivo o con l'ora italiana.
10. Struttura dei file: file unico o `index.html` + CSS + JS + dati + font separati.
11. Nuovo nome del souvenir "Lontano!".
12. Esistenza degli script che hanno generato `MAP` e `QS`. Oggi l'HTML è l'unica fonte nota.
