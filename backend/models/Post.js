const mongoose = require('mongoose');

const postSchema = new mongoose.Schema({
  author: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  caption: {
    type: String,
    maxlength: 2200,
    default: ''
  },
  image: {
    type: String,
    default: ''
  },
  video: {
    type: String,
    default: ''
  },
  type: {
    type: String,
    enum: ['image', 'video'],
    default: 'image'
  },
  isReel: {
    type: Boolean,
    default: false
  },
  likes: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  }],
  likesCount: {
    type: Number,
    default: 0
  },
  commentsCount: {
    type: Number,
    default: 0
  },
  tags: [{
    type: String,
    trim: true
  }],
  location: {
    type: String,
    maxlength: 100,
    default: ''
  }
}, { timestamps: true });

postSchema.index({ author: 1, createdAt: -1 });
postSchema.index({ likes: 1 });

module.exports = mongoose.model('Post', postSchema);
