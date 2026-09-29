const prisma = require('../../lib/prisma');
const publicId = require('../../lib/public-id');
const { notFound } = require('../../lib/errors');
const disputeAssist = require('./dispute-assist');

// 建議與裁決結果的對應；need_more_info 不是裁決方向，不計入一致率。
const MATCHING_RESULTS = {
  refund: ['refund_manual', 'refund_auto'],
  dismiss: ['dismissed'],
  mediate: ['mediated']
};

const parse = (value) => {
  try {
    const json = JSON.parse(String(value ?? ''));
    return json && typeof json === 'object' && !Array.isArray(json) ? json : {};
  } catch {
    return {};
  }
};

const shape = (row) => {
  const { images_skipped: skipped = 0, ...result } = parse(row.result);
  return {
    ...result,
    analysis_no: publicId.encode('ai_dispute_analysis', row.analysis_id),
    images: { listing: Number(row.listing_images ?? 0), evidence: Number(row.evidence_images ?? 0), skipped: Number(skipped) || 0 },
    provider: row.provider,
    model: row.model,
    helpful: row.helpful ?? null,
    created_at: row.created_at
  };
};

const latestRow = (disputeId) => prisma.ai_dispute_analyses.findFirst({
  where: { dispute_id: disputeId },
  orderBy: { analysis_id: 'desc' }
});

const assertDispute = async (disputeId) => {
  const exists = await prisma.transaction_disputes.count({ where: { dispute_id: disputeId } });
  if (!exists) throw notFound('找不到該爭議案件');
};

const latest = async (disputeId) => {
  await assertDispute(disputeId);
  const row = await latestRow(disputeId);
  return row ? shape(row) : null;
};

const run = async (disputeId, adminId) => {
  const output = await disputeAssist.analyze(disputeId, adminId);
  const { images, provider, model, ...result } = output;
  const row = await prisma.ai_dispute_analyses.create({
    data: {
      dispute_id: disputeId,
      admin_id: adminId,
      result: JSON.stringify({ ...result, images_skipped: Number(images?.skipped ?? 0) }),
      suggestion: String(result.suggestion ?? ''),
      listing_images: Number(images?.listing ?? 0),
      evidence_images: Number(images?.evidence ?? 0),
      provider,
      model,
      prompt_version: disputeAssist.PROMPT_VERSION,
      created_at: new Date()
    }
  });
  return shape(row);
};

// 評價管理員看到的那一次分析：其他管理員之後重新分析時，評價不可記到新的結果上。
const rate = async (disputeId, analysisNo, helpful) => {
  await assertDispute(disputeId);
  const analysisId = publicId.decode('ai_dispute_analysis', analysisNo);
  const row = analysisId == null
    ? null
    : await prisma.ai_dispute_analyses.findFirst({ where: { analysis_id: analysisId, dispute_id: disputeId } });
  if (!row) throw notFound('找不到此分析結果');
  await prisma.ai_dispute_analyses.update({ where: { analysis_id: row.analysis_id }, data: { helpful } });
  return shape({ ...row, helpful });
};

const agreementOf = (suggestion, result) => (MATCHING_RESULTS[suggestion] ? MATCHING_RESULTS[suggestion].includes(result) : null);

// 只比對裁決前最後一次分析，管理員看到的就是這一份。
const recordResolution = async (db, disputeId, result) => {
  const row = await db.ai_dispute_analyses.findFirst({ where: { dispute_id: disputeId }, orderBy: { analysis_id: 'desc' } });
  if (!row) return;
  await db.ai_dispute_analyses.update({
    where: { analysis_id: row.analysis_id },
    data: { resolved_result: result, agreed: agreementOf(row.suggestion, result), resolved_at: new Date() }
  });
};

module.exports = { MATCHING_RESULTS, latest, run, rate, agreementOf, recordResolution };
