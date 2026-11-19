const express = require('express');
const pool = require('../db');
const { uploadToCloudinary } = require('../cloudinary');
const { verifyToken, authorizeRoles } = require('../middleware/auth');
const { handleUpload } = require('../middleware/upload');

const router = express.Router();

// GET /api/orders — Pelanggan melihat pesanannya sendiri; Operator/Admin melihat semua pesanan
router.get('/', verifyToken, async (req, res) => {
  try {
    let query = `
      SELECT 
        o.*,
        p.name AS produk_name,
        p.unit AS produk_unit,
        p.harga AS harga_satuan,
        u_pel.nama AS pelanggan_nama,
        u_pel.hp AS pelanggan_hp,
        u_op.nama AS operator_nama
      FROM orders o
      JOIN products p ON o.produk_id = p.id
      JOIN users u_pel ON o.pelanggan_id = u_pel.id
      LEFT JOIN users u_op ON o.operator_id = u_op.id
    `;
    const params = [];

    if (req.user.role === 'PELANGGAN') {
      query += ' WHERE o.pelanggan_id = $1';
      params.push(req.user.id);
    }

    query += ' ORDER BY o.created_at DESC';

    const result = await pool.query(query, params);

    res.status(200).json({
      success: true,
      message: 'Daftar pesanan berhasil diambil.',
      data: result.rows,
    });
  } catch (error) {
    console.error('Error get orders:', error);
    res.status(500).json({
      success: false,
      message: 'Gagal mengambil data pesanan.',
    });
  }
});

// GET /api/orders/:id — Detail satu pesanan
router.get('/:id', verifyToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT 
        o.*,
        p.name AS produk_name,
        p.unit AS produk_unit,
        p.harga AS harga_satuan,
        u_pel.nama AS pelanggan_nama,
        u_pel.hp AS pelanggan_hp,
        u_op.nama AS operator_nama
      FROM orders o
      JOIN products p ON o.produk_id = p.id
      JOIN users u_pel ON o.pelanggan_id = u_pel.id
      LEFT JOIN users u_op ON o.operator_id = u_op.id
      WHERE o.id = $1`,
      [req.params.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Pesanan tidak ditemukan.',
      });
    }

    const order = result.rows[0];
    if (req.user.role === 'PELANGGAN' && order.pelanggan_id !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Anda tidak memiliki akses ke pesanan ini.',
      });
    }

    res.status(200).json({
      success: true,
      message: 'Detail pesanan berhasil diambil.',
      data: order,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Gagal mengambil detail pesanan.',
    });
  }
});

// POST /api/orders — Buat pesanan baru + wajib upload file desain (Khusus PELANGGAN)
router.post(
  '/',
  verifyToken,
  authorizeRoles('PELANGGAN'),
  handleUpload('design_image'),
  async (req, res) => {
    try {
      const { produk_id, quantity, notes } = req.body;

      if (!produk_id || !quantity) {
        return res.status(400).json({
          success: false,
          message: 'Produk dan jumlah pesanan (quantity) wajib diisi.',
        });
      }

      if (isNaN(quantity) || Number(quantity) <= 0) {
        return res.status(400).json({
          success: false,
          message: 'Jumlah pesanan harus lebih dari 0.',
        });
      }

      if (!req.file) {
        return res.status(400).json({
          success: false,
          message: 'File gambar desain wajib diunggah.',
        });
      }

      // Ambil harga produk langsung dari database (anti manipulasi harga dari client)
      const productResult = await pool.query(
        'SELECT id, harga, is_active FROM products WHERE id = $1',
        [produk_id]
      );

      if (productResult.rows.length === 0 || !productResult.rows[0].is_active) {
        return res.status(404).json({
          success: false,
          message: 'Produk tidak ditemukan atau sedang tidak tersedia.',
        });
      }

      const hargaSatuan = Number(productResult.rows[0].harga);
      const totalHarga = hargaSatuan * Number(quantity);

      // Upload file desain ke Cloudinary
      const uploaded = await uploadToCloudinary(req.file.buffer, 'tintakita/designs');

      const insertResult = await pool.query(
        `INSERT INTO orders (pelanggan_id, produk_id, quantity, total_harga, notes, design_image_url)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING *`,
        [
          req.user.id,
          produk_id,
          Number(quantity),
          totalHarga,
          notes || '',
          uploaded.secure_url,
        ]
      );

      res.status(201).json({
        success: true,
        message: 'Pesanan cetak berhasil dibuat.',
        data: insertResult.rows[0],
      });
    } catch (error) {
      console.error('Error create order:', error);
      res.status(500).json({
        success: false,
        message: 'Gagal membuat pesanan cetak.',
      });
    }
  }
);

// PATCH /api/orders/:id/status — Update progres produksi & upload bukti hasil cetak (Khusus OPERATOR / ADMIN)
router.patch(
  '/:id/status',
  verifyToken,
  authorizeRoles('OPERATOR', 'ADMIN'),
  handleUpload('result_image'),
  async (req, res) => {
    try {
      const { id } = req.params;
      const { status, reject_reason } = req.body;

      const validStatuses = ['DESIGN_VERIFIED', 'PRINTING', 'READY', 'COMPLETED', 'REJECTED'];
      if (!status || !validStatuses.includes(status)) {
        return res.status(400).json({
          success: false,
          message: `Status tidak valid. Pilihan status: ${validStatuses.join(', ')}.`,
        });
      }

      const existing = await pool.query('SELECT * FROM orders WHERE id = $1', [id]);
      if (existing.rows.length === 0) {
        return res.status(404).json({
          success: false,
          message: 'Pesanan tidak ditemukan.',
        });
      }

      const currentOrder = existing.rows[0];

      if (status === 'REJECTED' && (!reject_reason || reject_reason.trim() === '')) {
        return res.status(400).json({
          success: false,
          message: 'Alasan penolakan (reject_reason) wajib diisi jika desain ditolak.',
        });
      }

      let resultImageUrl = currentOrder.result_image_url;

      if (status === 'READY') {
        if (!req.file && !resultImageUrl) {
          return res.status(400).json({
            success: false,
            message: 'Foto bukti hasil cetak (result_image) wajib diunggah saat pesanan siap diambil.',
          });
        }
        if (req.file) {
          const uploaded = await uploadToCloudinary(req.file.buffer, 'tintakita/results');
          resultImageUrl = uploaded.secure_url;
        }
      }

      const updated = await pool.query(
        `UPDATE orders
         SET status = $1,
             operator_id = $2,
             reject_reason = $3,
             result_image_url = $4,
             updated_at = CURRENT_TIMESTAMP
         WHERE id = $5
         RETURNING *`,
        [
          status,
          req.user.id,
          status === 'REJECTED' ? reject_reason.trim() : null,
          resultImageUrl,
          id,
        ]
      );

      res.status(200).json({
        success: true,
        message: `Status pesanan berhasil diubah menjadi ${status}.`,
        data: updated.rows[0],
      });
    } catch (error) {
      console.error('Error update order status:', error);
      res.status(500).json({
        success: false,
        message: 'Gagal memperbarui status pesanan.',
      });
    }
  }
);

// DELETE /api/orders/:id — Batalkan & hapus pesanan selama status masih PENDING (Khusus PELANGGAN)
router.delete('/:id', verifyToken, authorizeRoles('PELANGGAN'), async (req, res) => {
  try {
    const existing = await pool.query('SELECT * FROM orders WHERE id = $1', [req.params.id]);

    if (existing.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Pesanan tidak ditemukan.',
      });
    }

    const order = existing.rows[0];

    if (order.pelanggan_id !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Anda tidak berhak membatalkan pesanan milik orang lain.',
      });
    }

    if (order.status !== 'PENDING') {
      return res.status(400).json({
        success: false,
        message: 'Pesanan yang sudah diverifikasi atau diproses tidak dapat dibatalkan.',
      });
    }

    await pool.query('DELETE FROM orders WHERE id = $1', [req.params.id]);

    res.status(200).json({
      success: true,
      message: 'Pesanan berhasil dibatalkan dan dihapus.',
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Gagal membatalkan pesanan.',
    });
  }
});

module.exports = router;