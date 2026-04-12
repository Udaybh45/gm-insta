require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const mongoose = require('mongoose');
const cors = require('cors');
const path = require('path');

const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const postRoutes = require('./routes/posts');
const commentRoutes = require('./routes/comments');
const messageRoutes = require('./routes/messages');
const Message = require('./models/Message');
const { verifySocketToken } = require('./middleware/auth');

const app = express();
const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Serve frontend
app.use(express.static(path.join(__dirname, '../frontend')));

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/posts', postRoutes);
app.use('/api/comments', commentRoutes);
app.use('/api/messages', messageRoutes);

// Health check for auto-discovery
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', name: 'gminsta-backend', version: '1.1.0' });
});

// Final Error Handler (Ensure JSON response)
app.use((err, req, res, next) => {
  console.error('SERVER ERROR:', err);
  res.status(err.status || 500).json({
    message: err.message || 'Internal Server Error',
    error: process.env.NODE_ENV === 'development' ? err.stack : undefined
  });
});


// Serve frontend for non-API routes
app.get('*', (req, res) => {
  if (!req.path.startsWith('/api') && !req.path.startsWith('/uploads')) {
    res.sendFile(path.join(__dirname, '../frontend/pages/index.html'));
  }
});

// Socket.io for real-time chat
const onlineUsers = new Map();

io.use(verifySocketToken);

io.on('connection', (socket) => {
  const userId = socket.user.id;
  onlineUsers.set(userId, socket.id);
  io.emit('online_users', Array.from(onlineUsers.keys()));

  socket.on('send_message', async ({ receiverId, content }) => {
    try {
      const message = new Message({
        sender: userId,
        receiver: receiverId,
        content
      });
      await message.save();
      await message.populate('sender', 'username avatar');

      const receiverSocketId = onlineUsers.get(receiverId);
      if (receiverSocketId) {
        io.to(receiverSocketId).emit('receive_message', message);
      }
      socket.emit('message_sent', message);
    } catch (err) {
      socket.emit('error', { message: 'Failed to send message' });
    }
  });

  socket.on('typing', ({ receiverId }) => {
    const receiverSocketId = onlineUsers.get(receiverId);
    if (receiverSocketId) {
      io.to(receiverSocketId).emit('user_typing', { userId });
    }
  });

  socket.on('stop_typing', ({ receiverId }) => {
    const receiverSocketId = onlineUsers.get(receiverId);
    if (receiverSocketId) {
      io.to(receiverSocketId).emit('user_stop_typing', { userId });
    }
  });

  socket.on('disconnect', () => {
    onlineUsers.delete(userId);
    io.emit('online_users', Array.from(onlineUsers.keys()));
  });
});

// MongoDB connection
const connectDB = async () => {
  try {
    if (!process.env.MONGODB_URI) {
      console.error('❌ MONGODB_URI is missing in .env');
      process.exit(1);
    }
    
    console.log('⏳ Connecting to MongoDB Atlas...');
    await mongoose.connect(process.env.MONGODB_URI);
    
    console.log('✅ Connected to MongoDB Atlas');
    const PORT = process.env.PORT || 5000;
    server.listen(PORT, '0.0.0.0', () => {
      console.log(`🚀 GMinsta server running on all interfaces (0.0.0.0) at port ${PORT}`);
      console.log(`📡 Local: http://localhost:${PORT}`);
      
      // Dynamically display network IP
      const os = require('os');
      const networkInterfaces = os.networkInterfaces();
      for (const interfaceName in networkInterfaces) {
        const networkInterface = networkInterfaces[interfaceName];
        for (const info of networkInterface) {
          if (info.family === 'IPv4' && !info.internal) {
            console.log(`🌍 Network IP: http://${info.address}:${PORT}`);
          }
        }
      }
    });
  } catch (err) {
    console.error('❌ MongoDB connection error:', err.message);
    if (err.name === 'MongooseServerSelectionError') {
      console.error('💡 TIP: Check if your IP is whitelisted in MongoDB Atlas or if the host is correct.');
    }
    process.exit(1);
  }
};

connectDB();
