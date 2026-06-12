import http from 'node:http';

const port = Number(process.env.PORT || 9082);

const names = new Map([
  ['2769200001', 'Carol Lee'],
  ['2769100001', 'Wallet1 User'],
]);

function readJson(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', chunk => {
      data += chunk;
    });
    req.on('end', () => {
      if (!data) return resolve({});
      try {
        resolve(JSON.parse(data));
      } catch (err) {
        reject(err);
      }
    });
  });
}

function send(res, status, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(status, {
    'content-type': 'application/json',
    'content-length': Buffer.byteLength(body),
  });
  res.end(body);
}

const server = http.createServer(async (req, res) => {
  try {
    const body = await readJson(req);
    console.log(`${new Date().toISOString()} ${req.method} ${req.url}`, body);

    if (req.method === 'POST' && req.url === '/auth/token') {
      return send(res, 200, {
        code: 200,
        token_type: 'Bearer',
        access_token: 'local-bigbank-token',
        expires_in: 3600,
      });
    }

    if (req.method === 'POST' && req.url === '/payee/lookup') {
      const account = String(body.numerocompte || '');
      return send(res, 200, {
        code: 200,
        numerocompte: account,
        codeabonne: account,
        nom: names.get(account) || `BigBank ${account}`,
        devise: 'USD',
        status: 'ACTIVE',
        etatcompte: 'ACTIF',
        etatabonne: 'ACTIF',
      });
    }

    if (req.method === 'POST' && req.url === '/fees/calculate') {
      const amount = Number(body.amount || 0);
      const currency = body.currency || 'USD';
      return send(res, 200, {
        feeCalculationResultData: {
          transactionCurrency: currency,
          transactionAmount: amount,
          feeCurrency: currency,
          totalFeeAmount: 0.1,
          feeSplits: {
            payerFeeCatalyst: { currency, amount: 0.1 },
            payeeFeeCatalyst: { currency, amount: 0 },
            schemeFeeCatalyst: { currency, amount: 0 },
          },
          feePolicy: {
            feePolicyId: 'local-mock',
            scenario: body.scenario || 'PERSON_TO_PERSON',
            transactionCurrency: currency,
            splits: {},
            formula: [],
          },
        },
      });
    }

    if (req.method === 'POST' && req.url === '/payee/quote') {
      const amount = Number(body.montant || 0);
      return send(res, 200, {
        code: 200,
        quote_id: `BBQ-${Date.now()}`,
        numerocompte: body.numerocompte,
        montant: amount,
        devise: body.devise || 'USD',
        fees: 0,
        total: amount,
      });
    }

    if (req.method === 'POST' && req.url === '/payee/prevalidate') {
      return send(res, 200, {
        code: 200,
        prevalidated: true,
        numerocompte: body.numerocompte,
        montant: Number(body.montant || 0),
      });
    }

    if (req.method === 'POST' && req.url === '/payee/transfer') {
      return send(res, 200, {
        code: 200,
        end_to_end_id: body.end_to_end_id,
        status: 'success',
        error_code: '',
        error_message: '',
        core_ref: `BB-${body.end_to_end_id}`,
        numerocompte: body.numerocompte,
        montant: Number(body.montant || 0),
        devise: body.devise || 'USD',
        fees: 0,
        total: Number(body.montant || 0),
      });
    }

    send(res, 404, { error: 'not_found' });
  } catch (err) {
    console.error(err);
    send(res, 500, { error: String(err.message || err) });
  }
});

server.listen(port, '127.0.0.1', () => {
  console.log(`pivotal BigBank mock listening on http://127.0.0.1:${port}`);
});
