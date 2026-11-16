// Prueba de /api/places con Google simulado.
const assert = require('assert');
const handler = require('../api/places.js');
const { townFrom, MUNICIPIOS } = handler;

assert.strictEqual(MUNICIPIOS.length, 78);

// El municipio sale del área administrativa aunque la localidad sea un barrio.
assert.strictEqual(townFrom([
  { longText: 'Río Piedras', types: ['locality'] },
  { longText: 'San Juan', types: ['administrative_area_level_1'] },
], ''), 'San Juan');
assert.strictEqual(townFrom([{ longText: 'Mayaguez', types: ['locality'] }], ''), 'Mayagüez');
assert.strictEqual(townFrom([{ longText: 'Bayamón Municipio', types: ['administrative_area_level_2'] }], ''), 'Bayamón');
assert.strictEqual(townFrom([], 'Calle 5, Juana Díaz, 00795'), 'Juana Díaz');
assert.strictEqual(townFrom([], 'Calle Luna, Levittown'), null);

function call(query, env) {
  process.env.GOOGLE_MAPS_API_KEY = env || '';
  return new Promise((resolve) => {
    const res = {
      status(c) { this.code = c; return this; },
      json(b) { resolve({ code: this.code, body: b }); },
    };
    handler({ method: 'GET', query }, res);
  });
}

(async () => {
  let r = await call({});
  assert.deepStrictEqual(r.body, { ready: false });
  r = await call({ q: 'calle' });
  assert.strictEqual(r.code, 503);

  const sent = [];
  global.fetch = async (url, init) => {
    sent.push({ url, init });
    if (url.includes('autocomplete')) {
      return { ok: true, json: async () => ({ suggestions: [{ placePrediction: { placeId: 'abc', structuredFormat: { mainText: { text: 'El Patio' }, secondaryText: { text: 'Caguas, Puerto Rico' } } } }] }) };
    }
    return { ok: true, json: async () => ({
      formattedAddress: 'Calle Ruiz Belvis 10, Caguas, 00725, Puerto Rico',
      addressComponents: [
        { longText: 'Caguas', shortText: 'Caguas', types: ['locality', 'political'] },
        { longText: 'Puerto Rico', shortText: 'PR', types: ['country', 'political'] },
      ],
      location: { latitude: 18.23, longitude: -66.03 },
    }) };
  };

  r = await call({ q: 'El Patio', session: 's1' }, 'k');
  assert.deepStrictEqual(r.body.suggestions, [{ id: 'abc', main: 'El Patio', secondary: 'Caguas, Puerto Rico' }]);
  const body = JSON.parse(sent[0].init.body);
  assert.deepStrictEqual(body.includedRegionCodes, ['pr']);
  assert.strictEqual(body.sessionToken, 's1');
  assert.strictEqual(sent[0].init.headers['X-Goog-Api-Key'], 'k');

  r = await call({ id: 'abc', session: 's1' }, 'k');
  assert.strictEqual(r.body.town, 'Caguas');
  assert.strictEqual(r.body.address, 'Calle Ruiz Belvis 10, Caguas, 00725');
  assert.strictEqual(r.body.inPR, true);
  assert.strictEqual(r.body.lat, 18.23);
  assert.ok(sent[1].url.includes('places/abc?') && sent[1].url.includes('sessionToken=s1'));

  r = await call({ id: '../x' }, 'k');
  assert.strictEqual(r.code, 400);
  console.log('places ok');
})();
