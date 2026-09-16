const assert = require('assert');
const http = require('node:http');
const h = require('./harness');
const { addUser, setDns, site, html, connections, dnsLog, previewOf, safeFetch } = { ...h, safeFetch: h.api('lib/safe-fetch') };

const PAGE = '<html><head><title>公開網站</title></head></html>';

const expectNoConnection = () => assert.strictEqual(connections.length, 0, `不應建立任何連線：${JSON.stringify(connections)}`);

const tests = [
  ['位址分類：私有、保留、迴路、連結本機、多播與雲端中繼資料位址一律拒絕', async () => {
    const blocked = [
      '0.0.0.0', '0.1.2.3', '10.0.0.1', '100.64.0.1', '100.100.100.200', '127.0.0.1', '127.255.255.254',
      '169.254.169.254', '169.254.0.1', '172.16.0.1', '172.31.255.255', '192.0.0.170', '192.0.2.1', '192.168.1.1',
      '198.18.0.1', '198.51.100.7', '203.0.113.9', '224.0.0.1', '239.255.255.250', '240.0.0.1', '255.255.255.255',
      '::', '::1', '::ffff:127.0.0.1', '::ffff:7f00:1', '::ffff:169.254.169.254', '::ffff:10.1.2.3', '::127.0.0.1',
      '64:ff9b::a9fe:a9fe', '64:ff9b::7f00:1', 'fc00::1', 'fd00:ec2::254', 'fd12:3456::1', 'fe80::1', 'fe80::1%en0',
      'fec0::1', 'ff02::1', '2001:db8::1', '2001::1', '2002:7f00:1::1', '100::1', '3fff::1', 'not-an-ip', '1.2.3'
    ];
    for (const address of blocked) assert.strictEqual(safeFetch.isBlockedAddress(address), true, `${address} 應被拒絕`);

    const allowed = ['93.184.216.34', '8.8.8.8', '1.1.1.1', '172.32.0.1', '100.128.0.1', '2606:4700:4700::1111', '2a00:1450:4001:80b::200e', '::ffff:93.184.216.34', '64:ff9b::808:808'];
    for (const address of allowed) assert.strictEqual(safeFetch.isBlockedAddress(address), false, `${address} 應允許`);
  }],

  ['網址為私有或中繼資料 IP 時回傳 null 且不連線', async () => {
    const { token } = addUser();
    const urls = [
      'http://127.0.0.1/', 'http://169.254.169.254/latest/meta-data/', 'http://[::1]/', 'http://[::ffff:127.0.0.1]/',
      'http://[fd00:ec2::254]/', 'http://0x7f000001/', 'http://2130706433/', 'http://0177.0.0.1/', 'http://10.0.0.8/admin',
      'http://[fe80::1]/', 'http://0.0.0.0/'
    ];
    for (const url of urls) assert.strictEqual(await previewOf(token, url), null, url);
    expectNoConnection();
    assert.strictEqual(dnsLog.length, 0, 'IP 網址不需解析 DNS');
  }],

  ['主機名稱解析到私有位址時拒絕，任一解析結果不合格即拒絕', async () => {
    const { token } = addUser();
    setDns('intranet.example.com', ['10.1.2.3']);
    setDns('metadata.example.com', ['169.254.169.254']);
    setDns('mixed.example.com', ['93.184.216.34', '127.0.0.1']);
    setDns('mixed6.example.com', ['2606:4700:4700::1111', 'fd00:ec2::254']);
    for (const host of ['intranet', 'metadata', 'mixed', 'mixed6']) {
      site(`https://${host}.example.com/`, html(PAGE));
      assert.strictEqual(await previewOf(token, `https://${host}.example.com/`), null, host);
    }
    expectNoConnection();
  }],

  ['localhost 與單一標籤主機名稱直接拒絕', async () => {
    const { token } = addUser();
    for (const url of ['http://localhost/', 'http://api.localhost/', 'http://intranet/']) {
      assert.strictEqual(await previewOf(token, url), null, url);
    }
    assert.strictEqual(dnsLog.length, 0);
    expectNoConnection();
  }],

  ['非 http(s)、非預設連接埠與含帳密的網址拒絕', async () => {
    const { token } = addUser();
    setDns('example.com', ['93.184.216.34']);
    site('http://example.com/', html(PAGE));
    const urls = [
      'ftp://example.com/', 'file:///etc/passwd', 'javascript:alert(1)', 'data:text/html,hi', 'gopher://example.com/',
      'http://example.com:8080/', 'https://example.com:8443/', 'http://example.com:22/', 'http://user:pass@example.com/', 'example.com'
    ];
    for (const url of urls) assert.strictEqual(await previewOf(token, url), null, url);
    assert.strictEqual(dnsLog.length, 0);
    expectNoConnection();
  }],

  ['轉址到私有位址時拒絕，且不連線到轉址目標', async () => {
    const { token } = addUser();
    setDns('public.example.com', ['93.184.216.34']);
    setDns('internal.example.com', ['192.168.0.10']);
    site('https://public.example.com/go', { status: 302, headers: { location: 'http://internal.example.com/secret' } });
    site('http://internal.example.com/secret', html(PAGE));
    site('https://public.example.com/meta', { status: 301, headers: { location: 'http://169.254.169.254/latest/meta-data/' } });
    site('https://public.example.com/port', { status: 307, headers: { location: 'http://public.example.com:6379/' } });
    site('https://public.example.com/scheme', { status: 308, headers: { location: 'file:///etc/passwd' } });

    for (const path of ['go', 'meta', 'port', 'scheme']) {
      assert.strictEqual(await previewOf(token, `https://public.example.com/${path}`), null, path);
    }
    assert.deepStrictEqual(connections.map((c) => c.address), ['93.184.216.34', '93.184.216.34', '93.184.216.34', '93.184.216.34']);
  }],

  ['轉址最多 3 次，每次都重新解析並檢查', async () => {
    const { token } = addUser();
    setDns('a.example.com', ['93.184.216.34']);
    setDns('b.example.com', ['93.184.216.35']);
    site('https://a.example.com/1', { status: 301, headers: { location: 'https://b.example.com/2' } });
    site('https://b.example.com/2', { status: 302, headers: { location: '/3' } });
    site('https://b.example.com/3', { status: 303, headers: { location: 'https://a.example.com/4' } });
    site('https://a.example.com/4', html('<title>第三次轉址後</title>'));
    site('https://a.example.com/5', { status: 302, headers: { location: 'https://a.example.com/1' } });

    const ok = await previewOf(token, 'https://a.example.com/1');
    assert.strictEqual(ok.title, '第三次轉址後');
    assert.deepStrictEqual(dnsLog, ['a.example.com', 'b.example.com', 'b.example.com', 'a.example.com']);

    connections.length = 0;
    assert.strictEqual(await previewOf(token, 'https://a.example.com/5'), null, '第 4 次轉址應拒絕');
    assert.strictEqual(connections.length, 4);
  }],

  ['DNS rebinding：連線使用檢查時的位址，不會再次解析', async () => {
    const { token } = addUser();
    let calls = 0;
    setDns('rebind.example.com', () => {
      calls += 1;
      return calls === 1 ? ['93.184.216.34'] : ['127.0.0.1'];
    });
    site('https://rebind.example.com/', html('<title>重新綁定</title>'));

    const data = await previewOf(token, 'https://rebind.example.com/');
    assert.strictEqual(data.title, '重新綁定');
    assert.strictEqual(calls, 1, '檢查後不得再次查詢 DNS');
    assert.strictEqual(connections[0].address, '93.184.216.34');
    assert.strictEqual(connections[0].headers['user-agent'].startsWith('SaveMyBookLinkPreview/'), true);
  }],

  ['DNS rebinding：Node 實際建立連線時採用綁定的位址', async () => {
    const target = http.createServer((req, res) => res.end(`host=${req.headers.host}`));
    await new Promise((resolve) => target.listen(0, '127.0.0.1', resolve));
    const { port } = target.address();
    h.passthroughHosts.add('pinned.example.com');
    h.setDns('pinned.example.com', ['203.0.113.1']);
    try {
      const controller = new AbortController();
      const url = new URL(`http://pinned.example.com:${port}/check`);
      const res = await safeFetch.openRequest(url, { address: '127.0.0.1', family: 4 }, { headers: {}, signal: controller.signal });
      const chunks = [];
      for await (const chunk of res) chunks.push(chunk);
      assert.strictEqual(Buffer.concat(chunks).toString(), `host=pinned.example.com:${port}`);
      assert.strictEqual(dnsLog.length, 0, '連線不得交由系統重新解析');

      const lookup = safeFetch.pinnedLookup({ address: '93.184.216.34', family: 4 });
      await new Promise((resolve) => lookup('x', { all: true }, (err, list) => {
        assert.deepStrictEqual(list, [{ address: '93.184.216.34', family: 4 }]);
        resolve();
      }));
      await new Promise((resolve) => lookup('x', {}, (err, address, family) => {
        assert.deepStrictEqual([address, family], ['93.184.216.34', 4]);
        resolve();
      }));
    } finally {
      await new Promise((resolve) => target.close(resolve));
    }
  }],

  ['未登入不可使用', async () => {
    const res = await h.request('GET', '/api/chat/link-preview?url=https%3A%2F%2Fexample.com%2F');
    assert.strictEqual(res.status, 401);
    const image = await h.request('GET', '/api/chat/link-preview/image?u=abc.def');
    assert.strictEqual(image.status, 401);
  }]
];

module.exports = { name: 'SSRF 防護', tests };
