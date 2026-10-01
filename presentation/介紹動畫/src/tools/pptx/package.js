'use strict';

// PowerPoint 檔案的固定部件（主題、母片、版面配置），以及打包成 .pptx。
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const NS_A = 'http://schemas.openxmlformats.org/drawingml/2006/main';
const NS_R = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const NS_P = 'http://schemas.openxmlformats.org/presentationml/2006/main';
const REL = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const HEAD = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';

const SLIDE_W = 12192000;
const SLIDE_H = 6858000;

const EMPTY_TREE =
  '<p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree>';

function theme(font) {
  const clr = (name, v) => `<a:${name}><a:srgbClr val="${v}"/></a:${name}>`;
  const fontScheme = (tag) => `<a:${tag}><a:latin typeface="${font}"/><a:ea typeface="${font}"/><a:cs typeface="${font}"/></a:${tag}>`;
  const solid = '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>';
  return (
    HEAD +
    `<a:theme xmlns:a="${NS_A}" name="SaveMyBook"><a:themeElements>` +
    '<a:clrScheme name="SaveMyBook"><a:dk1><a:srgbClr val="151E27"/></a:dk1><a:lt1><a:srgbClr val="FFFFFF"/></a:lt1>' +
    clr('dk2', '0E1318') +
    clr('lt2', 'F3F5F7') +
    clr('accent1', '627D8D') +
    clr('accent2', '2E9E5B') +
    clr('accent3', 'D98613') +
    clr('accent4', 'D64545') +
    clr('accent5', '46B59C') +
    clr('accent6', '5B6770') +
    clr('hlink', '627D8D') +
    clr('folHlink', '8A969F') +
    '</a:clrScheme>' +
    `<a:fontScheme name="SaveMyBook">${fontScheme('majorFont')}${fontScheme('minorFont')}</a:fontScheme>` +
    '<a:fmtScheme name="SaveMyBook">' +
    `<a:fillStyleLst>${solid}${solid}${solid}</a:fillStyleLst>` +
    `<a:lnStyleLst><a:ln w="6350">${solid}</a:ln><a:ln w="12700">${solid}</a:ln><a:ln w="19050">${solid}</a:ln></a:lnStyleLst>` +
    '<a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst>' +
    `<a:bgFillStyleLst>${solid}${solid}${solid}</a:bgFillStyleLst>` +
    '</a:fmtScheme></a:themeElements><a:objectDefaults/><a:extraClrSchemeLst/></a:theme>'
  );
}

const CLR_MAP = '<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>';

function master(bg) {
  return (
    HEAD +
    `<p:sldMaster xmlns:a="${NS_A}" xmlns:r="${NS_R}" xmlns:p="${NS_P}">` +
    `<p:cSld><p:bg><p:bgPr><a:solidFill><a:srgbClr val="${bg}"/></a:solidFill><a:effectLst/></p:bgPr></p:bg>${EMPTY_TREE}</p:cSld>` +
    CLR_MAP +
    '<p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>' +
    '</p:sldMaster>'
  );
}

const LAYOUT =
  HEAD +
  `<p:sldLayout xmlns:a="${NS_A}" xmlns:r="${NS_R}" xmlns:p="${NS_P}" type="blank" preserve="1">` +
  `<p:cSld name="空白">${EMPTY_TREE}</p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>`;

function rels(list) {
  return (
    HEAD +
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
    list.map(([id, type, target]) => `<Relationship Id="${id}" Type="${REL}/${type}" Target="${target}"/>`).join('') +
    '</Relationships>'
  );
}

function write({ out, slides, media, title, bg, font }) {
  const dir = fs.mkdtempSync(path.join(require('os').tmpdir(), 'pptx-'));
  const put = (name, data) => {
    const f = path.join(dir, name);
    fs.mkdirSync(path.dirname(f), { recursive: true });
    fs.writeFileSync(f, data);
  };
  const n = slides.length;
  put(
    '[Content_Types].xml',
    HEAD +
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
      '<Default Extension="xml" ContentType="application/xml"/>' +
      '<Default Extension="png" ContentType="image/png"/>' +
      '<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>' +
      '<Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>' +
      '<Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>' +
      '<Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>' +
      '<Override PartName="/ppt/presProps.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presProps+xml"/>' +
      '<Override PartName="/ppt/viewProps.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.viewProps+xml"/>' +
      '<Override PartName="/ppt/tableStyles.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.tableStyles+xml"/>' +
      '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>' +
      '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>' +
      slides.map((_, i) => `<Override PartName="/ppt/slides/slide${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>`).join('') +
      '</Types>'
  );
  put('_rels/.rels', rels([['rId1', 'officeDocument', 'ppt/presentation.xml'], ['rId2', 'metadata/core-properties', 'docProps/core.xml'], ['rId3', 'extended-properties', 'docProps/app.xml']]).replace(`${REL}/metadata/core-properties`, 'http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties'));
  const now = new Date().toISOString().replace(/\.\d+Z$/, 'Z');
  put(
    'docProps/core.xml',
    HEAD +
      '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">' +
      `<dc:title>${title}</dc:title><dcterms:created xsi:type="dcterms:W3CDTF">${now}</dcterms:created><dcterms:modified xsi:type="dcterms:W3CDTF">${now}</dcterms:modified>` +
      '</cp:coreProperties>'
  );
  put('docProps/app.xml', HEAD + `<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"><Application>Microsoft Office PowerPoint</Application><Slides>${n}</Slides></Properties>`);
  put(
    'ppt/presentation.xml',
    HEAD +
      `<p:presentation xmlns:a="${NS_A}" xmlns:r="${NS_R}" xmlns:p="${NS_P}" saveSubsetFonts="1">` +
      '<p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>' +
      `<p:sldIdLst>${slides.map((_, i) => `<p:sldId id="${256 + i}" r:id="rId${i + 10}"/>`).join('')}</p:sldIdLst>` +
      `<p:sldSz cx="${SLIDE_W}" cy="${SLIDE_H}"/><p:notesSz cx="6858000" cy="9144000"/>` +
      '<p:defaultTextStyle><a:defPPr><a:defRPr lang="zh-TW"/></a:defPPr></p:defaultTextStyle>' +
      '</p:presentation>'
  );
  put(
    'ppt/_rels/presentation.xml.rels',
    rels([
      ['rId1', 'slideMaster', 'slideMasters/slideMaster1.xml'],
      ['rId2', 'theme', 'theme/theme1.xml'],
      ['rId3', 'presProps', 'presProps.xml'],
      ['rId4', 'viewProps', 'viewProps.xml'],
      ['rId5', 'tableStyles', 'tableStyles.xml'],
      ...slides.map((_, i) => [`rId${i + 10}`, 'slide', `slides/slide${i + 1}.xml`]),
    ])
  );
  put('ppt/presProps.xml', HEAD + `<p:presentationPr xmlns:a="${NS_A}" xmlns:r="${NS_R}" xmlns:p="${NS_P}"/>`);
  put('ppt/viewProps.xml', HEAD + `<p:viewPr xmlns:a="${NS_A}" xmlns:r="${NS_R}" xmlns:p="${NS_P}"><p:gridSpacing cx="76200" cy="76200"/></p:viewPr>`);
  put('ppt/tableStyles.xml', HEAD + `<a:tblStyleLst xmlns:a="${NS_A}" def="{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}"/>`);
  put('ppt/theme/theme1.xml', theme(font));
  put('ppt/slideMasters/slideMaster1.xml', master(bg));
  put('ppt/slideMasters/_rels/slideMaster1.xml.rels', rels([['rId1', 'slideLayout', '../slideLayouts/slideLayout1.xml'], ['rId2', 'theme', '../theme/theme1.xml']]));
  put('ppt/slideLayouts/slideLayout1.xml', LAYOUT);
  put('ppt/slideLayouts/_rels/slideLayout1.xml.rels', rels([['rId1', 'slideMaster', '../slideMasters/slideMaster1.xml']]));
  for (const [name, data] of Object.entries(media)) put(`ppt/media/${name}`, data);
  slides.forEach((s, i) => {
    put(`ppt/slides/slide${i + 1}.xml`, s.xml);
    put(`ppt/slides/_rels/slide${i + 1}.xml.rels`, rels([['rId1', 'slideLayout', '../slideLayouts/slideLayout1.xml'], ...s.images.map((m, j) => [`rIdP${j + 1}`, 'image', `../media/${m}`])]));
  });
  if (fs.existsSync(out)) fs.unlinkSync(out);
  // [Content_Types].xml 必須是壓縮檔中的第一個項目。
  execFileSync('zip', ['-X', '-q', out, '[Content_Types].xml'], { cwd: dir });
  execFileSync('zip', ['-X', '-q', '-r', out, '.', '-x', '[Content_Types].xml'], { cwd: dir });
  fs.rmSync(dir, { recursive: true, force: true });
}

module.exports = { write, SLIDE_W, SLIDE_H, NS_A, NS_R, NS_P, HEAD };
