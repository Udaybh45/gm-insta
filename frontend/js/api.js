// === GMinsta API Client ===
const API_BASE = '/api';

const api = {
  token: () => localStorage.getItem('gminsta_token'),
  user: () => JSON.parse(localStorage.getItem('gminsta_user') || 'null'),

  headers(isForm = false) {
    const h = { Authorization: `Bearer ${this.token()}` };
    if (!isForm) h['Content-Type'] = 'application/json';
    return h;
  },

  async request(method, path, body = null, isForm = false) {
    const opts = {
      method,
      headers: this.headers(isForm)
    };
    if (body) opts.body = isForm ? body : JSON.stringify(body);
    const res = await fetch(`${API_BASE}${path}`, opts);
    const data = await res.json();
    if (!res.ok) throw new Error(data.message || 'Request failed');
    return data;
  },

  get: (path) => api.request('GET', path),
  post: (path, body, isForm) => api.request('POST', path, body, isForm),
  put: (path, body, isForm) => api.request('PUT', path, body, isForm),
  delete: (path) => api.request('DELETE', path),
};

// Toast
const toast = {
  container: null,
  init() {
    this.container = document.getElementById('toast-container') || (() => {
      const el = document.createElement('div');
      el.id = 'toast-container';
      el.className = 'toast-container';
      document.body.appendChild(el);
      return el;
    })();
  },
  show(message, type = 'info') {
    if (!this.container) this.init();
    const el = document.createElement('div');
    el.className = `toast ${type}`;
    el.textContent = message;
    this.container.appendChild(el);
    setTimeout(() => el.remove(), 3000);
  },
  success: (m) => toast.show(m, 'success'),
  error: (m) => toast.show(m, 'error'),
  info: (m) => toast.show(m, 'info'),
};
toast.init();

// Auth guard
function requireAuth() {
  if (!api.token() || !api.user()) {
    window.location.href = '/pages/login.html';
    return false;
  }
  return true;
}

function requireGuest() {
  if (api.token() && api.user()) {
    window.location.href = '/pages/feed.html';
    return false;
  }
  return true;
}

// Time formatting
function timeAgo(date) {
  const now = new Date();
  const d = new Date(date);
  const diff = Math.floor((now - d) / 1000);
  if (diff < 60) return 'just now';
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  if (diff < 604800) return `${Math.floor(diff / 86400)}d ago`;
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

// Avatar helpers
function getAvatar(user) {
  if (user?.avatar) return user.avatar;
  return `https://ui-avatars.com/api/?name=${encodeURIComponent(user?.username || 'U')}&background=2a2a3a&color=c8a96e&size=128&font-size=0.5&bold=true`;
}

// Format numbers
function formatCount(n) {
  if (n >= 1000000) return (n / 1000000).toFixed(1) + 'M';
  if (n >= 1000) return (n / 1000).toFixed(1) + 'K';
  return n;
}

// SVG icons
const icons = {
  home: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>`,
  explore: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>`,
  reels: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="2" width="20" height="20" rx="5" ry="5"/><path d="M10 9l5 3-5 3z"/></svg>`,
  create: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg>`,
  messages: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z"/></svg>`,
  profile: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>`,
  heart: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20.84 4.61a5.5 5.5 0 00-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 00-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 000-7.78z"/></svg>`,
  comment: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z"/></svg>`,
  share: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/></svg>`,
  bookmark: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M19 21l-7-5-7 5V5a2 2 0 012-2h10a2 2 0 012 2z"/></svg>`,
  send: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/></svg>`,
  logout: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>`,
  image: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/></svg>`,
  dots: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="5" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="12" cy="19" r="1"/></svg>`,
  settings: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 010 2.83 2 2 0 01-2.83 0l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 01-4 0v-.09A1.65 1.65 0 009 19.4a1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 01-2.83 0 2 2 0 010-2.83l.06-.06A1.65 1.65 0 004.68 15a1.65 1.65 0 00-1.51-1H3a2 2 0 010-4h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 010-2.83 2 2 0 012.83 0l.06.06A1.65 1.65 0 009 4.68a1.65 1.65 0 001-1.51V3a2 2 0 014 0v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 012.83 0 2 2 0 010 2.83l-.06.06A1.65 1.65 0 0019.4 9a1.65 1.65 0 001.51 1H21a2 2 0 010 4h-.09a1.65 1.65 0 00-1.51 1z"/></svg>`,
  download: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>`,
};

// Build sidebar nav
function buildSidebar(activePage) {
  const user = api.user();
  if (!user) return;

  const navItems = [
    { icon: 'home', label: 'Home', href: '/pages/feed.html', key: 'feed' },
    { icon: 'explore', label: 'Explore', href: '/pages/explore.html', key: 'explore' },
    { icon: 'reels', label: 'Reels', href: '/pages/reels.html', key: 'reels' },
    { icon: 'heart', label: 'Notifications', href: '/pages/activity.html', key: 'activity' },
    { icon: 'create', label: 'Create Post', href: '#', key: 'create', action: 'openCreatePost' },
    { icon: 'messages', label: 'Messages', href: '/pages/chat.html', key: 'chat' },
    { icon: 'profile', label: 'Profile', href: `/pages/profile.html?u=${user.username}`, key: 'profile' },
  ];

  const sidebar = document.getElementById('sidebar');
  if (!sidebar) return;

  sidebar.innerHTML = `
    <div class="sidebar-logo">
      <h1>GMinsta</h1>
      <span>Share Your World</span>
    </div>
    <nav class="sidebar-nav">
      ${navItems.map(item => `
        <div class="nav-item ${activePage === item.key ? 'active' : ''}" 
             ${item.action ? `onclick="${item.action}()"` : `onclick="window.location='${item.href}'"` }
             data-page="${item.key}" id="nav-item-${item.key}" style="position:relative;">
          ${icons[item.icon]}
          <span class="nav-badge hidden" style="position:absolute;top:10px;left:28px;width:8px;height:8px;background:var(--accent);border-radius:50%;display:none;"></span>
          <span>${item.label}</span>
        </div>
      `).join('')}
    </nav>
    <div class="sidebar-user" onclick="window.location='/pages/profile.html?u=${user.username}'">
      <img class="sidebar-avatar" src="${getAvatar(user)}" alt="${user.username}" onerror="this.src='${getAvatar(user)}'">
      <div>
        <div class="sidebar-username">${user.username}</div>
        <div class="sidebar-handle">${user.fullName || 'View Profile'}</div>
      </div>
    </div>
    <div style="padding: 12px 20px 0;">
      <a href="/GMinsta-App.apk" download style="display:block; text-decoration:none;">
        <button class="btn btn-outline btn-sm" style="width:100%;gap:8px;margin-bottom:8px;border-color:var(--accent);color:var(--accent);">
          ${icons.download} Get App
        </button>
      </a>
      <button class="btn btn-ghost btn-sm" style="width:100%;gap:8px;" onclick="logout()">
        ${icons.logout} Log out
      </button>
    </div>
  `;

  // Mobile Bottom Nav
  let mobileNav = document.getElementById('mobile-nav');
  if (!mobileNav) {
    mobileNav = document.createElement('div');
    mobileNav.id = 'mobile-nav';
    mobileNav.className = 'mobile-nav';
    document.body.appendChild(mobileNav);
  }
  
  const mobileItems = [
    { icon: 'home', href: '/pages/feed.html', key: 'feed' },
    { icon: 'explore', href: '/pages/explore.html', key: 'explore' },
    { icon: 'reels', href: '/pages/reels.html', key: 'reels' },
    { icon: 'messages', href: '/pages/chat.html', key: 'chat' },
    { icon: 'heart', href: '/pages/activity.html', key: 'activity' },
    { icon: 'profile', href: `/pages/profile.html?u=${user.username}`, key: 'profile' }
  ];

  mobileNav.innerHTML = mobileItems.map(item =>
    `<div class="mobile-nav-item ${activePage === item.key ? 'active' : ''}" 
         ${item.action ? `onclick="${item.action}()"` : `onclick="window.location='${item.href}'"` }
         id="mobile-nav-item-${item.key}" style="position:relative;">
      ${icons[item.icon]}
      <span class="nav-badge hidden" style="position:absolute;top:10px;right:16px;width:8px;height:8px;background:var(--accent);border-radius:50%;display:none;"></span>
    </div>
  `).join('') +
  `<a href="/GMinsta-App.apk" download class="mobile-nav-item mobile-get-app" title="Download App" id="mobile-nav-item-download">
    <div class="mobile-get-app-icon">${icons.download}</div>
  </a>`;

  // Fetch unread notifications count to update badges
  api.get('/users/activity').then(data => {
    const unreadCount = (data.requests?.length || 0) + (data.likes?.length || 0);
    if (unreadCount > 0) {
      const desktopBadge = document.querySelector('#nav-item-activity .nav-badge');
      if (desktopBadge) {
        desktopBadge.style.display = 'block';
        desktopBadge.classList.remove('hidden');
      }
      const mobileBadge = document.querySelector('#mobile-nav-item-activity .nav-badge');
      if (mobileBadge) {
        mobileBadge.style.display = 'block';
        mobileBadge.classList.remove('hidden');
      }
    }
  }).catch(() => {});
}

function logout() {
  localStorage.removeItem('gminsta_token');
  localStorage.removeItem('gminsta_user');
  window.location.href = '/pages/login.html';
}
