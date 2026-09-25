const assert = require('assert');
const {
  request: send, prisma, api, ok, addUser, openRoom, createGroup, balanceOf, notificationsFor, paymentHeaders
} = require('./harness');

const PAYMENT_PATH = /\/transfers(\/\d+\/pay)?$/;

const request = (method, url, options = {}) => {
  const user = options.token && PAYMENT_PATH.test(url) ? prisma.rows('users').find((u) => u.token === options.token) : null;
  return send(method, url, user ? { ...options, headers: { ...paymentHeaders(user), ...options.headers } } : options);
};

const transferRecords = api('services/chat/transfer-records');

const txnTypes = (userId) => {
  const wallet = prisma.rows('wallets').find((w) => w.user_id === userId);
  return prisma.rows('wallet_transactions').filter((t) => t.wallet_id === wallet?.wallet_id);
};

const transferRow = (id) => prisma.rows('chat_transfers').find((t) => t.transfer_id === id);

const pair = async ({ from = 500, to = 0 } = {}) => {
  const payer = addUser({ nickname: '付款人', balance: from });
  const payee = addUser({ nickname: '收款人', balance: to });
  return { payer, payee, roomId: await openRoom(payer, payee.user_id) };
};

const tests = [
  ['轉帳會同時異動雙方餘額並留下交易紀錄與卡片訊息', async () => {
    const { payer, payee, roomId } = await pair({ from: 500, to: 30 });

    const res = await request('POST', `/api/chat/rooms/${roomId}/transfers`, {
      token: payer.token, body: { to_user_id: payee.user_id, amount: 120, note: '書款' }
    });
    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.message, '轉帳完成');
    assert.strictEqual(res.body.data.transfer.kind, 'transfer');
    assert.strictEqual(res.body.data.transfer.status, 'completed');
    assert.strictEqual(res.body.data.transfer.amount, 120);
    assert.strictEqual(res.body.data.transfer.note, '書款');
    assert.strictEqual(res.body.data.transfer.expires_at, null);
    assert.ok(res.body.data.transfer.transfer_no);
    assert.strictEqual(res.body.data.message.kind, 'transfer');

    assert.strictEqual(balanceOf(payer.user_id), 380);
    assert.strictEqual(balanceOf(payee.user_id), 150);

    const out = txnTypes(payer.user_id);
    assert.deepStrictEqual(out.map((t) => t.type), ['transfer_out']);
    assert.strictEqual(out[0].amount, -120);
    assert.strictEqual(out[0].balance_after, 380);
    assert.strictEqual(out[0].description, '轉帳給 收款人');
    const income = txnTypes(payee.user_id);
    assert.deepStrictEqual(income.map((t) => t.type), ['transfer_in']);
    assert.strictEqual(income[0].description, '付款人 轉帳');

    const wallets = prisma.rows('wallets');
    assert.strictEqual(wallets.find((w) => w.user_id === payer.user_id).total_expense, 120);
    assert.strictEqual(wallets.find((w) => w.user_id === payee.user_id).total_income, 120);

    assert.strictEqual(notificationsFor(payee.user_id).at(-1).content, '[轉帳] 120 代幣');
  }],

  ['餘額不足時轉帳會整筆失敗', async () => {
    const { payer, payee, roomId } = await pair({ from: 50 });

    const res = await request('POST', `/api/chat/rooms/${roomId}/transfers`, {
      token: payer.token, body: { to_user_id: payee.user_id, amount: 100 }
    });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.code, 'INSUFFICIENT_BALANCE');
    assert.strictEqual(res.body.message, '代幣餘額不足');
    assert.strictEqual(balanceOf(payer.user_id), 50);
    assert.strictEqual(balanceOf(payee.user_id), 0);
    assert.strictEqual(prisma.rows('chat_transfers').length, 0);
  }],

  ['轉帳的參數檢查', async () => {
    const { payer, payee, roomId } = await pair();
    const outsider = addUser();

    const cases = [
      [{ to_user_id: payee.user_id, amount: 0 }, '金額必須是 1 ~ 100000 之間的整數'],
      [{ to_user_id: payee.user_id, amount: 100001 }, '金額必須是 1 ~ 100000 之間的整數'],
      [{ to_user_id: payee.user_id, amount: 10, note: 'a'.repeat(101) }, '備註不可超過 100 個字'],
      [{ to_user_id: payer.user_id, amount: 10 }, '無法轉帳給自己'],
      [{ to_user_id: outsider.user_id, amount: 10 }, '對象不是此聊天室的成員']
    ];
    for (const [body, message] of cases) {
      const res = await request('POST', `/api/chat/rooms/${roomId}/transfers`, { token: payer.token, body });
      assert.strictEqual(res.status, 400, `${message} 應回 400，實際 ${res.status}`);
      assert.strictEqual(res.body.message, message);
    }
  }],

  ['一對一聊天室可省略對象，預設為另一方', async () => {
    const { payer, payee, roomId } = await pair({ from: 300 });

    const transfer = ok(await request('POST', `/api/chat/rooms/${roomId}/transfers`, {
      token: payer.token, body: { amount: 40 }
    })).data.transfer;
    assert.strictEqual(transfer.to_user_id, payee.user_id);
    assert.strictEqual(balanceOf(payee.user_id), 40);

    const requested = ok(await request('POST', `/api/chat/rooms/${roomId}/transfer-requests`, {
      token: payee.token, body: { amount: 20 }
    })).data.transfer;
    assert.strictEqual(requested.from_user_id, payer.user_id);
    assert.strictEqual(requested.to_user_id, payee.user_id);
  }],

  ['請款會建立待處理紀錄並附上到期時間', async () => {
    const { payer, payee, roomId } = await pair();

    const res = await request('POST', `/api/chat/rooms/${roomId}/transfer-requests`, {
      token: payee.token, body: { from_user_id: payer.user_id, amount: 200, note: '上次的書' }
    });
    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.message, '已送出請款');
    const { transfer } = res.body.data;
    assert.strictEqual(transfer.kind, 'request');
    assert.strictEqual(transfer.status, 'pending');
    assert.strictEqual(transfer.from_user_id, payer.user_id);
    assert.strictEqual(transfer.to_user_id, payee.user_id);
    const ttl = new Date(transfer.expires_at).getTime() - new Date(transfer.created_at).getTime();
    assert.strictEqual(ttl, 72 * 60 * 60 * 1000);

    assert.strictEqual(balanceOf(payer.user_id), 500);
    assert.strictEqual(notificationsFor(payer.user_id).at(-1).content, '[請款] 200 代幣');

    const list = ok(await request('GET', '/api/chat/rooms', { token: payer.token }));
    assert.strictEqual(list.data[0].last_message.preview, '[請款]');
  }],

  ['付款方支付請款後金額才會移動', async () => {
    const { payer, payee, roomId } = await pair({ from: 500 });
    const { transfer } = ok(await request('POST', `/api/chat/rooms/${roomId}/transfer-requests`, {
      token: payee.token, body: { from_user_id: payer.user_id, amount: 200 }
    })).data;

    const res = ok(await request('POST', `/api/chat/transfers/${transfer.transfer_id}/pay`, { token: payer.token }));
    assert.strictEqual(res.message, '付款完成');
    assert.strictEqual(res.data.transfer.status, 'completed');
    assert.ok(res.data.transfer.responded_at);
    assert.strictEqual(balanceOf(payer.user_id), 300);
    assert.strictEqual(balanceOf(payee.user_id), 200);
    assert.strictEqual(notificationsFor(payee.user_id).at(-1).content, '已支付請款 200 代幣');

    const again = await request('POST', `/api/chat/transfers/${transfer.transfer_id}/pay`, { token: payer.token });
    assert.strictEqual(again.status, 409);
    assert.strictEqual(again.body.code, 'TRANSFER_STATE_CHANGED');
    assert.strictEqual(again.body.message, '此筆請款狀態已變更，請重新整理');
    assert.strictEqual(balanceOf(payer.user_id), 300);
  }],

  ['婉拒與取消請款', async () => {
    const { payer, payee, roomId } = await pair();
    const declined = ok(await request('POST', `/api/chat/rooms/${roomId}/transfer-requests`, {
      token: payee.token, body: { from_user_id: payer.user_id, amount: 50 }
    })).data.transfer;
    const cancelled = ok(await request('POST', `/api/chat/rooms/${roomId}/transfer-requests`, {
      token: payee.token, body: { from_user_id: payer.user_id, amount: 60 }
    })).data.transfer;

    const declineRes = ok(await request('POST', `/api/chat/transfers/${declined.transfer_id}/decline`, { token: payer.token }));
    assert.strictEqual(declineRes.message, '已婉拒請款');
    assert.strictEqual(declineRes.data.transfer.status, 'declined');
    assert.strictEqual(notificationsFor(payee.user_id).at(-1).content, '已婉拒請款 50 代幣');

    const cancelRes = ok(await request('POST', `/api/chat/transfers/${cancelled.transfer_id}/cancel`, { token: payee.token }));
    assert.strictEqual(cancelRes.message, '已取消請款');
    assert.strictEqual(cancelRes.data.transfer.status, 'cancelled');

    assert.strictEqual(balanceOf(payer.user_id), 500);
    assert.strictEqual(balanceOf(payee.user_id), 0);
  }],

  ['只有指定的角色可以回應請款', async () => {
    const { payer, payee, roomId } = await pair();
    const outsider = addUser({ balance: 100 });
    const { transfer } = ok(await request('POST', `/api/chat/rooms/${roomId}/transfer-requests`, {
      token: payee.token, body: { from_user_id: payer.user_id, amount: 80 }
    })).data;

    const wrongPay = await request('POST', `/api/chat/transfers/${transfer.transfer_id}/pay`, { token: payee.token });
    assert.strictEqual(wrongPay.status, 403);
    assert.strictEqual(wrongPay.body.message, '僅付款方可支付此請款');

    const wrongDecline = await request('POST', `/api/chat/transfers/${transfer.transfer_id}/decline`, { token: payee.token });
    assert.strictEqual(wrongDecline.status, 403);
    assert.strictEqual(wrongDecline.body.message, '僅付款方可婉拒此請款');

    const wrongCancel = await request('POST', `/api/chat/transfers/${transfer.transfer_id}/cancel`, { token: payer.token });
    assert.strictEqual(wrongCancel.status, 403);
    assert.strictEqual(wrongCancel.body.message, '僅請款人可取消此請款');

    const stranger = await request('POST', `/api/chat/transfers/${transfer.transfer_id}/pay`, { token: outsider.token });
    assert.strictEqual(stranger.status, 404);
    assert.strictEqual(stranger.body.message, '找不到此筆請款');

    const missing = await request('POST', '/api/chat/transfers/999999/pay', { token: payer.token });
    assert.strictEqual(missing.status, 404);
    assert.strictEqual(missing.body.message, '找不到此筆請款');
  }],

  ['過期的請款會被排程標記並且無法再支付', async () => {
    const { payer, payee, roomId } = await pair();
    const { transfer } = ok(await request('POST', `/api/chat/rooms/${roomId}/transfer-requests`, {
      token: payee.token, body: { from_user_id: payer.user_id, amount: 90 }
    })).data;
    transferRow(transfer.transfer_id).expires_at = new Date(Date.now() - 1000);

    assert.strictEqual(await transferRecords.expireDue(), 1);
    assert.strictEqual(transferRow(transfer.transfer_id).status, 'expired');

    const res = await request('POST', `/api/chat/transfers/${transfer.transfer_id}/pay`, { token: payer.token });
    assert.strictEqual(res.status, 409);
    assert.strictEqual(res.body.code, 'TRANSFER_STATE_CHANGED');
    assert.strictEqual(balanceOf(payer.user_id), 500);

    // 已結案的紀錄不會被排程重複處理。
    assert.strictEqual(await transferRecords.expireDue(), 0);
  }],

  ['尚未過期時排程不會動到請款', async () => {
    const { payer, payee, roomId } = await pair();
    ok(await request('POST', `/api/chat/rooms/${roomId}/transfer-requests`, {
      token: payee.token, body: { from_user_id: payer.user_id, amount: 90 }
    }));
    assert.strictEqual(await transferRecords.expireDue(), 0);
    assert.strictEqual(prisma.rows('chat_transfers')[0].status, 'pending');
  }],

  ['群組內轉帳必須指定聊天室成員', async () => {
    const payer = addUser({ nickname: '付款人', balance: 300 });
    const payee = addUser({ nickname: '收款人', balance: 0 });
    const outsider = addUser();
    const roomId = await createGroup(payer, [payee.user_id]);

    const noTarget = await request('POST', `/api/chat/rooms/${roomId}/transfers`, {
      token: payer.token, body: { amount: 50 }
    });
    assert.strictEqual(noTarget.status, 400);
    assert.strictEqual(noTarget.body.message, '請指定對象');

    const notMember = await request('POST', `/api/chat/rooms/${roomId}/transfers`, {
      token: payer.token, body: { to_user_id: outsider.user_id, amount: 50 }
    });
    assert.strictEqual(notMember.status, 400);
    assert.strictEqual(notMember.body.message, '對象不是此聊天室的成員');

    const okRes = await request('POST', `/api/chat/rooms/${roomId}/transfers`, {
      token: payer.token, body: { to_user_id: payee.user_id, amount: 50 }
    });
    assert.strictEqual(okRes.status, 201);
    assert.strictEqual(balanceOf(payee.user_id), 50);
  }],

  ['封鎖或對方停用時無法轉帳', async () => {
    const { payer, payee, roomId } = await pair();
    ok(await request('PUT', `/api/chat/blocks/${payee.user_id}`, { token: payer.token }));

    const blocked = await request('POST', `/api/chat/rooms/${roomId}/transfers`, {
      token: payer.token, body: { to_user_id: payee.user_id, amount: 10 }
    });
    assert.strictEqual(blocked.status, 403);
    assert.strictEqual(blocked.body.code, 'CHAT_BLOCKED');

    ok(await request('DELETE', `/api/chat/blocks/${payee.user_id}`, { token: payer.token }));
    prisma.rows('users').find((u) => u.user_id === payee.user_id).is_active = false;
    const unavailable = await request('POST', `/api/chat/rooms/${roomId}/transfers`, {
      token: payer.token, body: { to_user_id: payee.user_id, amount: 10 }
    });
    assert.strictEqual(unavailable.status, 400);
    assert.strictEqual(unavailable.body.code, 'RECIPIENT_UNAVAILABLE');
    assert.strictEqual(balanceOf(payer.user_id), 500);
  }]
];

module.exports = { name: '轉帳與請款', tests };
