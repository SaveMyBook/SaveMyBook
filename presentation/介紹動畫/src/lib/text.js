'use strict';

const path = require('path');
const opentype = require('opentype.js');
const { el, g, fmt, motion, clipPath, nextId } = require('./core');

const FONT_DIR = path.resolve(__dirname, '../../../../savemybook_app/assets/fonts');
const WEIGHTS = { 100: 'Thin', 200: 'ExtraLight', 300: 'Light', 400: 'Regular', 500: 'Medium', 600: 'SemiBold', 700: 'Bold', 800: 'ExtraBold', 900: 'Black' };

const fonts = new Map();
const glyphs = new Map();

function font(weight) {
  if (!WEIGHTS[weight]) throw new Error(`沒有字重 ${weight}`);
  if (!fonts.has(weight)) fonts.set(weight, opentype.loadSync(path.join(FONT_DIR, `NotoSansTC-${WEIGHTS[weight]}.ttf`)));
  return fonts.get(weight);
}

const OPENING = new Set(['「', '『', '（', '【', '《', '〈']);
const CLOSING = new Set(['」', '』', '）', '】', '》', '〉']);

function glyphId(weight, glyph) {
  const id = `f${weight / 100}_${glyph.index.toString(36)}`;
  if (!glyphs.has(id)) {
    const d = glyph.getPath(0, 0, 1000).toPathData(0);
    glyphs.set(id, d);
  }
  return id;
}

const TIGHT_PUNCT = { '。': [-280, 600], '，': [-300, 520], '、': [-300, 520] };

function layout(str, { weight = 400, ls = 0, tight = true, punct } = {}) {
  const f = font(weight);
  const chars = [...str];
  const items = [];
  let x = 0;
  let prev = null;
  for (let i = 0; i < chars.length; i++) {
    const ch = chars[i];
    const gl = f.charToGlyph(ch);
    if (!gl || gl.index === 0) throw new Error(`字型缺字：${ch}`);
    if (prev) x += f.getKerningValue(prev, gl);
    let adv = gl.advanceWidth;
    let shift = 0;
    if (tight && OPENING.has(ch)) {
      shift = -500;
      adv = 500;
    } else if (tight && CLOSING.has(ch)) {
      adv = 500;
    } else if (punct === 'tight' && TIGHT_PUNCT[ch]) {
      [shift, adv] = TIGHT_PUNCT[ch];
    }
    items.push({ ch, id: ch === ' ' ? null : glyphId(weight, gl), x: x + shift, adv, index: i });
    x += adv + (i < chars.length - 1 ? ls * 1000 : 0);
    prev = gl;
  }
  return { items, width: x };
}

const measure = (str, size, opts = {}) => (layout(str, opts).width * size) / 1000;

function text(str, opts = {}) {
  const {
    x = 0,
    y = 0,
    size = 32,
    weight = 400,
    fill = '#151E27',
    anchor = 'start',
    ls = 0,
    opacity,
    perChar,
    attrs = {},
    tight = true,
    punct,
  } = opts;
  const { items, width } = layout(str, { weight, ls, tight, punct });
  const s = size / 1000;
  const offset = anchor === 'middle' ? -width / 2 : anchor === 'end' ? -width : 0;
  const pieces = items
    .filter((it) => it.id)
    .map((it, n) => {
      const use = el('use', { href: `#${it.id}`, x: it.x + offset });
      if (!perChar) return use;
      const spec = perChar(n, it.ch, ((it.x + offset + it.adv / 2) * s));
      if (!spec) return use;
      const conv = { ...spec };
      if (spec.t) conv.t = spec.t.map(([t, v, e]) => [t, [v[0] / s, v[1] / s], e]);
      if (spec.s) {
        conv.origin = [it.x + offset + it.adv / 2, -380];
      }
      return motion(conv, use);
    });
  const tag = TAG.on ? { class: 'tx', 'data-t': str } : {};
  return g({ transform: `translate(${fmt(x)} ${fmt(y)}) scale(${fmt(s)})`, fill, opacity, ...tag, ...attrs }, pieces);
}

// 檢查工具用：開啟後每段文字加上 class 與原文，方便比對文字是否被其他物件遮住。
const TAG = { on: process.env.SVG_TAG_TEXT === '1' };

function textBlock(str, opts = {}) {
  const { width } = layout(str, { weight: opts.weight || 400, ls: opts.ls || 0, tight: opts.tight !== false });
  return { markup: text(str, opts), width: (width * (opts.size || 32)) / 1000 };
}

function riseLine(str, opts) {
  const { x = 0, y = 0, size, t0, stagger = 0.045, dur = 0.8, rise = 0.9, ease = 'emph', anchor = 'start', clip = true, weight = 400, charFill } = opts;
  const w = measure(str, size, { weight, ls: opts.ls || 0 });
  const left = anchor === 'middle' ? x - w / 2 : anchor === 'end' ? x - w : x;
  const body = text(str, {
    ...opts,
    perChar: (n, ch) => ({
      t: [[t0 + n * stagger, [0, size * rise]], [t0 + n * stagger + dur, [0, 0], ease]],
      o: [[t0 + n * stagger, 0], [t0 + n * stagger + dur * 0.6, 1, 'out']],
      fill: charFill ? charFill(n, ch) : undefined,
    }),
  });
  if (!clip) return body;
  const id = nextId('rc');
  const url = clipPath(id, el('rect', { x: left - size, y: y - size * 1.25, width: w + size * 2, height: size * 1.62 }));
  return g({ 'clip-path': url }, body);
}

function textClip(id, str, opts = {}) {
  const { x = 0, y = 0, size = 32, weight = 400, anchor = 'start', ls = 0, punct } = opts;
  const { items, width } = layout(str, { weight, ls, punct });
  const s = size / 1000;
  const offset = anchor === 'middle' ? -width / 2 : anchor === 'end' ? -width : 0;
  const uses = items.filter((it) => it.id).map((it) => el('use', { href: `#${it.id}`, x: it.x + offset, transform: `translate(${fmt(x)} ${fmt(y)}) scale(${fmt(s)})` }));
  require('./core').addDef(el('clipPath', { id }, uses));
  return { url: `url(#${id})`, width: width * s, left: x + offset * s };
}

function ellipsize(str, size, maxW, opts = {}) {
  if (measure(str, size, opts) <= maxW) return str;
  const chars = [...str];
  while (chars.length > 1 && measure(chars.join('') + '…', size, opts) > maxW) chars.pop();
  return chars.join('') + '…';
}

function glyphDefs() {
  return [...glyphs.entries()].map(([id, d]) => el('path', { id, d }));
}

function resetGlyphs() {
  glyphs.clear();
}

module.exports = { font, layout, measure, text, textBlock, riseLine, textClip, ellipsize, glyphDefs, resetGlyphs, glyphs };
