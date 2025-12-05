#!/usr/bin/env python3
"""Simple static file server for Bomberman HTML export."""

import http.server
import socketserver
import os
import webbrowser

PORT = 3333
DIRECTORY = "bombexpert"

os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), DIRECTORY))

Handler = http.server.SimpleHTTPRequestHandler

with socketserver.TCPServer(("", PORT), Handler) as httpd:
    url = f"http://localhost:{PORT}"
    print(f"Serving at {url}")
    webbrowser.open(url)
    httpd.serve_forever()
