// 版面共用：主題、版型、排字小工具，以及寫檔後的 OOXML 後處理（主題色與字型、漸層字、影片自動播放）。
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const JSZip = require('jszip');

const ROOT = path.join(__dirname, '..');
const PRES = path.join(ROOT, '..');
const ASSETS = path.join(ROOT, 'build', 'assets');
// 示範影片：決賽重錄的匿名版（素材/video/）優先，其餘沿用複評素材
const VIDEO_DIRS = [path.join(ROOT, '素材', 'video'), path.join(PRES, '複評簡報', '素材', 'video')];

// 色票沿用易拉展（Apple 產品頁語言）：#F5F5F7 底、#1D1D1F 字、#6E6E73 次要字，強調色與「技術解法」綠出自 App
const THEME = {
  name: 'SaveMyBook',
  headFontFace: 'Noto Sans TC Black',
  bodyFontFace: 'Noto Sans TC Medium',
  colors: {
    dk1: '1D1D1F', lt1: 'FFFFFF', dk2: '6E6E73', lt2: 'F5F5F7',
    accent1: '2E749E', accent2: '2E9E5B', accent3: '7C97A6', accent4: '627D8D', accent5: 'E5E5EA', accent6: '151E27',
    hlink: '2E749E', folHlink: '627D8D'
  }
};
const BG = 'F5F5F7';
// 漸層字的記號色：後處理時換成 #7C97A6 → #2E749E 的線性漸層（同易拉展大標）
const GRAD = '2E749F';

const F = {
  black: 'Noto Sans TC Black',
  bold: 'Noto Sans TC',
  med: 'Noto Sans TC Medium',
  num: 'Manrope ExtraBold',
  numSemi: 'Manrope SemiBold'
};

const W = 13.333, H = 7.5, M = 0.6, CW = W - 2 * M;

const asset = (name) => path.join(ASSETS, name);
const videoDir = (name) => VIDEO_DIRS.find((d) => fs.existsSync(path.join(d, `${name}.mp4`))) || VIDEO_DIRS[1];
const videoPath = (name) => path.join(videoDir(name), `${name}.mp4`);
const dataUri = (file) => 'data:image/png;base64,' + fs.readFileSync(file).toString('base64');

function kit(pres) {
  const C = pres.SchemeColor;
  const col = { ink: C.text1, gray: C.text2, white: C.background1, accent: C.accent1, ok: C.accent2, mist: C.accent3, slate: C.accent4, line: C.accent5 };

  pres.defineSlideMaster({
    title: 'COVER',
    background: { color: BG }
  });
  pres.defineSlideMaster({
    title: 'CONTENT',
    background: { color: BG },
    objects: [
      { image: { x: M, y: 6.99, w: 0.24, h: 0.2, path: asset('logo.png') } },
      { text: { text: 'SaveMyBook', options: { x: M + 0.31, y: 6.96, w: 2, h: 0.26, margin: 0, fontFace: F.numSemi, fontSize: 11, color: col.gray, valign: 'middle' } } },
      { placeholder: { options: { name: 'title', type: 'title', x: M, y: 0.42, w: CW, h: 0.78, margin: 0, align: 'center', valign: 'middle', fontFace: F.black, fontSize: 34, color: col.ink }, text: '' } },
      { placeholder: { options: { name: 'sub', type: 'body', x: 1.1, y: 1.18, w: W - 2.2, h: 0.42, margin: 0, align: 'center', valign: 'middle', fontFace: F.med, fontSize: 16, color: col.gray }, text: '' } }
    ],
    slideNumber: { x: W - M - 0.8, y: 6.96, w: 0.8, h: 0.26, fontFace: F.numSemi, fontSize: 11, color: col.gray, align: 'right' }
  });

  // runs 陣列裡的純字串轉成 { text }（pptxgenjs 只收物件）
  const norm = (t) => (Array.isArray(t) ? t.map((r) => (typeof r === 'string' ? { text: r } : r)) : t);
  // 文字：一律 margin 0、靠上；text 可為字串或 runs
  const text = (slide, t, o) => slide.addText(norm(t), {
    isTextBox: true, margin: 0, x: o.x, y: o.y, w: o.w, h: o.h,
    fontFace: o.face || F.med, fontSize: o.size || 14, color: o.color || col.ink, bold: !!o.bold,
    align: o.align || 'left', valign: o.valign || 'top', lineSpacingMultiple: o.ls || 1.15,
    paraSpaceAfter: o.after || 0, objectName: o.name, lang: 'zh-TW'
  });
  // 白色大圓角格子（易拉展的便當格）
  const tile = (slide, x, y, w, h, name) => slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x, y, w, h, rectRadius: 0.2, fill: { color: col.white }, line: { type: 'none' }, objectName: name
  });
  // 大數字：數字用 Manrope、單位與前置字用思源黑體
  const num = (value, o = {}) => {
    const size = o.size || 44;
    const runs = [];
    if (o.pre) runs.push({ text: o.pre, options: { fontFace: F.black, fontSize: Math.round(size * 0.48) } });
    runs.push({ text: value, options: { fontFace: F.num, fontSize: size } });
    if (o.unit) runs.push({ text: o.unit, options: { fontFace: o.unit === '%' ? F.num : F.bold, bold: o.unit !== '%', fontSize: Math.round(size * 0.5) } });
    return runs;
  };
  const title = (slide, t) => slide.addText(norm(t), { placeholder: 'title', lang: 'zh-TW' });
  const sub = (slide, t) => slide.addText(norm(t), { placeholder: 'sub', lang: 'zh-TW' });
  const grad = (t) => ({ text: t, options: { color: GRAD } });
  // 影片：寬度依封面圖（<名稱>_poster.png）的長寬比；物件名稱「影片 <名稱>」供後處理加自動播放
  const video = (slide, name, x, y, h, caption) => {
    const poster = path.join(videoDir(name), `${name}_poster.png`);
    const png = fs.readFileSync(poster);
    const w = h * png.readUInt32BE(16) / png.readUInt32BE(20);
    slide.addMedia({ type: 'video', path: videoPath(name), cover: dataUri(poster), x, y, w, h, objectName: `影片 ${name}` });
    if (caption) text(slide, caption, { x, y: y + h + 0.06, w, h: 0.3, size: 13, face: F.bold, bold: true, color: col.gray, align: 'center' });
    return w;
  };
  return { C: col, text, tile, num, title, sub, grad, phone: video, video, durationMs: (name) => durationMs(videoPath(name)) };
}

// ── 後處理 ────────────────────────────────────────────────

const esc = (s) => s.replace(/&/g, '&amp;').replace(/"/g, '&quot;');

function patchTheme(xml) {
  const c = THEME.colors;
  const clr = (k) => `<a:${k}><a:srgbClr val="${c[k]}"/></a:${k}>`;
  const scheme = `<a:clrScheme name="${esc(THEME.name)}">${['dk1', 'lt1', 'dk2', 'lt2', 'accent1', 'accent2', 'accent3', 'accent4', 'accent5', 'accent6', 'hlink', 'folHlink'].map(clr).join('')}</a:clrScheme>`;
  const font = (tag, face) => `<a:${tag}><a:latin typeface="${face}"/><a:ea typeface="${face}"/><a:cs typeface="${face}"/><a:font script="Hant" typeface="${face}"/></a:${tag}>`;
  return xml
    .replace(/<a:clrScheme[\s\S]*?<\/a:clrScheme>/, scheme)
    .replace(/<a:majorFont>[\s\S]*?<\/a:majorFont>/, font('majorFont', THEME.headFontFace))
    .replace(/<a:minorFont>[\s\S]*?<\/a:minorFont>/, font('minorFont', THEME.bodyFontFace))
    .replace(/(<a:theme [^>]*name=")[^"]*"/, `$1${esc(THEME.name)}"`);
}

const GRAD_FILL = '<a:gradFill><a:gsLst><a:gs pos="0"><a:srgbClr val="7C97A6"/></a:gs><a:gs pos="100000"><a:srgbClr val="2E749E"/></a:gs></a:gsLst><a:lin ang="0" scaled="0"/></a:gradFill>';

const durationMs = (file) => {
  try {
    return Math.round(1000 * parseFloat(execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', file]).toString()));
  } catch { return 12000; }
};

// ── 動畫（XML 照複評簡報由 PowerPoint 存出的寫法）──
// 進入投影片後全部自動進行：影片播放並循環；標題、副標、各區塊依序「淡入＋上移」（presetID 42，500 毫秒）；
// 展示頁的步驟亮起依影片週期展開成多輪淡入淡出（presetID 10，300 毫秒）；轉場一律「淡出」。
const EMU = 914400;
const LOOPS = 10;
const TRANSITION = '<p:transition><p:fade/></p:transition>';

// 投影片上的形狀與位置；3D 模型的 mc:AlternateContent（內含替代圖）不列入
function shapesOf(xml) {
  const body = xml.replace(/<mc:AlternateContent[\s\S]*?<\/mc:AlternateContent>/g, '');
  return [...body.matchAll(/<p:(sp|pic)>[\s\S]*?<\/p:\1>/g)].map(([s, kind]) => {
    const [, id, name] = s.match(/<p:cNvPr id="(\d+)" name="([^"]*)"/);
    const off = s.match(/<a:off x="(-?\d+)" y="(-?\d+)"\/>/), ext = s.match(/<a:ext cx="(\d+)" cy="(\d+)"\/>/);
    const ph = s.includes('<p:ph') ? ((s.match(/<p:ph\b[^>]*?type="(\w+)"/) || [])[1] || 'body') : null;
    return { id, name, kind, ph, video: s.includes('<a:videoFile'), tile: s.includes('prst="roundRect"'),
      x: off ? +off[1] : 0, y: off ? +off[2] : 0, w: ext ? +ext[1] : 0, h: ext ? +ext[2] : 0 };
  });
}

// 進場順序：標題 → 副標 → 其餘區塊由上而下、由左而右；白色圓角格子連同格內的文字算同一個區塊
function entranceBlocks(shapes) {
  const anim = shapes.filter((s) => !s.video && !s.name.startsWith('步驟亮'));
  const tiles = anim.filter((s) => s.tile);
  const tol = 9144;
  const inside = (s, t) => s !== t && s.x >= t.x - tol && s.y >= t.y - tol && s.x + s.w <= t.x + t.w + tol && s.y + s.h <= t.y + t.h + tol;
  const blocks = anim.filter((s) => !tiles.some((t) => inside(s, t))).map((s) => [s, ...(s.tile ? anim.filter((o) => inside(o, s)) : [])]);
  const rank = (b) => (b[0].ph === 'title' ? 0 : b[0].ph ? 1 : 2);
  const row = (b) => Math.round(b[0].y / (EMU * 0.4));
  return blocks.sort((a, b) => rank(a) - rank(b) || row(a) - row(b) || a[0].x - b[0].x);
}

function timingXml(shapes) {
  let id = 4;
  const bld = [], grp = {};
  // 文字形狀每個效果各配一個 grpId，並登記在 bldLst（同 PowerPoint 的寫法）；圖片不需要
  const g = (s) => {
    if (s.kind !== 'sp') return '';
    const n = (grp[s.id] = (grp[s.id] ?? -1) + 1);
    bld.push(`<p:bldP spid="${s.id}" grpId="${n}" animBg="1"/>`);
    return ` grpId="${n}"`;
  };
  const tgt = (s) => `<p:tgtEl><p:spTgt spid="${s.id}"/></p:tgtEl>`;
  const vis = (s, v, delay = 0) => `<p:set><p:cBhvr><p:cTn id="${++id}" dur="1" fill="hold"><p:stCondLst><p:cond delay="${delay}"/></p:stCondLst></p:cTn>${tgt(s)}<p:attrNameLst><p:attrName>style.visibility</p:attrName></p:attrNameLst></p:cBhvr><p:to><p:strVal val="${v}"/></p:to></p:set>`;
  const fade = (s, dir, ms) => `<p:animEffect transition="${dir}" filter="fade"><p:cBhvr><p:cTn id="${++id}" dur="${ms}"/>${tgt(s)}</p:cBhvr></p:animEffect>`;
  const move = (s, attr, from, to) => `<p:anim calcmode="lin" valueType="num"><p:cBhvr><p:cTn id="${++id}" dur="500" fill="hold"/>${tgt(s)}<p:attrNameLst><p:attrName>${attr}</p:attrName></p:attrNameLst></p:cBhvr><p:tavLst><p:tav tm="0"><p:val><p:strVal val="${from}"/></p:val></p:tav><p:tav tm="100000"><p:val><p:strVal val="${to}"/></p:val></p:tav></p:tavLst></p:anim>`;
  const par = (preset, cls, s, delay, body) => {
    const a = ++id;
    return `<p:par><p:cTn id="${a}" presetID="${preset}" presetClass="${cls}" presetSubtype="0" fill="hold"${g(s)} nodeType="withEffect"><p:stCondLst><p:cond delay="${delay}"/></p:stCondLst><p:childTnLst>${body()}</p:childTnLst></p:cTn></p:par>`;
  };
  const fadeUp = (s, delay) => par(42, 'entr', s, delay, () => vis(s, 'visible') + fade(s, 'in', 500) + move(s, 'ppt_x', '#ppt_x', '#ppt_x') + move(s, 'ppt_y', '#ppt_y+0.04', '#ppt_y'));
  const fadeIn = (s, delay) => par(10, 'entr', s, delay, () => vis(s, 'visible') + fade(s, 'in', 300));
  const fadeOut = (s, delay) => par(10, 'exit', s, delay, () => fade(s, 'out', 300) + vis(s, 'hidden', 299));

  const videos = shapes.filter((s) => s.video);
  const pars = [];
  for (const v of videos) {
    const a = ++id, b = ++id;
    v.dur = durationMs(videoPath(v.name.replace(/^影片 /, '')));
    pars.push(`<p:par><p:cTn id="${a}" presetID="1" presetClass="mediacall" presetSubtype="0" fill="hold" nodeType="withEffect"><p:stCondLst><p:cond delay="0"/></p:stCondLst><p:childTnLst><p:cmd type="call" cmd="playFrom(0.0)"><p:cBhvr><p:cTn id="${b}" dur="${v.dur}" fill="hold"/>${tgt(v)}</p:cBhvr></p:cmd></p:childTnLst></p:cTn></p:par>`);
  }
  const blocks = entranceBlocks(shapes);
  const gap = blocks.length > 1 ? Math.min(120, 1400 / (blocks.length - 1)) : 0;
  blocks.forEach((b, i) => b.forEach((s) => pars.push(fadeUp(s, Math.round(i * gap)))));
  // 步驟亮起：物件名稱「步驟亮 n 底｜開始-結束-週期」（毫秒），依週期展開 LOOPS 輪
  for (const s of shapes.filter((x) => x.name.startsWith('步驟亮'))) {
    const [st, en, period] = s.name.split('｜')[1].split('-').map(Number);
    for (let l = 0; l < LOOPS; l++) pars.push(fadeIn(s, l * period + st), fadeOut(s, l * period + en));
  }
  if (!pars.length) return '';
  const nodes = videos.map((v) => `<p:video><p:cMediaNode vol="80000"><p:cTn id="${++id}" repeatCount="indefinite" fill="hold" display="0"><p:stCondLst><p:cond delay="indefinite"/></p:stCondLst></p:cTn>${tgt(v)}</p:cMediaNode></p:video>`).join('');
  return '<p:timing><p:tnLst><p:par><p:cTn id="1" dur="indefinite" restart="never" nodeType="tmRoot"><p:childTnLst>'
    + '<p:seq concurrent="1" nextAc="seek"><p:cTn id="2" dur="indefinite" nodeType="mainSeq"><p:childTnLst>'
    + '<p:par><p:cTn id="3" fill="hold"><p:stCondLst><p:cond delay="indefinite"/><p:cond evt="onBegin" delay="0"><p:tn val="2"/></p:cond></p:stCondLst><p:childTnLst>'
    + '<p:par><p:cTn id="4" fill="hold"><p:stCondLst><p:cond delay="0"/></p:stCondLst><p:childTnLst>'
    + pars.join('')
    + '</p:childTnLst></p:cTn></p:par>'
    + '</p:childTnLst></p:cTn></p:par>'
    + '</p:childTnLst></p:cTn><p:prevCondLst><p:cond evt="onPrev" delay="0"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:prevCondLst><p:nextCondLst><p:cond evt="onNext" delay="0"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:nextCondLst></p:seq>'
    + nodes
    + '</p:childTnLst></p:cTn></p:par></p:tnLst>'
    + (bld.length ? `<p:bldLst>${bld.join('')}</p:bldLst>` : '')
    + '</p:timing>';
}

// pptxgenjs 會在同一段的每個文字片段前都寫一次 <a:pPr>；新版 PowerPoint 把它當成另起一段而換行，只留第一個
const onePPr = (xml) => xml.replace(/<a:p>([\s\S]*?)<\/a:p>/g, (m, inner) => {
  let seen = false;
  return '<a:p>' + inner.replace(/<a:pPr\b[^>]*?(?:\/>|>[\s\S]*?<\/a:pPr>)/g, (p) => (seen ? '' : ((seen = true), p))) + '</a:p>';
});

// ── 封面 3D 模型（am3d:model3d）──
// 結構照 PowerPoint 以 Shapes.Add3DModel 存出的檔案（pptx-ts 的 test/read/fixtures/model3d.pptx）與
// [MS-ODRAWXML] 的 model3d schema：mc:Choice 是 PowerPoint 2019／365 即時算圖的 3D 模型，
// mc:Fallback 是舊版（含 Office 2016）顯示的替代圖。相機與畫框由 素材/cabinet.json 換算（見 海報_v2/tools/3d/web/harness.ts）。
const MODEL3D = { glb: path.join(ROOT, '素材', 'cabinet.glb'), json: path.join(ROOT, '素材', 'cabinet.json'), preview: asset('cabinet3d-preview.png') };
const EMU_PER_M = 36000000;
// PowerPoint 插入模型時固定寫入的燈光（環境光＋三盞點光源），照抄
const AM3D_LIGHTS = '<am3d:ambientLight><am3d:clr><a:scrgbClr r="50000" g="50000" b="50000"/></am3d:clr><am3d:illuminance n="500000" d="1000000"/></am3d:ambientLight>'
  + '<am3d:ptLight rad="0"><am3d:clr><a:scrgbClr r="100000" g="75000" b="50000"/></am3d:clr><am3d:intensity n="9765625" d="1000000"/><am3d:pos x="21959998" y="70920001" z="16344003"/></am3d:ptLight>'
  + '<am3d:ptLight rad="0"><am3d:clr><a:scrgbClr r="40000" g="60000" b="95000"/></am3d:clr><am3d:intensity n="12250000" d="1000000"/><am3d:pos x="-37964106" y="51130435" z="57631972"/></am3d:ptLight>'
  + '<am3d:ptLight rad="0"><am3d:clr><a:scrgbClr r="86837" g="72700" b="100000"/></am3d:clr><am3d:intensity n="3125000" d="1000000"/><am3d:pos x="-37739122" y="58056624" z="-34769649"/></am3d:ptLight>';

function model3dXml({ id, name, x, y, cx, cy, viewportSz, glbRid, imgRid, cam }) {
  const xfrm = `<a:off x="${x}" y="${y}"/><a:ext cx="${cx}" cy="${cy}"/>`;
  const one = 'n="1000000" d="1000000"';
  return '<mc:AlternateContent xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006">'
    + '<mc:Choice xmlns:am3d="http://schemas.microsoft.com/office/drawing/2017/model3d" Requires="am3d">'
    + `<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="${id}" name="${esc(name)}" descr="智慧書櫃 3D 模型"/><p:cNvGraphicFramePr><a:graphicFrameLocks/></p:cNvGraphicFramePr><p:nvPr/></p:nvGraphicFramePr>`
    + `<p:xfrm>${xfrm}</p:xfrm><a:graphic><a:graphicData uri="http://schemas.microsoft.com/office/drawing/2017/model3d">`
    + `<am3d:model3d r:embed="${glbRid}">`
    + `<am3d:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="${cx}" cy="${cy}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></am3d:spPr>`
    + `<am3d:camera><am3d:pos x="0" y="${cam.y}" z="${cam.z}"/><am3d:up dx="0" dy="${EMU_PER_M}" dz="0"/><am3d:lookAt x="0" y="0" z="0"/><am3d:perspective fov="2700000"/></am3d:camera>`
    + `<am3d:trans><am3d:meterPerModelUnit n="${cam.mpu}" d="1000000"/><am3d:preTrans dx="0" dy="0" dz="0"/><am3d:scale><am3d:sx ${one}/><am3d:sy ${one}/><am3d:sz ${one}/></am3d:scale><am3d:rot/><am3d:postTrans dx="0" dy="0" dz="0"/></am3d:trans>`
    + `<am3d:raster rName="Office3DRenderer" rVer="16.0.8326"><am3d:blip r:embed="${imgRid}"/></am3d:raster>`
    + `<am3d:objViewport viewportSz="${viewportSz}"/>${AM3D_LIGHTS}`
    + '</am3d:model3d></a:graphicData></a:graphic></p:graphicFrame></mc:Choice>'
    + `<mc:Fallback><p:pic><p:nvPicPr><p:cNvPr id="${id}" name="${esc(name)}" descr="智慧書櫃 3D 模型"/><p:cNvPicPr><a:picLocks noGrp="1" noRot="1" noChangeAspect="1" noMove="1" noResize="1" noEditPoints="1" noAdjustHandles="1" noChangeArrowheads="1" noChangeShapeType="1" noCrop="1"/></p:cNvPicPr><p:nvPr/></p:nvPicPr>`
    + `<p:blipFill><a:blip r:embed="${imgRid}"/><a:stretch><a:fillRect/></a:stretch></p:blipFill><p:spPr><a:xfrm>${xfrm}</a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr></p:pic></mc:Fallback>`
    + '</mc:AlternateContent>';
}

// 把物件名稱「封面書櫃」的靜態圖換成 3D 模型：高度與水平中心沿用靜態圖，寬度依模型投影比例
async function embedModel3d(zip, name, xml) {
  const pic = (xml.match(/<p:pic>[\s\S]*?<\/p:pic>/g) || []).find((p) => p.includes('name="封面書櫃"'));
  if (!pic) return xml;
  const [, id] = pic.match(/<p:cNvPr id="(\d+)"/);
  const [, ox, oy] = pic.match(/<a:off x="(\d+)" y="(\d+)"\/>/).map(Number);
  const [, ecx, ecy] = pic.match(/<a:ext cx="(\d+)" cy="(\d+)"\/>/).map(Number);
  const m = JSON.parse(fs.readFileSync(MODEL3D.json, 'utf8'));
  const viewportSz = Math.round(ecy / m.fy), cx = Math.round(viewportSz * m.fx);
  const cam = {
    y: Math.round(m.dist * Math.sin(m.pitch) * EMU_PER_M),
    z: Math.round(m.dist * Math.cos(m.pitch) * EMU_PER_M),
    mpu: Math.round(1000000 / m.maxExt)
  };
  zip.file('ppt/media/model3d1.glb', fs.readFileSync(MODEL3D.glb));
  zip.file('ppt/media/model3d1-preview.png', fs.readFileSync(MODEL3D.preview));
  const relsName = name.replace('slides/', 'slides/_rels/') + '.rels';
  const rels = await zip.file(relsName).async('string');
  zip.file(relsName, rels.replace('</Relationships>',
    '<Relationship Id="rIdM3d1" Type="http://schemas.microsoft.com/office/2017/06/relationships/model3d" Target="../media/model3d1.glb"/>'
    + '<Relationship Id="rIdM3d2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/model3d1-preview.png"/></Relationships>'));
  const ct = await zip.file('[Content_Types].xml').async('string');
  if (!ct.includes('Extension="glb"')) zip.file('[Content_Types].xml', ct.replace('<Default ', '<Default Extension="glb" ContentType="model/gltf.binary"/><Default '));
  return xml.replace(pic, model3dXml({
    id, name: '封面書櫃 3D', x: Math.round(ox + ecx / 2 - cx / 2), y: oy, cx, cy: ecy, viewportSz, glbRid: 'rIdM3d1', imgRid: 'rIdM3d2', cam
  }));
}

async function postprocess(file) {
  const zip = await JSZip.loadAsync(fs.readFileSync(file));
  for (const name of Object.keys(zip.files)) {
    if (/^ppt\/theme\/theme\d+\.xml$/.test(name)) zip.file(name, patchTheme(await zip.file(name).async('string')));
    if (!/^ppt\/(slides\/slide|slideLayouts\/slideLayout)\d+\.xml$/.test(name)) continue;
    let xml = await zip.file(name).async('string');
    xml = onePPr(xml.split(`<a:solidFill><a:srgbClr val="${GRAD}"/></a:solidFill>`).join(GRAD_FILL));
    if (name.startsWith('ppt/slides/')) {
      // pptxgenjs 會給影片重複的物件 id；timing 以 id 指向形狀，重複時 PowerPoint 拒開，所以先依序重新編號
      let n = 0;
      xml = xml.replace(/<p:cNvPr id="\d+"/g, () => `<p:cNvPr id="${++n}"`);
      xml = await embedModel3d(zip, name, xml);
      xml = xml.replace('</p:clrMapOvr>', '</p:clrMapOvr>' + TRANSITION + timingXml(shapesOf(xml)));
    }
    zip.file(name, xml);
  }
  fs.writeFileSync(file, await zip.generateAsync({ type: 'nodebuffer', compression: 'DEFLATE' }));
}

module.exports = { THEME, F, W, H, M, CW, asset, kit, postprocess, ROOT };
