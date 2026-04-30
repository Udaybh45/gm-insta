const express = require('express');
const router = express.Router();
const User = require('../models/User');
const Post = require('../models/Post');
const { protect } = require('../middleware/auth');
const upload = require('../middleware/upload');

// GET /api/users/search?q=query
router.get('/search', protect, async (req, res) => {
  try {
    const q = req.query.q;
    if (!q) return res.json([]);
    const users = await User.find({
      $or: [
        { username: { $regex: q, $options: 'i' } },
        { fullName: { $regex: q, $options: 'i' } }
      ]
    }).select('username fullName avatar').limit(10);
    res.json(users);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// GET /api/users/activity
router.get('/activity', protect, async (req, res) => {
  try {
    const user = await User.findById(req.user._id)
      .populate('followRequests', 'username avatar fullName');
    
    // Get recent posts with likes
    const posts = await Post.find({ author: req.user._id, likes: { $exists: true, $not: {$size: 0} } })
      .populate('likes', 'username avatar fullName')
      .sort({ updatedAt: -1 })
      .limit(20);

    let likesData = [];
    posts.forEach(post => {
      post.likes.forEach(liker => {
        if(liker._id.toString() !== req.user._id.toString()) {
          likesData.push({
            type: 'like',
            user: { _id: liker._id, username: liker.username, avatar: liker.avatar, fullName: liker.fullName },
            postImage: post.image || post.video,
            postId: post._id,
            createdAt: post.updatedAt 
          });
        }
      });
    });

    res.json({
      requests: user.followRequests,
      likes: likesData.reverse()
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});


// GET /api/users/suggestions
router.get('/suggestions', protect, async (req, res) => {
  try {
    const currentUser = await User.findById(req.user._id);
    const excluded = [...currentUser.following, req.user._id];
    const suggestions = await User.find({ _id: { $nin: excluded } })
      .select('username fullName avatar followers')
      .limit(5);
    res.json(suggestions);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// GET /api/users/:username
router.get('/:username', protect, async (req, res) => {
  try {
    const user = await User.findOne({ username: req.params.username })
      .populate('followers', 'username avatar fullName')
      .populate('following', 'username avatar fullName')
      .populate('followRequests', 'username avatar fullName');
    if (!user) return res.status(404).json({ message: 'User not found' });
    res.json(user);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// GET /api/users/:username/posts
router.get('/:username/posts', protect, async (req, res) => {
  try {
    const user = await User.findOne({ username: req.params.username });
    if (!user) return res.status(404).json({ message: 'User not found' });

    // Privacy check
    const isFollowing = user.followers.includes(req.user._id);
    const isMe = user._id.toString() === req.user._id.toString();

    if (user.isPrivate && !isFollowing && !isMe) {
      return res.json([]); // Return empty list or message if account is private
    }

    const posts = await Post.find({ author: user._id })
      .populate('author', 'username avatar')
      .sort({ createdAt: -1 });
    
    // Process posts to add isLiked field
    const processedPosts = posts.map(post => {
      const p = post.toObject();
      p.isLiked = post.likes.includes(req.user._id);
      return p;
    });

    res.json(processedPosts);

  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

const fs = require('fs');
const path = require('path');

// PUT /api/users/profile/update
router.put('/profile/update', protect, upload.single('avatar'), async (req, res) => {
  try {
    const { fullName, bio, website, isPrivate } = req.body;
    const updateData = { fullName, bio, website };
    if (isPrivate !== undefined) updateData.isPrivate = isPrivate === 'true' || isPrivate === true;
    
    if (req.file) {
      // Find current user to get old avatar path
      const user = await User.findById(req.user._id);
      if (user && user.avatar && user.avatar.startsWith('/uploads/')) {
        // Remove leading slash to make it relative to the joined path
        const relativePath = user.avatar.slice(1);
        const oldPath = path.join(__dirname, '..', relativePath);
        if (fs.existsSync(oldPath)) {
          fs.unlinkSync(oldPath);
        }
      }
      updateData.avatar = req.file.path;
    }
    const user = await User.findByIdAndUpdate(req.user._id, updateData, { new: true });
    res.json({ user });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// POST /api/users/:id/follow
router.post('/:id/follow', protect, async (req, res) => {
  try {
    if (req.params.id === req.user._id.toString()) {
      return res.status(400).json({ message: "You can't follow yourself" });
    }
    const targetUser = await User.findById(req.params.id);
    if (!targetUser) return res.status(404).json({ message: 'User not found' });

    const isFollowing = targetUser.followers.includes(req.user._id);
    const isRequested = targetUser.followRequests.includes(req.user._id);

    if (isFollowing) {
      await User.findByIdAndUpdate(req.params.id, { $pull: { followers: req.user._id } });
      await User.findByIdAndUpdate(req.user._id, { $pull: { following: req.params.id } });
      res.json({ following: false, requested: false, message: 'Unfollowed successfully' });
    } else if (isRequested) {
      await User.findByIdAndUpdate(req.params.id, { $pull: { followRequests: req.user._id } });
      await User.findByIdAndUpdate(req.user._id, { $pull: { followRequestsSent: req.params.id } });
      res.json({ following: false, requested: false, message: 'Follow request cancelled' });
    } else {
      if (targetUser.isPrivate) {
        await User.findByIdAndUpdate(req.params.id, { $addToSet: { followRequests: req.user._id } });
        await User.findByIdAndUpdate(req.user._id, { $addToSet: { followRequestsSent: req.params.id } });
        res.json({ following: false, requested: true, message: 'Follow request sent' });
      } else {
        await User.findByIdAndUpdate(req.params.id, { $addToSet: { followers: req.user._id } });
        await User.findByIdAndUpdate(req.user._id, { $addToSet: { following: req.params.id } });
        res.json({ following: true, requested: false, message: 'Followed successfully' });
      }
    }
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// POST /api/users/requests/:id/accept
router.post('/requests/:id/accept', protect, async (req, res) => {
  try {
    const requesterId = req.params.id;
    const userId = req.user._id;

    // Remove from requests, add to followers/following
    await User.findByIdAndUpdate(userId, { 
      $pull: { followRequests: requesterId },
      $addToSet: { followers: requesterId }
    });
    await User.findByIdAndUpdate(requesterId, { 
      $pull: { followRequestsSent: userId },
      $addToSet: { following: userId }
    });

    res.json({ message: 'Request accepted' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// POST /api/users/requests/:id/reject
router.post('/requests/:id/reject', protect, async (req, res) => {
  try {
    const requesterId = req.params.id;
    const userId = req.user._id;

    await User.findByIdAndUpdate(userId, { $pull: { followRequests: requesterId } });
    await User.findByIdAndUpdate(requesterId, { $pull: { followRequestsSent: userId } });

    res.json({ message: 'Request rejected' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
