const { Pool } = require('pg');
require('dotenv').config();

// Mencegah sslmode=require menimpa konfigurasi dan memicu error sertifikat Aiven
let connectionString = process.env.DATABASE_URL;
if (connectionString && connectionString.includes('sslmode=require')) {
  connectionString = connectionString.replace('sslmode=require', 'sslmode=no-verify');
}

const pool = new Pool({
  connectionString,
  ssl: {
    rejectUnauthorized: false,
  },
});

pool.on('error', (err) => {
  console.error('Terjadi error tidak terduga pada koneksi PostgreSQL:', err);
});

module.exports = pool;
