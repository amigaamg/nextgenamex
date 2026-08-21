const http = require('node:http');

const enc = '10d4d852-2d3c-4d9d-9cbb-3b1818e27d42';
const pat = 'cd32446e-fb2a-46ec-8835-7c1e3a9099af';

const req = http.get(
  `http://localhost:8787/events/stream?patientId=${pat}&encounterId=${enc}`,
  (res) => {
    console.log('status:', res.statusCode);
    let got = 0;
    let buffer = '';
    res.on('data', (chunk) => {
      buffer += chunk.toString('utf8');
      got += chunk.length;
      if (got > 8000) {
        console.log('received:', got, 'bytes');
        if (buffer.includes('"type":"projection"')) {
          console.log('INITIAL FRAME OK');
        } else {
          console.log('NO initial frame; head:', buffer.slice(0, 200));
        }
        res.destroy();
        process.exit(0);
      }
    });
    res.on('end', () => {
      console.log('stream ended, received:', got, 'bytes');
      console.log(buffer.slice(0, 300));
      process.exit(0);
    });
  },
);
req.setTimeout(10000, () => {
  console.log('TIMEOUT — no data, got:', got, 'bytes');
  process.exit(1);
});