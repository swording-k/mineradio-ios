# WebKit verification fixture; uses release bundle, production CSS/assets and a synthetic artwork only.
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlparse,unquote
ROOT=Path.cwd()
ART=b'<svg xmlns="http://www.w3.org/2000/svg" width="160" height="160" viewBox="0 0 160 160"><rect width="160" height="160" fill="#c42e6c"/><circle cx="80" cy="80" r="58" fill="#ffce88"/><circle cx="80" cy="80" r="17" fill="#400f52"/></svg>'
class Handler(SimpleHTTPRequestHandler):
 def __init__(self,*a,**kw): super().__init__(*a,directory=str(ROOT/'public'),**kw)
 def do_GET(self):
  path=urlparse(self.path).path
  if path=='/fixture.wav':
   import io,wave,math,struct
   buf=io.BytesIO()
   with wave.open(buf,'wb') as wav:
    wav.setparams((1,2,22050,0,'NONE','not compressed'))
    wav.writeframes(b''.join(struct.pack('<h',int(3000*math.sin(2*math.pi*220*n/22050))) for n in range(22050*12)))
   data=buf.getvalue();mime='audio/wav'
  elif path=='/apple-navigation.css': data=(ROOT/'apps/apple/Web/apple-navigation.css').read_bytes();mime='text/css'
  elif path=='/js/index-loader.js': data=(ROOT/'apps/apple/GeneratedWeb/index-modules.js').read_bytes(); mime='application/javascript'
  elif path=='/' or path=='/index.html':
   import re
   data=re.sub(r'<link\s+href="https://fonts.googleapis.com/[^>]+>','',(ROOT/'public/index.html').read_text()).encode();mime='text/html;charset=utf-8'
  elif path.startswith('/api/apple-music-art/') or path=='/api/cover':data=ART;mime='image/svg+xml'
  elif path.startswith('/api/'):data=b'{"ok":true,"loggedIn":false,"songs":[],"tracks":[],"playlists":[],"items":[]}';mime='application/json'
  else:return super().do_GET()
  self.send_response(200);self.send_header('Content-Type',mime);self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
 def log_message(self,*a):pass
http=ThreadingHTTPServer(('127.0.0.1',0),Handler)
print(http.server_port,flush=True);http.serve_forever()
