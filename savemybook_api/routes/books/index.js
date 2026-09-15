const express = require('express');

const SECTIONS = [
  './catalog',
  './listings'
];

const router = express.Router();

for (const section of SECTIONS) {
  router.use(require(section));
}

module.exports = router;
