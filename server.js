const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';
const PREVIEW_DIR = path.join(__dirname, 'preview');
const ADMIN_DIR = path.join(__dirname, 'admin_web');
const SUPABASE_DIR = path.join(__dirname, 'supabase');

const mimeTypes = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
};

function safePath(base, requestPath) {
  const decoded = decodeURIComponent((requestPath || '/').split('?')[0]);
  const relative = decoded === '/' ? 'index.html' : decoded.replace(/^[/\\]+/, '');
  const resolved = path.resolve(base, relative);
  return resolved === base || resolved.startsWith(`${base}${path.sep}`) ? resolved : null;
}

function send(res, status, body, type = 'text/plain; charset=utf-8') {
  res.writeHead(status, { 'Content-Type': type, 'Cache-Control': 'no-store' });
  res.end(body);
}

const server = http.createServer((req, res) => {
  let reqUrl = req.url;

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // Supabase is the only source of real data; never expose in-memory demo data.
  if (reqUrl.split('?')[0].startsWith('/api/')) {
    return send(res, 410, JSON.stringify({ error: 'Servidor de vista local: configurá Supabase para datos reales.' }), 'application/json; charset=utf-8');
  }

  // Archivos Estáticos y Web Panel Admin
  let targetDir = PREVIEW_DIR;
  if (reqUrl.startsWith('/admin')) {
    targetDir = ADMIN_DIR;
    reqUrl = reqUrl.replace('/admin', '') || '/';
  }
  if (reqUrl.startsWith('/supabase/')) {
    targetDir = SUPABASE_DIR;
    reqUrl = reqUrl.replace('/supabase', '') || '/';
  }
  if (reqUrl.split('?')[0] === '/supabase-bundle.html') {
    targetDir = path.join(__dirname, 'web');
    reqUrl = '/supabase-bundle.html';
  }

  let filePath = safePath(targetDir, reqUrl);
  if (!filePath) return send(res, 400, 'Ruta inválida');
  const extname = String(path.extname(filePath)).toLowerCase();
  const contentType = mimeTypes[extname] || 'text/html';

  fs.readFile(filePath, (error, content) => {
    if (error) {
      if (error.code === 'ENOENT' && String(req.headers.accept || '').includes('text/html')) {
        fs.readFile(safePath(targetDir, '/index.html'), (err, fallbackContent) => {
          if (err) return send(res, 404, 'No encontrado');
          res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
          res.end(fallbackContent);
        });
      } else {
        send(res, 404, 'No encontrado');
      }
    } else {
      res.writeHead(200, { 'Content-Type': contentType + '; charset=utf-8' });
      res.end(content, 'utf-8');
    }
  });
});

if (require.main === module) server.listen(PORT, HOST, () => {
  console.log(`\n=============================================================`);
  console.log(` QuiacaGo - Servidores Locales Iniciados`);
  console.log(` 📱 App Móvil (Pasajero/Conductor): http://localhost:${PORT}/`);
  console.log(` 💻 Panel Web Admin Municipal:      http://localhost:${PORT}/admin`);
  console.log(` 🌐 Red local:                      http://IP-DE-ESTA-PC:${PORT}/admin`);
  console.log(`=============================================================\n`);
});

module.exports = { server, safePath };
