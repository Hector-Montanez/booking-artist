// Prueba de /api/notify con Firebase, Twilio y Resend simulados.
const Module = require('module');
const assert = require('assert');
const store = {
  'notifications/n1': { senderUid: 'client1', recipientEmail: 'sofia@ejemplo.com', title: 'Nueva solicitud de reserva', body: 'El Patio quiere reservarte.', sms: true },
  'users/art1': { name: 'Sofía', phone: '(787) 555-0101' },
};
const ref = (k) => ({
  get: async () => ({ data: () => store[k] && { ...store[k] } }),
  update: async (v) => Object.assign(store[k], v),
});
const fakeAdmin = {
  apps: [1], app: () => {},
  auth: () => ({
    verifyIdToken: async (t) => { if (t !== 'ok') throw new Error('bad'); return { uid: 'client1' }; },
    getUserByEmail: async (e) => { if (e !== 'sofia@ejemplo.com') throw new Error('none'); return { uid: 'art1' }; },
  }),
  firestore: () => ({
    collection: (c) => ({ doc: (id) => ref(`${c}/${id}`) }),
    runTransaction: async (fn) => fn({ get: (r) => r.get(), update: (r, v) => r.update(v) }),
  }),
};
const orig = Module._load;
Module._load = function (r, ...a) { return r === 'firebase-admin' ? fakeAdmin : orig.call(this, r, ...a); };
const sent = [];
global.fetch = async (url, opts) => { sent.push({ url, body: opts.body }); return { ok: true, text: async () => '' }; };
const handler = require(require('path').join(__dirname, '../api/notify.js'));
const call = (method, body, token = 'ok') => new Promise((done) => {
  const res = { code: 200, status(c) { this.code = c; return this; }, json(j) { done({ code: this.code, ...j }); } };
  handler({ method, headers: { authorization: `Bearer ${token}` }, body }, res);
});
(async () => {
  // Sin llaves: todo apagado y nada se envía.
  let s = await call('GET');
  assert.match(s.sms, /apagado/); assert.match(s.email, /apagado/);

  process.env.TWILIO_ACCOUNT_SID = 'AC1'; process.env.TWILIO_AUTH_TOKEN = 't'; process.env.TWILIO_FROM = '+18885550000';
  process.env.RESEND_API_KEY = 're_1';
  s = await call('GET');
  assert.match(s.sms, /activo/); assert.match(s.email, /modo prueba/);
  process.env.EMAIL_FROM = 'Booking Artist <avisos@bookingartist.com>';
  assert.match((await call('GET')).email, /activo/);
  assert.ok(!JSON.stringify(await call('GET')).includes('re_1'), 'no muestra llaves');

  assert.equal((await call('POST', { id: 'n1' }, 'bad')).code, 401);
  const r = await call('POST', { id: 'n1' });
  assert.deepEqual([r.sms, r.email], ['enviado', 'enviado']);
  const sms = sent.find((x) => x.url.includes('twilio'));
  assert.equal(new URLSearchParams(sms.body).get('To'), '+17875550101');
  assert.ok(JSON.parse(sent.find((x) => x.url.includes('resend')).body).to[0] === 'sofia@ejemplo.com');
  // Un aviso se envía una sola vez.
  assert.equal((await call('POST', { id: 'n1' })).code, 409);
  console.log('notify: todas las pruebas pasaron');
})().catch((e) => { console.error(e); process.exit(1); });
