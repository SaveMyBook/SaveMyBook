const express = require('express');
const authenticateToken = require('../../middleware/auth');

const SECTIONS = [
  './rooms',
  './messages',
  './groups',
  './reservations',
  './transfers',
  './controls',
  './link-preview'
];

const router = express.Router();

router.use(authenticateToken);

for (const section of SECTIONS) {
  router.use(require(section));
}

module.exports = router;
