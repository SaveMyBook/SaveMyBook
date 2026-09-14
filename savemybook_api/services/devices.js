const PLATFORM_NAMES = { ios: 'iOS', android: 'Android' };

const deviceLabel = ({ deviceName, platform } = {}) => {
  const name = typeof deviceName === 'string' ? deviceName.trim().slice(0, 80) : '';
  const os = PLATFORM_NAMES[platform] ?? (typeof platform === 'string' ? platform.slice(0, 20) : '');
  if (name && os) return `${name}（${os}）`;
  return name || os || '未知裝置';
};

module.exports = { deviceLabel };
