# 📸 GMinsta — Full-Stack Mini Instagram

A complete, production-ready social media application with real-time chat, built with Node.js, Express, MongoDB Atlas, and Socket.io.

---

## ✨ Features

| Feature | Details |
|---|---|
| **Authentication** | Register, Login, JWT tokens, bcrypt password hashing |
| **User Profiles** | Avatar upload, bio, website, follow/unfollow |
| **Posts** | Image + text posts, drag & drop upload, hashtags, location |
| **Feed** | Paginated feed from followed users + explore page |
| **Likes** | Like/unlike posts in real-time |
| **Comments** | Add, view, delete comments on any post |
| **Real-time Chat** | Socket.io 1-to-1 messaging, typing indicators, online status |
| **Search** | Search users by username or full name |
| **Suggestions** | Follow suggestions for new users |

---

## 🗂️ Folder Structure

```
gminsta/
├── backend/
│   ├── models/
│   │   ├── User.js         # User schema (bcrypt hashed passwords)
│   │   ├── Post.js         # Post schema with likes, tags
│   │   ├── Comment.js      # Comment schema with threading
│   │   └── Message.js      # Chat message schema
│   ├── routes/
│   │   ├── auth.js         # POST /register, /login, GET /me
│   │   ├── users.js        # Profile, follow, search, suggestions
│   │   ├── posts.js        # CRUD, feed, explore, likes
│   │   ├── comments.js     # CRUD, likes on comments
│   │   └── messages.js     # Conversations, history
│   ├── middleware/
│   │   ├── auth.js         # JWT protect + socket token verify
│   │   └── upload.js       # Multer config (images, 10MB limit)
│   ├── uploads/            # Uploaded images (auto-created)
│   ├── server.js           # Express + Socket.io entry point
│   ├── package.json
│   └── .env.example        # Copy to .env and fill in values
│
└── frontend/
    ├── pages/
    │   ├── index.html      # Root redirect
    │   ├── login.html      # Login page
    │   ├── register.html   # Register page
    │   ├── feed.html       # Main feed + create post + comments
    │   ├── explore.html    # Explore grid + user search
    │   ├── profile.html    # User profile + edit profile
    │   └── chat.html       # Real-time chat
    ├── css/
    │   └── style.css       # Full responsive dark theme UI
    └── js/
        └── api.js          # API client, helpers, sidebar
```

---

## 🚀 Quick Start

### 1. MongoDB Atlas Setup (Free)
1. Go to [mongodb.com/atlas](https://mongodb.com/atlas) → Create free account
2. Create a **free M0 cluster**
3. Under **Database Access**: create a user with password
4. Under **Network Access**: add `0.0.0.0/0` (allow all IPs)
5. Click **Connect** → **Drivers** → Copy the connection string

### 2. Environment Setup

```bash
cd backend
cp .env.example .env
```

Edit `.env`:
```env
PORT=5000
MONGODB_URI=mongodb+srv://youruser:yourpassword@cluster0.xxxxx.mongodb.net/gminsta?retryWrites=true&w=majority
JWT_SECRET=change_this_to_a_long_random_secret_string
NODE_ENV=development
```

### 3. Install & Run

```bash
cd backend
npm install
npm start
# or for development with auto-reload:
npm run dev
```

Open browser: **http://localhost:5000**

---

## 📡 REST API Reference

### Auth
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register new user |
| POST | `/api/auth/login` | Login user |
| GET | `/api/auth/me` | Get current user |

### Users
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/users/search?q=` | Search users |
| GET | `/api/users/suggestions` | Follow suggestions |
| GET | `/api/users/:username` | Get user profile |
| GET | `/api/users/:username/posts` | Get user posts |
| PUT | `/api/users/profile/update` | Update profile |
| POST | `/api/users/:id/follow` | Follow/unfollow user |

### Posts
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/posts/feed` | Get feed (paginated) |
| GET | `/api/posts/explore` | Explore posts |
| POST | `/api/posts` | Create post (multipart) |
| GET | `/api/posts/:id` | Get single post |
| DELETE | `/api/posts/:id` | Delete own post |
| POST | `/api/posts/:id/like` | Toggle like |

### Comments
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/comments/:postId` | Get comments |
| POST | `/api/comments/:postId` | Add comment |
| DELETE | `/api/comments/:id` | Delete own comment |

### Messages
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/messages/conversations` | Get all conversations |
| GET | `/api/messages/:userId` | Get chat history |
| POST | `/api/messages/:userId` | Send message |

### Socket.io Events
| Event | Direction | Payload |
|-------|-----------|---------|
| `send_message` | Client → Server | `{ receiverId, content }` |
| `receive_message` | Server → Client | Message object |
| `message_sent` | Server → Client | Message object |
| `typing` | Client → Server | `{ receiverId }` |
| `user_typing` | Server → Client | `{ userId }` |
| `stop_typing` | Client → Server | `{ receiverId }` |
| `user_stop_typing` | Server → Client | `{ userId }` |
| `online_users` | Server → Client | Array of online user IDs |

---

## 🛠️ MongoDB Schema Design

### Users Collection
```js
{ username, email, password(hashed), fullName, bio, avatar,
  website, followers[], following[], postsCount, timestamps }
```

### Posts Collection
```js
{ author(ref:User), caption, image, likes[], likesCount,
  commentsCount, tags[], location, timestamps }
```

### Comments Collection
```js
{ post(ref:Post), author(ref:User), content,
  likes[], parentComment(ref:Comment), timestamps }
```

### Messages Collection
```js
{ sender(ref:User), receiver(ref:User),
  content, read(bool), timestamps }
```

---

## 📦 Dependencies

```json
{
  "express": "^4.18",       // Web framework
  "mongoose": "^8.0",       // MongoDB ODM
  "socket.io": "^4.7",      // Real-time WebSockets
  "bcryptjs": "^2.4",       // Password hashing
  "jsonwebtoken": "^9.0",   // JWT auth
  "multer": "^1.4",         // File upload
  "cors": "^2.8",           // CORS headers
  "dotenv": "^16.3"         // Environment variables
}
```

---

## 🎨 UI Design

- **Dark theme** with gold accent (`#c8a96e`)
- **Fonts**: Playfair Display (headings) + DM Sans (body)
- **Fully responsive** — mobile, tablet, desktop
- **Animated** — post cards, modals, toasts, typing indicators
- **Glassmorphism** effects on modals

---

## 🔐 Security Features

- Passwords hashed with bcrypt (salt rounds: 12)
- JWT tokens with 30-day expiration
- File upload validation (images only, 10MB max)
- Protected routes via `Authorization: Bearer <token>` header
- MongoDB injection prevention via Mongoose
- CORS configured for API security

---

## 📝 Notes

- The `uploads/` folder is auto-created on first image upload
- For production, consider using **Cloudinary** or **AWS S3** for image storage
- Set `NODE_ENV=production` and a strong `JWT_SECRET` in production
- The frontend is served statically from the Express server — no separate build step needed
