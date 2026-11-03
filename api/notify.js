// Envía por SMS (Twilio) y por email (Resend) un aviso que la app ya guardó
// en Firestore. La app llama aquí con el id del aviso y el token de la
// persona que lo envió; los datos del destinatario se leen del servidor.
//
// Variables de entorno (Vercel → Settings → Environment Variables):
//   FIREBASE_SERVICE_ACCOUNT  JSON de la cuenta de servicio de Firebase
//   TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM (+1XXXXXXXXXX)
//   RESEND_API_KEY, EMAIL_FROM (p. ej. "Booking Artist <onboarding@resend.dev>")
//   APP_URL (opcional) enlace que va en los avisos
// Si faltan las de Twilio o Resend, ese canal simplemente no se usa.

const admin = require('firebase-admin');

function app() {
  if (admin.apps.length) return admin.app();
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  return admin.initializeApp(
    raw ? { credential: admin.credential.cert(JSON.parse(raw)) } : {},
  );
}

// Números de Puerto Rico y EE. UU.: 787 555 0101 → +17875550101
function toE164(phone) {
  const d = String(phone || '').replace(/\D/g, '');
  if (d.length === 10) return '+1' + d;
  if (d.length === 11 && d.startsWith('1')) return '+' + d;
  return null;
}

async function sendSms(to, text) {
  const { TWILIO_ACCOUNT_SID: sid, TWILIO_AUTH_TOKEN: token, TWILIO_FROM: from } = process.env;
  if (!sid || !token || !from || !to) return 'omitido';
  const r = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`, {
    method: 'POST',
    headers: {
      Authorization: 'Basic ' + Buffer.from(`${sid}:${token}`).toString('base64'),
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({ To: to, From: from, Body: text }),
  });
  return r.ok ? 'enviado' : `error ${r.status}: ${(await r.text()).slice(0, 200)}`;
}

async function sendEmail(to, subject, text) {
  const { RESEND_API_KEY: key, EMAIL_FROM: from } = process.env;
  if (!key || !to) return 'omitido';
  const r = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from: from || 'Booking Artist <onboarding@resend.dev>',
      to: [to],
      subject,
      text,
    }),
  });
  return r.ok ? 'enviado' : `error ${r.status}: ${(await r.text()).slice(0, 200)}`;
}

// Abre /api/notify en el navegador para ver qué canales están activos.
// No muestra ninguna llave.
function status() {
  const e = process.env;
  const from = e.EMAIL_FROM || 'Booking Artist <onboarding@resend.dev>';
  const testSender = /@resend\.dev>?\s*$/.test(from);
  return {
    servidor: e.FIREBASE_SERVICE_ACCOUNT ? 'listo' : 'falta FIREBASE_SERVICE_ACCOUNT',
    sms: e.TWILIO_ACCOUNT_SID && e.TWILIO_AUTH_TOKEN && e.TWILIO_FROM
      ? `activo (desde ${e.TWILIO_FROM})`
      : 'apagado: faltan TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN o TWILIO_FROM',
    email: !e.RESEND_API_KEY
      ? 'apagado: falta RESEND_API_KEY'
      : testSender
        ? 'modo prueba: solo llega al correo de tu cuenta de Resend (verifica un dominio y cambia EMAIL_FROM)'
        : `activo (desde ${from})`,
  };
}

module.exports = async (req, res) => {
  if (req.method === 'GET') return res.json(status());
  if (req.method !== 'POST') return res.status(405).json({ error: 'Usa POST' });
  try {
    app();
    const token = (req.headers.authorization || '').replace(/^Bearer /, '');
    const caller = await admin.auth().verifyIdToken(token);
    const { id } = typeof req.body === 'string' ? JSON.parse(req.body) : req.body || {};
    if (!id) return res.status(400).json({ error: 'Falta el id del aviso' });

    const db = admin.firestore();
    const ref = db.collection('notifications').doc(String(id));
    // Cada aviso se envía una sola vez, y solo lo puede enviar quien lo creó.
    const n = await db.runTransaction(async (t) => {
      const snap = await t.get(ref);
      const data = snap.data();
      if (!data || data.senderUid !== caller.uid || data.delivery) return null;
      t.update(ref, { delivery: { status: 'enviando' } });
      return data;
    });
    if (!n) return res.status(409).json({ error: 'Aviso no válido o ya enviado' });

    // Solo se avisa a personas con cuenta en la app.
    let user = null;
    try {
      const u = await admin.auth().getUserByEmail(n.recipientEmail);
      user = (await db.collection('users').doc(u.uid).get()).data() || {};
    } catch (_) {}
    if (!user) {
      await ref.update({ delivery: { status: 'sin cuenta' } });
      return res.json({ sms: 'omitido', email: 'omitido' });
    }

    const link = process.env.APP_URL ? `\n${process.env.APP_URL}` : '';
    const [sms, email] = await Promise.all([
      n.sms ? sendSms(toE164(user.phone), `Booking Artist: ${n.title}. ${n.body}${link}`) : 'omitido',
      sendEmail(n.recipientEmail, n.title, `Hola ${user.name || ''}:\n\n${n.body}\n\nAbre la app para ver los detalles.${link}\n\nBooking Artist`),
    ]);
    await ref.update({ delivery: { status: 'listo', sms, email, at: Date.now() } });
    return res.json({ sms, email });
  } catch (e) {
    return res.status(401).json({ error: 'No autorizado', detail: String(e.message || e).slice(0, 200) });
  }
};
