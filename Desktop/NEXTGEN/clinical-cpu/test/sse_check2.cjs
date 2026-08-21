const http = require('node:http');

const fs = require('node:fs');
const enc = fs.readFileSync(process.env.TEMP + '\\enc3.txt', 'utf8').trim();
const pat = fs.readFileSync(process.env.TEMP + '\\pat3.txt', 'utf8').trim();

let got = 0;
let buffer = '';

const req = http.get(
  `http://localhost:8787/events/stream?patientId=${pat}&encounterId=${enc}`,
  (res) => {
    console.log('status:', res.statusCode);
    res.on('data', (chunk) => {
      buffer += chunk.toString('utf8');
      got += chunk.length;
      if (got > 1000) {
        console.log('received:', got, 'bytes');
        console.log('has projection frame:', buffer.includes('"type":"projection"'));
        console.log('head:', buffer.slice(0, 160));
        res.destroy();
        process.exit(0);
      }
    });
  },
);
req.setTimeout(8000, () => {
  console.log('TIMEOUT after', got, 'bytes; head:', JSON.stringify(buffer.slice(0, 120)));
  process.exit(1);
});