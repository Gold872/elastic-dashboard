import http.server
import socketserver

PORT = 4902

Handler = http.server.SimpleHTTPRequestHandler

with socketserver.ThreadingTCPServer(("", PORT), Handler) as httpd:
    print(f"Serving at port {PORT}")
    httpd.serve_forever()
