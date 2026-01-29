import express from 'express';
import cors from 'cors';
import morgan from 'morgan';
import dotenv from 'dotenv';
import authRoutes from './routes/auth.js';
import catalogRoutes from './routes/catalog.js';
import inventoryRoutes from './routes/inventory.js';
import posRoutes from './routes/pos.js';
import debtRoutes from './routes/debt.js';
import reportRoutes from './routes/reports.js';

dotenv.config();

const app = express();
const port = process.env.PORT || 4000;

app.use(cors({
  origin: true,
  credentials: true
}));
app.use(express.json({ limit: '2mb' }));
app.use(morgan('dev'));

app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use('/auth', authRoutes);
app.use('/catalog', catalogRoutes);
app.use('/inventory', inventoryRoutes);
app.use('/pos', posRoutes);
app.use('/debt', debtRoutes);
app.use('/reports', reportRoutes);

// Error handler
app.use((err, req, res, next) => {
  // eslint-disable-line no-unused-vars
  console.error(err);
  const status = err?.status || err?.statusCode || 500;
  res.status(status).json({
    message: err?.message || 'Internal server error'
  });
});

app.listen(port, () => {
  console.log(`API server running on http://localhost:${port}`);
});