import http from 'node:http';
import { URL } from 'node:url';

const port = Number(process.env.PORT ?? 3000);
const walletLabel = process.env.WALLET_LABEL ?? 'wallet';
const partyId = process.env.PARTY_ID ?? '';
const displayName = process.env.DISPLAY_NAME ?? walletLabel;
const firstName = process.env.FIRST_NAME ?? walletLabel;
const lastName = process.env.LAST_NAME ?? 'User';
const supportedCurrencies = (process.env.SUPPORTED_CURRENCIES ?? 'USD')
  .split(',')
  .map((value) => value.trim())
  .filter(Boolean);
const feeAmount = Number(process.env.FEE_AMOUNT ?? '0');
const ledgerId = Number(process.env.LEDGER_ID ?? '1000');
const walletId = Number(process.env.WALLET_ID ?? '2000');
let transactionCounter = Number(process.env.TRANSACTION_OFFSET ?? '5000');
let balance = Number(process.env.STARTING_BALANCE ?? '1000000');

const json = (res, statusCode, body) => {
  res.writeHead(statusCode, { 'content-type': 'application/json' });
  res.end(JSON.stringify(body));
};

const readJson = async (req) => {
  const chunks = [];
  for await (const chunk of req) {
    chunks.push(chunk);
  }

  if (chunks.length === 0) {
    return {};
  }

  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
};

const notFound = (res, mobile) => json(res, 404, {
  statusCode: '3204',
  message: `Party not found for mobile ${mobile}`,
  localeMessage: `Party not found for mobile ${mobile}`,
  detailedDescription: `Mock backend ${walletLabel} has no account for ${mobile}`,
});

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url ?? '/', `http://127.0.0.1:${port}`);

  if (req.method === 'GET' && url.pathname === '/health') {
    return json(res, 200, { status: 'ok', wallet: walletLabel });
  }

  if (req.method !== 'POST') {
    return json(res, 405, { message: 'Method not allowed' });
  }

  if (url.pathname === '/find_user_quote') {
    const mobile = url.searchParams.get('mobile') ?? '';
    console.log(`[${walletLabel}] lookup mobile=${mobile}`);

    if (mobile !== partyId) {
      return notFound(res, mobile);
    }

    return json(res, 200, {
      userId: walletId,
      firstName,
      lastName,
      displayName,
      mobile,
      nric: '',
      address: '',
      supportedCurrencies,
    });
  }

  if (url.pathname === '/calculate_fee') {
    const body = await readJson(req);
    console.log(`[${walletLabel}] quote mobile=${body.mobile} amount=${body.amount}`);

    if (body.mobile !== partyId) {
      return notFound(res, body.mobile);
    }

    return json(res, 200, { fee: feeAmount });
  }

  if (url.pathname === '/fees/calculate') {
    const body = await readJson(req);
    console.log(`[${walletLabel}] fee-engine amount=${body.amount} currency=${body.currency} scenario=${body.scenario}`);

    return json(res, 200, {
      feeCalculationResultData: {
        transactionCurrency: body.currency ?? supportedCurrencies[0] ?? 'USD',
        transactionAmount: Number(body.amount ?? 0),
        feeCurrency: body.currency ?? supportedCurrencies[0] ?? 'USD',
        totalFeeAmount: feeAmount,
        feeSplits: {
          PAYER_FSP: {
            currency: body.currency ?? supportedCurrencies[0] ?? 'USD',
            amount: 0,
          },
          PAYEE_FSP: {
            currency: body.currency ?? supportedCurrencies[0] ?? 'USD',
            amount: feeAmount,
          },
          HUB: {
            currency: body.currency ?? supportedCurrencies[0] ?? 'USD',
            amount: 0,
          },
        },
        feePolicy: {
          feePolicyId: `${walletLabel}-local-policy`,
          scenario: body.scenario ?? 'TRANSFER',
          transactionCurrency: body.currency ?? supportedCurrencies[0] ?? 'USD',
          splits: {},
          formula: [],
        },
      },
    });
  }

  if (url.pathname === '/credit_amount') {
    const body = await readJson(req);
    console.log(`[${walletLabel}] credit mobile=${body.mobile} amount=${body.amount} transferId=${body.mojaloopTransferId}`);

    if (body.mobile !== partyId) {
      return notFound(res, body.mobile);
    }

    const amount = Number(body.amount ?? 0);
    const balanceBefore = balance;
    balance += amount;
    transactionCounter += 1;

    return json(res, 200, {
      ledgerId,
      transactionId: transactionCounter,
      walletId,
      amount,
      transactionType: 'TRANSFER',
      actionType: 'CREDIT',
      balanceBefore,
      balanceAfter: balance,
    });
  }

  return json(res, 404, { message: `Unknown path ${url.pathname}` });
});

server.listen(port, '0.0.0.0', () => {
  console.log(`[${walletLabel}] mock backend listening on ${port}`);
});
