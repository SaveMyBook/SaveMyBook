const assert = require('assert');
const h = require('./session-harness');

const { prisma } = h;

const patchStatus = (token, orderId, status) => h.request('PATCH', `/api/orders/${orderId}/status`, { token, body: { status } });
const depositBook = (token, bookId) => h.request('POST', `/api/books/${bookId}/deposit`, { token });
const retrieveBook = (token, bookId) => h.request('POST', `/api/books/${bookId}/retrieve`, { token });
const confirm = (ctx, no, note, { slotId, token = ctx.adminToken } = {}) => h.request('POST', `/api/admin/cabinet-manual-reports/${no}/confirm`, {
  token, body: { ...(note ? { note } : {}), ...(slotId ? { slot_id: slotId } : {}) }
});
const reject = (ctx, no, note, { token = ctx.adminToken } = {}) => h.request('POST', `/api/admin/cabinet-manual-reports/${no}/reject`, { token, body: { note } });
const buyNow = (token, bookId) => h.request('POST', '/api/orders/buy-now', {
  token, headers: h.verifyHeaders(token, 'payment'), body: { book_id: bookId }
});
const reports = () => prisma.rows('cabinet_manual_reports');

const goOffline = (ctx) => { h.deviceRow(ctx.device.device_id).last_seen_at = h.ago(130000); };

const addDeposit = (ctx, book, channel) => {
  prisma.rows('book_deposits').push({
    book_id: book.book_id, cabinet_id: ctx.cabinet.cabinet_id, deposited_at: new Date(), paused_at: null,
    auto_paused: false, reminded_at: null, escalated_at: null
  });
  if (channel) h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, channel).slot_id);
};

module.exports = {
  name: '書櫃故障備援：手動回報待客服確認',
  tests: [
    ['裝置在線時，一般使用者的手動回報一律回 CABINET_SCAN_REQUIRED', async () => {
      const ctx = h.scene();
      const listed = h.listedBook(ctx);
      const stored = h.listedBook(ctx);
      addDeposit(ctx, stored, 2);
      const sold = h.listedBook(ctx);
      const order = h.orderFor(ctx, sold.book_id);

      for (const res of [
        await patchStatus(ctx.sellerToken, order.order_id, 'deposited'),
        await depositBook(ctx.sellerToken, listed.book_id),
        await retrieveBook(ctx.sellerToken, stored.book_id)
      ]) {
        assert.strictEqual(res.status, 409, res.text);
        assert.strictEqual(res.body.code, 'CABINET_SCAN_REQUIRED');
        assert.strictEqual(res.body.message, '此書櫃已啟用掃碼存取，請至書櫃以 App 掃描 QR Code 辦理');
        assert.strictEqual(res.body.cabinet_id, ctx.cabinet.cabinet_id);
      }
      h.orderOf(order.order_id).status = 'deposited';
      const pickup = await patchStatus(ctx.buyerToken, order.order_id, 'picked_up');
      assert.strictEqual(pickup.body.code, 'CABINET_SCAN_REQUIRED');
      const legacy = await patchStatus(ctx.buyerToken, order.order_id, 'completed');
      assert.strictEqual(legacy.body.code, 'CABINET_SCAN_REQUIRED');
      assert.strictEqual(reports().length, 0);
    }],

    ['有裝置而維修中或停用時為 CABINET_MAINTENANCE／CABINET_UNAVAILABLE', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id);
      goOffline(ctx);
      h.cabinetRow(ctx.cabinet.cabinet_id).is_maintenance = 1;
      const maintenance = await patchStatus(ctx.sellerToken, order.order_id, 'deposited');
      assert.strictEqual(maintenance.body.code, 'CABINET_MAINTENANCE');
      h.cabinetRow(ctx.cabinet.cabinet_id).is_maintenance = 0;
      h.cabinetRow(ctx.cabinet.cabinet_id).is_active = false;
      const inactive = await patchStatus(ctx.sellerToken, order.order_id, 'deposited');
      assert.strictEqual(inactive.body.code, 'CABINET_UNAVAILABLE');
    }],

    ['從未配對裝置的書櫃：手動回報同樣待客服確認；書櫃沒有櫃門時確認不需指定櫃門', async () => {
      const admin = h.addAdmin();
      const cabinet = h.addCabinet({ name: '一般書櫃' });
      const seller = h.addUser();
      const buyer = h.addUser();
      const book = h.addBook({ sellerId: seller.user_id, cabinet_id: cabinet.cabinet_id, status: 'reserved' });
      const order = h.addPaidOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: book.book_id, cabinetId: cabinet.cabinet_id });
      const res = await patchStatus(h.tokenFor(seller), order.order_id, 'deposited');
      assert.strictEqual(res.status, 202, res.text);
      assert.strictEqual(res.body.data.manual_report.reason, 'no_device');
      assert.strictEqual(h.orderOf(order.order_id).status, 'pending_deposit');
      assert.strictEqual(h.notificationsOf(buyer.user_id).length, 0);
      assert.strictEqual(h.eventsOf('manual_report').length, 1);
      assert.ok(h.notificationsOf(admin.user_id).some((n) => n.title === '書櫃手動回報待確認'
        && n.content.includes('於未配對裝置期間收到存書的手動回報')));

      const done = await confirm({ adminToken: h.tokenFor(admin) }, res.body.data.manual_report.report_no);
      assert.strictEqual(done.status, 200, done.text);
      assert.strictEqual(h.orderOf(order.order_id).status, 'deposited');
      assert.ok(h.notificationsOf(buyer.user_id).some((n) => n.title === '書籍已存入書櫃'));
    }],

    ['裝置離線超過 2 分鐘：存書回報成為待確認，通知管理員；管理員確認後才改為已存書並通知買家', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id);
      goOffline(ctx);

      const res = await patchStatus(ctx.sellerToken, order.order_id, 'deposited');
      assert.strictEqual(res.status, 202, res.text);
      assert.strictEqual(res.body.message, '已送出手動回報，待客服確認後生效');
      assert.strictEqual(res.body.data.status, 'pending_deposit');
      const pending = res.body.data.manual_report;
      assert.strictEqual(pending.kind, 'deposit');
      assert.strictEqual(pending.status, 'pending');
      assert.strictEqual(pending.reason, 'offline');
      assert.strictEqual(pending.target_status, 'deposited');
      assert.ok(pending.report_no.startsWith('MR'));
      assert.strictEqual(res.body.data.cabinet_access.mode, 'manual');
      assert.strictEqual(h.orderOf(order.order_id).status, 'pending_deposit');
      assert.strictEqual(h.notificationsOf(ctx.buyer.user_id).length, 0);

      const notice = h.adminNotices(ctx, '書櫃手動回報待確認')[0];
      assert.strictEqual(notice.content, `「北商大書櫃」於裝置離線期間收到存書的手動回報（訂單 ${order.order_no}），請確認後於後台處理。`);
      assert.strictEqual(notice.related_type, 'cabinet');
      const event = h.eventsOf('manual_report')[0];
      assert.strictEqual(event.order_id, order.order_id);
      assert.strictEqual(JSON.parse(event.detail).kind, 'deposit');

      const detail = await h.request('GET', `/api/orders/${order.order_id}`, { token: ctx.sellerToken });
      assert.strictEqual(detail.body.data.manual_report.report_no, pending.report_no);
      const list = await h.request('GET', '/api/orders?role=seller', { token: ctx.sellerToken });
      assert.strictEqual(list.body.data[0].manual_report.status, 'pending');

      const again = await patchStatus(ctx.sellerToken, order.order_id, 'deposited');
      assert.strictEqual(again.status, 409);
      assert.strictEqual(again.body.code, 'MANUAL_REPORT_PENDING');

      const listed = await h.request('GET', `/api/admin/cabinets/${ctx.cabinet.cabinet_id}/manual-reports`, { token: ctx.adminToken });
      assert.strictEqual(listed.status, 200);
      assert.strictEqual(listed.body.data[0].report_no, pending.report_no);
      assert.strictEqual(listed.body.data[0].order.order_no, order.order_no);
      assert.strictEqual(listed.body.data[0].user.nickname, '賣家');

      const noDoor = await confirm(ctx, pending.report_no, '已與現場人員確認');
      assert.strictEqual(noDoor.status, 400);
      assert.strictEqual(noDoor.body.code, 'DOOR_REQUIRED');
      assert.strictEqual(noDoor.body.message, '請指定書籍存放的櫃門');
      const door = h.doorOf(ctx.cabinet.cabinet_id, 3);
      const confirmed = await confirm(ctx, pending.report_no, '已與現場人員確認', { slotId: door.slot_id });
      assert.strictEqual(confirmed.status, 200, confirmed.text);
      assert.strictEqual(h.slotItemOf(book.book_id).slot_id, door.slot_id);
      assert.strictEqual(h.slotItemOf(book.book_id).placed_by, 'admin');
      assert.strictEqual(door.status, 'occupied');
      assert.strictEqual(h.cabinetRow(ctx.cabinet.cabinet_id).available_slots, 3);
      assert.strictEqual(h.orderOf(order.order_id).slot_id, door.slot_id);
      assert.ok(h.eventsOf('door_placed').some((e) => e.lock_channel === 3));
      assert.strictEqual(confirmed.body.data.status, 'confirmed');
      assert.strictEqual(confirmed.body.data.reviewer_nickname, '客服人員');
      assert.strictEqual(h.orderOf(order.order_id).status, 'deposited');
      assert.ok(h.notificationsOf(ctx.buyer.user_id).some((n) => n.title === '書籍已存入書櫃'));
      assert.ok(h.notificationsOf(ctx.seller.user_id).some((n) => n.title === '手動回報已確認'
        && n.content === `您於「北商大書櫃」的存書手動回報（訂單 ${order.order_no}）已由客服確認。`));
      assert.ok(h.logs().some((l) => l.action === '確認書櫃手動回報'));
      assert.strictEqual(reports()[0].pending_key, null);

      const after = await h.request('GET', `/api/orders/${order.order_id}`, { token: ctx.sellerToken });
      assert.strictEqual(after.body.data.manual_report, null);
      const twice = await confirm(ctx, pending.report_no);
      assert.strictEqual(twice.status, 409);
      assert.strictEqual(twice.body.code, 'MANUAL_REPORT_NOT_PENDING');
    }],

    ['裝置故障超過 2 分鐘：取書回報待確認；駁回時狀態不變並通知回報者', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id, { status: 'deposited' });
      Object.assign(h.deviceRow(ctx.device.device_id), { fault_code: 'POWER', fault_since: h.ago(130000) });

      const res = await patchStatus(ctx.buyerToken, order.order_id, 'picked_up');
      assert.strictEqual(res.status, 202, res.text);
      assert.strictEqual(res.body.data.manual_report.reason, 'fault');
      assert.strictEqual(h.orderOf(order.order_id).picked_up_at, null);
      assert.ok(h.adminNotices(ctx, '書櫃手動回報待確認')[0].content.includes('裝置故障期間收到取書的手動回報'));

      const empty = await reject(ctx, res.body.data.manual_report.report_no, '');
      assert.strictEqual(empty.status, 400);
      const rejected = await reject(ctx, res.body.data.manual_report.report_no, '現場確認書籍仍在櫃內');
      assert.strictEqual(rejected.status, 200, rejected.text);
      assert.strictEqual(rejected.body.data.status, 'rejected');
      assert.strictEqual(h.orderOf(order.order_id).picked_up_at, null);
      assert.ok(h.notificationsOf(ctx.buyer.user_id).some((n) => n.title === '手動回報未通過確認'
        && n.content.endsWith('狀態未變更。說明：現場確認書籍仍在櫃內')));
      assert.strictEqual(h.notificationsOf(ctx.seller.user_id).filter((n) => n.title === '買家已取書').length, 0);

      const retry = await patchStatus(ctx.buyerToken, order.order_id, 'picked_up');
      assert.strictEqual(retry.status, 202);
    }],

    ['確認取書回報：記錄取書時間、通知賣家、刪除櫃內紀錄並把原櫃門設為待確認', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id, { status: 'deposited' });
      h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, 3).slot_id);
      goOffline(ctx);
      const res = await patchStatus(ctx.buyerToken, order.order_id, 'completed');
      assert.strictEqual(res.status, 202, res.text);
      assert.strictEqual(res.body.data.manual_report.target_status, 'completed');

      const confirmed = await confirm(ctx, res.body.data.manual_report.report_no);
      assert.strictEqual(confirmed.status, 200, confirmed.text);
      const current = h.orderOf(order.order_id);
      assert.ok(current.picked_up_at);
      assert.strictEqual(current.status, 'deposited');
      assert.ok(h.notificationsOf(ctx.seller.user_id).some((n) => n.title === '買家已取書'));
      assert.strictEqual(h.slotItemOf(book.book_id), null);
      assert.strictEqual(h.doorOf(ctx.cabinet.cabinet_id, 3).check_reason, 'MANUAL_REPORT');
    }],

    ['曾配對裝置而目前沒有裝置：先行存書與取回都成為待確認，書籍檢視顯示待確認', async () => {
      const ctx = h.scene();
      h.deviceRow(ctx.device.device_id).status = 'revoked';
      Object.assign(h.deviceRow(ctx.device.device_id), { active_cabinet_id: null, revoked_at: h.ago(600000), revoke_reason: 'admin' });
      const book = h.listedBook(ctx);
      const res = await depositBook(ctx.sellerToken, book.book_id);
      assert.strictEqual(res.status, 202, res.text);
      assert.strictEqual(res.body.data.in_cabinet, false);
      assert.strictEqual(res.body.data.deposit, null);
      assert.strictEqual(res.body.data.manual_report.reason, 'no_device');
      assert.strictEqual(h.depositOf(book.book_id), null);

      const own = await h.request('GET', `/api/books/${book.book_id}`, { token: ctx.sellerToken });
      assert.strictEqual(own.body.data.manual_report.kind, 'deposit');
      assert.strictEqual(own.body.data.cabinet_access.mode, 'manual');
      const store = await h.request('GET', `/api/books/${book.book_id}`, { token: ctx.buyerToken });
      assert.ok(!('manual_report' in store.body.data));

      const placed = await confirm(ctx, res.body.data.manual_report.report_no, null, { slotId: h.doorOf(ctx.cabinet.cabinet_id, 2).slot_id });
      assert.strictEqual(placed.status, 200, placed.text);
      assert.strictEqual(h.depositOf(book.book_id).cabinet_id, ctx.cabinet.cabinet_id);
      assert.strictEqual(h.slotItemOf(book.book_id).slot_id, h.doorOf(ctx.cabinet.cabinet_id, 2).slot_id);

      const back = await retrieveBook(ctx.sellerToken, book.book_id);
      assert.strictEqual(back.status, 202, back.text);
      assert.strictEqual(back.body.data.manual_report.kind, 'retrieve');
      assert.strictEqual(back.body.data.status, 'removed', '待確認期間暫停販售');
      assert.ok(h.depositOf(book.book_id));
      const done = await confirm(ctx, back.body.data.manual_report.report_no);
      assert.strictEqual(done.status, 200, done.text);
      assert.strictEqual(h.depositOf(book.book_id), null);
      assert.strictEqual(h.slotItemOf(book.book_id), null);
      assert.strictEqual(h.bookOf(book.book_id).status, 'on_sale', '取回上架中的書後維持上架');
      assert.strictEqual(reports().find((r) => r.kind === 'retrieve').held_on_sale, false);
      assert.strictEqual(h.doorOf(ctx.cabinet.cabinet_id, 2).check_reason, 'MANUAL_REPORT');
    }],

    ['有 cabinets 權限且非當事人的管理員可直接處理；是當事人或沒有權限的管理員比照一般使用者', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id);

      const limited = h.addAdmin({ can_manage_cabinets: false });
      const denied = await patchStatus(h.tokenFor(limited), order.order_id, 'deposited');
      assert.strictEqual(denied.body.code, 'CABINET_SCAN_REQUIRED');

      const partyBook = h.listedBook(ctx);
      const partyOrder = h.orderFor(ctx, partyBook.book_id, { buyer: ctx.admin });
      const party = await patchStatus(ctx.adminToken, partyOrder.order_id, 'deposited');
      assert.strictEqual(party.status, 403, '身為買家的管理員不得代替賣家回報存書');
      assert.strictEqual(party.body.message, '僅賣家可執行此操作');
      h.orderOf(partyOrder.order_id).status = 'deposited';
      const own = await patchStatus(ctx.adminToken, partyOrder.order_id, 'picked_up');
      assert.strictEqual(own.body.code, 'CABINET_SCAN_REQUIRED', '以本人身分操作時比照一般使用者');

      const staff = h.addAdmin();
      const ok = await patchStatus(h.tokenFor(staff), order.order_id, 'deposited');
      assert.strictEqual(ok.status, 200, ok.text);
      assert.strictEqual(h.orderOf(order.order_id).status, 'deposited');
      assert.strictEqual(reports().length, 0);
    }],

    ['項目狀態已變更時確認失敗：回 MANUAL_REPORT_STALE，回報改為失效', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id);
      goOffline(ctx);
      const res = await patchStatus(ctx.sellerToken, order.order_id, 'deposited');
      h.orderOf(order.order_id).status = 'cancelled';
      const stale = await confirm(ctx, res.body.data.manual_report.report_no, null, { slotId: h.doorOf(ctx.cabinet.cabinet_id, 1).slot_id });
      assert.strictEqual(stale.status, 409);
      assert.strictEqual(stale.body.code, 'MANUAL_REPORT_STALE');
      assert.strictEqual(reports()[0].status, 'cancelled');
      assert.strictEqual(reports()[0].pending_key, null);
      assert.strictEqual(h.notificationsOf(ctx.buyer.user_id).length, 0);
    }],

    ['裝置恢復後以掃碼完成存書時，待確認的手動回報隨之失效', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id);
      goOffline(ctx);
      const res = await patchStatus(ctx.sellerToken, order.order_id, 'deposited');
      assert.strictEqual(res.status, 202);
      h.deviceRow(ctx.device.device_id).last_seen_at = new Date();

      const { final } = await h.runSession(ctx, ctx.sellerToken);
      assert.strictEqual(final.status, 'completed');
      assert.strictEqual(reports()[0].status, 'cancelled');
      assert.strictEqual(reports()[0].review_note, '已於書櫃掃碼完成');
      assert.strictEqual(h.orderOf(order.order_id).status, 'deposited');
    }],

    ['管理員不得處理與本人相關的手動回報，也不得代替對方回報；由其他管理員確認', async () => {
      const ctx = h.scene();
      goOffline(ctx);
      const sellerAdmin = h.addAdmin();
      const sellerToken = h.tokenFor(sellerAdmin);
      const book = h.addBook({ sellerId: sellerAdmin.user_id, cabinet_id: ctx.cabinet.cabinet_id, status: 'reserved' });
      const order = h.addPaidOrder({
        buyerId: ctx.buyer.user_id, sellerId: sellerAdmin.user_id, bookId: book.book_id, cabinetId: ctx.cabinet.cabinet_id
      });

      const own = await patchStatus(sellerToken, order.order_id, 'deposited');
      assert.strictEqual(own.status, 202, own.text);
      const no = own.body.data.manual_report.report_no;
      const door = h.doorOf(ctx.cabinet.cabinet_id, 1);
      for (const res of [
        await confirm(ctx, no, null, { slotId: door.slot_id, token: sellerToken }),
        await reject(ctx, no, '自行駁回', { token: sellerToken })
      ]) {
        assert.strictEqual(res.status, 403, res.text);
        assert.strictEqual(res.body.code, 'MANUAL_REPORT_SELF_REVIEW');
        assert.strictEqual(res.body.message, '此手動回報與您本人相關，須由其他管理員處理');
      }
      assert.strictEqual(reports()[0].status, 'pending');
      assert.strictEqual(h.orderOf(order.order_id).status, 'pending_deposit');

      const confirmed = await confirm(ctx, no, null, { slotId: door.slot_id });
      assert.strictEqual(confirmed.status, 200, confirmed.text);
      assert.strictEqual(h.orderOf(order.order_id).status, 'deposited');

      const asBuyer = await patchStatus(sellerToken, order.order_id, 'picked_up');
      assert.strictEqual(asBuyer.status, 403, '身為賣家的管理員不得代替買家回報取書');
      const pickup = await patchStatus(ctx.buyerToken, order.order_id, 'picked_up');
      assert.strictEqual(pickup.status, 202, pickup.text);
      const counterpart = await confirm(ctx, pickup.body.data.manual_report.report_no, null, { token: sellerToken });
      assert.strictEqual(counterpart.body.code, 'MANUAL_REPORT_SELF_REVIEW', '訂單的賣家不得確認買家的取書回報');
      assert.strictEqual(h.orderOf(order.order_id).picked_up_at, null);
    }],

    ['確認存書時指定的櫃門須屬於本書櫃且沒有其他項目；不符時回報維持待確認', async () => {
      const ctx = h.scene();
      const other = h.listedBook(ctx);
      addDeposit(ctx, other, 2);
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id);
      goOffline(ctx);
      const res = await patchStatus(ctx.sellerToken, order.order_id, 'deposited');
      const no = res.body.data.manual_report.report_no;

      const elsewhere = h.addCabinet({ name: '公館書櫃' });
      h.syncDoors(elsewhere.cabinet_id, 4);
      const foreign = await confirm(ctx, no, null, { slotId: h.doorOf(elsewhere.cabinet_id, 1).slot_id });
      assert.strictEqual(foreign.status, 404);
      assert.strictEqual(foreign.body.code, 'DOOR_NOT_FOUND');

      const shared = await confirm(ctx, no, null, { slotId: h.doorOf(ctx.cabinet.cabinet_id, 2).slot_id });
      assert.strictEqual(shared.status, 409, shared.text);
      assert.strictEqual(shared.body.code, 'DOOR_ASSIGN_INVALID');
      assert.strictEqual(reports()[0].status, 'pending');
      assert.strictEqual(h.orderOf(order.order_id).status, 'pending_deposit');
      assert.strictEqual(h.slotItemOf(book.book_id), null);

      const ok = await confirm(ctx, no, null, { slotId: h.doorOf(ctx.cabinet.cabinet_id, 4).slot_id });
      assert.strictEqual(ok.status, 200, ok.text);
      assert.strictEqual(h.slotItemOf(book.book_id).slot_id, h.doorOf(ctx.cabinet.cabinet_id, 4).slot_id);
      assert.ok(h.logs().some((l) => l.action === '確認書櫃手動回報' && JSON.parse(l.detail).summary.includes('存放於櫃門 A04')));
    }],

    ['手動先行存書同樣受每位賣家上限與保留櫃門限制，待確認的回報與沒有櫃門紀錄的存書都計入', async () => {
      const ctx = h.scene();
      goOffline(ctx);
      const legacy = h.listedBook(ctx);
      addDeposit(ctx, legacy);
      const first = h.listedBook(ctx);
      const second = h.listedBook(ctx);

      const blocked = await depositBook(ctx.sellerToken, first.book_id);
      assert.strictEqual(blocked.status, 409, blocked.text);
      assert.strictEqual(blocked.body.code, 'PREDEPOSIT_LIMIT');
      assert.strictEqual(blocked.body.message, '您在此書櫃的先行存書已達上限，請待售出或取回後再存入');
      assert.strictEqual(reports().length, 0);

      prisma.store.book_deposits = prisma.rows('book_deposits').filter((r) => r.book_id !== legacy.book_id);
      const pending = await depositBook(ctx.sellerToken, first.book_id);
      assert.strictEqual(pending.status, 202, pending.text);
      const again = await depositBook(ctx.sellerToken, second.book_id);
      assert.strictEqual(again.body.code, 'PREDEPOSIT_LIMIT', '待確認的先行存書回報計入上限');
      const same = await depositBook(ctx.sellerToken, first.book_id);
      assert.strictEqual(same.body.code, 'MANUAL_REPORT_PENDING');

      h.deviceRow(ctx.device.device_id).last_seen_at = new Date();
      const scanned = await h.createSession(ctx, ctx.sellerToken);
      assert.strictEqual(scanned.status, 409, scanned.text);
      assert.strictEqual(scanned.body.code, 'CABINET_ITEM_BLOCKED');
      assert.ok(scanned.body.items.length >= 2 && scanned.body.items.every((i) => i.blocked.code === 'PREDEPOSIT_LIMIT'), JSON.stringify(scanned.body.items));
      goOffline(ctx);

      // 並行送出造成兩筆待確認時，第二筆於確認時仍受上限限制，回報維持待確認由管理員駁回。
      prisma.rows('cabinet_manual_reports').push({
        report_id: prisma.nextId('cabinet_manual_reports'), cabinet_id: ctx.cabinet.cabinet_id, user_id: ctx.seller.user_id,
        kind: 'deposit', order_id: null, book_id: second.book_id, target_status: null, reason: 'offline', status: 'pending',
        pending_key: `deposit:book:${second.book_id}`, held_on_sale: false, reviewed_by: null, reviewed_at: null, review_note: null,
        created_at: new Date(), updated_at: new Date()
      });
      const secondNo = h.publicId.encode('cabinet_manual_report', reports().at(-1).report_id);
      assert.strictEqual((await confirm(ctx, pending.body.data.manual_report.report_no, null, { slotId: h.doorOf(ctx.cabinet.cabinet_id, 1).slot_id })).status, 200);
      const over = await confirm(ctx, secondNo, null, { slotId: h.doorOf(ctx.cabinet.cabinet_id, 2).slot_id });
      assert.strictEqual(over.status, 409, over.text);
      assert.strictEqual(over.body.code, 'PREDEPOSIT_LIMIT');
      assert.strictEqual(reports().at(-1).status, 'pending');
      assert.strictEqual(h.depositOf(second.book_id), null);
    }],

    ['手動先行存書：可用櫃門只剩 1 扇時不接受，保留給依訂單存書', async () => {
      const ctx = h.scene();
      for (const channel of [1, 2, 3]) {
        const stored = h.addBook({ sellerId: h.addUser().user_id, cabinet_id: ctx.cabinet.cabinet_id });
        addDeposit(ctx, stored, channel);
      }
      goOffline(ctx);
      const book = h.listedBook(ctx);
      const res = await depositBook(ctx.sellerToken, book.book_id);
      assert.strictEqual(res.status, 409, res.text);
      assert.strictEqual(res.body.code, 'CABINET_FULL');
      assert.strictEqual(res.body.available_doors, 1);
      assert.strictEqual(reports().length, 0);

      const sold = h.listedBook(ctx);
      const order = h.orderFor(ctx, sold.book_id);
      const orderDeposit = await patchStatus(ctx.sellerToken, order.order_id, 'deposited');
      assert.strictEqual(orderDeposit.status, 202, '依訂單存書不受保留櫃門限制');
    }],

    ['取回回報待確認期間暫停販售；恢復連線後以掃碼完成取回時回報失效，書籍恢復上架', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      addDeposit(ctx, book, 2);
      goOffline(ctx);
      const res = await retrieveBook(ctx.sellerToken, book.book_id);
      assert.strictEqual(res.status, 202, res.text);
      assert.strictEqual(h.bookOf(book.book_id).status, 'removed');
      assert.strictEqual(reports()[0].held_on_sale, true);
      const bought = await buyNow(ctx.buyerToken, book.book_id);
      assert.strictEqual(bought.status, 400, bought.text);
      const listed = await h.request('GET', `/api/books/${book.book_id}`, { token: ctx.buyerToken });
      assert.strictEqual(listed.body.data.in_cabinet, false);

      h.deviceRow(ctx.device.device_id).last_seen_at = new Date();
      const { final } = await h.runSession(ctx, ctx.sellerToken, { keys: [`book:${book.book_id}`] });
      assert.strictEqual(final.status, 'completed', JSON.stringify(final));
      assert.strictEqual(reports()[0].status, 'cancelled');
      assert.strictEqual(reports()[0].held_on_sale, false);
      assert.strictEqual(h.bookOf(book.book_id).status, 'on_sale');
      assert.strictEqual(h.depositOf(book.book_id), null);
      assert.strictEqual(h.slotItemOf(book.book_id), null);
    }]
  ]
};
