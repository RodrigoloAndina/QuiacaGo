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

// Almacenamiento en memoria para sincronización de viajes y conductores
let pendingTrips = [];
let registeredDrivers = [
  { id: 1, name: 'Carlos Mendoza', phone: '+54 3885 401234', vehicle: 'Chevrolet Corsa', plate: 'ABC 123', taxiNumber: '045', isApproved: true },
  { id: 2, name: 'Roberto Sulca', phone: '+54 3885 998877', vehicle: 'Fiat Siena', plate: 'XYZ 789', taxiNumber: '012', isApproved: true }
];

const server = http.createServer((req, res) => {
  let reqUrl = req.url;

  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, PUT, DELETE');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // API REST /api/trips
  if (reqUrl.startsWith('/api/trips')) {
    if (req.method === 'POST') {
      let body = '';
      req.on('data', chunk => body += chunk.toString());
      req.on('end', () => {
        try {
          const tripData = JSON.parse(body || '{}');
          tripData.id = 'TRIP-' + Date.now();
          tripData.status = 'requested';
          tripData.createdAt = new Date().toISOString();
          pendingTrips.push(tripData);
          
          console.log(`\n🚗 [NUEVO VIAJE SOLICITADO] ID: ${tripData.id} | Pasajero: ${tripData.passengerName || 'Pasajero'} | Tarifa: $${tripData.fareAmount || 2500}`);
          
          res.writeHead(201, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ success: true, trip: tripData }));
        } catch (e) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'JSON inválido' }));
        }
      });
      return;
    }

    if (req.method === 'GET') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ trips: pendingTrips }));
      return;
    }
  }

  // API REST /api/drivers
  if (reqUrl.startsWith('/api/drivers')) {
    if (req.method === 'POST') {
      let body = '';
      req.on('data', chunk => body += chunk.toString());
      req.on('end', () => {
        try {
          const driver = JSON.parse(body || '{}');
          driver.id = registeredDrivers.length + 1;
          registeredDrivers.push(driver);
          res.writeHead(201, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ success: true, driver }));
        } catch (e) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'JSON inválido' }));
        }
      });
      return;
    }

    if (req.method === 'GET') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ drivers: registeredDrivers }));
      return;
    }
  }

  // Archivos Estáticos y Web Panel Admin
  let targetDir = PREVIEW_DIR;
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
