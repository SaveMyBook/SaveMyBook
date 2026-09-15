const { init, isReady } = require('./setup');
const devices = require('./devices');
const dispatcher = require('./dispatcher');

module.exports = { init, isReady, ...devices, ...dispatcher };
