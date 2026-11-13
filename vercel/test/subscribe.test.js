// Prueba de /api/subscribe con Firebase y Stripe simulados.
const path = require('path');
const Module = require('module');
const assert = require('assert');
const store = {};
const doc = (col, id) => ({
  id,
  get: async () => ({ exists: !!store[`${col}/${id}`], data: () => store[`${col}/${id}`] && { ...store[`${col}/${id}`] } }),
  set: async (v, o) => { store[`${col}/${id}`] = o?.merge ? { ...(store[`${col}/${id}`] || {}), ...v } : v; },
});
const DAY = 86400000;
let callerUid = 'art1';
const created = Date.now() - 10 * DAY;
const fakeAdmin = {
  apps: [1], app: () => {},
  auth: () => ({
    verifyIdToken: async (t) => { if (!t) throw new Error('x'); return { uid: callerUid, email: 'a@x.com' }; },
    getUser: async () => ({ metadata: { creationTime: new Date(created).toUTCString() } }),
  }),
  firestore: () => ({ collection: (c) => ({ doc: (id) => doc(c, id) }) }),
};
const origLoad = Module._load;
Module._load = function (req, ...a) { return req === 'firebase-admin' ? fakeAdmin : origLoad.call(this, req, ...a); };

let lastCheckout;
let stripeSub = { id: 'sub_1', status: 'trialing', customer: 'cus_1', metadata: { uid: 'art1' }, trial_end: 0, cancel_at_period_end: false, items: { data: [{ current_period_end: 0 }] } };
global.fetch = async (url, opts) => {
  const ok = (j) => ({ ok: true, status: 200, json: async () => j });
  if (url.endsWith('/customers')) return ok({ id: 'cus_1' });
  if (url.endsWith('/checkout/sessions')) { lastCheckout = new URLSearchParams(opts.body); return ok({ id: 'cs_9', url: 'https://checkout.stripe.com/sub' }); }
  if (url.includes('/checkout/sessions/cs_9')) return ok({ status: 'complete', subscription: 'sub_1' });
  if (url.includes('/subscriptions/sub_1')) {
    if (opts.method === 'POST') stripeSub.cancel_at_period_end = new URLSearchParams(opts.body).get('cancel_at_period_end') === 'true';
    return ok(stripeSub);
  }
  return ok({});
};
process.env.FIREBASE_SERVICE_ACCOUNT = '{}';
process.env.STRIPE_SECRET_KEY = 'sk_test_x';
const handler = require(process.argv[2] || path.join(__dirname, '../api/subscribe.js'));
const call = (body, uid = 'art1', headers = { authorization: 'Bearer t' }) => new Promise((resolve) => {
  callerUid = uid;
  const res = { code: 200, status(c) { this.code = c; return this; }, json(j) { resolve({ code: this.code, ...j }); }, setHeader() {}, send(t) { resolve({ code: this.code, html: t }); } };
  handler({ method: 'POST', headers: { host: 'x.app', ...headers }, body }, res);
});

(async () => {
  store['users/art1'] = { role: 'artista' };
  store['users/cli1'] = { role: 'cliente' };

  // Los clientes no tienen suscripción.
  assert.equal((await call({ action: 'status' }, 'cli1')).code, 403);

  // Artista nuevo: mes gratis desde que creó la cuenta, sin tarjeta.
  let r = await call({ action: 'status' });
  const trialEnd = Math.max(created, Date.UTC(2026, 10, 7)) + 30 * DAY;
  assert.equal(r.subscription.status, 'sinTarjeta');
  assert.ok(Math.abs(r.subscription.trialEnd - trialEnd) < 2000);
  assert.ok(handler.visible(r.subscription), 'aparece durante el mes gratis');
  assert.ok(!handler.visible({ ...r.subscription, trialEnd: Date.now() - 1 }), 'sin prueba ni pago no aparece');

  // Se suscribe: $10 al mes y no se cobra hasta que termine el mes gratis.
  r = await call({ action: 'checkout' });
  assert.equal(r.url, 'https://checkout.stripe.com/sub');
  assert.equal(lastCheckout.get('mode'), 'subscription');
  assert.equal(lastCheckout.get('line_items[0][price_data][unit_amount]'), '1000');
  assert.equal(lastCheckout.get('line_items[0][price_data][recurring][interval]'), 'month');
  assert.equal(lastCheckout.get('subscription_data[trial_end]'), String(Math.floor(store['subscriptions/art1'].trialEnd / 1000)));
  assert.ok(!store['billing/art1'].subscriptionId);

  // Al volver de Stripe, el estado se pone al día.
  stripeSub.trial_end = Math.floor(trialEnd / 1000);
  stripeSub.items.data[0].current_period_end = Math.floor(trialEnd / 1000);
  r = await call({ action: 'status' });
  assert.equal(r.subscription.status, 'trialing');
  assert.equal(store['billing/art1'].subscriptionId, 'sub_1');

  // Cancelar y seguir.
  r = await call({ action: 'cancel' });
  assert.equal(r.subscription.cancelAtPeriodEnd, true);
  r = await call({ action: 'resume' });
  assert.equal(r.subscription.cancelAtPeriodEnd, false);

  // Aviso de Stripe (webhook): se lee la suscripción en Stripe, no del aviso.
  stripeSub.status = 'past_due';
  r = await call({ type: 'invoice.payment_failed', data: { object: { object: 'invoice', subscription: 'sub_1', status: 'active' } } }, 'x', { 'stripe-signature': 't=1' });
  assert.equal(r.ok, true);
  assert.equal(store['subscriptions/art1'].status, 'past_due');

  // Sin Stripe: se activa en modo de prueba.
  delete process.env.STRIPE_SECRET_KEY;
  store['users/art2'] = { role: 'artista' };
  r = await call({ action: 'checkout' }, 'art2');
  assert.equal(r.simulated, true);
  assert.equal(r.subscription.status, 'trialing');
  console.log('Todas las pruebas de suscripción pasaron');
})().catch((e) => { console.error(e); process.exit(1); });
