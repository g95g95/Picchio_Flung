import os
import re
import unittest

import server


def meta(pagina, prop):
    return re.search(rf'<meta property="{prop}" content="([^"]*)">', pagina)[1]


class AnteprimaRisultato(unittest.TestCase):
    def test_index_html_ha_i_meta_tag_sostituibili(self):
        with open(os.path.join(server.ROOT, "index.html"), encoding="utf-8") as f:
            pagina = server.pagina_risultato(f.read(), 295, 2)
        self.assertIsNotNone(pagina, "server.py non trova i meta tag Open Graph di index.html")
        self.assertTrue(meta(pagina, "og:image").endswith("/anteprime/295.jpg"))
        self.assertEqual(meta(pagina, "og:image:type"), "image/jpeg")
        self.assertEqual(meta(pagina, "og:title"), "Lentà #2 — 295 km")
        self.assertTrue(meta(pagina, "og:url").endswith("/?km=295&amp;n=2"))

    def test_parametri(self):
        casi = {
            "km=295&n=2": (295, 2),
            "km=0": (0, None),
            "km=500&fbclid=abc": (500, None),
            "": None,
            "km=7": None,
            "km=505": None,
            "km=abc": None,
            "km=295%0A": None,
            "km=295&km=300": None,
            "km=295&n=0": None,
            "km=295&n=100000": None,
            "km=295&n=%3Cscript%3E": None,
        }
        for query, atteso in casi.items():
            with self.subTest(query=query):
                self.assertEqual(server.parametri_risultato(query), atteso)


if __name__ == "__main__":
    unittest.main()
