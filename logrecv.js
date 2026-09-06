const http = require('http');
const fs = require('fs');
const LOG = 'c:/Users/xbdki/code/chat/app_err.log';

const server = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.statusCode = 204; res.end(); return; }
  if (req.method === 'POST') {
    let body = '';
    req.on('data', (c) => (body += c));
    req.on('end', () => {
      const ts = new Date().toISOString();
      try { fs.appendFileSync(LOG, '==== ' + ts + ' ====\n' + body + '\n\n'); } catch (e) {}
      res.statusCode = 200; res.end('ok');
    });
    return;
  }
  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/plain');
  try { res.end(fs.readFileSync(LOG)); } catch (e) { res.end(''); }
});
server.listen(5300, '0.0.0.0', () => console.log('logrecv on http://0.0.0.0:5300'));
