const prisma = require('../lib/prisma');
const { notFound, conflict } = require('../lib/errors');
const { notifyActiveUsers } = require('./notify');
const audit = require('./audit');

const KEY_RE = /^[a-z0-9_-]{1,50}$/;

const metaByKey = async () => {
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
  await prisma.$executeRaw`UPDATE legal_documents SET version = version + 1 WHERE doc_key = ${docKey}`;
  return (await metaByKey()).get(docKey)?.version ?? null;
};

// 兩張表的 collation 可能不同（MySQL 8 預設 0900_ai_ci），字串直接比較會拋 1267。
const pendingFor = (userId) => prisma.$queryRaw`
  SELECT d.doc_id, d.doc_key, d.title, d.content, d.version, d.updated_at
  FROM legal_documents d
  LEFT JOIN user_legal_consents c
    ON c.user_id = ${userId}
    AND CONVERT(c.doc_key USING utf8mb4) COLLATE utf8mb4_unicode_ci = CONVERT(d.doc_key USING utf8mb4) COLLATE utf8mb4_unicode_ci
  WHERE d.requires_consent = 1 AND d.version > COALESCE(c.version, 1)
  ORDER BY d.doc_id`;

const accept = async (userId, docKey, version) => {
  await prisma.$executeRaw`
    INSERT INTO user_legal_consents (user_id, doc_key, version, accepted_at)
    VALUES (${userId}, ${docKey}, ${version}, ${new Date()})
    ON DUPLICATE KEY UPDATE version = GREATEST(version, VALUES(version)), accepted_at = VALUES(accepted_at)`;
};

const acceptAllCurrent = async (userId) => {
  const meta = await metaByKey();
  for (const [key, m] of meta) {
    if (m.requires_consent) await accept(userId, key, m.version);
  }
};

const pendingDocs = async (userId) => {
  const docs = await pendingFor(userId);
  return docs.map((d) => ({
    doc_id: Number(d.doc_id),
    doc_key: d.doc_key,
    title: d.title,
    content: d.content,
    version: Number(d.version),
    updated_at: d.updated_at
  }));
};

const acceptVersion = async (userId, docKey, version) => {
  const meta = (await metaByKey()).get(docKey);
  if (!meta) throw notFound('找不到此文件');
  if (meta.version !== version) throw conflict('此文件已更新，請重新閱讀後再同意', 'LEGAL_VERSION_CHANGED');
  await accept(userId, docKey, version);
};

const listSummaries = async () => withMeta(await prisma.legal_documents.findMany({
  orderBy: { doc_id: 'asc' },
  select: { doc_id: true, doc_key: true, title: true, updated_at: true }
}));

const listFull = async () => withMeta(await prisma.legal_documents.findMany({ orderBy: { doc_id: 'asc' } }));

const findByKey = async (key) => {
  const doc = await prisma.legal_documents.findUnique({ where: { doc_key: key } });
  if (!doc) throw notFound('找不到此文件');
  const [withVersion] = await withMeta([doc]);
  return withVersion;
};

const publishedDocs = async () => withMeta(await prisma.legal_documents.findMany({
  select: { doc_id: true, doc_key: true, title: true, content: true, updated_at: true },
  orderBy: { doc_id: 'asc' }
}));

const save = async (key, { title, content, major }, { adminId, req }) => {
  const existing = await prisma.legal_documents.findUnique({ where: { doc_key: key } });

  const saved = await prisma.legal_documents.upsert({
    where: { doc_key: key },
    update: { title, content, updated_by: adminId, updated_at: new Date() },
    create: { doc_key: key, title, content, updated_by: adminId }
  });

  const contentChanged = !existing || existing.content !== content;
  let version = null;
  let notified = 0;
  let requiresConsent = false;

  if (major && contentChanged) {
    version = existing ? await bumpVersion(key) : 1;
    requiresConsent = (await metaByKey()).get(key)?.requires_consent ?? false;

    notified = await notifyActiveUsers({
      title: `${title}已更新`,
      content: requiresConsent
        ? `我們已更新${title}，下次開啟 App 時須重新閱讀並同意才能繼續使用。`
        : `我們已更新${title}，歡迎查看最新內容。`,
      relatedId: saved.doc_id,
      relatedType: 'legal'
    });
  }

  const fields = { title: '標題', content: '內容' };
  const changes = audit.diff(existing, { title, content }, fields);
  await audit.record(null, {
    adminId,
    action: '編輯法律文件',
    targetType: 'legal',
    targetId: saved.doc_id,
    summary: `${existing ? '編輯' : '建立'}「${title}」`
      + (version ? `，列為重大更新（第 ${version} 版）並通知 ${notified} 位使用者${requiresConsent ? '重新同意' : ''}` : '，小幅修改未通知使用者'),
    changes,
    undo: existing && changes.length ? [audit.undoUpdate('legal_documents', key, existing, { title, content }, fields)] : null,
    req
  });

  return { notified, version };
};

module.exports = {
  KEY_RE, pendingDocs, acceptVersion, acceptAllCurrent, listSummaries, listFull, findByKey, publishedDocs, save
};
