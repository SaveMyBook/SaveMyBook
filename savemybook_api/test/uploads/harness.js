const fs = require('fs');
const os = require('os');
const path = require('path');

const root = fs.mkdtempSync(path.join(os.tmpdir(), 'smb-uploads-'));
for (const folder of ['avatars', 'books', 'chat']) fs.mkdirSync(path.join(root, folder), { recursive: true });

const server = require('../lib/server');
const { registerModels } = require('../lib/fake-prisma');

const uploadLib = server.api('lib/upload');
// UPLOAD_ROOT 是唯讀匯出，測試改以覆寫的方式指向暫存目錄。
Object.defineProperty(uploadLib, 'UPLOAD_ROOT', { value: root, writable: true, configurable: true });

const uploadsFs = server.api('lib/uploads-fs');

registerModels({
  autoKeys: { users: 'user_id', book_images: 'image_id', chat_rooms: 'room_id' },
  uniqueKeys: { book_images: [['image_id']] }
});

const write = (relative) => {
  const target = path.join(root, relative);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, 'x');
  uploadsFs.forget(`/uploads/${relative}`);
  return `/uploads/${relative}`;
};

const missing = (relative) => {
  uploadsFs.forget(`/uploads/${relative}`);
  return `/uploads/${relative}`;
};

server.setDefaultReset(() => server.reset({ tables: { users: [], book_images: [], chat_rooms: [] } }));

// 每個測試都用不同檔名，才不會受到存在與否的快取影響。
let seq = 0;
const nextName = () => { seq += 1; return `f${seq}-${Date.now()}.jpg`; };

module.exports = { ...server, root, write, missing, uploadsFs, nextName };
