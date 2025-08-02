#!/usr/bin/env python3
import http.server
import ssl
import os

# Create HTTP server
httpd = http.server.HTTPServer(('0.0.0.0', 3000), http.server.SimpleHTTPRequestHandler)

# Change to the build/web directory for serving files
os.chdir('build/web')

# Wrap with SSL using the backend certificates
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain('../../backend/cert.pem', '../../backend/key.pem')
httpd.socket = context.wrap_socket(httpd.socket, server_side=True)

print("Serving HTTPS on port 3000...")
print("Access the app at: https://localhost:3000")
httpd.serve_forever()