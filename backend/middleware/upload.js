require('dotenv').config();
const multer = require('multer');
const { CloudinaryStorage } = require('multer-storage-cloudinary');
const cloudinary = require('cloudinary').v2;
const path = require('path');

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET
});

const storage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: async (req, file) => {
    let folder = 'gminsta';
    let resource_type = 'auto'; // automatically detects image or video
    
    // Determine type
    if (file.mimetype.startsWith('video/') || file.originalname.match(/\.(mp4|webm|mov)$/i)) {
      resource_type = 'video';
      folder = 'gminsta/videos';
    } else {
      resource_type = 'image';
      folder = 'gminsta/images';
    }

    return {
      folder: folder,
      resource_type: resource_type,
      public_id: Date.now() + '-' + Math.round(Math.random() * 1e9)
    };
  },
});

const fileFilter = (req, file, cb) => {
  const allowedExt = /jpeg|jpg|png|gif|webp|mp4|webm|mov/i;
  const extname = allowedExt.test(path.extname(file.originalname).toLowerCase());
  
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
  limits: { fileSize: 100 * 1024 * 1024 } // 100MB limit for Cloudinary
});

module.exports = upload;
