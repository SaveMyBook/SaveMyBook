'use strict';

const path = require('path');
const { el } = require('./core');

const QR = require(path.resolve(__dirname, '../../../../savemybook_api/views/kiosk/qrcode.js'));

function qrMatrix(payload) {
  return QR.encode(payload);
}

function qrPath(matrix, x, y, moduleSize) {
  const { size, modules } = matrix;
  let d = '';
  for (let r = 0; r < size; r++) {
    let c = 0;
    while (c < size) {
      if (!modules[r][c]) {
        c++;
        continue;
      }
      let run = 1;
      while (c + run < size && modules[r][c + run]) run++;
      d += `M${+(x + c * moduleSize).toFixed(2)} ${+(y + r * moduleSize).toFixed(2)}h${+(run * moduleSize).toFixed(2)}v${+moduleSize.toFixed(2)}h${-(run * moduleSize).toFixed(2)}z`;
      c += run;
    }
  }
  return d;
}

function qrCode(payload, { x, y, box, quiet = 4, fill = '#000000', bg = '#FFFFFF' }) {
  const m = qrMatrix(payload);
  const unit = box / (m.size + quiet * 2);
  return {
    matrix: m,
    markup: [el('rect', { x, y, width: box, height: box, fill: bg }), el('path', { d: qrPath(m, x + quiet * unit, y + quiet * unit, unit), fill })],
  };
}

module.exports = { qrMatrix, qrPath, qrCode };
