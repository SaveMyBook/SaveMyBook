// 產生 poster.css 的疊層陰影變數（無模糊、可向量輸出到 PDF）。
//   node tools/shadows.mjs   → 印出 CSS，貼回 src/poster.css 的 :root
// 每個陰影＝動畫的 1px 細線層＋以 N 層遞增擴散模擬的模糊層。
// 參數（動畫像素，乘上 --px）：y 位移、b 模糊半徑、A 最深處不透明度。
const N = 10;
const defs = [
  ['--shadow-card', 16, 36, 0.08],
  ['--shadow-chip', 8, 20, 0.08],
  ['--shadow-badge', 10, 24, 0.12],
  ['--shadow-tile', 18, 36, 0.10],
];
for (const [name, y, b, A] of defs) {
  const a = 1 - Math.pow(1 - A, 1 / N); // N 層疊起來最深處 = A
  const layers = ['0 calc(1 * var(--px)) 0 rgba(98, 125, 141, .12)'];
  for (let i = 0; i < N; i++) {
    const s = -b / 2 + (b * (i + 0.5)) / N;
    layers.push(`0 calc(${y} * var(--px)) 0 calc(${s.toFixed(2)} * var(--px)) rgba(22, 34, 43, ${a.toFixed(4)})`);
  }
  console.log(`  ${name}:\n    ${layers.join(',\n    ')};`);
}
