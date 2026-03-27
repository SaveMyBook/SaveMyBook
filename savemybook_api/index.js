require('dotenv').config();
const express = require('express');
const swaggerUi = require('swagger-ui-express');

const swaggerSpec = require('./config/swagger');
const userRoutes = require('./routes/users');

const app = express();
const port = process.env.PORT || 3000;

app.use(express.json());

// Set up Swagger UI route
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// Register API routes
app.use('/api/users', userRoutes);

app.get('/', (req, res) => {
  res.send('Welcome to the SaveMyBook API! Visit /api-docs for API documentation.');
});

app.listen(port, () => {
  console.log(`🚀 Server is running on http://localhost:${port}`);
  console.log(`🔗 Test API: http://localhost:${port}/api/users`);
  console.log(`📄 Swagger UI: http://localhost:${port}/api-docs`);
});