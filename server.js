const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 3000;
const PREVIEW_DIR = path.join(__dirname, 'preview');
const ADMIN_DIR = path.join(__dirname, 'admin_web');

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

const server = http.createServer((req, res) => {
  let targetDir = PREVIEW_DIR;
  let reqUrl = req.url;

  // Ruta /admin para el Panel Web Desktop Municipal
  if (reqUrl.startsWith('/admin')) {
    targetDir = ADMIN_DIR;
    reqUrl = reqUrl.replace('/admin', '') || '/';
  }

  let filePath = path.join(targetDir, reqUrl === '/' ? 'index.html' : reqUrl);
  const extname = String(path.extname(filePath)).toLowerCase();
  const contentType = mimeTypes[extname] || 'text/html';

  fs.readFile(filePath, (error, content) => {
    if (error) {
      if (error.code === 'ENOENT') {
        fs.readFile(path.join(targetDir, 'index.html'), (err, fallbackContent) => {
          res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
          res.end(fallbackContent, 'utf-8');
        });
      } else {
        res.writeHead(500);
        res.end('Server Error: ' + error.code);
      }
    } else {
      res.writeHead(200, { 'Content-Type': contentType + '; charset=utf-8' });
      res.end(content, 'utf-8');
    }
  });
});

server.listen(PORT, () => {
  console.log(`\n=============================================================`);
  console.log(` QuiacaGo - Servidores Locales Iniciados`);
  console.log(` 📱 App Móvil (Pasajero/Conductor): http://localhost:${PORT}/`);
  console.log(` 💻 Panel Web Admin Municipal:      http://localhost:${PORT}/admin`);
  console.log(`=============================================================\n`);
});
