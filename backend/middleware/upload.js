const multer = require('multer');
const path = require('path');

const storage = multer.memoryStorage();

const fileFilter = (req, file, cb) => {
  const allowedMimes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
  const allowedExts = ['.jpg', '.jpeg', '.png', '.webp'];
  const ext = path.extname(file.originalname || '').toLowerCase();

  const isAllowedMime = allowedMimes.includes(file.mimetype);
  const isOctetWithValidExt =
    file.mimetype === 'application/octet-stream' && allowedExts.includes(ext);

  if (isAllowedMime || isOctetWithValidExt) {
    cb(null, true);
  } else {
    const err = new Error('Format file tidak didukung. Gunakan gambar JPG, PNG, atau WebP.');
    err.status = 400;
    cb(err, false);
  }
};

const upload = multer({
  storage,
  limits: {
    fileSize: 5 * 1024 * 1024, // Maksimal 5 MB
  },
  fileFilter,
});

// Wrapper agar error ukuran/format file langsung mengembalikan HTTP 400 JSON yang rapi
const handleUpload = (fieldName) => {
  return (req, res, next) => {
    upload.single(fieldName)(req, res, (err) => {
      if (err) {
        if (err instanceof multer.MulterError && err.code === 'LIMIT_FILE_SIZE') {
          return res.status(400).json({
            success: false,
            message: 'Ukuran file terlalu besar. Maksimal 5 MB.',
          });
        }
        return res.status(err.status || 400).json({
          success: false,
          message: err.message || 'Gagal memproses file unggahan.',
        });
      }
      next();
    });
  };
};

module.exports = { handleUpload };