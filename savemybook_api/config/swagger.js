const swaggerJsdoc = require('swagger-jsdoc');

const port = process.env.PORT || 3000;

// ==========================================
// Swagger Configuration
// ==========================================
const swaggerOptions = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'SaveMyBook API',
      version: '1.0.0',
      description: 'API documentation for the SaveMyBook application',
    },
    servers: [
      {
        url: `http://localhost:${port}`,
        description: 'Local development server',
      },
    ],
  },
  apis: ['./docs/*.yaml'], 
};

const swaggerSpec = swaggerJsdoc(swaggerOptions);

module.exports = swaggerSpec;