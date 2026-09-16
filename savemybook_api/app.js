const express = require('express');
const cors = require('cors');
const path = require('path');
const { apiReference } = require('@scalar/express-api-reference');

const { env } = require('./config/env');
const { buildSpec } = require('./config/openapi');
const { registerRoutes } = require('./routes');
const { securityHeaders, uploadHeaders, ensureBody } = require('./middleware/security');
const { uploadsGuard } = require('./middleware/uploads-guard');
const { notFound, errorHandler } = require('./middleware/errorHandler');
const maintenance = require('./lib/maintenance');

const createApp = () => {
  const app = express();

  app.disable('x-powered-by');
  app.set('trust proxy', env.trustProxy);

  app.use(securityHeaders);
  app.use(maintenance.middleware);
  app.use(cors({ origin: env.corsOrigins }));
  app.use(express.json({ limit: '1mb' }));
  app.use(ensureBody);

  app.use(uploadsGuard);

  app.use('/uploads', express.static(path.join(__dirname, 'uploads'), {
    dotfiles: 'deny',
    index: false,
    redirect: false,
    setHeaders: uploadHeaders
  }));

  const openapiSpec = buildSpec();

  app.get('/openapi.json', (req, res) => res.json(openapiSpec));

  app.use(
    '/api-docs',
    apiReference({
      content: openapiSpec,
      theme: 'default',
      layout: 'modern',
      hideModels: false,
      hideDownloadButton: false,
      defaultHttpClient: { targetKey: 'shell', clientKey: 'curl' },
      metaData: {
        title: 'SaveMyBook API 文件',
        description: 'SaveMyBook 二手書交易平台的完整 API 文件'
      }
    })
  );

  app.get('/', (req, res) => {
    res.send('SaveMyBook API is running. Visit /api-docs for API documentation.');
  });

  registerRoutes(app);

  app.use(notFound);
  app.use(errorHandler);

  return app;
};

module.exports = { createApp };
