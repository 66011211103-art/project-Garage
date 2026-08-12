// ============================================================
// ไฟล์: admin-shell.js
// ใช้ร่วมกันทุกหน้าใน admin/ — sidebar เมนู, auth guard, helper ต่างๆ
// ============================================================

const ADMIN_MENU = [
  { group: 'ภาพรวม', items: [
    { key: 'dashboard', href: 'dashboard.html', label: 'แดชบอร์ด',
      icon: '<rect x="3" y="3" width="7" height="9" rx="1.5"/><rect x="14" y="3" width="7" height="5" rx="1.5"/><rect x="14" y="12" width="7" height="9" rx="1.5"/><rect x="3" y="16" width="7" height="5" rx="1.5"/>' },
  ]},
  { group: 'จัดการผู้ใช้งาน', items: [
    { key: 'users', href: 'users.html', label: 'บัญชีผู้ใช้งาน',
      icon: '<circle cx="9" cy="8" r="3.2"/><path d="M3 20c0-3.3 2.7-6 6-6s6 2.7 6 6"/><path d="M16 9a2.8 2.8 0 1 0 0-5.6M17.5 14.2c2.5.4 4.5 2.4 4.5 5.8"/>' },
  ]},
  { group: 'จัดการอู่ซ่อมรถ', items: [
    { key: 'garages', href: 'garages.html', label: 'อู่ซ่อมรถ & อนุมัติ',
      icon: '<path d="M3 21V9l9-6 9 6v12"/><path d="M9 21v-7h6v7"/>' },
  ]},
  { group: 'ควบคุมคุณภาพ', items: [
    { key: 'repairs', href: 'repairs.html', label: 'ปรับสถานะงานซ่อม',
      icon: '<path d="M9 12h6m-6 4h6M9 8h2"/><rect x="4" y="4" width="16" height="16" rx="2.5"/>' },
    { key: 'reviews', href: 'reviews.html', label: 'รีวิว & ข้อร้องเรียน',
      icon: '<path d="M21 11.5a8.5 8.5 0 1 1-4.4-7.4"/><path d="M21 4 12 13l-3-3"/>' },
  ]},
  { group: 'รายงาน', items: [
    { key: 'reports', href: 'reports.html', label: 'สถิติ & กราฟ',
      icon: '<path d="M4 20V10m6 10V4m6 16v-7"/>' },
  ]},
  { group: 'ระบบ', items: [
    { key: 'settings', href: 'settings.html', label: 'ตั้งค่า & สิทธิ์',
      icon: '<path d="M12 2 3 6v6c0 5 4 8.5 9 10 5-1.5 9-5 9-10V6l-9-4z"/>' },
  ]},
];

function requireAdmin() {
  const raw = sessionStorage.getItem('adminUser');
  if (!raw) {
    window.location.href = 'login.html';
    return null;
  }
  return JSON.parse(raw);
}

function mountSidebar(activeKey) {
  const admin = requireAdmin();
  const mount = document.getElementById('sidebarMount');
  if (!mount) return;

  const menuHtml = ADMIN_MENU.map(group => `
    <div class="menu-group">
      <div class="menu-title">${group.group}</div>
      ${group.items.map(item => `
        <a class="menu-item ${item.key === activeKey ? 'active' : ''}" href="${item.href}">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">${item.icon}</svg>
          ${item.label}
        </a>`).join('')}
    </div>`).join('');

  mount.innerHTML = `
    <div class="sidebar-brand">
      <div class="icon">
        <svg viewBox="0 0 24 24" fill="none"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z" stroke="white" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>
      </div>
      <div class="label">Good Garage<small>ADMIN PANEL</small></div>
    </div>
    <nav class="menu">${menuHtml}</nav>
    <div class="sidebar-footer">
      <div class="admin-chip">
        <div class="admin-avatar">${(admin && admin.email ? admin.email.charAt(0) : 'A').toUpperCase()}</div>
        <div class="admin-info">
          <div class="name">${admin ? (admin.name || 'ผู้ดูแลระบบ') : ''}</div>
          <div class="email">${admin ? admin.email : ''}</div>
        </div>
      </div>
      <button class="logout-btn" onclick="logoutAdmin()">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>
        ออกจากระบบ
      </button>
    </div>
  `;
}

function logoutAdmin() {
  sessionStorage.removeItem('adminUser');
  window.location.href = 'login.html';
}

function escapeHtml(str) {
  if (str === null || str === undefined) return '';
  return String(str)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function formatDate(isoString) {
  if (!isoString) return '-';
  const d = new Date(isoString);
  if (isNaN(d)) return '-';
  return d.toLocaleDateString('th-TH', { day: 'numeric', month: 'short', year: 'numeric' });
}

function badge(text, type) {
  return `<span class="badge badge-${type}">${escapeHtml(text)}</span>`;
}

function toast(message, success = true) {
  let box = document.getElementById('toastBox');
  if (!box) {
    box = document.createElement('div');
    box.id = 'toastBox';
    document.body.appendChild(box);
  }
  const el = document.createElement('div');
  el.className = `toast ${success ? 'success' : 'error'}`;
  el.textContent = message || (success ? 'สำเร็จ' : 'เกิดข้อผิดพลาด');
  box.appendChild(el);
  setTimeout(() => el.remove(), 3200);
}
