'use strict';

const fs = require('fs');
const path = require('path');
const core = require('./lib/core');
const text = require('./lib/text');
const C = require('./lib/palette');

const OUT_DIR = path.resolve(__dirname, '..');

const TARGETS = {
  full: { scene: './scenes/full', file: '四技第115414組-救「舊」我的書-介紹動畫.svg' },
  sample: { scene: './scenes/sample5', file: '四技第115414組-救「舊」我的書-介紹動畫樣片.svg' },
  sample4: { scene: './scenes/sample4', file: '四技第115414組-救「舊」我的書-介紹動畫樣片v4.svg' },
  sample3: { scene: './scenes/sample', file: '四技第115414組-救「舊」我的書-介紹動畫樣片v3.svg' },
};

function assemble(result, { clickToStart = false } = {}) {
  const start = clickToStart
    ? core.el(
        'rect',
        { id: 'startCover', width: 1920, height: 1080, fill: C.stage },
        core.el('animate', { id: 'start', attributeName: 'opacity', from: 1, to: 0, dur: '0.01s', begin: 'click', fill: 'freeze', restart: 'never' }),
        core.el('set', { attributeName: 'display', to: 'none', begin: 'start.end' })
      )
    : '';
  const defs = core.el('defs', {}, text.glyphDefs(), core.defs);
  const heartbeat = core.el(
    'rect',
    { x: 0, y: 0, width: 2, height: 2, fill: C.stage, 'fill-opacity': 0 },
    core.el('animate', { attributeName: 'x', values: '0;2;0', dur: `${result.duration}s`, begin: clickToStart ? 'start.begin' : '0s', fill: 'freeze' })
  );
  return [
    '<?xml version="1.0" encoding="UTF-8"?>',
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1920 1080" width="100%" height="100%" preserveAspectRatio="xMidYMid meet" style="background:${C.stage}">`,
    `<title>${core.esc(result.title)}</title>`,
    defs,
    heartbeat,
    ...result.body,
    start,
    '</svg>',
  ].join('\n');
}

function build(name, { clickToStart = false } = {}) {
  const target = TARGETS[name];
  if (!target) throw new Error(`未知目標：${name}`);
  core.resetDefs();
  text.resetGlyphs();
  core.clock.base = clickToStart ? 'start' : null;
  const scene = require(target.scene);
  core.clock.end = null;
  const probe = scene.build();
  core.resetDefs();
  text.resetGlyphs();
  core.clock.end = probe.duration;
  const result = scene.build();
  const svg = assemble(result, { clickToStart });
  const file = clickToStart ? target.file.replace('.svg', '-點擊播放.svg') : target.file;
  const out = process.env.SVG_OUT || path.join(OUT_DIR, file);
  fs.writeFileSync(out, svg);
  const stats = {
    file: out,
    duration: result.duration,
    bytes: svg.length,
    glyphs: text.glyphs.size,
    animations: (svg.match(/<animate|<set /g) || []).length,
  };
  return stats;
}

if (require.main === module) {
  const name = process.argv[2] || 'sample';
  const click = process.argv.includes('--click');
  const stats = build(name, { clickToStart: click });
  console.log(JSON.stringify(stats, null, 2));
}

module.exports = { build };
