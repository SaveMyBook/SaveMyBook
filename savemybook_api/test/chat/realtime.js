const assert = require('assert');
const { io: connect } = require('socket.io-client');
const server = require('../lib/server');
const { request, addUser, openRoom, say, createGroup, api } = require('./harness');

const realtime = api('services/realtime');

let handle = null;
const clients = [];

const ensureAttached = () => {
  handle ??= realtime.attach(server.httpServer);
};

const open = (token) => new Promise((resolve, reject) => {
  ensureAttached();
  const client = connect(server.baseUrl(), { auth: { token }, transports: ['websocket'], reconnection: false, forceNew: true });
  clients.push(client);
  client.on('connect', () => resolve(client));
  client.on('connect_error', reject);
});

const next = (client, event, { timeout = 2000 } = {}) => new Promise((resolve, reject) => {
  const timer = setTimeout(() => reject(new Error(`未收到 ${event}`)), timeout);
  client.once(event, (payload) => {
    clearTimeout(timer);
    resolve(payload);
  });
});

const silent = (client, event, ms = 400) => new Promise((resolve, reject) => {
  const handler = () => reject(new Error(`不應收到 ${event}`));
  client.once(event, handler);
  setTimeout(() => {
    client.off(event, handler);
    resolve();
  }, ms);
});

const closeAll = () => {
  while (clients.length) clients.pop().disconnect();
};

const tests = [
  ['未帶有效登入權杖時拒絕連線', async () => {
    await assert.rejects(open('not-a-token'), /登入已失效/);
    await assert.rejects(open(undefined), /請先登入/);
    closeAll();
  }],

  ['對方傳訊息時即時通知，自己不會收到', async () => {
    const me = addUser();
    const partner = addUser();
    const roomId = await openRoom(me, partner.user_id);
    const [mine, theirs] = await Promise.all([open(me.token), open(partner.token)]);

    const received = next(theirs, 'chat:room');
    const quiet = silent(mine, 'chat:room');
    await say(me, roomId, '午安');
    assert.deepStrictEqual(await received, { room_id: roomId });
    await quiet;
    closeAll();
  }],

  ['被拒絕的請求不會推送', async () => {
    const me = addUser();
    const partner = addUser();
    const roomId = await openRoom(me, partner.user_id);
    const theirs = await open(partner.token);

    const quiet = silent(theirs, 'chat:room');
    const res = await request('POST', `/api/chat/rooms/${roomId}/messages`, { token: me.token, body: { content: '加我line abc123' } });
    assert.strictEqual(res.status, 409);
    await quiet;
    closeAll();
  }],

  ['對方讀取訊息後通知傳送者更新已讀', async () => {
    const me = addUser();
    const partner = addUser();
    const roomId = await openRoom(me, partner.user_id);
    await say(me, roomId, '在嗎');
    const mine = await open(me.token);

    const received = next(mine, 'chat:room');
    await request('GET', `/api/chat/rooms/${roomId}/messages`, { token: partner.token });
    assert.deepStrictEqual(await received, { room_id: roomId });

    const quiet = silent(mine, 'chat:room');
    await request('GET', `/api/chat/rooms/${roomId}/messages`, { token: partner.token });
    await quiet;
    closeAll();
  }],

  ['透過連線回報輸入中，群組其他成員即時收到', async () => {
    const owner = addUser();
    const a = addUser();
    const b = addUser();
    const roomId = await createGroup(owner, [a.user_id, b.user_id]);
    const [ownerSocket, aSocket, bSocket] = await Promise.all([open(owner.token), open(a.token), open(b.token)]);

    const toA = next(aSocket, 'chat:typing');
    const toB = next(bSocket, 'chat:typing');
    const quiet = silent(ownerSocket, 'chat:typing');
    ownerSocket.emit('typing', { room_id: roomId, typing: true });
    assert.deepStrictEqual(await toA, { room_id: roomId, user_id: owner.user_id, typing: true });
    assert.deepStrictEqual(await toB, { room_id: roomId, user_id: owner.user_id, typing: true });
    await quiet;
    closeAll();
  }],

  ['非成員回報輸入中會被忽略', async () => {
    const me = addUser();
    const partner = addUser();
    const outsider = addUser();
    const roomId = await openRoom(me, partner.user_id);
    const [theirs, stranger] = await Promise.all([open(partner.token), open(outsider.token)]);

    const quiet = silent(theirs, 'chat:typing');
    stranger.emit('typing', { room_id: roomId, typing: true });
    await quiet;
    closeAll();
    handle.close();
    handle = null;
  }]
];

module.exports = { name: '即時推送', tests };
