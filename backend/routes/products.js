const express = require('express');
const pool = require('../db');
const { uploadToCloudinary } = require('../cloudinary');
const { verifyToken, authorizeRoles } = require('../middleware/auth');
const { handleUpload } = require('../middleware/upload');

const router = express.Router();

// GET /api/products — Menampilkan daftar katalog produk aktif
router.get('/', async (req, res) => {
  try {
    const showAll = req.query.all === 'true';
    const query = showAll
      ? 'SELECT * FROM products ORDER BY id ASC'
      : 'SELECT * FROM products WHERE is_active = TRUE ORDER BY id ASC';

    const result = await pool.query(query);

    res.status(200).json({
      success: true,
      message: 'Daftar produk berhasil diambil.',
      data: result.rows,
    });
  } catch (error) {
    console.error('Error get products:', error);
    res.status(500).json({
      success: false,
      message: 'Gagal mengambil data produk.',
    });
  }
});

// GET /api/products/:id — Detail satu produk
router.get('/:id', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM products WHERE id = $1', [req.params.id]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Produk tidak ditemukan.',
      });
    }

    res.status(200).json({
      success: true,
      message: 'Detail produk berhasil diambil.',
      data: result.rows[0],
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Gagal mengambil detail produk.',
    });
  }
});

// POST /api/products — Tambah produk baru (Khusus ADMIN)
router.post(
  '/',
  verifyToken,
  authorizeRoles('ADMIN'),
  handleUpload('thumbnail'),
  async (req, res) => {
    try {
      const { name, deskripsi, unit, harga } = req.body;

      if (!name || !unit || !harga) {
        return res.status(400).json({
          success: false,
          message: 'Nama produk, satuan (unit), dan harga wajib diisi.',
        });
      }

      if (isNaN(harga) || Number(harga) <= 0) {
        return res.status(400).json({
          success: false,
          message: 'Harga produk harus berupa angka lebih dari 0.',
        });
      }

      let thumbnailUrl = 'https://res.cloudinary.com/demo/image/upload/sample.jpg';
      if (req.file) {
        const uploaded = await uploadToCloudinary(req.file.buffer, 'tintakita/products');
        thumbnailUrl = uploaded.secure_url;
      }

      const result = await pool.query(
        `INSERT INTO products (name, deskripsi, unit, harga, thumbnail_url)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING *`,
        [name.trim(), deskripsi || '', unit.trim(), Number(harga), thumbnailUrl]
      );

      res.status(201).json({
        success: true,
        message: 'Produk baru berhasil ditambahkan.',
        data: result.rows[0],
      });
    } catch (error) {
      console.error('Error create product:', error);
      res.status(500).json({
        success: false,
        message: 'Gagal menambahkan produk.',
      });
    }
  }
);

// PATCH /api/products/:id — Edit data produk (Khusus ADMIN)
router.patch(
  '/:id',
  verifyToken,
  authorizeRoles('ADMIN'),
  handleUpload('thumbnail'),
  async (req, res) => {
    try {
      const { id } = req.params;
      const { name, deskripsi, unit, harga, is_active } = req.body;

      const existing = await pool.query('SELECT * FROM products WHERE id = $1', [id]);
      if (existing.rows.length === 0) {
        return res.status(404).json({
          success: false,
          message: 'Produk tidak ditemukan.',
        });
      }

      if (harga !== undefined && (isNaN(harga) || Number(harga) <= 0)) {
        return res.status(400).json({
          success: false,
          message: 'Harga produk harus lebih dari 0.',
        });
      }

      let thumbnailUrl = existing.rows[0].thumbnail_url;
      if (req.file) {
        const uploaded = await uploadToCloudinary(req.file.buffer, 'tintakita/products');
        thumbnailUrl = uploaded.secure_url;
      }

      const activeValue =
        is_active !== undefined ? is_active === true || is_active === 'true' : existing.rows[0].is_active;

      const result = await pool.query(
        `UPDATE products
         SET name = COALESCE($1, name),
             deskripsi = COALESCE($2, deskripsi),
             unit = COALESCE($3, unit),
             harga = COALESCE($4, harga),
             thumbnail_url = $5,
             is_active = $6
         WHERE id = $7
         RETURNING *`,
        [
          name ? name.trim() : null,
          deskripsi !== undefined ? deskripsi : null,
          unit ? unit.trim() : null,
          harga !== undefined ? Number(harga) : null,
          thumbnailUrl,
          activeValue,
          id,
        ]
      );

      res.status(200).json({
        success: true,
        message: 'Data produk berhasil diperbarui.',
        data: result.rows[0],
      });
    } catch (error) {
      console.error('Error update product:', error);
      res.status(500).json({
        success: false,
        message: 'Gagal memperbarui data produk.',
      });
    }
  }
);

// DELETE /api/products/:id — Hapus produk (Khusus ADMIN)
router.delete('/:id', verifyToken, authorizeRoles('ADMIN'), async (req, res) => {
  try {
    const result = await pool.query('DELETE FROM products WHERE id = $1 RETURNING id', [
      req.params.id,
    ]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Produk tidak ditemukan.',
      });
    }

    res.status(200).json({
      success: true,
      message: 'Produk berhasil dihapus.',
    });
  } catch (error) {
    // Error kode 23503 = Foreign Key constraint violation di PostgreSQL
    if (error.code === '23503') {
      return res.status(400).json({
        success: false,
        message:
          'Produk tidak dapat dihapus karena sudah pernah dipesan pelanggan. Nonaktifkan status produk sebagai gantinya.',
      });
    }
    res.status(500).json({
      success: false,
      message: 'Gagal menghapus produk.',
    });
  }
});

module.exports = router;