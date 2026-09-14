const prisma = require('../lib/prisma');

const logAction = (adminId, action, targetType, targetId = null, detail = null, db = prisma) =>
  db.admin_operation_logs.create({
    data: {
      admin_id: adminId,
      action: String(action).slice(0, 100),
      target_type: targetType,
      target_id: targetId,
      detail: detail == null ? null : String(detail)
    }
  });

module.exports = { logAction };
