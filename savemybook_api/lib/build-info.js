const { execSync } = require('child_process');
const path = require('path');

const readCommit = () => {
  try {
    return execSync('git rev-parse --short HEAD', { cwd: path.join(__dirname, '..'), stdio: ['ignore', 'pipe', 'ignore'] })
      .toString()
      .trim();
  } catch {
    return null;
  }
};

const buildInfo = Object.freeze({
  commit: readCommit(),
  startedAt: new Date(),
  apiRevision: 10
});

module.exports = { buildInfo };
