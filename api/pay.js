// Función de Vercel: cobros de Booking Artist con tarjeta (Stripe) y ATH Móvil.
//
// La app nunca ve llaves secretas ni decide cuánto se cobra: este servidor lee
// el precio del paquete en Firestore, calcula el monto y es el único que puede
// cambiar el estado del pago y de la reserva.
//
// Tarjeta: Stripe Checkout con captura manual. El dinero queda retenido en la
// tarjeta y se cobra cuando el artista acepta (la retención dura ~7 días).
// ATH Móvil: Botón de Pago de ATH Business. ATH no retiene: cobra al momento y,
// si el artista rechaza o el cliente cancela, se hace un reembolso.
//
// Variables de entorno (Vercel → Settings → Environment Variables):
//   FIREBASE_SERVICE_ACCOUNT  JSON de la cuenta de servicio de Firebase (ya lo usa /api/notify)
//   STRIPE_SECRET_KEY         sk_test_... (prueba) o sk_live_... (real)
//   ATHM_PUBLIC_TOKEN         Token público de ATH Business (Ajustes → Desarrolladores)
//   ATHM_PRIVATE_TOKEN        Token privado de ATH Business (solo para reembolsos)
//   APP_URL                   (opcional) dirección de la app, p. ej. https://booking-artist-khaki.vercel.app
//   FEE_RATE                  (opcional) tarifa de la plataforma, 0.10 = 10 %
// Si falta la llave de un método, ese método funciona en modo simulado (no cobra).

const admin = require('firebase-admin');

const FEE_RATE = Number(process.env.FEE_RATE || 0.1);
const ATHM_URL = 'https://payments.athmovil.com/api/business-transaction/ecommerce';
const ATHM_MAX = 1500; // Límite de ATH Móvil por pago.

function firebase() {
  if (admin.apps.length) return admin.app();
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  return admin.initializeApp(raw ? { credential: admin.credential.cert(JSON.parse(raw)) } : {});
}

const has = {
  card: () => !!process.env.STRIPE_SECRET_KEY,
  ath: () => !!process.env.ATHM_PUBLIC_TOKEN,
};

class Fail extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

// ---------- Montos ----------

const round2 = (n) => Math.round(n * 100) / 100;

/** Mismo cálculo que la app (booking_screen.dart), hecho con los datos del servidor. */
function amounts(artist, packageName, payDeposit) {
  const pkg = (artist.packages || []).find((p) => p.name === packageName);
  if (!pkg) throw new Fail(400, 'El paquete ya no existe');
  const price = Number(pkg.price);
  const total = round2(price * (1 + FEE_RATE));
  const pct = Number(artist.depositPercent ?? 30);
  const deposit = Math.round((total * pct) / 100);
  return { price, fee: round2(total - price), total, dueNow: payDeposit ? deposit : total };
}

// ---------- Stripe ----------

/** Llama a la API de Stripe con parámetros anidados: {a: {b: 1}} → a[b]=1. */
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

// ---------- ATH Móvil ----------

async function athm(path, payload, bearer) {
  const headers = { Accept: 'application/json', 'Content-Type': 'application/json' };
  if (bearer) headers.Authorization = `Bearer ${bearer}`;
  const r = await fetch(`${ATHM_URL}/${path}`, {
    method: 'POST',
    headers,
    body: payload ? JSON.stringify(payload) : '',
  });
  const json = await r.json().catch(() => ({}));
  if (!r.ok || json.status !== 'success') {
    throw new Fail(502, `ATH Móvil: ${json.message || json.errorcode || r.status}`);
  }
  return json.data;
}

const tenDigits = (phone) => {
  const d = String(phone || '').replace(/\D/g, '');
  return d.length === 11 && d.startsWith('1') ? d.slice(1) : d;
};

// ---------- Acciones ----------

function baseUrl(req) {
  if (process.env.APP_URL) return process.env.APP_URL.replace(/\/$/, '');
  return `https://${req.headers['x-forwarded-host'] || req.headers.host}`;
}

async function load(db, bookingId) {
  const ref = db.collection('bookings').doc(String(bookingId || ''));
  const snap = await ref.get();
  if (!snap.exists) throw new Fail(404, 'No encontramos la reserva');
  const secretRef = db.collection('payments').doc(ref.id);
  const secret = (await secretRef.get()).data() || {};
  return { ref, b: snap.data(), secretRef, secret };
}

/** El cliente empieza a pagar: tarjeta, ATH Móvil o prueba (simulado). */
async function start(req, db, caller, body) {
  const { ref, b, secretRef, secret } = await load(db, body.bookingId);
  if (b.clientUid !== caller.uid) throw new Fail(403, 'Esta reserva no es tuya');
  if (b.payment !== 'porPagar') throw new Fail(409, 'Esta reserva ya se pagó o se canceló');

  const artist = (await db.collection('artists').doc(b.artistId).get()).data();
  if (!artist) throw new Fail(404, 'El artista ya no existe');
  const m = amounts(artist, b.package, b.payDeposit !== false);
  const concept = `${b.package} · ${artist.name}`.slice(0, 80);
  const common = { total: m.total, amountCharged: m.dueNow, fee: m.fee };

  let method = body.method;
  if ((method === 'tarjeta' && !has.card()) || (method === 'ath' && !has.ath())) method = 'prueba';

  if (method === 'prueba') {
    await ref.update({ ...common, paymentMethod: 'prueba', cardLast4: '4242', payment: 'retenido' });
    return { payment: 'retenido', amount: m.dueNow, simulated: true };
  }

  if (method === 'tarjeta') {
    // Si ya hay una ventana de pago abierta para esta reserva, se reusa.
    if (secret.stripeSession) {
      const s = await stripe('GET', `checkout/sessions/${secret.stripeSession}`);
      if (s.status === 'open') return { url: s.url, amount: m.dueNow };
    }
    const back = `${baseUrl(req)}/api/pay?fin=`;
    const s = await stripe('POST', 'checkout/sessions', {
      mode: 'payment',
      locale: 'es',
      client_reference_id: ref.id,
      customer_email: b.clientEmail || undefined,
      payment_method_types: ['card'],
      line_items: [
        {
          quantity: 1,
          price_data: {
            currency: 'usd',
            unit_amount: Math.round(m.dueNow * 100),
            product_data: {
              name: concept,
              description: b.payDeposit !== false ? 'Depósito de la reserva' : 'Pago completo de la reserva',
            },
          },
        },
      ],
      payment_intent_data: {
        capture_method: 'manual', // Se retiene; se cobra cuando el artista acepta.
        description: `Booking Artist · ${concept}`,
        metadata: { bookingId: ref.id },
      },
      metadata: { bookingId: ref.id },
      expires_at: Math.floor(Date.now() / 1000) + 31 * 60,
      success_url: `${back}ok`,
      cancel_url: `${back}cancelado`,
    });
    await secretRef.set({ method: 'tarjeta', stripeSession: s.id }, { merge: true });
    await ref.update({ ...common, paymentMethod: 'tarjeta' });
    return { url: s.url, amount: m.dueNow };
  }

  if (method === 'ath') {
    if (m.dueNow > ATHM_MAX) throw new Fail(400, `ATH Móvil acepta pagos de hasta $${ATHM_MAX}. Paga el depósito o usa tarjeta.`);
    const phone = tenDigits(body.phone);
    if (phone.length !== 10) throw new Fail(400, 'Escribe el teléfono de tu cuenta de ATH Móvil (10 dígitos)');
    if (secret.athId && secret.athStatus === 'OPEN') {
      await athm('business/cancel', { ecommerceId: secret.athId, publicToken: process.env.ATHM_PUBLIC_TOKEN }).catch(() => {});
    }
    const price = m.dueNow.toFixed(2);
    const p = await athm('payment', {
      env: 'production',
      publicToken: process.env.ATHM_PUBLIC_TOKEN,
      timeout: 600,
      total: price,
      subtotal: price,
      tax: '0',
      metadata1: `Reserva ${ref.id}`.slice(0, 40),
      metadata2: artist.name.slice(0, 40),
      items: [{ name: concept.slice(0, 40), description: b.payDeposit !== false ? 'Deposito' : 'Pago completo', quantity: '1', price, tax: '0', metadata: ref.id.slice(0, 40) }],
      phoneNumber: phone,
    });
    await secretRef.set(
      { method: 'ath', athId: p.ecommerceId, athToken: p.auth_token, athStatus: 'OPEN' },
      { merge: true },
    );
    await ref.update({ ...common, paymentMethod: 'ath', cardLast4: phone.slice(-4) });
    return { payment: 'porPagar', amount: m.dueNow, waiting: 'ath' };
  }

  throw new Fail(400, 'Forma de pago no válida');
}

/** La app pregunta si ya se pagó. Aquí se confirma el pago con Stripe o ATH. */
async function status(db, caller, body) {
  const { ref, b, secretRef, secret } = await load(db, body.bookingId);
  if (b.clientUid !== caller.uid && b.artistId !== caller.uid) throw new Fail(403, 'Esta reserva no es tuya');
  if (b.payment !== 'porPagar') return { payment: b.payment };

  if (secret.method === 'tarjeta' && secret.stripeSession) {
    const s = await stripe('GET', `checkout/sessions/${secret.stripeSession}`, {
      expand: ['payment_intent.latest_charge'],
    });
    const pi = s.payment_intent;
    if (s.status === 'complete' && pi && pi.status === 'requires_capture') {
      const card = pi.latest_charge?.payment_method_details?.card || {};
      await secretRef.set({ stripeIntent: pi.id }, { merge: true });
      await ref.update({ payment: 'retenido', cardLast4: card.last4 || '', cardBrand: card.brand || '' });
      return { payment: 'retenido' };
    }
    if (s.status === 'expired') {
      // Se puede intentar otra vez con una ventana nueva.
      await secretRef.set({ stripeSession: null }, { merge: true });
      return { payment: 'porPagar', failed: 'La ventana de pago venció. Intenta otra vez.' };
    }
    return { payment: 'porPagar' };
  }

  if (secret.method === 'ath' && secret.athId) {
    const p = await athm(
      'business/findPayment',
      { ecommerceId: secret.athId, publicToken: process.env.ATHM_PUBLIC_TOKEN },
      secret.athToken,
    );
    let st = p.ecommerceStatus;
    let refNum = p.referenceNumber;
    if (st === 'CONFIRM') {
      // El cliente confirmó en su teléfono: ahora se completa el cobro.
      const done = await athm('authorization', null, secret.athToken);
      st = done.ecommerceStatus;
      refNum = done.referenceNumber;
    }
    await secretRef.set({ athStatus: st, athRef: refNum || '' }, { merge: true });
    if (st === 'COMPLETED') {
      await ref.update({ payment: 'pagado' });
      return { payment: 'pagado' };
    }
    if (st === 'CANCEL') {
      await secretRef.set({ athId: null, athToken: null }, { merge: true });
      return { payment: 'porPagar', failed: 'El pago de ATH Móvil se canceló o venció. Intenta otra vez.' };
    }
    return { payment: 'porPagar' };
  }
  return { payment: 'porPagar' };
}

/** Devuelve o libera el dinero de una reserva que no se va a dar. */
async function release(b, secret) {
  if (secret.method === 'tarjeta') {
    if (secret.stripeIntent) {
      await stripe('POST', `payment_intents/${secret.stripeIntent}/cancel`);
    } else if (secret.stripeSession) {
      await stripe('POST', `checkout/sessions/${secret.stripeSession}/expire`).catch(() => {});
    }
    return 'liberado';
  }
  if (secret.method === 'ath') {
    if (secret.athStatus === 'COMPLETED' && secret.athRef) {
      await athm('refund', {
        publicToken: process.env.ATHM_PUBLIC_TOKEN,
        privateToken: process.env.ATHM_PRIVATE_TOKEN,
        referenceNumber: secret.athRef,
        amount: Number(b.amountCharged).toFixed(2),
        message: 'Reserva no confirmada',
      });
      return 'reembolsado';
    }
    if (secret.athId) {
      await athm('business/cancel', { ecommerceId: secret.athId, publicToken: process.env.ATHM_PUBLIC_TOKEN }).catch(() => {});
    }
  }
  return 'liberado';
}

/** El artista acepta o rechaza; el cliente cancela antes de que responda. */
async function decide(db, caller, body) {
  const { ref, b, secretRef, secret } = await load(db, body.bookingId);
  const action = body.action;
  const isArtist = b.artistId === caller.uid;
  const isClient = b.clientUid === caller.uid;
  if ((action === 'cancel' && !isClient) || (action !== 'cancel' && !isArtist)) {
    throw new Fail(403, 'No puedes hacer eso con esta reserva');
  }
  if (b.status !== 'pendiente') throw new Fail(409, 'Esta reserva ya fue respondida');

  if (action === 'accept') {
    if (!['retenido', 'pagado'].includes(b.payment)) throw new Fail(409, 'El cliente todavía no ha pagado');
    if (secret.method === 'tarjeta' && secret.stripeIntent) {
      try {
        await stripe('POST', `payment_intents/${secret.stripeIntent}/capture`);
      } catch (e) {
        throw new Fail(409, 'No se pudo cobrar la tarjeta: la retención venció o fue cancelada. Pídele al cliente que reserve de nuevo.');
      }
    }
    await ref.update({ status: 'confirmada', payment: 'cobrado' });
    await secretRef.set({ capturedAt: Date.now() }, { merge: true });
    return { status: 'confirmada', payment: 'cobrado' };
  }

  const payment = await release(b, secret);
  const st = action === 'cancel' ? 'cancelada' : 'rechazada';
  await ref.update({ status: st, payment });
  await db.collection('busy').doc(ref.id).delete();
  return { status: st, payment };
}

// ---------- Entrada ----------

const PAGE = (title, text) => `<!doctype html><html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}</title>
<style>body{font-family:system-ui,sans-serif;display:grid;place-items:center;min-height:90vh;margin:0 16px;text-align:center;color:#222;background:#fafafa}
@media(prefers-color-scheme:dark){body{background:#121212;color:#eee}}</style></head>
<body><div><h1>${title}</h1><p>${text}</p></div><script>setTimeout(()=>window.close(),2500)</script></body></html>`;

module.exports = async (req, res) => {
  if (req.method === 'GET') {
    // Página a la que vuelve Stripe al terminar.
    if (req.query?.fin) {
      const ok = req.query.fin === 'ok';
      res.setHeader('Content-Type', 'text/html; charset=utf-8');
      return res.send(
        ok
          ? PAGE('Pago recibido', 'Ya puedes cerrar esta ventana y volver a Booking Artist.')
          : PAGE('Pago cancelado', 'No se cobró nada. Vuelve a Booking Artist para intentarlo otra vez.'),
      );
    }
    // La app pregunta qué formas de pago están activas.
    const key = process.env.STRIPE_SECRET_KEY || '';
    return res.json({
      ready: !!process.env.FIREBASE_SERVICE_ACCOUNT,
      card: has.card(),
      cardTest: key.startsWith('sk_test_'),
      ath: has.ath(),
      athMax: ATHM_MAX,
      feeRate: FEE_RATE,
    });
  }
  if (req.method !== 'POST') return res.status(405).json({ error: 'Usa POST' });

  let caller;
  try {
    firebase();
    const token = (req.headers.authorization || '').replace(/^Bearer /, '');
    caller = await admin.auth().verifyIdToken(token);
  } catch (e) {
    return res.status(401).json({ error: 'Entra a tu cuenta otra vez' });
  }
  try {
    const body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body || {};
    const db = admin.firestore();
    switch (body.action) {
      case 'start':
        return res.json(await start(req, db, caller, body));
      case 'status':
        return res.json(await status(db, caller, body));
      case 'accept':
      case 'reject':
      case 'cancel':
        return res.json(await decide(db, caller, body));
      default:
        return res.status(400).json({ error: 'Acción no válida' });
    }
  } catch (e) {
    return res.status(e.status || 500).json({ error: e.status ? e.message : 'Error del servidor', detail: String(e.message || e).slice(0, 200) });
  }
};

module.exports.amounts = amounts;
