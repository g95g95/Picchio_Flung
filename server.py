"""Server del gioco Picchio Flung sulla porta 8795.

Serve solo i file pubblici del gioco elencati in PUBBLICI (niente elenchi di cartelle):
CLAUDE.md, tasks/, strumenti/, server.py e il resto del repo restano privati.
GET /healthz risponde "ok": lo usa il controllo del servizio.
Ascolta su 127.0.0.1: da fuori si arriva solo tramite il tunnel cloudflared.
"""
import os
import sys
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote, urlsplit

ROOT = os.path.dirname(os.path.abspath(__file__))
# Percorsi pubblici: file esatti, o cartelle (con "/" finale) di cui si servono i file .js.
PUBBLICI = {"index.html", "font.css", "config.js", "anteprima.png", "esempi/foglio-esempio.csv"}
CARTELLE_PUBBLICHE = {"dati/"}
HOST = os.environ.get("PICCHIO_HOST", "127.0.0.1")
PORT = int(os.environ.get("PICCHIO_PORT", "8795"))


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
        rel = unquote(urlsplit(self.path).path).lstrip("/") or "index.html"
        parts = rel.split("/")
        ok = rel in PUBBLICI or (
            len(parts) == 2 and parts[0] + "/" in CARTELLE_PUBBLICHE
            and parts[1].endswith(".js") and not parts[1].startswith(".")
        )
        if not ok or "\\" in rel:
            self.send_error(404)
            return None
        return super().send_head()

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
