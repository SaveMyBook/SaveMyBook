const prisma = require('../../lib/prisma');
const { adminIdsWith } = require('../admin-permissions');
const { notifyMany } = require('../notify');
const settingsService = require('./settings');
const usage = require('./usage');

const THRESHOLDS = [80, 100];

const usd = (value) => `US$ ${value.toFixed(2)}`;

const messageOf = (threshold, cost, budget, memberCap) => {
  let effect = '';
  if (cost >= budget) effect = '所有 AI 功能已暫停，下月起或調高預算後恢復。';
  else if (cost >= memberCap) effect = '會員端 AI 功能已暫停，上架審核與管理輔助仍可使用至預算上限。';
  return {
    title: `AI 費用已達本月預算的 ${threshold}%`,
    content: `本月 AI 費用 ${usd(cost)}，每月預算 ${usd(budget)}。${effect}`
  };
};

// 每個門檻每月只通知一次，同一輪跨過多個門檻時只通知最高的一個。
// 紀錄與通知在同一交易：通知失敗時紀錄一併回滾，下一輪再通知；多個伺服器同時寫入時，後到者撞主鍵而放棄。
const check = async (now = new Date()) => {
  const settings = await settingsService.load();
  const budget = Number(settings.limits.monthly_budget_usd) || 0;
  if (budget <= 0) return null;
  const cost = await usage.monthCost(now);
  const month = usage.localDate(now).slice(0, 7);

  const crossed = THRESHOLDS.filter((threshold) => cost >= (budget * threshold) / 100);
  if (crossed.length === 0) return null;
  const sent = new Set((await prisma.ai_budget_alerts.findMany({ where: { month }, select: { threshold: true } }))
    .map((r) => Number(r.threshold)));
  const due = crossed.filter((threshold) => !sent.has(threshold));
  if (due.length === 0) return null;

  const reached = due[due.length - 1];
  const adminIds = await adminIdsWith('system');
  try {
    await prisma.$transaction(async (tx) => {
      await tx.ai_budget_alerts.createMany({ data: due.map((threshold) => ({ month, threshold, cost_usd: cost, created_at: now })) });
      if (adminIds.length > 0) {
        await notifyMany(tx, adminIds, { ...messageOf(reached, cost, budget, usage.budgetCap(settings)), relatedType: 'ai_budget' });
      }
    });
  } catch (err) {
    if (err.code === 'P2002') return null;
    throw err;
  }
  return reached;
};

module.exports = { THRESHOLDS, check };
