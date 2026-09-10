require('dotenv').config();
const express = require('express');
const swaggerUi = require('swagger-ui-express');
const cors = require('cors');
const path = require('path');

const swaggerSpec = require('./config/swagger');
const userRoutes = require('./routes/users');
const authRoutes = require('./routes/auth');
const bookRoutes = require('./routes/books');
const categoriesRoutes = require('./routes/categories');
const cabinetRoutes = require('./routes/cabinets');
const favoriteRoutes = require('./routes/favorites');
const cartRoutes = require('./routes/cart');
const orderRoutes = require('./routes/orders');
const notificationRoutes = require('./routes/notifications');
const chatRoutes = require('./routes/chat');
const walletRoutes = require('./routes/wallet');
const disputeRoutes = require('./routes/disputes');
const reportRoutes = require('./routes/reports');
const announcementRoutes = require('./routes/announcements');
const adminRoutes = require('./routes/admin');
const uploadRoutes = require('./routes/uploads');

const app = express();
const port = process.env.PORT || 3000;

app.use(cors({
    origin: ['https://savemybook.today', 'https://www.savemybook.today']
}));
app.use(express.json());

app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

app.use('/api/users', userRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/books', bookRoutes);
app.use('/api/categories', categoriesRoutes);
app.use('/api/cabinets', cabinetRoutes);
app.use('/api/favorites', favoriteRoutes);
app.use('/api/cart', cartRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/wallet', walletRoutes);
app.use('/api/disputes', disputeRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/announcements', announcementRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/uploads', uploadRoutes);

app.get('/', (req, res) => {
  res.send('SaveMyBook API is running. Visit /api-docs for API documentation.');
});

app.listen(port, () => {
  console.log(`🚀 Server is running on http://localhost:${port}`);
  console.log(`🔗 Users API: http://localhost:${port}/api/users`);
  console.log(`🔐 Auth API: http://localhost:${port}/api/auth/login`);
  console.log(`📚 Books API: http://localhost:${port}/api/books`);
  console.log(`📂 Categories API: http://localhost:${port}/api/categories`);
  console.log(`🗄️ Cabinets API: http://localhost:${port}/api/cabinets`);
  console.log(`🛒 Cart / Orders API: http://localhost:${port}/api/cart, /api/orders`);
  console.log(`🔔 Notifications API: http://localhost:${port}/api/notifications`);
  console.log(`💬 Chat API: http://localhost:${port}/api/chat`);
  console.log(`🪙 Wallet API: http://localhost:${port}/api/wallet`);
  console.log(`🛡️ Admin API: http://localhost:${port}/api/admin`);
  console.log(`📄 Swagger UI: http://localhost:${port}/api-docs`);
});