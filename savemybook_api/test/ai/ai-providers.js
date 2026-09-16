const assert = require('assert');
const h = require('./harness');

const ai = h.ai;
const { realGenerate } = h;

// 重試的退避時間預設 800ms，測試中縮短以免拖慢整組。
h.aiHttp.options.backoffMs = 5;

const responses = [];
const requests = [];

const enqueue = (...items) => responses.push(...items);

const reply = (url, init) => {
  requests.push({ url, body: JSON.parse(init.body), headers: init.headers });
  const next = responses.shift();
  if (!next) throw new Error(`測試未預期的服務商請求：${url}`);
  if (typeof next === 'function') return next(url, init);
  return h.jsonResponse(next.body, { status: next.status ?? 200, headers: next.headers ?? {} });
};

h.onFetch('https://generativelanguage.googleapis.com', reply);
h.onFetch('https://api.openai.com', reply);
h.onFetch('https://api.deepseek.com', reply);

const geminiOk = (overrides = {}) => ({
  body: {
    candidates: [{ content: { parts: [{ text: '{"ok":true}' }] }, finishReason: 'STOP' }],
    usageMetadata: { promptTokenCount: 100, cachedContentTokenCount: 40, candidatesTokenCount: 20, thoughtsTokenCount: 5 },
    ...overrides
  }
});

const openaiOk = (overrides = {}) => ({
  body: {
    status: 'completed',
    output: [{ type: 'message', content: [{ type: 'output_text', text: '{"ok":true}' }] }],
    usage: { input_tokens: 80, input_tokens_details: { cached_tokens: 30 }, output_tokens: 10 },
    ...overrides
  }
});

const deepseekOk = (overrides = {}) => ({
  body: {
    choices: [{ message: { content: '{"ok":true}' } }],
    usage: { prompt_tokens: 60, prompt_cache_hit_tokens: 20, completion_tokens: 8 },
    ...overrides
  }
});

const errorBody = (message, extra = {}) => ({ error: { message, ...extra } });

module.exports = {
  name: 'AI 服務商轉接器',
  before: () => {
    responses.length = 0;
    requests.length = 0;
  },
  tests: [
    ['Gemini：JSON 請求帶上思考預算、回應格式與系統指示', async () => {
      enqueue(geminiOk());
      const result = await realGenerate('gemini', {
        model: 'gemini-3.1-flash-lite', system: '你是助理', prompt: '請回覆 JSON', json: true, maxOutputTokens: 400
      });
      const [req] = requests;
      assert.ok(req.url.endsWith('/models/gemini-3.1-flash-lite:generateContent'));
      assert.strictEqual(req.headers['x-goog-api-key'], 'test-gemini-key');
      assert.strictEqual(req.body.systemInstruction.parts[0].text, '你是助理');
      assert.strictEqual(req.body.generationConfig.responseMimeType, 'application/json');
      assert.strictEqual(req.body.generationConfig.thinkingConfig.thinkingLevel, 'minimal');
      // 思考 token 也算進 maxOutputTokens，因此要加上 2048 的緩衝。
      assert.strictEqual(req.body.generationConfig.maxOutputTokens, 400 + 2048);
      assert.strictEqual(req.body.tools, undefined);
      assert.deepStrictEqual(result.json, { ok: true });
      assert.deepStrictEqual(result.usage, { input_tokens: 100, cached_tokens: 40, output_tokens: 25, search_calls: 0 });
    }],

    ['Gemini：圖片以 inlineData 傳送，思考段落不計入文字', async () => {
      enqueue({
        body: {
          candidates: [{ content: { parts: [{ text: '內部思考', thought: true }, { text: '結論' }] } }],
          usageMetadata: {}
        }
      });
      const result = await realGenerate('gemini', {
        model: 'gemini-3.1-flash-lite', prompt: '看圖', images: [{ mimeType: 'image/jpeg', data: 'AAAA' }]
      });
      const parts = requests[0].body.contents[0].parts;
      assert.deepStrictEqual(parts[1].inlineData, { mimeType: 'image/jpeg', data: 'AAAA' });
      assert.strictEqual(result.text, '結論');
    }],

    ['Gemini：搜尋時改掛 google_search 工具且不要求 JSON 格式', async () => {
      enqueue({
        body: {
          candidates: [{
            content: { parts: [{ text: '{"ok":true}' }] },
            groundingMetadata: {
              webSearchQueries: ['挪威的森林 ISBN', ''],
              groundingChunks: [{ web: { title: '博客來', uri: 'https://example.test/book' } }, { web: {} }]
            }
          }],
          usageMetadata: { promptTokenCount: 10, candidatesTokenCount: 5 }
        }
      });
      const result = await realGenerate('gemini', { model: 'gemini-3.1-flash-lite', prompt: '查書', json: true, search: true });
      assert.deepStrictEqual(requests[0].body.tools, [{ google_search: {} }]);
      assert.strictEqual(requests[0].body.generationConfig.responseMimeType, undefined);
      assert.strictEqual(requests[0].body.generationConfig.thinkingConfig.thinkingLevel, 'low');
      assert.deepStrictEqual(result.sources, [{ title: '博客來', url: 'https://example.test/book' }]);
      assert.strictEqual(result.usage.search_calls, 1);
    }],

    ['Gemini：安全機制擋下時回 BLOCKED', async () => {
      enqueue({ body: { candidates: [{ finishReason: 'SAFETY' }] } });
      await assert.rejects(
        () => realGenerate('gemini', { model: 'gemini-3.1-flash-lite', prompt: 'x' }),
        (err) => err.reason === 'BLOCKED' && err.detail === '內容遭服務安全機制拒絕' && err.status === 502
      );
    }],

    ['Gemini：輸出長度耗盡且沒有文字時回 INCOMPLETE', async () => {
      enqueue({ body: { candidates: [{ finishReason: 'MAX_TOKENS', content: { parts: [] } }] } });
      await assert.rejects(
        () => realGenerate('gemini', { model: 'gemini-3.1-flash-lite', prompt: 'x' }),
        (err) => err.reason === 'INCOMPLETE' && err.detail === '回應超過輸出長度上限'
      );
    }],

    ['Gemini：429 夾帶額度用盡字樣時判為 QUOTA 且不重試', async () => {
      enqueue({ status: 429, body: errorBody('You exceeded your current quota') });
      await assert.rejects(
        () => realGenerate('gemini', { model: 'gemini-3.1-flash-lite', prompt: 'x' }),
        (err) => err.reason === 'QUOTA' && err.detail.includes('額度不足')
      );
      assert.strictEqual(requests.length, 1);
    }],

    ['Gemini：單純的 429 判為 RATE_LIMITED 並重試一次', async () => {
      enqueue({ status: 429, body: errorBody('too many requests') }, { status: 429, body: errorBody('too many requests') });
      await assert.rejects(
        () => realGenerate('gemini', { model: 'gemini-3.1-flash-lite', prompt: 'x' }),
        (err) => err.reason === 'RATE_LIMITED' && err.detail === '請求過於頻繁'
      );
      assert.strictEqual(requests.length, 2);
    }],

    ['Gemini：金鑰錯誤判為 AUTH，模型不存在判為 MODEL_NOT_FOUND', async () => {
      enqueue({ status: 400, body: errorBody('API key not valid. Please pass a valid API key.') });
      await assert.rejects(
        () => realGenerate('gemini', { model: 'gemini-3.1-flash-lite', prompt: 'x' }),
        (err) => err.reason === 'AUTH'
      );
      enqueue({ status: 404, body: errorBody('models/none is not found') });
      await assert.rejects(
        () => realGenerate('gemini', { model: 'none', prompt: 'x' }),
        (err) => err.reason === 'MODEL_NOT_FOUND'
      );
    }],

    ['OpenAI：JSON 請求帶上推理強度、輸出格式與緩衝', async () => {
      enqueue(openaiOk());
      const result = await realGenerate('openai', {
        apiKey: 'sk-test-key', model: 'gpt-5-nano', system: '你是助理', prompt: '整理資料', json: true, maxOutputTokens: 400
      });
      const [req] = requests;
      assert.ok(req.url.endsWith('/v1/responses'));
      assert.strictEqual(req.headers.authorization, 'Bearer sk-test-key');
      assert.strictEqual(req.body.instructions, '你是助理');
      assert.deepStrictEqual(req.body.text, { format: { type: 'json_object' } });
      assert.deepStrictEqual(req.body.reasoning, { effort: 'minimal' });
      assert.strictEqual(req.body.max_output_tokens, 400 + 2000);
      assert.strictEqual(req.body.store, false);
      // json_object 要求輸入出現 json 字樣，提示詞沒有時由轉接器補上。
      assert.ok(req.body.input[0].content[0].text.includes('請只輸出一個 JSON 物件'));
      assert.deepStrictEqual(result.usage, { input_tokens: 80, cached_tokens: 30, output_tokens: 10, search_calls: 0 });
    }],

    ['OpenAI：搜尋時改掛 web_search 工具、提高推理強度並統計呼叫次數', async () => {
      enqueue(openaiOk({
        output: [
          { type: 'web_search_call' },
          { type: 'web_search_call' },
          {
            type: 'message',
            content: [{
              type: 'output_text',
              text: '{"ok":true}',
              annotations: [{ type: 'url_citation', url: 'https://example.test/a', title: 'A' }]
            }]
          }
        ]
      }));
      const result = await realGenerate('openai', {
        apiKey: 'sk-test-key', model: 'gpt-5-nano', prompt: '查資料', json: true, search: true, maxOutputTokens: 400
      });
      assert.deepStrictEqual(requests[0].body.tools, [{ type: 'web_search' }]);
      assert.strictEqual(requests[0].body.text, undefined);
      assert.deepStrictEqual(requests[0].body.reasoning, { effort: 'low' });
      assert.strictEqual(requests[0].body.max_output_tokens, 400 + 8000);
      assert.strictEqual(result.usage.search_calls, 2);
      assert.deepStrictEqual(result.sources, [{ title: 'A', url: 'https://example.test/a' }]);
    }],

    ['OpenAI：只接受支援的圖片格式', async () => {
      enqueue(openaiOk());
      await realGenerate('openai', {
        apiKey: 'sk-test-key',
        model: 'gpt-5-nano',
        prompt: '看圖',
        images: [{ mimeType: 'image/heic', data: 'AA' }, { mimeType: 'image/png', data: 'BB' }]
      });
      const content = requests[0].body.input[0].content;
      assert.strictEqual(content.length, 2);
      assert.strictEqual(content[1].image_url, 'data:image/png;base64,BB');
    }],

    ['OpenAI：回應未完成時依原因回 INCOMPLETE 或 BLOCKED', async () => {
      enqueue(openaiOk({ status: 'incomplete', output: [], incomplete_details: { reason: 'max_output_tokens' } }));
      await assert.rejects(
        () => realGenerate('openai', { apiKey: 'sk-test-key', model: 'gpt-5-nano', prompt: 'x' }),
        (err) => err.reason === 'INCOMPLETE'
          && err.providerMessage === 'status incomplete: max_output_tokens'
          && err.usage.input_tokens === 80
      );
      enqueue(openaiOk({ status: 'incomplete', output: [], incomplete_details: { reason: 'content_filter' } }));
      await assert.rejects(
        () => realGenerate('openai', { apiKey: 'sk-test-key', model: 'gpt-5-nano', prompt: 'x' }),
        (err) => err.reason === 'BLOCKED'
      );
    }],

    ['OpenAI：模型拒答時回 BLOCKED，額度不足時回 QUOTA', async () => {
      enqueue(openaiOk({ output: [{ type: 'message', content: [{ type: 'refusal', refusal: '不予回答' }] }] }));
      await assert.rejects(
        () => realGenerate('openai', { apiKey: 'sk-test-key', model: 'gpt-5-nano', prompt: 'x' }),
        (err) => err.reason === 'BLOCKED'
      );
      enqueue({ status: 429, body: errorBody('You exceeded your current quota', { type: 'insufficient_quota' }) });
      await assert.rejects(
        () => realGenerate('openai', { apiKey: 'sk-test-key', model: 'gpt-5-nano', prompt: 'x' }),
        (err) => err.reason === 'QUOTA'
      );
    }],

    ['DeepSeek：JSON 模式補上提示詞並對應用量欄位', async () => {
      enqueue(deepseekOk());
      const result = await realGenerate('deepseek', {
        model: 'deepseek-flash', system: '你是助理', prompt: '整理資料', json: true, maxOutputTokens: 300, temperature: 0.3
      });
      const [req] = requests;
      assert.ok(req.url.endsWith('/chat/completions'));
      assert.deepStrictEqual(req.body.response_format, { type: 'json_object' });
      assert.strictEqual(req.body.max_tokens, 300);
      assert.strictEqual(req.body.temperature, 0.3);
      assert.strictEqual(req.body.stream, false);
      assert.ok(req.body.messages[1].content.includes('請只輸出一個 JSON 物件。'));
      assert.deepStrictEqual(result.usage, { input_tokens: 60, cached_tokens: 20, output_tokens: 8, search_calls: 0 });
      assert.deepStrictEqual(result.sources, []);
    }],

    ['DeepSeek：提示詞已含 json 字樣時不重複附加', async () => {
      enqueue(deepseekOk());
      await realGenerate('deepseek', { model: 'deepseek-flash', prompt: '請輸出 json 結果', json: true });
      assert.strictEqual(requests[0].body.messages[0].content, '請輸出 json 結果');
    }],

    ['DeepSeek：餘額不足判為 QUOTA', async () => {
      enqueue({ status: 402, body: errorBody('Insufficient Balance') });
      await assert.rejects(
        () => realGenerate('deepseek', { model: 'deepseek-flash', prompt: 'x' }),
        (err) => err.reason === 'QUOTA' && err.provider === 'deepseek'
      );
    }],

    ['伺服器錯誤會重試一次後成功', async () => {
      enqueue({ status: 500, body: errorBody('internal') }, deepseekOk());
      const result = await realGenerate('deepseek', { model: 'deepseek-flash', prompt: 'x' });
      assert.strictEqual(requests.length, 2);
      assert.strictEqual(result.text, '{"ok":true}');
    }],

    ['Retry-After 超過上限時不重試', async () => {
      enqueue({ status: 429, body: errorBody('slow down'), headers: { 'retry-after': '10' } });
      await assert.rejects(
        () => realGenerate('deepseek', { model: 'deepseek-flash', prompt: 'x' }),
        (err) => err.reason === 'RATE_LIMITED'
      );
      assert.strictEqual(requests.length, 1);
    }],

    ['逾時會中止請求並回 TIMEOUT', async () => {
      enqueue((url, init) => new Promise((resolve, reject) => {
        init.signal.addEventListener('abort', () => reject(init.signal.reason ?? new Error('aborted')), { once: true });
      }));
      await assert.rejects(
        () => realGenerate('deepseek', { model: 'deepseek-flash', prompt: 'x', timeoutMs: 30 }),
        (err) => err.reason === 'TIMEOUT' && err.detail === '連線逾時'
      );
    }],

    ['服務商訊息中的金鑰片段會被遮蔽後才保留', async () => {
      enqueue({ status: 400, body: errorBody('bad request for key=sk-live-abcdefgh12345 and AIzaSyABCDEFGH12345678') });
      await assert.rejects(
        () => realGenerate('deepseek', { model: 'deepseek-flash', prompt: 'x' }),
        (err) => !/sk-live-abcdefgh/.test(err.providerMessage)
          && !/AIzaSyABCDEFGH/.test(err.providerMessage)
          && err.providerMessage.includes('[redacted]')
          && err.fullDetail.startsWith(err.detail)
      );
    }],

    ['非 JSON 的錯誤內容仍會保留摘要', async () => {
      const gateway = () => new Response('<html>502 Bad Gateway</html>', { status: 503 });
      enqueue(gateway, gateway);
      await assert.rejects(
        () => realGenerate('deepseek', { model: 'deepseek-flash', prompt: 'x', timeoutMs: 2000 }),
        (err) => err.reason === 'SERVER' && err.providerMessage.includes('502 Bad Gateway')
      );
    }],

    ['未知的服務商或未設定金鑰時不會送出請求', async () => {
      await assert.rejects(() => realGenerate('claude', { prompt: 'x' }), (err) => err.reason === 'BAD_REQUEST');
      await assert.rejects(
        () => realGenerate('openai', { model: 'gpt-5-nano', prompt: 'x' }),
        (err) => err.reason === 'NOT_CONFIGURED' && err.detail === '尚未設定 API 金鑰'
      );
      assert.strictEqual(requests.length, 0);
    }],

    ['要求 JSON 但輸出不是物件時回 INVALID_OUTPUT', async () => {
      enqueue(deepseekOk({ choices: [{ message: { content: '我不知道' } }] }));
      await assert.rejects(
        () => realGenerate('deepseek', { model: 'deepseek-flash', prompt: 'x', json: true }),
        (err) => err.reason === 'INVALID_OUTPUT' && err.detail === '回應格式不正確'
      );
    }],

    ['JSON 解析容許程式碼圍籬與前後多餘文字', () => {
      assert.deepStrictEqual(ai.extractJson('```json\n{"a":1}\n```'), { a: 1 });
      assert.deepStrictEqual(ai.extractJson('好的，結果如下：{"a":1} 以上'), { a: 1 });
      assert.strictEqual(ai.extractJson('沒有物件'), null);
      assert.strictEqual(ai.extractJson(null), null);
    }],

    ['用量換算成本時，快取輸入以較低單價計算', () => {
      const prices = { input_per_m: 1, cached_input_per_m: 0.1, output_per_m: 2, search_price_per_k: 0, search_free_per_month: 0 };
      const cost = ai.tokenCost({ input_tokens: 1000000, cached_tokens: 500000, output_tokens: 1000000 }, prices);
      assert.strictEqual(cost, 0.5 * 1 + 0.5 * 0.1 + 2);
      // 快取數不會超過輸入數，負數一律視為 0。
      assert.strictEqual(ai.tokenCost({ input_tokens: 100, cached_tokens: 999999, output_tokens: -5 }, prices), 0.1 * 100 / 1e6);
    }],

    ['搜尋每月免費額度用完之後才計費', () => {
      assert.strictEqual(ai.billableSearchCalls(10, 0, 100), 0);
      assert.strictEqual(ai.billableSearchCalls(10, 95, 100), 5);
      assert.strictEqual(ai.billableSearchCalls(10, 200, 100), 10);
      assert.strictEqual(ai.billableSearchCalls(10, 0, 0), 10);
      const prices = { input_per_m: 0, cached_input_per_m: 0, output_per_m: 0, search_price_per_k: 14, search_free_per_month: 5000 };
      // 免費額度剩 500 次，其餘 500 次以每千次 14 美元計價。
      assert.strictEqual(ai.costOf({ search_calls: 1000 }, prices, { searchUsedThisMonth: 4500 }), 7);
      assert.strictEqual(ai.costOf({ search_calls: 1000 }, prices, { searchUsedThisMonth: 0 }), 0);
    }]
  ]
};
