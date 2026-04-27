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
const cabinetRoutes = require('./routes/cabinets'); // 新增這行

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
  console.log(`📄 Swagger UI: http://localhost:${port}/api-docs`);
});