// Prueba de /api/pay con Firebase, Stripe y ATH simulados.
const path = require('path');
const Module = require('module');
const store = {};
const doc = (col, id) => ({
  id,
  get: async () => ({ exists: !!store[`${col}/${id}`], data: () => store[`${col}/${id}`] && { ...store[`${col}/${id}`] } }),
  set: async (v, o) => { store[`${col}/${id}`] = o?.merge ? { ...(store[`${col}/${id}`] || {}), ...v } : v; },
  update: async (v) => { if (!store[`${col}/${id}`]) throw new Error('no doc'); Object.assign(store[`${col}/${id}`], v); },
  delete: async () => { delete store[`${col}/${id}`]; },
});
let callerUid = 'client1';
const fakeAdmin = {
  apps: [1], app: () => {},
  auth: () => ({ verifyIdToken: async (t) => { if (!t) throw new Error('x'); return { uid: callerUid }; } }),
  firestore: () => ({ collection: (c) => ({ doc: (id) => doc(c, id) }) }),
};
const origLoad = Module._load;
Module._load = function (req, ...a) { return req === 'firebase-admin' ? fakeAdmin : origLoad.call(this, req, ...a); };

const calls = [];
let athStatus = 'OPEN';
global.fetch = async (url, opts) => {
  calls.push(`${opts.method} ${url.replace(/\?.*/, '')}`);
  const ok = (j) => ({ ok: true, status: 200, json: async () => j, text: async () => '' });
  if (url.includes('stripe.com')) {
    if (url.endsWith('/checkout/sessions')) {
      const p = new URLSearchParams(opts.body);
      if (p.get('payment_intent_data[capture_method]') !== 'manual') throw new Error('no manual');
      global.lastAmount = p.get('line_items[0][price_data][unit_amount]');
      return ok({ id: 'cs_1', url: 'https://checkout.stripe.com/x', status: 'open' });
    }
    if (url.includes('/checkout/sessions/cs_1')) return ok({ status: 'complete', payment_intent: { id: 'pi_1', status: 'requires_capture', latest_charge: { payment_method_details: { card: { last4: '4242', brand: 'visa' } } } } });
    return ok({});
  }
  if (url.includes('athmovil')) {
    if (url.endsWith('/payment')) { global.athBody = JSON.parse(opts.body); return ok({ status: 'success', data: { ecommerceId: 'e1', auth_token: 'tok' } }); }
    if (url.endsWith('/findPayment')) return ok({ status: 'success', data: { ecommerceStatus: athStatus } });
    if (url.endsWith('/authorization')) return ok({ status: 'success', data: { ecommerceStatus: 'COMPLETED', referenceNumber: 'ref1' } });
    if (url.endsWith('/refund')) { global.refundBody = JSON.parse(opts.body); return ok({ status: 'success', data: {} }); }
    return ok({ status: 'success', data: 'ok' });
  }
};
process.env.STRIPE_SECRET_KEY = 'sk_test_x';
process.env.ATHM_PUBLIC_TOKEN = 'pub';
process.env.ATHM_PRIVATE_TOKEN = 'priv';
process.env.FIREBASE_SERVICE_ACCOUNT = '{}';
const handler = require(process.argv[2] || require("path").join(__dirname, "../api/pay.js"));
const call = (body, uid = 'client1') => new Promise((resolve) => {
  callerUid = uid;
  const res = { code: 200, status(c) { this.code = c; return this; }, json(j) { resolve({ code: this.code, ...j }); }, setHeader() {}, send(t) { resolve({ code: this.code, html: t }); } };
  handler({ method: 'POST', headers: { authorization: 'Bearer t', host: 'x.app' }, body }, res);
});
const assert = require('assert');
(async () => {
  store['artists/art1'] = { name: 'Sofía', depositPercent: 30, packages: [{ name: 'Básico', price: 175 }] };
  store['subscriptions/art1'] = { status: 'active', trialEnd: 0, paidUntil: Date.now() + 86400000 };
  const mk = (id, payDeposit = true) => { store[`bookings/${id}`] = { clientUid: 'client1', artistId: 'art1', package: 'Básico', payDeposit, status: 'pendiente', payment: 'porPagar', total: 1, amountCharged: 1 }; store[`busy/${id}`] = {}; };

  // Tarjeta: retener y cobrar al aceptar.
  mk('b1');
  let r = await call({ action: 'start', bookingId: 'b1', method: 'tarjeta' });
  assert.equal(r.url, 'https://checkout.stripe.com/x');
  assert.equal(store['bookings/b1'].total, 192.5);
  assert.equal(store['bookings/b1'].amountCharged, 58);
  assert.equal(global.lastAmount, '5800');
  assert.equal((await call({ action: 'accept', bookingId: 'b1' }, 'art1')).code, 409, 'no aceptar sin pago');
  r = await call({ action: 'status', bookingId: 'b1' });
  assert.equal(r.payment, 'retenido');
  assert.equal(store['bookings/b1'].cardLast4, '4242');
  assert.equal((await call({ action: 'accept', bookingId: 'b1' }, 'client1')).code, 403, 'el cliente no acepta');
  r = await call({ action: 'accept', bookingId: 'b1' }, 'art1');
  assert.equal(r.payment, 'cobrado');
  assert.ok(calls.includes('POST https://api.stripe.com/v1/payment_intents/pi_1/capture'));

  // Otra persona no puede pagar/ver la reserva.
  mk('b0');
  assert.equal((await call({ action: 'start', bookingId: 'b0', method: 'tarjeta' }, 'intruso')).code, 403);

  // ATH: cobra al confirmar, reembolsa al rechazar.
  mk('b2', false);
  r = await call({ action: 'start', bookingId: 'b2', method: 'ath', phone: '(787) 555-0101' });
  assert.equal(r.waiting, 'ath');
  assert.equal(global.athBody.phoneNumber, '7875550101');
  assert.equal(global.athBody.total, '192.50');
  r = await call({ action: 'status', bookingId: 'b2' });
  assert.equal(r.payment, 'porPagar');
  athStatus = 'CONFIRM';
  r = await call({ action: 'status', bookingId: 'b2' });
  assert.equal(r.payment, 'pagado');
  r = await call({ action: 'reject', bookingId: 'b2' }, 'art1');
  assert.equal(r.payment, 'reembolsado');
  assert.equal(global.refundBody.amount, '192.50');
  assert.equal(global.refundBody.referenceNumber, 'ref1');
  assert.ok(!store['busy/b2'], 'libera el horario');

  // Cliente cancela tarjeta retenida: se cancela la retención.
  mk('b3');
  await call({ action: 'start', bookingId: 'b3', method: 'tarjeta' });
  await call({ action: 'status', bookingId: 'b3' });
  r = await call({ action: 'cancel', bookingId: 'b3' });
  assert.equal(r.status, 'cancelada');
  assert.equal(r.payment, 'liberado');
  assert.ok(calls.includes('POST https://api.stripe.com/v1/payment_intents/pi_1/cancel'));

  // Sin llave de Stripe: pago simulado.
  delete process.env.STRIPE_SECRET_KEY;
  mk('b4');
  r = await call({ action: 'start', bookingId: 'b4', method: 'tarjeta' });
  assert.equal(r.simulated, true);
  assert.equal(store['bookings/b4'].paymentMethod, 'prueba');

  // ATH sobre $1,500 se rechaza.
  store['artists/art1'].packages.push({ name: 'Boda', price: 1500 });
  mk('b5', false); store['bookings/b5'].package = 'Boda';
  r = await call({ action: 'start', bookingId: 'b5', method: 'ath', phone: '7875550101' });
  assert.equal(r.code, 400);

  // Paquete de restaurante: sin depósito, no se cobra nada.
  store['artists/art1'].packages.push({ name: 'Cena', price: 180, kind: 'restaurante' });
  mk('b6'); store['bookings/b6'].package = 'Cena';
  r = await call({ action: 'start', bookingId: 'b6', method: 'ninguno' });
  assert.equal(r.payment, 'sinPago');
  assert.equal(store['bookings/b6'].amountCharged, 0);
  assert.equal(store['bookings/b6'].total, 180);
  r = await call({ action: 'accept', bookingId: 'b6' }, 'art1');
  assert.equal(r.status, 'confirmada');
  assert.equal(store['bookings/b6'].payment, 'sinPago');
  mk('b7'); store['bookings/b7'].package = 'Cena';
  await call({ action: 'start', bookingId: 'b7', method: 'ninguno' });
  r = await call({ action: 'reject', bookingId: 'b7' }, 'art1');
  assert.equal(r.payment, 'sinPago');

  // Un paquete de actividad no se puede reservar sin depósito.
  mk('b8');
  r = await call({ action: 'start', bookingId: 'b8', method: 'ninguno' });
  assert.equal(r.code, 400);

  // Artista sin suscripción ni mes gratis: no se le puede reservar.
  store['subscriptions/art1'] = { status: 'canceled', trialEnd: Date.now() - 1000, paidUntil: Date.now() + 86400000 };
  mk('b9');
  r = await call({ action: 'start', bookingId: 'b9', method: 'tarjeta' });
  assert.equal(r.code, 409);
  console.log('Todas las pruebas del servidor pasaron');
})().catch((e) => { console.error(e); process.exit(1); });
