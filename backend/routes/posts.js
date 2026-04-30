const express = require("express");
const router = express.Router();
const Post = require("../models/Post");
const User = require("../models/User");
const Comment = require("../models/Comment");
const { protect } = require("../middleware/auth");
const upload = require("../middleware/upload");

// GET /api/posts/feed
router.get("/feed", protect, async (req, res) => {
  try {
    const user = await User.findById(req.user._id);
    const feedUsers = [...user.following, req.user._id];
    const page = parseInt(req.query.page) || 1;
    const limit = 10;
    const posts = await Post.find({ author: { $in: feedUsers } })
      .populate("author", "username avatar fullName")
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit);

    // Process posts to add isLiked field
    const processedPosts = posts.map((post) => {
      const p = post.toObject();
      p.isLiked = post.likes.includes(req.user._id);
      return p;
    });

    const total = await Post.countDocuments({ author: { $in: feedUsers } });
    res.json({
      posts: processedPosts,
      total,
      pages: Math.ceil(total / limit),
      page,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// GET /api/posts/explore
router.get("/explore", protect, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = 12;
    const posts = await Post.find()
      .populate("author", "username avatar")
      .sort({ likesCount: -1, createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit);

    const processedPosts = posts.map((post) => {
      const p = post.toObject();
      p.isLiked = post.likes.includes(req.user._id);
      return p;
    });

    res.json({ posts: processedPosts });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// POST /api/posts
router.post("/", protect, upload.single("media"), async (req, res) => {
  try {
    const { caption, location, tags, isReel } = req.body;
    if (!req.file) {
      return res
        .status(400)
        .json({ message: "Post must have a photo or video" });
    }
    const postData = {
      author: req.user._id,
      caption,
      location,
      tags: tags ? tags.split(",").map((t) => t.trim()) : [],
      isReel: isReel === "true" || isReel === true,
    };
    if (req.file) {
      const isVideo = req.file.mimetype.startsWith("video/");
      postData.type = isVideo ? "video" : "image";
      if (isVideo) postData.video = req.file.path;
      else postData.image = req.file.path;
    }
    const post = await Post.create(postData);
    await User.findByIdAndUpdate(req.user._id, { $inc: { postsCount: 1 } });
    await post.populate("author", "username avatar fullName");
    res.status(201).json(post);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// GET /api/posts/reels
router.get("/reels", protect, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = 5;
    const reels = await Post.find({ type: "video" })
      .populate("author", "username avatar fullName")
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit);

    // If no reels yet, add some simulated "real" reels for a good first impression
    if (reels.length === 0 && page === 1) {
      const simulated = [
        {
          _id: "sim1",
          type: "video",
          video:
            "https://assets.mixkit.co/videos/preview/mixkit-girl-in-neon-light-dancing-29337-large.mp4",
          caption: "Stunning Neon Dance! #SimulatedReel",
          author: {
            username: "reels_hub",
            avatar: "",
            fullName: "Reels Global",
          },
          likesCount: 1200,
          commentsCount: 45,
          isLiked: false,
          createdAt: new Date(),
        },
        {
          _id: "sim2",
          type: "video",
          video:
            "https://assets.mixkit.co/videos/preview/mixkit-waves-in-the-ocean-at-sunset-2189-large.mp4",
          caption: "Sunset waves 🌊 #nature",
          author: {
            username: "nature_vibe",
            avatar: "",
            fullName: "Nature Vibes",
          },
          likesCount: 850,
          commentsCount: 12,
          isLiked: false,
          createdAt: new Date(),
        },
      ];
      return res.json({ reels: simulated, pages: 1, page: 1 });
    }

    const processedReels = reels.map((post) => {
      const p = post.toObject();
      p.isLiked = post.likes.includes(req.user._id);
      return p;
    });

    const total = await Post.countDocuments({ type: "video" });
    res.json({
      reels: processedReels,
      total,
      pages: Math.ceil(total / limit),
      page,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// GET /api/posts/:id
router.get("/:id", protect, async (req, res) => {
  try {
    const post = await Post.findById(req.params.id).populate(
      "author",
      "username avatar fullName",
    );
    if (!post) return res.status(404).json({ message: "Post not found" });

    const p = post.toObject();
    p.isLiked = post.likes.includes(req.user._id);

    res.json(p);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// DELETE /api/posts/:id
router.delete("/:id", protect, async (req, res) => {
  try {
    const post = await Post.findById(req.params.id);
    if (!post) return res.status(404).json({ message: "Post not found" });
    if (post.author.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: "Not authorized" });
    }
    await post.deleteOne();
    await Comment.deleteMany({ post: post._id });
    await User.findByIdAndUpdate(req.user._id, { $inc: { postsCount: -1 } });
    res.json({ message: "Post deleted" });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// POST /api/posts/:id/like
router.post("/:id/like", protect, async (req, res) => {
  try {
    const post = await Post.findById(req.params.id);
    if (!post) return res.status(404).json({ message: "Post not found" });
    const isLiked = post.likes.includes(req.user._id);
    if (isLiked) {
      post.likes.pull(req.user._id);
      post.likesCount = Math.max(0, post.likesCount - 1);
    } else {
      post.likes.addToSet(req.user._id);
      post.likesCount++;
    }
    await post.save();
    res.json({ liked: !isLiked, likesCount: post.likesCount });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
