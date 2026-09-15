const prisma = require('../lib/prisma');
const password = require('../lib/password');

const passwordMatches = async (userId, plain) => {
  const user = await prisma.users.findUnique({ where: { user_id: userId }, select: { password_hash: true } });
  return password.verify(plain, user?.password_hash);
};

module.exports = { passwordMatches };
