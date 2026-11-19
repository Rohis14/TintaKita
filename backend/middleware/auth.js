const jwt = require('jsonwebtoken');

// Memastikan request membawa token JWT yang valid
const verifyToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Format: Bearer <token>

  if (!token) {
    return res.status(401).json({
      success: false,
      message: 'Akses ditolak. Token autentikasi tidak ditemukan.',
    });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded; // Berisi { id, nama, email, role }
    next();
  } catch (error) {
    return res.status(401).json({
      success: false,
      message: 'Token tidak valid atau sudah kedaluwarsa.',
    });
  }
};

// Membatasi akses endpoint berdasarkan role pengguna
const authorizeRoles = (...allowedRoles) => {
  return (req, res, next) => {
    if (!req.user || !allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: `Akses terlarang. Fitur ini hanya untuk role: ${allowedRoles.join(', ')}.`,
      });
    }
    next();
  };
};

module.exports = { verifyToken, authorizeRoles };