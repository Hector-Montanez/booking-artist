// Busca direcciones de Puerto Rico con Google Maps (Places API "New") y
// saca el pueblo (municipio) de la dirección escogida. La llave de Google
// se queda en el servidor; la app nunca la ve.
//
// Variable de entorno (Vercel → Settings → Environment Variables):
//   GOOGLE_MAPS_API_KEY  llave de Google Cloud con "Places API (New)" activa
// Sin la llave, la app muestra un campo de dirección normal y el pueblo se
// escoge de la lista.
//
//   GET /api/places                      → { ready }
//   GET /api/places?q=texto&session=…    → { suggestions: [{ id, main, secondary }] }
//   GET /api/places?id=placeId&session=… → { address, town, lat, lng }

const MUNICIPIOS = [
  'Adjuntas', 'Aguada', 'Aguadilla', 'Aguas Buenas', 'Aibonito', 'Añasco',
  'Arecibo', 'Arroyo', 'Barceloneta', 'Barranquitas', 'Bayamón', 'Cabo Rojo',
  'Caguas', 'Camuy', 'Canóvanas', 'Carolina', 'Cataño', 'Cayey', 'Ceiba',
  'Ciales', 'Cidra', 'Coamo', 'Comerío', 'Corozal', 'Culebra', 'Dorado',
  'Fajardo', 'Florida', 'Guánica', 'Guayama', 'Guayanilla', 'Guaynabo',
  'Gurabo', 'Hatillo', 'Hormigueros', 'Humacao', 'Isabela', 'Jayuya',
  'Juana Díaz', 'Juncos', 'Lajas', 'Lares', 'Las Marías', 'Las Piedras',
  'Loíza', 'Luquillo', 'Manatí', 'Maricao', 'Maunabo', 'Mayagüez', 'Moca',
  'Morovis', 'Naguabo', 'Naranjito', 'Orocovis', 'Patillas', 'Peñuelas',
  'Ponce', 'Quebradillas', 'Rincón', 'Río Grande', 'Sabana Grande', 'Salinas',
  'San Germán', 'San Juan', 'San Lorenzo', 'San Sebastián', 'Santa Isabel',
  'Toa Alta', 'Toa Baja', 'Trujillo Alto', 'Utuado', 'Vega Alta', 'Vega Baja',
  'Vieques', 'Villalba', 'Yabucoa', 'Yauco',
];

const norm = (s) =>
  String(s || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/\s+municipio$/, '')
    .replace(/^municipio (de )?/, '')
    .trim();

const BY_NORM = new Map(MUNICIPIOS.map((m) => [norm(m), m]));

// Google pone el municipio en distintos campos según la dirección; se prueba
// primero el área administrativa y luego la localidad. Si nada coincide, se
// busca el nombre del pueblo dentro de la dirección completa.
function townFrom(components, formatted) {
  const order = [
    'administrative_area_level_1',
    'administrative_area_level_2',
    'locality',
    'postal_town',
    'sublocality',
  ];
  const list = components || [];
  for (const type of order) {
    for (const c of list) {
      if (!(c.types || []).includes(type)) continue;
      const hit = BY_NORM.get(norm(c.longText)) || BY_NORM.get(norm(c.shortText));
      if (hit) return hit;
    }
  }
  for (const c of list) {
    const hit = BY_NORM.get(norm(c.longText));
    if (hit) return hit;
  }
  const text = norm(formatted);
  // Los nombres más largos primero, para que "San Juan" no gane a "Juana Díaz".
  const found = [...BY_NORM.keys()]
    .sort((a, b) => b.length - a.length)
    .find((m) => new RegExp(`(^|[\\s,])${m}([\\s,]|$)`).test(text));
  return found ? BY_NORM.get(found) : null;
}

const clean = (v, max) => String(v || '').trim().slice(0, max);

async function google(path, key, init = {}) {
  const r = await fetch(`https://places.googleapis.com/v1/${path}`, {
    ...init,
    headers: { 'X-Goog-Api-Key': key, 'Content-Type': 'application/json', ...init.headers },
  });
  const data = await r.json().catch(() => ({}));
  if (!r.ok) {
    const err = new Error((data.error && data.error.message) || `Google ${r.status}`);
    err.status = 502;
    throw err;
  }
  return data;
}

module.exports = async (req, res) => {
  if (req.method !== 'GET') return res.status(405).json({ error: 'Usa GET' });
  const key = process.env.GOOGLE_MAPS_API_KEY;
  const q = clean(req.query.q, 120);
  const id = clean(req.query.id, 300);
  const session = clean(req.query.session, 64);
  if (!q && !id) return res.status(200).json({ ready: !!key });
  if (!key) return res.status(503).json({ error: 'Búsqueda de direcciones no configurada' });

  try {
    if (id) {
      if (!/^[\w-]+$/.test(id)) return res.status(400).json({ error: 'Lugar no válido' });
      const qs = new URLSearchParams({ languageCode: 'es', regionCode: 'pr' });
      if (session) qs.set('sessionToken', session);
      const p = await google(`places/${id}?${qs}`, key, {
        headers: { 'X-Goog-FieldMask': 'formattedAddress,addressComponents,location' },
      });
      const country = (p.addressComponents || []).find((c) => (c.types || []).includes('country'));
      return res.status(200).json({
        address: (p.formattedAddress || '').replace(/,\s*(Puerto Rico|PR)$/i, ''),
        town: townFrom(p.addressComponents, p.formattedAddress),
        inPR: !country || country.shortText === 'PR',
        lat: p.location ? p.location.latitude : null,
        lng: p.location ? p.location.longitude : null,
      });
    }

    if (q.length < 3) return res.status(200).json({ suggestions: [] });
    const body = { input: q, includedRegionCodes: ['pr'], languageCode: 'es', regionCode: 'pr' };
    if (session) body.sessionToken = session;
    const data = await google('places:autocomplete', key, { method: 'POST', body: JSON.stringify(body) });
    const suggestions = (data.suggestions || [])
      .map((s) => s.placePrediction)
      .filter(Boolean)
      .map((p) => ({
        id: p.placeId,
        main: (p.structuredFormat && p.structuredFormat.mainText && p.structuredFormat.mainText.text) || (p.text && p.text.text) || '',
        secondary: (p.structuredFormat && p.structuredFormat.secondaryText && p.structuredFormat.secondaryText.text) || '',
      }));
    return res.status(200).json({ suggestions });
  } catch (e) {
    return res.status(e.status || 500).json({ error: 'No se pudo buscar la dirección', detail: String(e.message || e).slice(0, 200) });
  }
};

module.exports.townFrom = townFrom;
module.exports.MUNICIPIOS = MUNICIPIOS;
