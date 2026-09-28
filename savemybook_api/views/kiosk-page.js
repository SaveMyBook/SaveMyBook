const { escapeHtml } = require('../lib/html');

// CSP 只允許同源的腳本與樣式，這裡不可加入任何行內 <script>、<style> 或 style 屬性。
const kioskPage = ({ base }) => {
  const asset = (file) => escapeHtml(`${base}/assets/${file}`);
  return `<!doctype html>
<html lang="zh-Hant">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<meta name="color-scheme" content="light dark">
<title>模擬書櫃｜救「舊」我的書</title>
<link rel="icon" href="data:,">
<link rel="stylesheet" href="${asset('kiosk.css')}">
<script src="${asset('qrcode.js')}" defer></script>
<script src="${asset('device-core.js')}" defer></script>
<script src="${asset('kiosk.js')}" defer></script>
</head>
<body>
<div class="watermark" role="note">測試用模擬書櫃，非實體書櫃</div>
<main id="kiosk" class="layout"></main>
</body>
</html>
`;
};

module.exports = { kioskPage };
