const prisma = require('../lib/prisma');

// 欄位由 migrations/007 新增且不在 Prisma client 中，須用原生 SQL 存取。

let available = null;
let checkedAt = 0;

const isAvailable = async () => {
  if (available === true || (available === false && Date.now() - checkedAt < 60 * 1000)) return available;
  const rows = await prisma.$queryRaw`
    SELECT
      (SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'legal_documents' AND COLUMN_NAME = 'requires_consent') AS cols,
      (SELECT COUNT(*) FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'user_legal_consents') AS tbl`;
  available = Number(rows[0].cols) > 0 && Number(rows[0].tbl) > 0;
  checkedAt = Date.now();
  return available;
};

const metaByKey = async () => {
  if (!(await isAvailable())) return new Map();
  const rows = await prisma.$queryRaw`SELECT doc_key, version, requires_consent FROM legal_documents`;
  return new Map(rows.map((r) => [r.doc_key, { version: Number(r.version), requires_consent: Boolean(Number(r.requires_consent)) }]));
};

const withMeta = async (docs) => {
  const meta = await metaByKey();
  return docs.map((d) => ({
    ...d,
    version: meta.get(d.doc_key)?.version ?? 1,
    requires_consent: meta.get(d.doc_key)?.requires_consent ?? ['terms', 'privacy'].includes(d.doc_key)
  }));
};

const bumpVersion = async (docKey) => {
  if (!(await isAvailable())) return null;
  await prisma.$executeRaw`UPDATE legal_documents SET version = version + 1 WHERE doc_key = ${docKey}`;
  return (await metaByKey()).get(docKey)?.version ?? null;
};

const pendingFor = async (userId) => {
  if (!(await isAvailable())) return [];
  return prisma.$queryRaw`
    SELECT d.doc_id, d.doc_key, d.title, d.content, d.version, d.updated_at
    FROM legal_documents d
    LEFT JOIN user_legal_consents c ON c.user_id = ${userId} AND c.doc_key = d.doc_key
    WHERE d.requires_consent = 1 AND d.version > COALESCE(c.version, 1)
    ORDER BY d.doc_id`;
};

const accept = async (userId, docKey, version) => {
  await prisma.$executeRaw`
    INSERT INTO user_legal_consents (user_id, doc_key, version, accepted_at)
    VALUES (${userId}, ${docKey}, ${version}, ${new Date()})
    ON DUPLICATE KEY UPDATE version = GREATEST(version, VALUES(version)), accepted_at = VALUES(accepted_at)`;
};

const acceptAllCurrent = async (userId) => {
  if (!(await isAvailable())) return;
  const meta = await metaByKey();
  for (const [key, m] of meta) {
    if (m.requires_consent) await accept(userId, key, m.version);
  }
};

module.exports = { isAvailable, metaByKey, withMeta, bumpVersion, pendingFor, accept, acceptAllCurrent };
