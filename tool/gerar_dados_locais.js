// Gera os arquivos Dart com dados geográficos embutidos no app (modo local).
//
// Uso:  node tool/gerar_dados_locais.js [pasta-de-dados]
// Padrão da pasta de dados: ../dados (ao lado do repositório).
//
// Entradas (JSON):
//   bairros-rio-preto.json            -> lib/core/local/data/neighborhoods_data.dart
//   pontos-de-coleta-rio-preto.json   -> lib/core/local/data/collection_points_data.dart
//
// Os bairros vêm do OpenStreetMap (© colaboradores do OpenStreetMap, ODbL).
const fs = require('node:fs');
const path = require('node:path');

const dataDir = path.resolve(
  process.argv[2] || path.join(__dirname, '..', '..', 'dados'),
);
const outDir = path.join(__dirname, '..', 'lib', 'core', 'local', 'data');
fs.mkdirSync(outDir, { recursive: true });

const BACKSLASH = String.fromCharCode(92);

/** Texto como literal de string do Dart, com aspas simples. */
function q(value) {
  if (value === null || value === undefined || value === '') return 'null';
  let out = '';
  for (const ch of String(value)) {
    if (ch === BACKSLASH || ch === "'" || ch === '$') out += BACKSLASH + ch;
    else if (ch === '\n' || ch === '\r') out += ' ';
    else out += ch;
  }
  return "'" + out + "'";
}

function num(value) {
  const parsed = typeof value === 'string' ? Number(value) : value;
  return typeof parsed === 'number' && Number.isFinite(parsed)
    ? String(parsed)
    : 'null';
}

/**
 * Observações para mostrar ao usuário: ficam as frases sobre o uso do ponto
 * e saem as anotações de método do levantamento (origem da coordenada, fontes).
 * A observação completa continua no arquivo JSON original.
 */
function publicNotes(text) {
  if (!text) return null;
  const method =
    /(coordenad|openstreetmap|\bosm\b|google|mapa oficial|pol[ií]gono|geocod|confere|fonte|lista[s]? da prefeitura|nominatim|precis[aã]o|levantamento|consta n|posi[cç][aã]o na via|interpola|listado em|nome conforme|n[aã]o cita|logmed|green eletron|reciclus|tamb[eé]m lista)/i;
  // Abreviações ("Av.", "R.") não encerram frase.
  const guarded = String(text).replace(
    /\b(Av|R|Dr|Dra|Prof|Jd|Pq|Vl|Sto|Sta|S|Cel|Cap|Gal|Eng|Pe|n|nº|tel)\.(\s)/gi,
    '$1§$2',
  );
  const kept = guarded
    .split(/(?<=[.!?])\s+/)
    .filter((sentence) => !method.test(sentence));
  return kept.join(' ').replace(/§/g, '.').trim() || null;
}

function readJson(name) {
  const file = path.join(dataDir, name);
  if (!fs.existsSync(file)) return null;
  let text = fs.readFileSync(file, 'utf8');
  if (text.charCodeAt(0) === 0xfeff) text = text.slice(1);
  return JSON.parse(text);
}

// ----- Bairros -----
const bairros = readJson('bairros-rio-preto.json');
if (bairros) {
  const rows = bairros.bairros
    .map(
      (b) => `  (name: ${q(b.nome)}, lat: ${num(b.lat)}, lon: ${num(b.lon)}),`,
    )
    .join('\n');
  fs.writeFileSync(
    path.join(outDir, 'neighborhoods_data.dart'),
    `// GERADO por tool/gerar_dados_locais.js. Não edite à mão.
// Fonte: ${bairros.fonte}
// Consulta: ${bairros.consulta} (${bairros.data}).

/// Bairros de São José do Rio Preto e arredores, com o ponto central.
const List<({String name, double lat, double lon})> neighborhoodsData = [
${rows}
];
`,
  );
  console.log(`bairros: ${bairros.bairros.length}`);
} else {
  console.log(
    'bairros-rio-preto.json não encontrado: o arquivo de bairros não foi regerado.',
  );
}

// ----- Pontos de coleta -----
const pontosRaw = readJson('pontos-de-coleta-rio-preto.json');
const pontos = Array.isArray(pontosRaw)
  ? pontosRaw
  : (pontosRaw && (pontosRaw.pontos || pontosRaw.points)) || [];
const list = pontos.filter((p) => p && p.nome);
const pointRows = list
  .map((p) => {
    const materiais = Array.isArray(p.materiais)
      ? p.materiais
      : p.materiais
        ? [p.materiais]
        : [];
    return `  {
    'name': ${q(p.nome)},
    'type': ${q(p.tipo || 'outros')},
    'materials': <String>[${materiais.map(q).join(', ')}],
    'address': ${q(p.endereco)},
    'neighborhood': ${q(p.bairro)},
    'cep': ${q(p.cep)},
    'hours': ${q(p.horario)},
    'phone': ${q(p.telefone)},
    'responsible': ${q(p.responsavel)},
    'lat': ${num(p.lat)},
    'lon': ${num(p.lon)},
    'coord_precision': ${q(p.precisao_coordenada)},
    'source_url': ${q(p.fonte_url)},
    'source_date': ${q(p.fonte_data)},
    'confidence': ${q(p.confianca)},
    'notes': ${q(publicNotes(p.observacoes))},
  },`;
  })
  .join('\n');
fs.writeFileSync(
  path.join(outDir, 'collection_points_data.dart'),
  `// GERADO por tool/gerar_dados_locais.js. Não edite à mão.
// Fonte: dados/pontos-de-coleta-rio-preto.json (cada ponto traz a própria fonte).

/// Pontos de coleta de São José do Rio Preto.
const List<Map<String, Object?>> collectionPointsData = [
${pointRows}
];
`,
);
console.log(`pontos de coleta: ${list.length}`);
