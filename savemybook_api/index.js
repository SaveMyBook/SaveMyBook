require('dotenv').config();
const express = require('express');
const swaggerUi = require('swagger-ui-express');

const swaggerSpec = require('./config/swagger');
const userRoutes = require('./routes/users');
const authRoutes = require('./routes/auth'); 
const bookRoutes = require('./routes/books');

const app = express();
const port = process.env.PORT || 3000;

app.use(express.json());

app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

app.use('/api/users', userRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/books', bookRoutes);

app.get('/', (req, res) => {
  res.send('SaveMyBook API is running. Visit /api-docs for API documentation.');
});

app.listen(port, () => {
  console.log(`🚀 Server is running on http://localhost:${port}`);
  console.log(`🔗 Users API: http://localhost:${port}/api/users`);
  console.log(`🔐 Auth API: http://localhost:${port}/api/auth/login`);
  console.log(`📚 Books API: http://localhost:${port}/api/books`);
  console.log(`📄 Swagger UI: http://localhost:${port}/api-docs`);
});