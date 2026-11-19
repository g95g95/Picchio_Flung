"""Server del gioco Picchio Flung sulla porta 8795.

Serve solo i file pubblici del gioco elencati in PUBBLICI (niente elenchi di cartelle):
CLAUDE.md, tasks/, strumenti/, server.py e il resto del repo restano privati.
GET /healthz risponde "ok": lo usa il controllo del servizio.
GET /?km=295&n=2 risponde con index.html con i meta tag dell'anteprima del risultato.
Ascolta su 127.0.0.1: da fuori si arriva solo tramite il tunnel cloudflared.
"""
import html
import io
import os
import re
import sys
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, unquote, urljoin, urlsplit

ROOT = os.path.dirname(os.path.abspath(__file__))
# Percorsi pubblici: file esatti, o cartelle (con "/" finale) di cui si servono i file con l'estensione indicata.
PUBBLICI = {"index.html", "font.css", "config.js", "anteprima.png", "esempi/foglio-esempio.csv"}
CARTELLE_PUBBLICHE = {"dati/": ".js", "anteprime/": ".jpg"}
HOST = os.environ.get("PICCHIO_HOST", "127.0.0.1")
PORT = int(os.environ.get("PICCHIO_PORT", "8795"))


def parametri_risultato(query):
    """(km, n) dalla query del link condiviso, n None se assente; None se i parametri mancano o non sono validi."""
    q = parse_qs(query, keep_blank_values=True)
    km, n = q.get("km", []), q.get("n", [None])
    if len(km) != 1 or len(n) != 1 or not re.fullmatch(r"[0-9]{1,3}", km[0]):
        return None
    if n[0] is not None and not re.fullmatch(r"[0-9]{1,5}", n[0]):
        return None
    km, n = int(km[0]), None if n[0] is None else int(n[0])
    if km > 500 or km % 5 or (n is not None and n < 1):
        return None
    return km, n


def pagina_risultato(pagina, km, n):
    """index.html con i meta tag Open Graph del risultato; None se un meta tag atteso manca o è doppio."""
    def meta(prop):
        trovati = re.findall(rf'<meta property="{prop}" content="([^"]*)">', pagina)
        return html.unescape(trovati[0]) if len(trovati) == 1 else None

    url, immagine = meta("og:url"), meta("og:image")
    if url is None or immagine is None:
        return None
    nuovi = {
        "og:url": urljoin(url, f"?km={km}" + (f"&n={n}" if n else "")),
        "og:title": f"Lentà #{n} — {km} km" if n else f"Lentà — {km} km",
        "og:image": urljoin(immagine, f"anteprime/{km}.jpg"),
        "og:image:type": "image/jpeg",
        "og:image:width": "1200",
        "og:image:height": "630",
        "og:image:alt": f"Lentà: il percorso della spedizione, arrivata a {km} km",
    }
    for prop, valore in nuovi.items():
        pagina, quanti = re.subn(rf'(<meta property="{prop}" content=")[^"]*(">)',
                                 lambda m: m[1] + html.escape(valore) + m[2], pagina)
        if quanti != 1:
            return None
    return pagina


class Handler(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".html": "text/html; charset=utf-8",
        ".css": "text/css; charset=utf-8",
        ".js": "text/javascript; charset=utf-8",
        ".csv": "text/csv; charset=utf-8",
        ".mjs": "text/javascript; charset=utf-8",
        ".json": "application/json; charset=utf-8",
        ".svg": "image/svg+xml",
        ".jpg": "image/jpeg",
        ".wasm": "application/wasm",
    }

    def do_GET(self):
        if urlsplit(self.path).path == "/healthz":
            body = b"ok"
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)
            return
        super().do_GET()

    def send_head(self):
        url = urlsplit(self.path)
        rel = unquote(url.path).lstrip("/") or "index.html"
        parts = rel.split("/")
        ok = rel in PUBBLICI or (
            len(parts) == 2 and parts[0] + "/" in CARTELLE_PUBBLICHE
            and parts[1].endswith(CARTELLE_PUBBLICHE[parts[0] + "/"]) and not parts[1].startswith(".")
        )
        if not ok or "\\" in rel:
            self.send_error(404)
            return None
        if rel == "index.html" and (risultato := parametri_risultato(url.query)):
            return self.send_risultato(*risultato) or super().send_head()
        return super().send_head()

    def send_risultato(self, km, n):
        with open(os.path.join(self.directory, "index.html"), encoding="utf-8") as f:
            pagina = pagina_risultato(f.read(), km, n)
        if pagina is None:
            self.log_message("index.html: meta tag Open Graph attesi non trovati, anteprima del risultato non applicata")
            return None
        body = pagina.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", self.guess_type("index.html"))
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        return io.BytesIO(body)

    def list_directory(self, path):
        self.send_error(404)
        return None

    def end_headers(self):
        self.send_header("X-Content-Type-Options", "nosniff")
        if urlsplit(self.path).path != "/healthz":
            self.send_header("Cache-Control", "no-cache")
        super().end_headers()


class Server(ThreadingHTTPServer):
    daemon_threads = True


def main():
    try:
        server = Server((HOST, PORT), partial(Handler, directory=ROOT))
    except OSError as e:
        sys.exit(f"Porta {PORT} non disponibile ({e}). Il server e' forse gia' avviato.")
    print(f"Picchio Flung attivo: http://{HOST}:{PORT}/  (cartella {ROOT})", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
