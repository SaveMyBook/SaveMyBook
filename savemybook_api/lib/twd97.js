// TWD97 二度分帶（TM2，中央經線 121°）平面座標轉 WGS84 經緯度，GRS80 橢球。
const A = 6378137.0;
const B = 6356752.314245;
const LON0 = (121 * Math.PI) / 180;
const K0 = 0.9999;
const DX = 250000;

const E = Math.sqrt(1 - (B * B) / (A * A));
const E2 = ((E * A) / B) ** 2;
const E1 = (1 - Math.sqrt(1 - E ** 2)) / (1 + Math.sqrt(1 - E ** 2));
const J1 = (3 * E1) / 2 - (27 * E1 ** 3) / 32;
const J2 = (21 * E1 ** 2) / 16 - (55 * E1 ** 4) / 32;
const J3 = (151 * E1 ** 3) / 96;
const J4 = (1097 * E1 ** 4) / 512;

const toWgs84 = (x, y) => {
  const mu = y / K0 / (A * (1 - E ** 2 / 4 - (3 * E ** 4) / 64 - (5 * E ** 6) / 256));
  const fp = mu + J1 * Math.sin(2 * mu) + J2 * Math.sin(4 * mu) + J3 * Math.sin(6 * mu) + J4 * Math.sin(8 * mu);
  const sin = Math.sin(fp);
  const cos = Math.cos(fp);
  const C1 = E2 * cos ** 2;
  const T1 = Math.tan(fp) ** 2;
  const R1 = (A * (1 - E ** 2)) / (1 - E ** 2 * sin ** 2) ** 1.5;
  const N1 = A / Math.sqrt(1 - E ** 2 * sin ** 2);
  const D = (x - DX) / (N1 * K0);

  const lat = fp - ((N1 * Math.tan(fp)) / R1) * (
    (D * D) / 2
    - ((5 + 3 * T1 + 10 * C1 - 4 * C1 * C1 - 9 * E2) * D ** 4) / 24
    + ((61 + 90 * T1 + 298 * C1 + 45 * T1 * T1 - 3 * C1 * C1 - 252 * E2) * D ** 6) / 720
  );
  const lng = LON0 + (
    D
    - ((1 + 2 * T1 + C1) * D ** 3) / 6
    + ((5 - 2 * C1 + 28 * T1 - 3 * C1 * C1 + 8 * E2 + 24 * T1 * T1) * D ** 5) / 120
  ) / cos;

  return { lat: (lat * 180) / Math.PI, lng: (lng * 180) / Math.PI };
};

module.exports = { toWgs84 };
