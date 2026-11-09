// Gera o mapa-base vetorial embutido no app (assets/map/rio_preto.json).
//
// Uso:  node tool/gerar_mapa_base.js
//
// Baixa da Overpass API os DADOS do OpenStreetMap (vias principais e cursos
// d'água) da área urbana de São José do Rio Preto, simplifica as linhas e
// grava um arquivo compacto que o app desenha sozinho, sem internet.
//
// Importante: são dados (licença ODbL, com crédito "© colaboradores do
// OpenStreetMap" na tela), não as imagens de tile.openstreetmap.org, cujo uso
// offline a política da OSMF não permite.
const fs = require('node:fs');
const path = require('node:path');

const BBOX = '-20.93,-49.50,-20.70,-49.28'; // sul, oeste, norte, leste
const ENDPOINTS = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
];
const QUERY = `[out:json][timeout:120];
(
  way["highway"~"^(motorway|trunk|primary|secondary|tertiary)$"](${BBOX});
  way["waterway"~"^(river|stream)$"](${BBOX});
  way["natural"="water"](${BBOX});
);
out tags geom;`;

async function fetchOverpass() {
  let lastError;
  for (const url of ENDPOINTS) {
    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'EcoViva-academico/1.0 (trabalho escolar; mapa-base)',
        },
        body: 'data=' + encodeURIComponent(QUERY),
      });
      if (!response.ok) throw new Error(`${url}: HTTP ${response.status}`);
      return await response.json();
    } catch (error) {
      lastError = error;
      console.log('falhou:', String(error).slice(0, 120));
    }
  }
  throw lastError;
}

/** Distância perpendicular aproximada, em graus, do ponto p ao segmento a-b. */
function distanceToSegment(p, a, b) {
  const dx = b[1] - a[1];
  const dy = b[0] - a[0];
  if (dx === 0 && dy === 0) return Math.hypot(p[1] - a[1], p[0] - a[0]);
  const t = Math.max(
    0,
    Math.min(1, ((p[1] - a[1]) * dx + (p[0] - a[0]) * dy) / (dx * dx + dy * dy)),
  );
  return Math.hypot(p[1] - (a[1] + t * dx), p[0] - (a[0] + t * dy));
}

/** Simplificação de Douglas-Peucker. */
function simplify(points, tolerance) {
  if (points.length <= 2) return points;
  let maxDistance = 0;
  let index = 0;
  for (let i = 1; i < points.length - 1; i += 1) {
    const d = distanceToSegment(points[i], points[0], points[points.length - 1]);
    if (d > maxDistance) {
      maxDistance = d;
      index = i;
    }
  }
  if (maxDistance <= tolerance) return [points[0], points[points.length - 1]];
  const left = simplify(points.slice(0, index + 1), tolerance);
  const right = simplify(points.slice(index), tolerance);
  return left.slice(0, -1).concat(right);
}

const round = (value) => Math.round(value * 1e5) / 1e5;

(async () => {
  const data = await fetchOverpass();
  const roads = [];
  const water = [];
  const lakes = [];
  for (const element of data.elements || []) {
    if (element.type !== 'way' || !element.geometry) continue;
    const tags = element.tags || {};
    const raw = element.geometry.map((g) => [g.lat, g.lon]);
    // Tolerância de ~6 m: some com o ruído sem deformar as curvas.
    const points = simplify(raw, 0.00006).map((p) => [round(p[0]), round(p[1])]);
    if (points.length < 2) continue;
    const flat = points.flat();
    if (tags.highway) {
      roads.push({ c: tags.highway, n: tags.name || tags.ref || null, p: flat });
    } else if (tags.natural === 'water') {
      if (points.length >= 4) lakes.push({ n: tags.name || null, p: flat });
    } else if (tags.waterway) {
      water.push({ c: tags.waterway, n: tags.name || null, p: flat });
    }
  }

  const out = {
    attribution: '© colaboradores do OpenStreetMap',
    license: 'ODbL 1.0 (https://www.openstreetmap.org/copyright)',
    generatedAt: new Date().toISOString().slice(0, 10),
    bbox: { south: -20.93, west: -49.5, north: -20.7, east: -49.28 },
    // p = [lat, lon, lat, lon, ...]; c = classe da via; n = nome.
    roads,
    water,
    lakes,
  };
  const dir = path.join(__dirname, '..', 'assets', 'map');
  fs.mkdirSync(dir, { recursive: true });
  const file = path.join(dir, 'rio_preto.json');
  fs.writeFileSync(file, JSON.stringify(out));
  const byClass = {};
  for (const road of roads) byClass[road.c] = (byClass[road.c] || 0) + 1;
  console.log('vias:', roads.length, JSON.stringify(byClass));
  console.log('cursos de água:', water.length, 'lagos/represas:', lakes.length);
  console.log('arquivo:', file, Math.round(fs.statSync(file).size / 1024) + ' KB');
})().catch((error) => {
  console.error('ERRO', error);
  process.exit(1);
});
