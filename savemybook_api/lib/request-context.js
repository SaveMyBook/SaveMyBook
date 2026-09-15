const actorOf = (req) => ({ adminId: req.user.userId, req });

module.exports = { actorOf };
