const multer = require('multer');
const path = require('path');
const fs = require('fs');

const ensureDir = (dir) => {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
};

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadPath = path.join(__dirname, '../uploads');
    ensureDir(uploadPath);
    cb(null, uploadPath);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    cb(null, uniqueSuffix + path.extname(file.originalname));
  }
});

const fileFilter = (req, file, cb) => {
  const allowedExt = /jpeg|jpg|png|gif|webp|mp4|webm|mov/i;
  const extname = allowedExt.test(path.extname(file.originalname).toLowerCase());
  
  // Some clients send application/octet-stream especially when sending bytes
  const mimetype = file.mimetype.startsWith('image/') || 
                   file.mimetype.startsWith('video/') ||
                   file.mimetype === 'application/octet-stream';
                   
  if (extname && mimetype) {
    cb(null, true);
  } else {
    cb(new Error('Only image and video files are allowed!'));
  }
};

const upload = multer({
  storage,
  fileFilter,
  limits: { fileSize: 50 * 1024 * 1024 } // 50MB for videos
});

module.exports = upload;
