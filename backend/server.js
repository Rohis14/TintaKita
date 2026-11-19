const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware global
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Rute cek status server (Health Check)
app.get('/', (req, res) => {
  res.status(200).json({
    success: true,
    message: 'Backend API TintaKita berjalan dengan baik!',
  });
});

// Rute API utama
app.use('/api/auth', require('./routes/auth'));
app.use('/api/products', require('./routes/products'));
app.use('/api/orders', require('./routes/orders'));

// Middleware penanganan 404 (Route tidak ditemukan)
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: 'Endpoint tidak ditemukan.',
  });
});

// Middleware penanganan error global
app.use((err, req, res, next) => {
  console.error('Unhandled Server Error:', err);
  res.status(500).json({
    success: false,
    message: 'Terjadi kesalahan internal pada server.',
  });
});

// Menjalankan server secara lokal (tidak dipanggil di Vercel Serverless)
if (!process.env.VERCEL) {
  app.listen(PORT, () => {
    console.log(`Server TintaKita aktif di port ${PORT}`);
    console.log(`URL: http://localhost:${PORT}`);
  });
}

module.exports = app;