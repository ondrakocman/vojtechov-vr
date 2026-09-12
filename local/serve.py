#!/usr/bin/env python3
"""Minimal HTTPS static server with HTTP Range support (needed for 8K video on Quest).

Usage: serve.py [--port 8443] [--cert certs/cert.pem] [--key certs/key.pem] [--root ..]
"""
import argparse, os, ssl, sys, mimetypes, posixpath, urllib.parse
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler

mimetypes.add_type('image/webp', '.webp')
mimetypes.add_type('video/mp4', '.mp4')
mimetypes.add_type('image/svg+xml', '.svg')
mimetypes.add_type('application/javascript', '.js')

class RangeHandler(SimpleHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def end_headers(self):
        self.send_header('Accept-Ranges', 'bytes')
        self.send_header('Cache-Control', 'public, max-age=3600')
        super().end_headers()

    def send_head(self):
        path = self.translate_path(self.path)
        if os.path.isdir(path):
            if not self.path.endswith('/'):
                self.send_response(301)
                self.send_header('Location', self.path + '/')
                self.end_headers()
                return None
            index = os.path.join(path, 'index.html')
            if os.path.exists(index):
                path = index
            else:
                return self.list_directory(path)
        try:
            f = open(path, 'rb')
        except OSError:
            self.send_error(404, 'File not found')
            return None
        size = os.fstat(f.fileno()).st_size
        ctype = self.guess_type(path)
        rng = self.headers.get('Range')
        start, end = 0, size - 1
        if rng and rng.startswith('bytes='):
            spec = rng[6:].split(',')[0].strip()
            a, _, b = spec.partition('-')
            try:
                if a == '':
                    start = max(size - int(b), 0)
                else:
                    start = int(a)
                    if b:
                        end = min(int(b), size - 1)
            except ValueError:
                start, end = 0, size - 1
            if start > end or start >= size:
                self.send_response(416)
                self.send_header('Content-Range', 'bytes */%d' % size)
                self.end_headers()
                f.close()
                return None
            self.send_response(206)
            self.send_header('Content-Range', 'bytes %d-%d/%d' % (start, end, size))
        else:
            self.send_response(200)
        self.send_header('Content-Type', ctype)
        self.send_header('Content-Length', str(end - start + 1))
        self.end_headers()
        f.seek(start)
        self._range = (start, end)
        return f

    def copyfile(self, source, outputfile):
        start, end = getattr(self, '_range', (0, None))
        remaining = None if end is None else end - start + 1
        bufsize = 1024 * 256
        while remaining is None or remaining > 0:
            chunk = source.read(bufsize if remaining is None else min(bufsize, remaining))
            if not chunk:
                break
            outputfile.write(chunk)
            if remaining is not None:
                remaining -= len(chunk)

    def log_message(self, fmt, *args):
        sys.stderr.write('%s  %s\n' % (self.address_string(), fmt % args))


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser()
    ap.add_argument('--port', type=int, default=8443)
    ap.add_argument('--bind', default='0.0.0.0')
    ap.add_argument('--cert', default=os.path.join(here, 'certs', 'cert.pem'))
    ap.add_argument('--key', default=os.path.join(here, 'certs', 'key.pem'))
    ap.add_argument('--root', default=os.path.dirname(here))
    a = ap.parse_args()

    os.chdir(a.root)
    httpd = ThreadingHTTPServer((a.bind, a.port), RangeHandler)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(a.cert, a.key)
    httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)
    print('Serving %s over HTTPS on %s:%d' % (a.root, a.bind, a.port), flush=True)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass

if __name__ == '__main__':
    main()
