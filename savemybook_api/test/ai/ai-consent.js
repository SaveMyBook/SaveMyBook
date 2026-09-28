const assert = require('assert');
const h = require('./harness');

const consent = h.api('services/ai/consent');
const support = h.api('services/ai/support');
const bookChat = h.api('services/ai/book-chat');
const embeddings = h.api('lib/ai/embeddings');
const { prisma, request } = h;

const DAY_MS = 24 * 60 * 60 * 1000;

const setPrivacyVersion = (version) => {
  prisma.store.legal_documents = [{ doc_id: 2, doc_key: 'privacy', title: '隱私權政策', content: '內容', version, requires_consent: 1 }];
};

// 匯出用的訊息查詢是 JOIN，迷你直譯器不支援，改由測試依記憶體資料表回答。
const answerJoins = () => {
  h.onSql(/FROM ai_support_messages m JOIN ai_support_sessions s/, (values) => {
    const userId = values[0];
    const sessionIds = prisma.rows('ai_support_sessions')
      .filter((s) => Number(s.user_id) === Number(userId))
      .map((s) => Number(s.session_id));
    return prisma.rows('ai_support_messages').filter((m) => sessionIds.includes(Number(m.session_id)));
  });
  h.onSql(/FROM ai_chat_messages m JOIN ai_chat_sessions s/, () => prisma.rows('ai_chat_messages'));
};

const enable = (userId, { granted = true, config = {} } = {}) => {
  h.setSettings({ enabled: true, ...config });
  if (granted !== null) h.setConsent(userId, granted);
};

module.exports = {
  name: 'AI 同意與客服對話',
  tests: [
    ['沒有同意紀錄時視為未同意', async () => {
      assert.strictEqual(await consent.isGranted(1), false);
      assert.strictEqual(await consent.isGranted(null), false);
      h.setConsent(1, false);
      assert.strictEqual(await consent.isGranted(1), false);
      h.setConsent(1, true);
      assert.strictEqual(await consent.isGranted(1), true);
    }],

    ['撤回同意會刪除該使用者的 AI 客服對話、書籍顧問對話與推薦快取，不影響其他使用者', async () => {
      const now = new Date();
      prisma.store.ai_recommendation_cache = [
        { user_id: 1, payload: '{"items":[]}', created_at: now },
        { user_id: 2, payload: '{"items":[]}', created_at: now }
      ];
      prisma.store.ai_support_sessions = [
        { session_id: 1, user_id: 1, status: 'escalated', updated_at: now },
        { session_id: 2, user_id: 2, status: 'open', updated_at: now }
      ];
      prisma.store.ai_chat_sessions = [
        { session_id: 3, user_id: 1, status: 'open', updated_at: now },
        { session_id: 4, user_id: 2, status: 'open', updated_at: now }
      ];
      await consent.setGranted(1, true);
      assert.strictEqual(prisma.rows('ai_recommendation_cache').length, 2);
      assert.strictEqual(prisma.rows('ai_support_sessions').length, 2);

      await consent.setGranted(1, false);
      assert.deepStrictEqual(prisma.rows('ai_recommendation_cache').map((r) => r.user_id), [2]);
      assert.deepStrictEqual(prisma.rows('ai_support_sessions').map((r) => r.user_id), [2]);
      assert.deepStrictEqual(prisma.rows('ai_chat_sessions').map((r) => r.user_id), [2]);
      assert.strictEqual(Number(prisma.rows('ai_consents')[0].granted), 0);
    }],

    ['同意時記錄當時的隱私權政策版本；政策重大更新後原同意失效，重新同意後恢復', async () => {
      const user = h.addUser();
      const token = h.tokenFor(user);
      h.setSettings({ enabled: true });
      setPrivacyVersion(2);

      const on = await request('PUT', '/api/ai/consent', { token, body: { granted: true, notice_version: consent.NOTICE_VERSION } });
      assert.strictEqual(on.body.data.consented, true);
      assert.strictEqual(on.body.data.consent_outdated, false);
      assert.strictEqual(Number(prisma.rows('ai_consents')[0].policy_version), 2);

      prisma.store.legal_documents[0].version = 3;
      const stale = await request('GET', '/api/ai/status', { token });
      assert.strictEqual(stale.body.data.consented, false);
      assert.strictEqual(stale.body.data.consent_outdated, true);
      await assert.rejects(() => consent.assertGranted(user.user_id), (err) => err.code === 'AI_CONSENT_REQUIRED');
      await assert.rejects(() => support.sendMessage(user.user_id, '你好'), (err) => err.code === 'AI_CONSENT_REQUIRED');
      assert.strictEqual(h.calls.length, 0);

      const again = await request('PUT', '/api/ai/consent', { token, body: { granted: true, notice_version: consent.NOTICE_VERSION } });
      assert.strictEqual(again.body.data.consented, true);
      assert.strictEqual(again.body.data.consent_outdated, false);
      assert.strictEqual(Number(prisma.rows('ai_consents')[0].policy_version), 3);
    }],

    ['未記錄政策版本的舊同意一律須重新同意；撤回或未同意時不標示為待更新', async () => {
      prisma.store.ai_consents = [
        { user_id: 1, granted: 1, policy_version: 0, updated_at: new Date() },
        { user_id: 2, granted: 0, policy_version: 0, updated_at: new Date() }
      ];
      assert.deepStrictEqual(await consent.stateOf(1), { granted: false, outdated: true });
      assert.deepStrictEqual(await consent.stateOf(2), { granted: false, outdated: false });
      assert.deepStrictEqual(await consent.stateOf(3), { granted: false, outdated: false });
      assert.strictEqual(consent.POLICY_DOC, 'privacy');
    }],

    ['保存期限：以最後一則訊息的時間起算刪除超過 90 天的對話，不論是否已結束；最近才結束或轉接不會延長', async () => {
      const now = new Date('2026-09-28T04:00:00Z');
      const ago = (days) => new Date(now.getTime() - days * DAY_MS);
      const purgeLike = (sessions, messages) => ([cutoff, cutoffAgain]) => {
        const recent = new Set(prisma.rows(messages).filter((m) => m.created_at >= cutoffAgain).map((m) => Number(m.session_id)));
        const keep = prisma.rows(sessions).filter((r) => !(r.created_at < cutoff && !recent.has(Number(r.session_id))));
        const removed = prisma.rows(sessions).length - keep.length;
        prisma.store[sessions] = keep;
        return removed;
      };
      h.onSql(/DELETE FROM ai_support_sessions WHERE created_at < \? AND NOT EXISTS \(SELECT 1 FROM ai_support_messages m WHERE m\.session_id = ai_support_sessions\.session_id AND m\.created_at >= \?\)/,
        purgeLike('ai_support_sessions', 'ai_support_messages'));
      h.onSql(/DELETE FROM ai_chat_sessions WHERE created_at < \? AND NOT EXISTS \(SELECT 1 FROM ai_chat_messages m WHERE m\.session_id = ai_chat_sessions\.session_id AND m\.created_at >= \?\)/,
        purgeLike('ai_chat_sessions', 'ai_chat_messages'));
      prisma.store.ai_support_sessions = [
        { session_id: 1, user_id: 1, status: 'closed', created_at: ago(95), updated_at: ago(1) },
        { session_id: 2, user_id: 1, status: 'open', created_at: ago(130), updated_at: ago(120) },
        { session_id: 3, user_id: 2, status: 'escalated', created_at: ago(100), updated_at: ago(2) },
        { session_id: 6, user_id: 2, status: 'escalated', created_at: ago(95), updated_at: ago(3) }
      ];
      prisma.store.ai_support_messages = [
        { message_id: 1, session_id: 1, role: 'user', content: 'q', created_at: ago(91) },
        { message_id: 2, session_id: 2, role: 'user', content: 'q', created_at: ago(120) },
        { message_id: 3, session_id: 3, role: 'user', content: 'q', created_at: ago(89) },
        { message_id: 4, session_id: 6, role: 'user', content: 'q', created_at: ago(92) }
      ];
      prisma.store.ai_chat_sessions = [
        { session_id: 4, user_id: 1, status: 'closed', created_at: ago(100), updated_at: ago(0.5) },
        { session_id: 5, user_id: 1, status: 'open', created_at: ago(100), updated_at: ago(1) }
      ];
      prisma.store.ai_chat_messages = [
        { message_id: 7, session_id: 4, role: 'user', content: 'q', created_at: ago(90.01) },
        { message_id: 8, session_id: 5, role: 'user', content: 'q', created_at: ago(1) }
      ];

      assert.strictEqual(consent.CONVERSATION_RETENTION_DAYS, 90);
      assert.deepStrictEqual(await consent.purgeExpired(now), { support: 3, book_chat: 1 });
      assert.deepStrictEqual(prisma.rows('ai_support_sessions').map((r) => r.session_id), [3]);
      assert.deepStrictEqual(prisma.rows('ai_chat_sessions').map((r) => r.session_id), [5]);
    }],

    ['功能狀態：AI 客服、書籍顧問或推薦可用時，資料接收者包含嵌入服務商', async () => {
      const token = h.tokenFor(h.addUser());
      embeddings.ORDER = ['gemini'];
      h.setSettings({ enabled: true, features: { listing_assist: { enabled: false } } });
      const on = await request('GET', '/api/ai/status', { token });
      assert.strictEqual(on.body.data.embedding_provider, 'Google Gemini');
      assert.deepStrictEqual(on.body.data.providers_in_use, ['DeepSeek', 'Google Gemini']);

      h.setSettings({ enabled: true, features: { support: { enabled: false }, recommend: { enabled: false }, book_chat: { enabled: false } } });
      const listingOnly = await request('GET', '/api/ai/status', { token });
      assert.strictEqual(listingOnly.body.data.embedding_provider, null);
      assert.deepStrictEqual(listingOnly.body.data.providers_in_use, ['Google Gemini']);

      embeddings.ORDER = [];
      h.setSettings({ enabled: true, features: { listing_assist: { enabled: false } } });
      const noKey = await request('GET', '/api/ai/status', { token });
      assert.strictEqual(noKey.body.data.embedding_provider, null);
      assert.deepStrictEqual(noKey.body.data.providers_in_use, ['DeepSeek']);
    }],

    ['未同意時錯誤訊息說明要先同意資料處理', async () => {
      await assert.rejects(
        () => consent.assertGranted(1),
        (err) => err.status === 403
          && err.code === 'AI_CONSENT_REQUIRED'
          && err.message === '使用 AI 功能前，請先同意將相關資料提供給 AI 服務商處理'
      );
    }],

    ['同意狀態 API：同意時須附上目前的說明版本，舊版 App 顯示的舊說明無法完成同意；撤回不檢查版本', async () => {
      const user = h.addUser();
      const token = h.tokenFor(user);
      h.setSettings({ enabled: true });
      assert.strictEqual(consent.NOTICE_VERSION, 2);
      for (const body of [{ granted: true }, { granted: true, notice_version: 1 }, { granted: true, notice_version: '2' }]) {
        const res = await request('PUT', '/api/ai/consent', { token, body });
        assert.strictEqual(res.status, 409, JSON.stringify(body));
        assert.strictEqual(res.body.code, 'AI_CONSENT_NOTICE_OUTDATED');
        assert.strictEqual(res.body.message, '請更新 App 後再同意 AI 資料處理');
      }
      assert.strictEqual(prisma.rows('ai_consents').length, 0);

      const off = await request('PUT', '/api/ai/consent', { token, body: { granted: false } });
      assert.strictEqual(off.status, 200);
      assert.strictEqual(off.body.data.consented, false);
    }],

    ['同意狀態 API：granted 必須是布林值', async () => {
      const user = h.addUser();
      const token = h.tokenFor(user);
      const res = await request('PUT', '/api/ai/consent', { token, body: { granted: 'yes' } });
      assert.strictEqual(res.status, 400);
      assert.strictEqual(res.body.message, 'granted 必須是 true 或 false');
    }],

    ['同意狀態 API：更新後回傳最新的功能狀態', async () => {
      const user = h.addUser();
      const token = h.tokenFor(user);
      h.setSettings({ enabled: true });

      const on = await request('PUT', '/api/ai/consent', { token, body: { granted: true, notice_version: consent.NOTICE_VERSION } });
      assert.strictEqual(on.status, 200);
      assert.strictEqual(on.body.message, '已同意 AI 資料處理');
      assert.strictEqual(on.body.data.consented, true);
      assert.strictEqual(on.body.data.support, true);
      assert.strictEqual(on.body.data.web_search, true);
      assert.deepStrictEqual(on.body.data.providers_in_use, ['DeepSeek', 'Google Gemini']);

      const off = await request('PUT', '/api/ai/consent', { token, body: { granted: false } });
      assert.strictEqual(off.body.message, '已停止 AI 資料處理');
      assert.strictEqual(off.body.data.consented, false);
    }],

    ['功能狀態：總開關關閉時所有入口都是 false', async () => {
      const user = h.addUser();
      h.setSettings({ enabled: false });
      const res = await request('GET', '/api/ai/status', { token: h.tokenFor(user) });
      assert.strictEqual(res.status, 200);
      assert.deepStrictEqual(res.body.data, {
        support: false, listing_assist: false, recommend: false, book_chat: false, web_search: false,
        providers_in_use: [], embedding_provider: null, consented: false, consent_outdated: false
      });
    }],

    ['個資匯出：包含同意紀錄、客服對話與推薦快取', async () => {
      answerJoins();
      const now = new Date();
      h.setConsent(3, true);
      prisma.store.ai_support_sessions = [{ session_id: 1, user_id: 3, status: 'open', created_at: now, updated_at: now }];
      prisma.store.ai_support_messages = [
        { message_id: 1, session_id: 1, role: 'user', content: '我要退款', created_at: now },
        { message_id: 2, session_id: 1, role: 'assistant', content: '請提供訂單編號', created_at: now }
      ];
      prisma.store.ai_chat_sessions = [{ session_id: 9, user_id: 3, status: 'closed', created_at: now, updated_at: now }];
      prisma.store.ai_chat_messages = [{ message_id: 5, session_id: 9, role: 'user', content: '推薦推理小說', created_at: now }];
      prisma.store.ai_recommendation_cache = [{ user_id: 3, payload: JSON.stringify({ items: [{ book_id: 1 }] }), created_at: now }];

      const data = await consent.exportUser(3);
      assert.strictEqual(data.consent.granted, true);
      assert.strictEqual(data.consent.policy_version, 1);
      assert.strictEqual(data.support_sessions.length, 1);
      assert.deepStrictEqual(data.support_sessions[0].messages.map((m) => m.role), ['user', 'assistant']);
      assert.strictEqual(data.support_sessions[0].messages[0].content, '我要退款');
      assert.strictEqual(data.book_chat_sessions.length, 1);
      assert.strictEqual(data.book_chat_sessions[0].status, 'closed');
      assert.deepStrictEqual(data.recommendations.items, [{ book_id: 1 }]);
    }],

    ['個資匯出：推薦快取內容損毀時不致命', async () => {
      answerJoins();
      prisma.store.ai_recommendation_cache = [{ user_id: 3, payload: '不是 JSON', created_at: new Date() }];
      const data = await consent.exportUser(3);
      assert.strictEqual(data.recommendations, null);
      assert.strictEqual(data.consent, null);
      assert.deepStrictEqual(data.support_sessions, []);
    }],

    ['清除帳號時會刪掉聊天、客服、推薦快取與同意紀錄', async () => {
      h.setConsent(3, true);
      prisma.store.ai_support_sessions = [{ session_id: 1, user_id: 3 }, { session_id: 2, user_id: 4 }];
      prisma.store.ai_chat_sessions = [{ session_id: 1, user_id: 3 }];
      prisma.store.ai_recommendation_cache = [{ user_id: 3 }, { user_id: 4 }];

      await consent.purgeUser(prisma, 3);
      assert.deepStrictEqual(prisma.rows('ai_support_sessions').map((r) => r.user_id), [4]);
      assert.deepStrictEqual(prisma.rows('ai_chat_sessions'), []);
      assert.deepStrictEqual(prisma.rows('ai_recommendation_cache').map((r) => r.user_id), [4]);
      assert.deepStrictEqual(prisma.rows('ai_consents'), []);
    }],

    ['客服對話：未同意時擋在模型呼叫之前', async () => {
      enable(1, { granted: false });
      await assert.rejects(() => support.sendMessage(1, '你好'), (err) => err.code === 'AI_CONSENT_REQUIRED');
      assert.strictEqual(h.calls.length, 0);
    }],

    ['客服對話：功能關閉時回 AI_DISABLED', async () => {
      enable(1, { config: { features: { support: { enabled: false } } } });
      await assert.rejects(() => support.sendMessage(1, '你好'), (err) => err.code === 'AI_DISABLED' && err.status === 503);
    }],

    ['客服對話：第一次發問會建立對話並存下兩則訊息', async () => {
      enable(1);
      h.queueJson({ reply: '請至「我的訂單」查看目前狀態。', suggest_handoff: false });

      const data = await support.sendMessage(1, '我的訂單在哪裡查？');
      assert.strictEqual(prisma.rows('ai_support_sessions').length, 1);
      assert.strictEqual(data.session_id, Number(prisma.rows('ai_support_sessions')[0].session_id));
      assert.strictEqual(data.user_message.content, '我的訂單在哪裡查？');
      assert.strictEqual(data.reply.content, '請至「我的訂單」查看目前狀態。');
      assert.strictEqual(data.suggest_handoff, false);
      assert.deepStrictEqual(prisma.rows('ai_support_messages').map((m) => m.role), ['user', 'assistant']);
      // 系統提示必須帶入平台知識，且要求模型輸出 JSON。
      assert.ok(h.calls[0].options.system.includes('SaveMyBook'));
      assert.strictEqual(h.calls[0].options.json, true);
      assert.deepStrictEqual(h.calls[0].options.history, []);
    }],

    ['客服對話：延續既有對話並附上歷史訊息', async () => {
      enable(1);
      h.queueJson({ reply: '第一則回覆。', suggest_handoff: false }, { reply: '第二則回覆。', suggest_handoff: true });

      await support.sendMessage(1, '第一個問題');
      const second = await support.sendMessage(1, '第二個問題');

      assert.strictEqual(prisma.rows('ai_support_sessions').length, 1);
      assert.strictEqual(prisma.rows('ai_support_messages').length, 4);
      assert.deepStrictEqual(h.calls[1].options.history, [
        { role: 'user', content: '第一個問題' },
        { role: 'assistant', content: '第一則回覆。' }
      ]);
      assert.strictEqual(second.suggest_handoff, true);
    }],

    ['客服對話：模型輸出會被清掉 HTML 與控制字元；空白回覆視為格式錯誤', async () => {
      enable(1);
      h.queueJson({ reply: '<b>請</b>​稍候 。', suggest_handoff: false }, { reply: '   ', suggest_handoff: false });

      const data = await support.sendMessage(1, '問題一');
      assert.strictEqual(data.reply.content, '請稍候。');

      await assert.rejects(
        () => support.sendMessage(1, '問題二'),
        (err) => err.code === 'AI_PROVIDER_ERROR' && err.reason === 'INVALID_OUTPUT'
      );
    }],

    ['客服對話：超過每日次數時不會呼叫模型', async () => {
      enable(1, { config: { limits: { daily_per_user: { support: 1 } } } });
      h.addUsageLog({ user_id: 1, feature: 'support', created_at: new Date() });
      await assert.rejects(() => support.sendMessage(1, '你好'), (err) => err.code === 'AI_DAILY_LIMIT');
      assert.strictEqual(h.calls.length, 0);
    }],

    ['客服對話：讀取目前對話會回傳全部訊息', async () => {
      enable(1);
      h.queueJson({ reply: '好的。', suggest_handoff: false });
      await support.sendMessage(1, '問題');

      const session = await support.currentSession(1);
      assert.strictEqual(session.status, 'open');
      assert.deepStrictEqual(session.messages.map((m) => m.content), ['問題', '好的。']);
      assert.strictEqual(await support.currentSession(999), null);
    }],

    ['客服對話：結束後不再視為進行中', async () => {
      enable(1);
      h.queueJson({ reply: '好的。', suggest_handoff: false });
      await support.sendMessage(1, '問題');
      await support.close(1);
      assert.strictEqual(prisma.rows('ai_support_sessions')[0].status, 'closed');
      assert.strictEqual(await support.currentSession(1), null);
    }],

    ['轉真人客服：沒有對話時回 400', async () => {
      enable(1);
      await assert.rejects(
        () => support.escalate(1, null),
        (err) => err.status === 400 && err.message === '目前沒有進行中的 AI 客服對話'
      );
    }],

    ['轉真人客服：建立工單並附上對話紀錄，對話標記為已轉接', async () => {
      const user = h.addUser();
      enable(user.user_id);
      h.queueJson({ reply: '建議聯絡客服。', suggest_handoff: true });
      await support.sendMessage(user.user_id, '款項沒有入帳');

      const { ticket_id: ticketId } = await support.escalate(user.user_id, null);
      const ticket = prisma.rows('support_tickets')[0];
      assert.strictEqual(Number(ticketId), Number(ticket.ticket_id));
      assert.strictEqual(ticket.subject, 'AI 客服轉接：款項沒有入帳');
      assert.strictEqual(ticket.category, 'other');
      assert.strictEqual(prisma.rows('ai_support_sessions')[0].status, 'escalated');
      assert.strictEqual(Number(prisma.rows('ai_support_sessions')[0].ticket_id), Number(ticketId));
    }],

    ['轉真人客服：對話紀錄過長時只保留結尾', () => {
      const messages = [{ role: 'user', content: '很長'.repeat(4000) }];
      const transcript = support.transcriptOf(messages);
      assert.ok(transcript.startsWith('以下為 AI 客服對話紀錄：\n…'));
      assert.strictEqual(transcript.length, 5000);
      assert.strictEqual(
        support.transcriptOf([{ role: 'assistant', content: '您好' }]),
        '以下為 AI 客服對話紀錄：\nAI 客服：您好'
      );
    }],

    ['客服對話 API：內容不可為空', async () => {
      const user = h.addUser();
      const res = await request('POST', '/api/ai/support/messages', { token: h.tokenFor(user), body: { content: '   ' } });
      assert.strictEqual(res.status, 400);
      assert.strictEqual(res.body.message, '請輸入訊息內容');
    }],

    ['書籍顧問也受同意狀態約束', async () => {
      enable(1, { granted: false });
      await assert.rejects(() => bookChat.sendMessage(1, '推薦推理小說'), (err) => err.code === 'AI_CONSENT_REQUIRED');
      assert.strictEqual(h.calls.length, 0);
    }]
  ]
};
