const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');

const router = express.Router();

router.get('/', authenticateToken, async (req, res) => {
  const cabinets = await prisma.smart_cabinets.findMany({
    where: { is_active: true },
    select: {
      cabinet_id: true,
      cabinet_name: true,
      address: true,
      available_slots: true,
      latitude: true,
      longitude: true
    },
    orderBy: { cabinet_id: 'asc' }
  });

  res.status(200).json({ success: true, data: cabinets });
});

module.exports = router;
