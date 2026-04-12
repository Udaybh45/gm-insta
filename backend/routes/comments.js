const express = require('express');
const router = express.Router();
const Comment = require('../models/Comment');
const Post = require('../models/Post');
const { protect } = require('../middleware/auth');

// GET /api/comments/:postId
router.get('/:postId', protect, async (req, res) => {
  try {
    const comments = await Comment.find({ post: req.params.postId, parentComment: null })
      .populate('author', 'username avatar')
      .sort({ createdAt: 1 });
    res.json(comments);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// POST /api/comments/:postId
router.post('/:postId', protect, async (req, res) => {
  try {
    const { content, parentComment } = req.body;
    if (!content) return res.status(400).json({ message: 'Comment content required' });
    const post = await Post.findById(req.params.postId);
    if (!post) return res.status(404).json({ message: 'Post not found' });
    const comment = await Comment.create({
      post: req.params.postId,
      author: req.user._id,
      content,
      parentComment: parentComment || null
    });
    await Post.findByIdAndUpdate(req.params.postId, { $inc: { commentsCount: 1 } });
    await comment.populate('author', 'username avatar');
    res.status(201).json(comment);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// DELETE /api/comments/:id
router.delete('/:id', protect, async (req, res) => {
  try {
    const comment = await Comment.findById(req.params.id);
    if (!comment) return res.status(404).json({ message: 'Comment not found' });
    if (comment.author.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: 'Not authorized' });
    }
    await comment.deleteOne();
    await Post.findByIdAndUpdate(comment.post, { $inc: { commentsCount: -1 } });
    res.json({ message: 'Comment deleted' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// POST /api/comments/:id/like
router.post('/:id/like', protect, async (req, res) => {
  try {
    const comment = await Comment.findById(req.params.id);
    if (!comment) return res.status(404).json({ message: 'Comment not found' });
    const isLiked = comment.likes.includes(req.user._id);
    if (isLiked) {
      comment.likes.pull(req.user._id);
    } else {
      comment.likes.addToSet(req.user._id);
    }
    await comment.save();
    res.json({ liked: !isLiked, likesCount: comment.likes.length });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
