const express = require('express');

const SECTIONS = [
  './account',
  './preferences',
  './profiles'
];

const router = express.Router();

// /me/* 須排在 /:id 之前。
for (const section of SECTIONS) {
  router.use(require(section));
}

module.exports = router;
