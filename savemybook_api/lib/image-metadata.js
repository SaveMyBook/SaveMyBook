const JPEG_DROP = new Set([0xe1, 0xe2, 0xec, 0xed, 0xfe]);
const PNG_DROP = new Set(['eXIf', 'tEXt', 'iTXt', 'zTXt', 'tIME']);
const WEBP_DROP = new Set(['EXIF', 'XMP ']);

const jpegOrientation = (segment) => {
  if (segment.length < 14 || segment.toString('latin1', 0, 6) !== 'Exif\0\0') return 0;
  const tiff = segment.subarray(6);
  const little = tiff.toString('latin1', 0, 2) === 'II';
  const u16 = (o) => (little ? tiff.readUInt16LE(o) : tiff.readUInt16BE(o));
  const u32 = (o) => (little ? tiff.readUInt32LE(o) : tiff.readUInt32BE(o));
  const ifd = u32(4);
  if (ifd + 2 > tiff.length) return 0;
  const count = u16(ifd);
  for (let i = 0; i < count; i += 1) {
    const entry = ifd + 2 + i * 12;
    if (entry + 12 > tiff.length) return 0;
    if (u16(entry) === 0x0112) {
      const value = u16(entry + 8);
      return value >= 1 && value <= 8 ? value : 0;
    }
  }
  return 0;
};

const orientationSegment = (orientation) => {
  const body = Buffer.alloc(6 + 8 + 2 + 12 + 4);
  body.write('Exif\0\0', 0, 'latin1');
  body.write('MM', 6, 'latin1');
  body.writeUInt16BE(42, 8);
  body.writeUInt32BE(8, 10);
  body.writeUInt16BE(1, 14);
  body.writeUInt16BE(0x0112, 16);
  body.writeUInt16BE(3, 18);
  body.writeUInt32BE(1, 20);
  body.writeUInt16BE(orientation, 24);
  const header = Buffer.from([0xff, 0xe1, 0, 0]);
  header.writeUInt16BE(body.length + 2, 2);
  return Buffer.concat([header, body]);
};

const stripJpeg = (buf) => {
  if (buf.length < 4 || buf[0] !== 0xff || buf[1] !== 0xd8) return null;
  const parts = [buf.subarray(0, 2)];
  let orientation = 0;
  let pos = 2;
  while (pos + 4 <= buf.length) {
    if (buf[pos] !== 0xff) return null;
    const marker = buf[pos + 1];
    if (marker === 0xda) {
      parts.push(buf.subarray(pos));
      if (orientation > 1) parts.splice(1, 0, orientationSegment(orientation));
      return Buffer.concat(parts);
    }
    const length = buf.readUInt16BE(pos + 2);
    const end = pos + 2 + length;
    if (length < 2 || end > buf.length) return null;
    if (JPEG_DROP.has(marker)) {
      if (marker === 0xe1 && !orientation) orientation = jpegOrientation(buf.subarray(pos + 4, end));
    } else {
      parts.push(buf.subarray(pos, end));
    }
    pos = end;
  }
  return null;
};

const stripPng = (buf) => {
  if (buf.length < 8 || buf[0] !== 0x89 || buf.toString('latin1', 1, 4) !== 'PNG') return null;
  const parts = [buf.subarray(0, 8)];
  let pos = 8;
  while (pos + 12 <= buf.length) {
    const length = buf.readUInt32BE(pos);
    const type = buf.toString('latin1', pos + 4, pos + 8);
    const end = pos + 12 + length;
    if (end > buf.length) return null;
    if (!PNG_DROP.has(type)) parts.push(buf.subarray(pos, end));
    pos = end;
    if (type === 'IEND') return Buffer.concat(parts);
  }
  return null;
};

const stripWebp = (buf) => {
  if (buf.length < 12 || buf.toString('latin1', 0, 4) !== 'RIFF' || buf.toString('latin1', 8, 12) !== 'WEBP') return null;
  const chunks = [];
  let pos = 12;
  while (pos + 8 <= buf.length) {
    const type = buf.toString('latin1', pos, pos + 4);
    const size = buf.readUInt32LE(pos + 4);
    const end = pos + 8 + size + (size % 2);
    if (pos + 8 + size > buf.length) return null;
    if (!WEBP_DROP.has(type)) {
      const chunk = Buffer.from(buf.subarray(pos, Math.min(end, buf.length)));
      // VP8X 旗標仍標示含 EXIF/XMP 時，部分解碼器會因找不到對應區塊而拒絕解析。
      if (type === 'VP8X' && chunk.length > 8) chunk[8] &= ~0x0c;
      chunks.push(chunk);
    }
    pos = end;
  }
  const body = Buffer.concat(chunks);
  const header = Buffer.alloc(12);
  header.write('RIFF', 0, 'latin1');
  header.writeUInt32LE(body.length + 4, 4);
  header.write('WEBP', 8, 'latin1');
  return Buffer.concat([header, body]);
};

// 無法解析時必須回傳 null 而非原檔：原檔可能含拍攝位置，不可送交外部 AI 服務商。
const stripImageMetadata = (buffer, mimeType) => {
  if (!Buffer.isBuffer(buffer)) return null;
  try {
    if (mimeType === 'image/jpeg') return stripJpeg(buffer);
    if (mimeType === 'image/png') return stripPng(buffer);
    if (mimeType === 'image/webp') return stripWebp(buffer);
    if (mimeType === 'image/gif') return buffer;
    return null;
  } catch {
    return null;
  }
};

module.exports = { stripImageMetadata };
