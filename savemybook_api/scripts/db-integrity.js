#!/usr/bin/env node
// 資料庫關聯健檢：檢查外鍵是否建立、資料表引擎是否支援外鍵，以及指向不存在資料的「孤兒資料」。
//   node scripts/db-integrity.js                      只檢查並列出結果，不修改任何資料
//   node scripts/db-integrity.js --fix                先備份，再清理可以安全處理的孤兒資料
//   node scripts/db-integrity.js --fix --add-constraints  清理後補建缺少的外鍵
// 帳務相關資料（錢包、訂單、退款、爭議、轉帳）與必填的非串聯關聯只列出、不自動刪除，須人工確認。

// [資料表, 欄位, 參照資料表, 參照欄位, 可為 NULL, 刪除規則, 外鍵名稱]；依 prisma/schema.prisma 整理。
const RELATIONS = [
  ['admin_operation_logs', 'admin_id', 'users', 'user_id', false, 'NoAction', 'fk_oplog_admin'],
  ['admin_permissions', 'user_id', 'users', 'user_id', false, 'Cascade', 'fk_admin_user'],
  ['bankbooks', 'user_id', 'users', 'user_id', false, 'Cascade', 'fk_bankbook_user'],
  ['book_categories', 'parent_id', 'book_categories', 'category_id', true, 'SetNull', 'fk_category_parent'],
  ['book_images', 'book_id', 'books', 'book_id', false, 'Cascade', 'fk_image_book'],
  ['books', 'cabinet_id', 'smart_cabinets', 'cabinet_id', true, 'SetNull', 'fk_book_cabinet'],
  ['books', 'category_id', 'book_categories', 'category_id', true, 'SetNull', 'fk_book_category'],
  ['books', 'seller_id', 'users', 'user_id', false, 'Cascade', 'fk_book_seller'],
  ['cabinet_slots', 'cabinet_id', 'smart_cabinets', 'cabinet_id', false, 'Cascade', 'fk_slot_cabinet'],
  ['chat_messages', 'room_id', 'chat_rooms', 'room_id', false, 'Cascade', 'fk_msg_room'],
  ['chat_messages', 'sender_id', 'users', 'user_id', false, 'NoAction', 'fk_msg_sender'],
  ['chat_rooms', 'book_id', 'books', 'book_id', true, 'SetNull', 'fk_chat_book'],
  ['chat_rooms', 'user_a_id', 'users', 'user_id', false, 'NoAction', 'fk_chat_user_a'],
  ['chat_rooms', 'user_b_id', 'users', 'user_id', false, 'NoAction', 'fk_chat_user_b'],
  ['content_reviews', 'admin_id', 'users', 'user_id', true, 'NoAction', 'fk_content_admin'],
  ['favorites', 'book_id', 'books', 'book_id', false, 'Cascade', 'fk_fav_book'],
  ['favorites', 'user_id', 'users', 'user_id', false, 'Cascade', 'fk_fav_user'],
  ['login_logs', 'user_id', 'users', 'user_id', false, 'Cascade', 'fk_login_user'],
  ['notifications', 'user_id', 'users', 'user_id', false, 'Cascade', 'fk_notif_user'],
  ['order_items', 'book_id', 'books', 'book_id', false, 'NoAction', 'fk_item_book'],
  ['order_items', 'order_id', 'orders', 'order_id', false, 'Cascade', 'fk_item_order'],
  ['orders', 'buyer_id', 'users', 'user_id', false, 'NoAction', 'fk_order_buyer'],
  ['orders', 'cabinet_id', 'smart_cabinets', 'cabinet_id', true, 'SetNull', 'fk_order_cabinet'],
  ['orders', 'seller_id', 'users', 'user_id', false, 'NoAction', 'fk_order_seller'],
  ['orders', 'slot_id', 'cabinet_slots', 'slot_id', true, 'SetNull', 'fk_order_slot'],
  ['recommendation_logs', 'book_id', 'books', 'book_id', false, 'Cascade', 'fk_rec_book'],
  ['recommendation_logs', 'user_id', 'users', 'user_id', false, 'Cascade', 'fk_rec_user'],
  ['referral_records', 'invitee_id', 'users', 'user_id', false, 'NoAction', 'fk_ref_invitee'],
  ['referral_records', 'inviter_id', 'users', 'user_id', false, 'NoAction', 'fk_ref_inviter'],
  ['refund_records', 'admin_id', 'users', 'user_id', true, 'NoAction', 'fk_refund_admin'],
  ['refund_records', 'dispute_id', 'transaction_disputes', 'dispute_id', true, 'SetNull', 'fk_refund_dispute'],
  ['refund_records', 'order_id', 'orders', 'order_id', false, 'NoAction', 'fk_refund_order'],
  ['reports', 'admin_id', 'users', 'user_id', true, 'NoAction', 'fk_report_admin'],
  ['reports', 'reporter_id', 'users', 'user_id', false, 'NoAction', 'fk_report_reporter'],
  ['reservations', 'book_id', 'books', 'book_id', false, 'NoAction', 'fk_reservation_book'],
  ['reservations', 'buyer_id', 'users', 'user_id', false, 'NoAction', 'fk_reservation_buyer'],
  ['reservations', 'cabinet_id', 'smart_cabinets', 'cabinet_id', true, 'SetNull', 'fk_reservation_cabinet'],
  ['reservations', 'seller_id', 'users', 'user_id', false, 'NoAction', 'fk_reservation_seller'],
  ['shopping_cart', 'book_id', 'books', 'book_id', false, 'Cascade', 'fk_cart_book'],
  ['shopping_cart', 'user_id', 'users', 'user_id', false, 'Cascade', 'fk_cart_user'],
  ['system_announcements', 'admin_id', 'users', 'user_id', false, 'NoAction', 'fk_announce_admin'],
  ['transaction_disputes', 'admin_id', 'users', 'user_id', true, 'NoAction', 'fk_dispute_admin'],
  ['transaction_disputes', 'applicant_id', 'users', 'user_id', false, 'NoAction', 'fk_dispute_applicant'],
  ['transaction_disputes', 'order_id', 'orders', 'order_id', false, 'NoAction', 'fk_dispute_order'],
  ['user_achievements', 'achievement_id', 'achievements', 'achievement_id', false, 'Cascade', 'fk_ua_achievement'],
  ['user_achievements', 'user_id', 'users', 'user_id', false, 'Cascade', 'fk_ua_user'],
  ['user_qr_codes', 'user_id', 'users', 'user_id', false, 'Cascade', 'fk_qr_user'],
  ['user_settings', 'user_id', 'users', 'user_id', false, 'Cascade', 'fk_setting_user'],
  ['wallet_transactions', 'related_order_id', 'orders', 'order_id', true, 'SetNull', 'fk_txn_order'],
  ['wallet_transactions', 'wallet_id', 'wallets', 'wallet_id', false, 'NoAction', 'fk_txn_wallet'],
  ['wallets', 'user_id', 'users', 'user_id', false, 'Cascade', 'fk_wallet_user'],
  ['legal_documents', 'updated_by', 'users', 'user_id', true, 'NoAction', 'fk_legal_admin'],
  ['support_tickets', 'user_id', 'users', 'user_id', false, 'Cascade', 'fk_ticket_user'],
  ['support_ticket_messages', 'sender_id', 'users', 'user_id', false, 'NoAction', 'fk_tmsg_sender'],
  ['support_ticket_messages', 'ticket_id', 'support_tickets', 'ticket_id', false, 'Cascade', 'fk_tmsg_ticket'],
  ['chat_aliases', 'owner_id', 'users', 'user_id', false, 'Cascade', 'fk_alias_owner'],
  ['chat_aliases', 'target_user_id', 'users', 'user_id', false, 'Cascade', 'fk_alias_target'],
  ['chat_room_members', 'room_id', 'chat_rooms', 'room_id', false, 'Cascade', 'fk_member_room'],
  ['chat_room_members', 'user_id', 'users', 'user_id', false, 'Cascade', 'fk_member_user'],
  ['chat_room_mutes', 'room_id', 'chat_rooms', 'room_id', false, 'Cascade', 'fk_mute_room'],
  ['chat_room_mutes', 'user_id', 'users', 'user_id', false, 'Cascade', 'fk_mute_user'],
  ['chat_room_pins', 'room_id', 'chat_rooms', 'room_id', false, 'Cascade', 'fk_pin_room'],
  ['chat_room_pins', 'user_id', 'users', 'user_id', false, 'Cascade', 'fk_pin_user'],
  ['chat_transfers', 'from_user_id', 'users', 'user_id', false, 'NoAction', 'fk_transfer_from'],
  ['chat_transfers', 'to_user_id', 'users', 'user_id', false, 'NoAction', 'fk_transfer_to'],
  ['db_backups', 'admin_id', 'users', 'user_id', true, 'SetNull', 'fk_backup_admin'],
  ['push_devices', 'user_id', 'users', 'user_id', false, 'Cascade', 'fk_push_user'],
  ['user_blocks', 'blocked_id', 'users', 'user_id', false, 'Cascade', 'fk_block_blocked'],
  ['user_blocks', 'blocker_id', 'users', 'user_id', false, 'Cascade', 'fk_block_blocker'],
  ['user_legal_consents', 'user_id', 'users', 'user_id', false, 'Cascade', 'fk_consent_user'],
  ['user_security', 'user_id', 'users', 'user_id', false, 'Cascade', 'fk_security_user'],
  ['user_sessions', 'user_id', 'users', 'user_id', false, 'Cascade', 'fk_session_user'],
  ['ai_book_reviews', 'book_id', 'books', 'book_id', false, 'Cascade', 'fk_ai_review_book'],
  ['ai_chat_messages', 'session_id', 'ai_chat_sessions', 'session_id', false, 'Cascade', 'fk_ai_chat_message_session'],
  ['ai_chat_sessions', 'user_id', 'users', 'user_id', false, 'Cascade', 'fk_ai_chat_session_user'],
  ['ai_consents', 'user_id', 'users', 'user_id', false, 'Cascade', 'fk_ai_consent_user'],
  ['ai_recommendation_cache', 'user_id', 'users', 'user_id', false, 'Cascade', 'fk_ai_rec_user'],
  ['ai_support_messages', 'session_id', 'ai_support_sessions', 'session_id', false, 'Cascade', 'fk_ai_message_session'],
  ['ai_support_sessions', 'user_id', 'users', 'user_id', false, 'Cascade', 'fk_ai_session_user'],
  ['chat_mentions', 'message_id', 'chat_messages', 'message_id', false, 'Cascade', 'fk_mention_message'],
  ['user_identities', 'user_id', 'users', 'user_id', false, 'Cascade', 'fk_identity_user'],
  ['user_passkeys', 'user_id', 'users', 'user_id', false, 'Cascade', 'fk_passkey_user'],
  ['support_ticket_attachments', 'message_id', 'support_ticket_messages', 'message_id', true, 'Cascade', 'fk_support_attachment_message'],
  ['support_ticket_attachments', 'uploader_id', 'users', 'user_id', false, 'Cascade', 'fk_support_attachment_uploader'],
].map(([table, column, refTable, refColumn, nullable, onDelete, name]) => ({
  table, column, refTable, refColumn, nullable, onDelete, name
}));

// 沒有外鍵（多型關聯或刻意不設外鍵）但仍應指向存在資料的欄位。action：null 清空、delete 刪除、report 只列出。
const SOFT = [
  { table: 'cabinet_slots', column: 'current_book_id', refTable: 'books', refColumn: 'book_id', action: 'null' },
  { table: 'cabinet_slots', column: 'current_order_id', refTable: 'orders', refColumn: 'order_id', action: 'null' },
  { table: 'chat_messages', column: 'reply_to_id', refTable: 'chat_messages', refColumn: 'message_id', action: 'null' },
  { table: 'notifications', column: 'actor_id', refTable: 'users', refColumn: 'user_id', action: 'null' },
  { table: 'notifications', column: 'related_id', refTable: 'books', refColumn: 'book_id', action: 'null', where: "c.related_type = 'book'" },
  { table: 'notifications', column: 'related_id', refTable: 'orders', refColumn: 'order_id', action: 'null', where: "c.related_type = 'order'" },
  { table: 'notifications', column: 'related_id', refTable: 'chat_rooms', refColumn: 'room_id', action: 'null', where: "c.related_type = 'chat_room'" },
  {
    table: 'notifications', column: 'related_id', refTable: 'support_tickets', refColumn: 'ticket_id', action: 'null',
    where: "c.related_type IN ('ticket', 'admin_ticket')"
  },
  { table: 'chat_transfers', column: 'message_id', refTable: 'chat_messages', refColumn: 'message_id', action: 'null' },
  // 刪除一對一聊天室時轉帳紀錄屬帳務資料，刻意保留，因此只列出。
  { table: 'chat_transfers', column: 'room_id', refTable: 'chat_rooms', refColumn: 'room_id', action: 'report' },
  { table: 'ai_support_sessions', column: 'ticket_id', refTable: 'support_tickets', refColumn: 'ticket_id', action: 'null' },
  { table: 'ai_usage_logs', column: 'user_id', refTable: 'users', refColumn: 'user_id', action: 'null' },
  { table: 'chat_mentions', column: 'room_id', refTable: 'chat_rooms', refColumn: 'room_id', action: 'delete' },
  { table: 'chat_mentions', column: 'user_id', refTable: 'users', refColumn: 'user_id', action: 'delete' },
  { table: 'oauth_states', column: 'user_id', refTable: 'users', refColumn: 'user_id', action: 'delete' },
  { table: 'webauthn_challenges', column: 'user_id', refTable: 'users', refColumn: 'user_id', action: 'delete' },
  {
    table: 'ai_embeddings', column: 'ref_id', refTable: 'books', refColumn: 'book_id', action: 'delete',
    where: "c.kind = 'book'", cast: true
  },
  { table: 'reports', column: 'target_id', refTable: 'users', refColumn: 'user_id', action: 'report', where: "c.target_type = 'user'" },
  { table: 'reports', column: 'target_id', refTable: 'books', refColumn: 'book_id', action: 'report', where: "c.target_type = 'book'" },
  {
    table: 'reports', column: 'target_id', refTable: 'chat_messages', refColumn: 'message_id', action: 'report',
    where: "c.target_type = 'message'"
  }
];

// 帳務與稽核資料：即使關聯失效也不自動刪除或清空，避免帳目對不上。
const PROTECTED = new Set([
  'wallets', 'wallet_transactions', 'orders', 'order_items', 'refund_records', 'transaction_disputes',
  'chat_transfers', 'admin_operation_logs', 'db_backups', 'bankbooks'
]);

const SAMPLE_LIMIT = 5;
const MAX_PASSES = 5;

const RULE_SQL = { Cascade: 'CASCADE', SetNull: 'SET NULL', NoAction: 'NO ACTION', Restrict: 'RESTRICT' };

const planFor = (rel) => {
  if (PROTECTED.has(rel.table)) return 'report';
  if (rel.action) return rel.action;
  if (rel.onDelete === 'Cascade') return 'delete';
  if (rel.nullable) return 'null';
  return 'report';
};

const refExpr = (rel) => (rel.cast ? `CAST(c.${rel.column} AS UNSIGNED)` : `c.${rel.column}`);

// 自我參照時 MySQL 不允許在 UPDATE／DELETE 的子查詢讀同一張表（錯誤 1093），改用不會被合併的衍生資料表。
const refSource = (rel) => (rel.table === rel.refTable
  ? `(SELECT DISTINCT ${rel.refColumn} FROM ${rel.refTable})`
  : rel.refTable);

const orphanWhere = (rel) => [
  `c.${rel.column} IS NOT NULL`,
  rel.table === 'chat_messages' && rel.column === 'reply_to_id' ? 'c.reply_to_id <> 0' : null,
  `NOT EXISTS (SELECT 1 FROM ${refSource(rel)} p WHERE p.${rel.refColumn} = ${refExpr(rel)})`,
  rel.where ?? null
].filter(Boolean).join(' AND ');

const pkOf = async (db, table) => {
  const rows = await db.$queryRawUnsafe(
    `SELECT COLUMN_NAME AS name FROM information_schema.KEY_COLUMN_USAGE
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND CONSTRAINT_NAME = 'PRIMARY' ORDER BY ORDINAL_POSITION`,
    table
  );
  return rows.map((r) => r.name);
};

const loadSchema = async (db) => {
  const [tables, columns, fks] = await Promise.all([
    db.$queryRawUnsafe(
      'SELECT TABLE_NAME AS name, ENGINE AS engine FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE()'
    ),
    db.$queryRawUnsafe(
      'SELECT TABLE_NAME AS tbl, COLUMN_NAME AS col FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE()'
    ),
    db.$queryRawUnsafe(
      `SELECT k.TABLE_NAME AS tbl, k.COLUMN_NAME AS col, k.REFERENCED_TABLE_NAME AS ref_tbl, k.CONSTRAINT_NAME AS name
       FROM information_schema.KEY_COLUMN_USAGE k
       WHERE k.TABLE_SCHEMA = DATABASE() AND k.REFERENCED_TABLE_NAME IS NOT NULL`
    )
  ]);
  return {
    engines: new Map(tables.map((t) => [t.name, String(t.engine ?? '')])),
    columns: new Set(columns.map((c) => `${c.tbl}.${c.col}`)),
    fks: fks.map((f) => ({ table: f.tbl, column: f.col, refTable: f.ref_tbl, name: f.name })),
    fkNames: new Set(fks.map((f) => f.name))
  };
};

const countOrphans = async (db, rel) => {
  const [row] = await db.$queryRawUnsafe(`SELECT COUNT(*) AS n FROM ${rel.table} c WHERE ${orphanWhere(rel)}`);
  return Number(row?.n ?? 0);
};

const sampleOrphans = async (db, rel) => {
  const pk = await pkOf(db, rel.table);
  const cols = [...new Set([...pk, rel.column])];
  const rows = await db.$queryRawUnsafe(
    `SELECT ${cols.map((c) => `c.${c}`).join(', ')} FROM ${rel.table} c WHERE ${orphanWhere(rel)} LIMIT ${SAMPLE_LIMIT}`
  );
  return rows.map((r) => cols.map((c) => `${c}=${r[c]}`).join(' '));
};

const inspect = async (db) => {
  const schema = await loadSchema(db);
  const all = [
    ...RELATIONS.map((r) => ({ ...r, kind: 'fk' })),
    ...SOFT.map((r) => ({ ...r, kind: 'soft' }))
  ];
  const results = [];
  for (const rel of all) {
    const result = { ...rel, plan: planFor(rel), orphans: 0, samples: [], issues: [] };
    const missingTable = [rel.table, rel.refTable].find((t) => !schema.engines.has(t));
    if (missingTable) {
      result.issues.push(`資料表 ${missingTable} 不存在（與 prisma/schema.prisma 不一致）`);
      result.skipped = true;
      results.push(result);
      continue;
    }
    if (!schema.columns.has(`${rel.table}.${rel.column}`)) {
      result.issues.push(`欄位 ${rel.table}.${rel.column} 不存在`);
      result.skipped = true;
      results.push(result);
      continue;
    }
    if (rel.kind === 'fk') {
      const found = schema.fks.find((f) => f.table === rel.table && f.column === rel.column && f.refTable === rel.refTable);
      result.constraint = found?.name ?? null;
      if (!found) result.issues.push('缺少外鍵');
      for (const t of [rel.table, rel.refTable]) {
        const engine = schema.engines.get(t);
        if (engine && engine.toLowerCase() !== 'innodb') result.issues.push(`${t} 使用 ${engine} 引擎，無法建立外鍵`);
      }
    }
    result.orphans = await countOrphans(db, rel);
    if (result.orphans > 0) result.samples = await sampleOrphans(db, rel);
    results.push(result);
  }
  return { schema, results };
};

const applyFix = async (db, rel) => {
  if (rel.plan === 'null') {
    return db.$executeRawUnsafe(`UPDATE ${rel.table} c SET c.${rel.column} = NULL WHERE ${orphanWhere(rel)}`);
  }
  if (rel.plan === 'delete') return db.$executeRawUnsafe(`DELETE c FROM ${rel.table} c WHERE ${orphanWhere(rel)}`);
  return 0;
};

// 刪除孤兒資料可能讓下一層資料變成孤兒（例如失效的訊息底下的提及），因此重複檢查到沒有變化為止。
const repair = async (db, results) => {
  const fixed = new Map();
  let targets = results.filter((r) => !r.skipped && r.orphans > 0 && r.plan !== 'report');
  for (let pass = 0; pass < MAX_PASSES && targets.length > 0; pass += 1) {
    let changed = 0;
    for (const rel of targets) {
      // 其他資料仍參照這些孤兒資料時（例如訂單明細參照已失效的書籍）刪除會被外鍵擋下，記錄後改列為需人工確認。
      try {
        const n = Number(await applyFix(db, rel)) || 0;
        if (n > 0) fixed.set(rel, (fixed.get(rel) ?? 0) + n);
        changed += n;
      } catch (err) {
        rel.plan = 'report';
        rel.issues.push(`自動清理失敗：${err.message.split('\n')[0]}`);
      }
    }
    if (changed === 0) break;
    const next = [];
    for (const rel of results.filter((r) => !r.skipped && r.plan !== 'report')) {
      if ((await countOrphans(db, rel)) > 0) next.push(rel);
    }
    targets = next;
  }
  return fixed;
};

const constraintSql = (rel, name) => `ALTER TABLE ${rel.table} ADD CONSTRAINT ${name} FOREIGN KEY (${rel.column})
  REFERENCES ${rel.refTable} (${rel.refColumn}) ON DELETE ${RULE_SQL[rel.onDelete] ?? 'NO ACTION'} ON UPDATE NO ACTION`;

const addConstraints = async (db, results, schema) => {
  const out = [];
  for (const rel of results.filter((r) => r.kind === 'fk' && !r.skipped && !r.constraint)) {
    if (rel.issues.some((i) => i.includes('引擎'))) {
      out.push({ rel, ok: false, message: '資料表引擎不支援外鍵，請先轉為 InnoDB' });
      continue;
    }
    if ((await countOrphans(db, rel)) > 0) {
      out.push({ rel, ok: false, message: '仍有孤兒資料，須先人工處理' });
      continue;
    }
    const name = schema.fkNames.has(rel.name) ? `${rel.name}_${Date.now().toString(36)}` : rel.name;
    try {
      await db.$executeRawUnsafe(constraintSql(rel, name));
      schema.fkNames.add(name);
      out.push({ rel, ok: true, message: name });
    } catch (err) {
      out.push({ rel, ok: false, message: err.message.split('\n')[0] });
    }
  }
  return out;
};

const PLAN_LABELS = { delete: '刪除', null: '清空欄位', report: '需人工確認' };

const label = (r) => `${r.table}.${r.column} → ${r.refTable}.${r.refColumn}${r.where ? `（${r.where.replace(/c\./g, '')}）` : ''}`;

const printReport = ({ results }, log = console.log) => {
  const checked = results.filter((r) => !r.skipped);
  const missingFk = checked.filter((r) => r.kind === 'fk' && !r.constraint);
  const orphaned = checked.filter((r) => r.orphans > 0);
  const skipped = results.filter((r) => r.skipped);

  log(`檢查關聯 ${results.length} 項（外鍵 ${RELATIONS.length}、無外鍵的參照 ${SOFT.length}）`);
  log(`  缺少外鍵：${missingFk.length} 項`);
  log(`  有孤兒資料：${orphaned.length} 項，共 ${orphaned.reduce((s, r) => s + r.orphans, 0)} 筆`);
  log(`  無法檢查：${skipped.length} 項`);

  if (missingFk.length) {
    log('\n【缺少外鍵】');
    for (const r of missingFk) log(`  - ${label(r)}（預期名稱 ${r.name}）${r.issues.filter((i) => i.includes('引擎')).map((i) => `；${i}`).join('')}`);
  }
  if (orphaned.length) {
    log('\n【孤兒資料】');
    for (const r of orphaned) {
      log(`  - ${label(r)}：${r.orphans} 筆，處理方式：${PLAN_LABELS[r.plan]}`);
      for (const issue of r.issues.filter((i) => i.startsWith('自動清理失敗'))) log(`      ${issue}`);
      if (r.samples.length) log(`      例：${r.samples.join('；')}`);
    }
  }
  if (skipped.length) {
    log('\n【無法檢查】');
    for (const r of skipped) log(`  - ${label(r)}：${r.issues.join('、')}`);
  }
  return { missingFk: missingFk.length, orphanRelations: orphaned.length, skipped: skipped.length };
};

const main = async () => {
  const prisma = require('../lib/prisma');
  const fix = process.argv.includes('--fix');
  const withConstraints = process.argv.includes('--add-constraints');
  const skipBackup = process.argv.includes('--skip-backup');
  try {
    const report = await inspect(prisma);
    const summary = printReport(report);

    if (!fix) {
      if (summary.orphanRelations || summary.missingFk) {
        console.log('\n尚未修改任何資料。確認後執行 --fix 清理孤兒資料；加上 --add-constraints 會在清理後補建外鍵。');
      } else {
        console.log('\n所有關聯皆正常。');
      }
      return;
    }

    if (!skipBackup) {
      const backup = require('../services/backup');
      console.log('\n正在備份資料庫…');
      try {
        const record = await backup.run({ trigger: 'integrity' });
        console.log(`備份完成：${record.file_name}`);
      } catch (err) {
        console.error(`❌ 備份失敗，未修改任何資料：${err.message}`);
        console.error('請先確認 mysqldump 可以使用；若已自行備份，可加上 --skip-backup 略過。');
        process.exitCode = 1;
        return;
      }
    }

    const fixed = await repair(prisma, report.results);
    console.log('\n【清理結果】');
    if (fixed.size === 0) console.log('  沒有需要自動清理的資料');
    for (const [rel, n] of fixed) console.log(`  - ${label(rel)}：${PLAN_LABELS[rel.plan]} ${n} 筆`);

    if (withConstraints) {
      const added = await addConstraints(prisma, report.results, report.schema);
      console.log('\n【補建外鍵】');
      if (added.length === 0) console.log('  沒有缺少的外鍵');
      for (const a of added) console.log(`  ${a.ok ? '✔' : '✘'} ${label(a.rel)}：${a.message}`);
    }

    const after = await inspect(prisma);
    console.log('\n【整理後】');
    printReport(after);
  } finally {
    await prisma.$disconnect();
  }
};

if (require.main === module) {
  main().catch((err) => {
    console.error('❌ 執行失敗：', err.message);
    process.exitCode = 1;
  });
}

module.exports = { RELATIONS, SOFT, PROTECTED, planFor, orphanWhere, constraintSql, inspect, repair, addConstraints, printReport };
