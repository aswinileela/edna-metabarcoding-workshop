#!/usr/bin/env python3
"""Render QIIME 2 visualizations (.qzv) to PNG screenshots with headless Chrome.

Usage: render_qzv_screenshots.py <qzv-or-dir> <out-dir> [width] [max-height]
The page is captured at max-height, then blank space below the content is trimmed.
Used to produce the images in docs/images/ from example_results/.
Needs google-chrome (or chromium) on PATH.
"""
import functools, http.server, pathlib, shutil, subprocess, sys, tempfile, threading, zipfile

src, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
width = sys.argv[3] if len(sys.argv) > 3 else "1200"
height = sys.argv[4] if len(sys.argv) > 4 else "3000"
chrome = shutil.which("google-chrome") or shutil.which("chromium") or shutil.which("chromium-browser")
if not chrome:
    sys.exit("Chrome/Chromium not found")
out.mkdir(parents=True, exist_ok=True)
qzvs = [src] if src.is_file() else sorted(src.rglob("*.qzv"))

with tempfile.TemporaryDirectory() as tmp:
    class Quiet(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *a, **k):
            pass
    handler = functools.partial(Quiet, directory=tmp)
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    port = srv.server_address[1]
    for q in qzvs:
        d = pathlib.Path(tmp) / q.stem
        with zipfile.ZipFile(q) as z:
            z.extractall(d)
        root = next(d.iterdir())  # <uuid>/
        png = out / f"{q.stem}.png"
        subprocess.run([chrome, "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                        f"--window-size={width},{height}", "--virtual-time-budget=8000",
                        f"--screenshot={png}", f"http://127.0.0.1:{port}/{q.stem}/{root.name}/data/index.html"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120)
        if png.exists() and shutil.which("convert"):  # trim blank space below the content
            subprocess.run(["convert", str(png), "-trim", "+repage", "-bordercolor", "white", "-border", "12", str(png)])
        print(png, png.exists())
    srv.shutdown()
