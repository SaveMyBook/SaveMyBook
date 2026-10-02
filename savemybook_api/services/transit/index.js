const { DATASETS } = require('./opendata');
const mrt = require('./mrt');
const youbike = require('./youbike');
const parking = require('./parking');
const roadside = require('./roadside');
const bus = require('./bus');
const road = require('./road');
const { resetAll } = require('./source');

const ATTRIBUTION = '資料來源：臺北市資料大平臺（data.taipei），依政府資料開放授權條款第 1 版使用';

const SOURCE_KEYS = [
  'mrtExits', 'mrtAccessibility', 'mrtFares', 'busStops', 'busEstimates', 'busRoutes', 'youbike',
  'parkingLots', 'roadsideSpaces', 'roadsideUsage', 'roadSpeed', 'taxiStands'
];

const nearby = async (lat, lng) => {
  const [metro, buses, bikes, lots, street, speed, taxi] = await Promise.all([
    mrt.nearby(lat, lng),
    bus.nearby(lat, lng),
    youbike.nearby(lat, lng),
    parking.nearby(lat, lng),
    roadside.nearby(lat, lng),
    road.speeds(lat, lng),
    road.taxi(lat, lng)
  ]);
  return {
    mrt: metro,
    bus: buses,
    youbike: bikes,
    parking_lots: lots,
    roadside: street,
    road_speed: speed,
    taxi_stands: taxi,
    attribution: ATTRIBUTION,
    sources: SOURCE_KEYS.map((key) => ({
      title: DATASETS[key].title,
      url: `https://data.taipei/dataset/detail?id=${DATASETS[key].dataset}`
    }))
  };
};

// 啟動後先載入每日更新的靜態資料與格位索引，第一位使用者查詢時只需等待即時資料。
const warm = async () => {
  roadside.currentLayer();
  await Promise.all([mrt.warm(), parking.warm(), bus.warm(), road.warm()]);
};

const reset = () => {
  resetAll();
  roadside.resetLayer();
};

module.exports = {
  nearby,
  stations: mrt.stations,
  fares: mrt.fares,
  refreshRoadsideLayer: roadside.refreshLayerIfDue,
  warm,
  reset,
  ATTRIBUTION
};
