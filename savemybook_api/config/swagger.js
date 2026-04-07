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
      {
        url: 'https://api.savemybook.today',
        description: 'Production server',
      }
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
          description: '請在此輸入您取得的 JWT Token（不需要手動輸入 Bearer 字樣）',
        },
      },
    },
  },
  apis: ['./docs/*.yaml'], 
};

const swaggerSpec = swaggerJsdoc(swaggerOptions);

module.exports = swaggerSpec;