const fs = require('fs');
const crypto = require('crypto');
const https = require('https');

function parseArgs(argv) {
  const out = {};
  for (let i = 2; i < argv.length; i += 1) {
    const arg = argv[i];
    if (!arg.startsWith('--')) continue;
    const key = arg.slice(2);
    const val = argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[i + 1] : '';
    out[key] = val;
    if (val) i += 1;
  }
  return out;
}

function base64url(input) {
  const buf = Buffer.isBuffer(input) ? input : Buffer.from(String(input), 'utf8');
  return buf.toString('base64').replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}

function postForm(url, formData) {
  return new Promise((resolve, reject) => {
    const body = new URLSearchParams(formData).toString();
    const req = https.request(
      url,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Content-Length': Buffer.byteLength(body)
        }
      },
      res => {
        let raw = '';
        res.on('data', chunk => {
          raw += chunk;
        });
        res.on('end', () => {
          let parsed;
          try {
            parsed = JSON.parse(raw || '{}');
          } catch (err) {
            reject(new Error(`Respuesta no JSON de OAuth: ${raw}`));
            return;
          }

          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(parsed);
            return;
          }
          reject(new Error(`OAuth error (${res.statusCode}): ${JSON.stringify(parsed)}`));
        });
      }
    );

    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

async function main() {
  const args = parseArgs(process.argv);
  const keyPath = args.keyPath;
  const scopesRaw = args.scopes || 'https://www.googleapis.com/auth/spreadsheets,https://www.googleapis.com/auth/drive';

  if (!keyPath) {
    throw new Error('Falta --keyPath');
  }

  const key = JSON.parse(fs.readFileSync(keyPath, 'utf8'));
  if (!key.client_email || !key.private_key) {
    throw new Error('El JSON de cuenta de servicio no contiene client_email/private_key');
  }

  const scopes = scopesRaw
    .split(/[,\s]+/)
    .map(s => s.trim())
    .filter(Boolean)
    .join(' ');

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: key.client_email,
    scope: scopes,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600
  };

  const encodedHeader = base64url(JSON.stringify(header));
  const encodedPayload = base64url(JSON.stringify(payload));
  const unsignedJwt = `${encodedHeader}.${encodedPayload}`;
  const signature = crypto.sign('RSA-SHA256', Buffer.from(unsignedJwt, 'utf8'), key.private_key);
  const assertion = `${unsignedJwt}.${base64url(signature)}`;

  const tokenResponse = await postForm('https://oauth2.googleapis.com/token', {
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion
  });

  if (!tokenResponse.access_token) {
    throw new Error(`No se obtuvo access_token: ${JSON.stringify(tokenResponse)}`);
  }

  process.stdout.write(String(tokenResponse.access_token));
}

main().catch(err => {
  process.stderr.write((err && err.message) ? err.message : String(err));
  process.exit(1);
});
