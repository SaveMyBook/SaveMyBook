const clip = (value, max) => (value.length > max ? `${value.slice(0, max - 1)}…` : value);

module.exports = { clip };
