const EARTH_RADIUS_M = 6371000;

const toRad = (deg) => (deg * Math.PI) / 180;

const distanceMeters = (lat1, lng1, lat2, lng2) => {
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return Math.round(2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(a))));
};

// 以經緯度方格分桶的點索引，查詢半徑內的點時只掃描涵蓋的方格。
const cellKey = (i, j) => `${i}:${j}`;

const createGridIndex = (count, latOf, lngOf, cellDeg = 0.005) => {
  const cells = new Map();
  for (let k = 0; k < count; k += 1) {
    const key = cellKey(Math.floor(latOf(k) / cellDeg), Math.floor(lngOf(k) / cellDeg));
    let list = cells.get(key);
    if (!list) cells.set(key, (list = []));
    list.push(k);
  }

  const within = (lat, lng, radiusM) => {
    const dLat = radiusM / 111320;
    const dLng = radiusM / (111320 * Math.cos(toRad(lat)));
    const hits = [];
    for (let i = Math.floor((lat - dLat) / cellDeg); i <= Math.floor((lat + dLat) / cellDeg); i += 1) {
      for (let j = Math.floor((lng - dLng) / cellDeg); j <= Math.floor((lng + dLng) / cellDeg); j += 1) {
        for (const k of cells.get(cellKey(i, j)) ?? []) {
          const d = distanceMeters(lat, lng, latOf(k), lngOf(k));
          if (d <= radiusM) hits.push({ index: k, distance: d });
        }
      }
    }
    return hits.sort((a, b) => a.distance - b.distance);
  };

  return { within };
};

module.exports = { distanceMeters, createGridIndex };
