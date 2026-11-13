// Función de Vercel: suscripción mensual de los artistas de Tarima.
//
// Cada artista paga $10 al mes para aparecer en la app. El primer mes es
// gratis y empieza cuando crea su cuenta, sin pedir tarjeta. Si se suscribe
// durante el mes gratis, Stripe no le cobra hasta que el mes termine.
//
// El estado vive en Firestore en subscriptions/{uid}, que todos leen (así la
// app sabe qué artistas mostrar) y solo este servidor escribe. El cliente de
// Stripe de cada artista se guarda en billing/{uid}, que nadie lee desde la app.
//
// Acciones (POST con el token de Firebase del artista):
//   status    Crea la suscripción con el mes gratis si es nueva y la pone al día con Stripe.
//   checkout  Devuelve la página de Stripe para poner la tarjeta.
//   cancel    Cancela al final del mes pagado.  resume: deshace la cancelación.
// POST sin token con la firma de Stripe (stripe-signature): aviso de Stripe
// (webhook). No se confía en lo que trae: se vuelve a leer la suscripción en Stripe.
//
// Variables de entorno: FIREBASE_SERVICE_ACCOUNT, STRIPE_SECRET_KEY (las
// mismas que /api/pay). Opcionales: STRIPE_PRICE_ID (un precio mensual creado
// en Stripe; si falta se usa $10 al mes), APP_URL.
// Sin STRIPE_SECRET_KEY la suscripción se activa en modo de prueba (no cobra).

const admin = require('firebase-admin');

const PRICE_CENTS = 1000;
const TRIAL_DAYS = 30;
const DAY = 24 * 60 * 60 * 1000;
// Los artistas que ya tenían cuenta reciben su mes gratis desde este día.
const LAUNCH = Date.UTC(2026, 10, 7);

function firebase() {
  if (admin.apps.length) return admin.app();
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  // Sin la cuenta de servicio no se puede comprobar quién llama: se avisa
  // claro en vez de decir "Entra a tu cuenta otra vez".
  if (!raw) throw new Fail(503, 'Falta FIREBASE_SERVICE_ACCOUNT en Vercel (Settings → Environment Variables).');
  let creds;
  try {
    creds = JSON.parse(raw);
  } catch (_) {
    throw new Fail(503, 'FIREBASE_SERVICE_ACCOUNT en Vercel no es un JSON válido: pega el archivo completo, desde { hasta }.');
  }
  return admin.initializeApp({ credential: admin.credential.cert(creds) });
}

class Fail extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

async function stripe(method, path, params) {
  const body = new URLSearchParams();
  const add = (prefix, v) => {
    if (v === undefined || v === null) return;
    if (typeof v === 'object') {
      for (const [k, x] of Object.entries(v)) add(prefix ? `${prefix}[${k}]` : k, x);
    } else body.append(prefix, String(v));
  };
  add('', params || {});
  const query = method === 'GET' && params ? `?${body}` : '';
  const r = await fetch(`https://api.stripe.com/v1/${path}${query}`, {
    method,
    headers: {
      Authorization: `Bearer ${process.env.STRIPE_SECRET_KEY}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: method === 'GET' ? undefined : body,
  });
  const json = await r.json();
  if (!r.ok) throw new Fail(502, `Stripe: ${json.error?.message || r.status}`);
  return json;
}

const hasStripe = () => !!process.env.STRIPE_SECRET_KEY;

function baseUrl(req) {
  if (process.env.APP_URL) return process.env.APP_URL.replace(/\/$/, '');
  return `https://${req.headers['x-forwarded-host'] || req.headers.host}`;
}

/** Fin del mes gratis: 30 días desde que creó la cuenta (o desde LAUNCH). */
async function trialEndFor(db, uid) {
  let created = 0;
  try {
    created = Date.parse((await admin.auth().getUser(uid)).metadata.creationTime) || 0;
  } catch (_) {}
  if (!created) {
    const a = (await db.collection('artists').doc(uid).get()).data() || {};
    created = Number(a.createdAt) || 0;
  }
  return Math.max(created, LAUNCH) + TRIAL_DAYS * DAY;
}

/** El artista aparece en la app (lo mismo que calcula la app). */
function visible(sub, now = Date.now()) {
  if (!sub) return false;
  const subscribed = ['trialing', 'active', 'past_due'].includes(sub.status);
  let until = Number(sub.trialEnd) || 0;
  if (subscribed && sub.paidUntil) {
    const paid = Number(sub.paidUntil) + (sub.status === 'past_due' ? 7 * DAY : 0);
    until = Math.max(until, paid);
  }
  return now < until;
}

/** Lo que se guarda en subscriptions/{uid} a partir de la suscripción de Stripe. */
function fromStripe(s, trialEnd) {
  const periodEnd = s.current_period_end ?? s.items?.data?.[0]?.current_period_end;
  return {
    status: s.status,
    trialEnd: Math.max(trialEnd, s.trial_end ? s.trial_end * 1000 : 0),
    paidUntil: periodEnd ? periodEnd * 1000 : null,
    cancelAtPeriodEnd: !!s.cancel_at_period_end,
    simulated: false,
    stripeLive: s.livemode === true,
    updatedAt: Date.now(),
  };
}

async function refs(db, uid) {
  const subRef = db.collection('subscriptions').doc(uid);
  const billRef = db.collection('billing').doc(uid);
  const [sub, bill] = await Promise.all([subRef.get(), billRef.get()]);
  return { subRef, billRef, sub: sub.data(), bill: bill.data() || {} };
}

async function requireArtist(db, uid) {
  const u = (await db.collection('users').doc(uid).get()).data();
  if (!u || u.role !== 'artista') throw new Fail(403, 'Solo los artistas tienen suscripción');
}

/** Crea la suscripción con el mes gratis y la pone al día con Stripe. */
async function status(db, uid) {
  const { subRef, billRef, sub, bill } = await refs(db, uid);
  let current = sub;
  if (!current) {
    current = { status: 'sinTarjeta', trialEnd: await trialEndFor(db, uid), paidUntil: null, cancelAtPeriodEnd: false, simulated: false, updatedAt: Date.now() };
    await subRef.set(current);
  }
  if (!hasStripe() || current.simulated) return current;

  // Si acaba de pagar en Stripe, la sesión dice cuál es su suscripción.
  let subscriptionId = bill.subscriptionId;
  if (!subscriptionId && bill.checkoutSession) {
    const s = await stripe('GET', `checkout/sessions/${bill.checkoutSession}`);
    if (s.status === 'complete' && s.subscription) {
      subscriptionId = s.subscription;
      await billRef.set({ subscriptionId, checkoutSession: null }, { merge: true });
    }
  }
  if (!subscriptionId) return current;
  const s = await stripe('GET', `subscriptions/${subscriptionId}`);
  const next = fromStripe(s, current.trialEnd);
  await subRef.set(next);
  return next;
}

/** Página de Stripe para poner la tarjeta. */
async function checkout(req, db, uid, caller) {
  const current = await status(db, uid);
  const { subRef, billRef, bill } = await refs(db, uid);

  if (!hasStripe()) {
    // Sin llave de Stripe: se activa sin cobrar, para probar.
    const start = Math.max(Date.now(), current.trialEnd);
    const sim = { ...current, status: current.trialEnd > Date.now() ? 'trialing' : 'active', paidUntil: start + 30 * DAY, cancelAtPeriodEnd: false, simulated: true, updatedAt: Date.now() };
    await subRef.set(sim);
    return { subscription: sim, simulated: true };
  }

  // Ya suscrito: si el cobro falló, se abre el portal para cambiar la tarjeta.
  if (['trialing', 'active', 'past_due', 'unpaid', 'incomplete'].includes(current.status) && bill.customerId && bill.subscriptionId) {
    const p = await stripe('POST', 'billing_portal/sessions', { customer: bill.customerId, return_url: `${baseUrl(req)}/api/subscribe?fin=ok`, locale: 'es' });
    return { url: p.url, subscription: current };
  }

  let customerId = bill.customerId;
  if (!customerId) {
    const c = await stripe('POST', 'customers', { email: caller.email || undefined, metadata: { uid } });
    customerId = c.id;
    await billRef.set({ customerId }, { merge: true });
  }
  // Stripe pide que el fin de la prueba sea al menos 2 días en el futuro.
  const trialEnd = current.trialEnd > Date.now() + 2 * DAY + 60000 ? Math.floor(current.trialEnd / 1000) : undefined;
  const back = `${baseUrl(req)}/api/subscribe?fin=`;
  const item = process.env.STRIPE_PRICE_ID
    ? { price: process.env.STRIPE_PRICE_ID, quantity: 1 }
    : {
        quantity: 1,
        price_data: {
          currency: 'usd',
          unit_amount: PRICE_CENTS,
          recurring: { interval: 'month' },
          product_data: { name: 'Tarima: suscripción de artista' },
        },
      };
  const s = await stripe('POST', 'checkout/sessions', {
    mode: 'subscription',
    locale: 'es',
    customer: customerId,
    client_reference_id: uid,
    line_items: [item],
    subscription_data: { trial_end: trialEnd, metadata: { uid } },
    metadata: { uid },
    success_url: `${back}ok`,
    cancel_url: `${back}cancelado`,
  });
  await billRef.set({ checkoutSession: s.id, subscriptionId: null }, { merge: true });
  return { url: s.url, subscription: current };
}

async function setCancel(db, uid, cancel) {
  const { subRef, bill, sub } = await refs(db, uid);
  if (!sub) throw new Fail(404, 'No tienes suscripción');
  if (sub.simulated || !hasStripe()) {
    const next = { ...sub, cancelAtPeriodEnd: cancel, updatedAt: Date.now() };
    await subRef.set(next);
    return next;
  }
  if (!bill.subscriptionId) throw new Fail(409, 'Todavía no te has suscrito');
  const s = await stripe('POST', `subscriptions/${bill.subscriptionId}`, { cancel_at_period_end: cancel });
  const next = fromStripe(s, sub.trialEnd);
  await subRef.set(next);
  return next;
}

/** Aviso de Stripe: se vuelve a leer la suscripción en Stripe y se guarda. */
async function webhook(db, event) {
  const o = event?.data?.object || {};
  const id = o.object === 'subscription' ? o.id : o.subscription;
  if (!id || typeof id !== 'string' || !hasStripe()) return { ignored: true };
  const s = await stripe('GET', `subscriptions/${id}`);
  const uid = s.metadata?.uid;
  if (!uid) return { ignored: true };
  const { subRef, billRef, sub } = await refs(db, uid);
  await billRef.set({ subscriptionId: s.id, customerId: s.customer }, { merge: true });
  await subRef.set(fromStripe(s, sub?.trialEnd || (await trialEndFor(db, uid))));
  return { ok: true };
}

const PAGE = (title, text) => `<!doctype html><html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}</title>
<style>body{font-family:system-ui,sans-serif;display:grid;place-items:center;min-height:90vh;margin:0 16px;text-align:center;color:#222;background:#fafafa}
@media(prefers-color-scheme:dark){body{background:#121212;color:#eee}}</style></head>
<body><div><h1>${title}</h1><p>${text}</p></div><script>setTimeout(()=>window.close(),2500)</script></body></html>`;

module.exports = async (req, res) => {
  if (req.method === 'GET') {
    if (req.query?.fin) {
      res.setHeader('Content-Type', 'text/html; charset=utf-8');
      return res.send(
        req.query.fin === 'ok'
          ? PAGE('Listo', 'Ya puedes cerrar esta ventana y volver a Tarima.')
          : PAGE('No se completó', 'No se cobró nada. Vuelve a Tarima para intentarlo otra vez.'),
      );
    }
    const key = process.env.STRIPE_SECRET_KEY || '';
    return res.json({ ready: !!process.env.FIREBASE_SERVICE_ACCOUNT, stripe: hasStripe(), test: key.startsWith('sk_test_'), price: PRICE_CENTS / 100, trialDays: TRIAL_DAYS });
  }
  if (req.method !== 'POST') return res.status(405).json({ error: 'Usa POST' });

  let body;
  try {
    body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body || {};
  } catch (_) {
    return res.status(400).json({ error: 'Datos no válidos' });
  }

  try {
    firebase();
    const db = admin.firestore();
    if (req.headers['stripe-signature'] && !req.headers.authorization) {
      return res.json(await webhook(db, body));
    }
    let caller;
    try {
      const token = (req.headers.authorization || '').replace(/^Bearer /, '');
      caller = await admin.auth().verifyIdToken(token);
    } catch (e) {
      return res.status(401).json({ error: 'Entra a tu cuenta otra vez' });
    }
    const uid = caller.uid;
    await requireArtist(db, uid);
    switch (body.action) {
      case 'status':
        return res.json({ subscription: await status(db, uid) });
      case 'checkout':
        return res.json(await checkout(req, db, uid, caller));
      case 'cancel':
      case 'resume':
        return res.json({ subscription: await setCancel(db, uid, body.action === 'cancel') });
      default:
        return res.status(400).json({ error: 'Acción no válida' });
    }
  } catch (e) {
    return res.status(e.status || 500).json({ error: e.status ? e.message : 'Error del servidor', detail: String(e.message || e).slice(0, 200) });
  }
};

module.exports.visible = visible;
module.exports.trialEndFor = trialEndFor;
