const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../db');
const { verifyToken } = require('../middleware/auth');

const router = express.Router();

// POST /api/auth/register — Pendaftaran akun baru (otomatis role PELANGGAN)
router.post('/register', async (req, res) => {
  try {
    const { nama, email, password, hp } = req.body;

    if (!nama || !email || !password || !hp) {
      return res.status(400).json({
        success: false,
        message: 'Nama, email, password, dan nomor HP wajib diisi.',
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password minimal harus 6 karakter.',
      });
    }

    const existingUser = await pool.query('SELECT id FROM users WHERE email = $1', [email.trim()]);
    if (existingUser.rows.length > 0) {
      return res.status(400).json({
        success: false,
        message: 'Email sudah terdaftar. Silakan gunakan email lain.',
      });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const result = await pool.query(
      `INSERT INTO users (nama, email, password, hp)
       VALUES ($1, $2, $3, $4)
       RETURNING id, nama, email, hp, role, created_at`,
      [nama.trim(), email.trim().toLowerCase(), hashedPassword, hp.trim()]
    );

    res.status(201).json({
      success: true,
      message: 'Registrasi berhasil. Silakan login.',
      data: result.rows[0],
    });
  } catch (error) {
    console.error('Error register:', error);
    res.status(500).json({
      success: false,
      message: 'Terjadi kesalahan pada server saat registrasi.',
    });
  }
});

// POST /api/auth/login — Autentikasi pengguna & penerbitan JWT
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email dan password wajib diisi.',
      });
    }

    const result = await pool.query('SELECT * FROM users WHERE email = $1', [
      email.trim().toLowerCase(),
    ]);

    if (result.rows.length === 0) {
      return res.status(401).json({
        success: false,
        message: 'Email atau password salah.',
      });
    }

    const user = result.rows[0];
    const isPasswordMatch = await bcrypt.compare(password, user.password);

    if (!isPasswordMatch) {
      return res.status(401).json({
        success: false,
        message: 'Email atau password salah.',
      });
    }

    const payload = {
      id: user.id,
      nama: user.nama,
      email: user.email,
      role: user.role,
    };

    const token = jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: '7d' });

    res.status(200).json({
      success: true,
      message: 'Login berhasil.',
      token,
      data: {
        id: user.id,
        nama: user.nama,
        email: user.email,
        hp: user.hp,
        role: user.role,
      },
    });
  } catch (error) {
    console.error('Error login:', error);
    res.status(500).json({
      success: false,
      message: 'Terjadi kesalahan pada server saat login.',
    });
  }
});

// GET /api/auth/me — Mengecek data akun yang sedang login
router.get('/me', verifyToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, nama, email, hp, role, created_at FROM users WHERE id = $1',
      [req.user.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Pengguna tidak ditemukan.',
      });
    }

    res.status(200).json({
      success: true,
      message: 'Data profil berhasil diambil.',
      data: result.rows[0],
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Gagal mengambil data profil.',
    });
  }
});

module.exports = router;