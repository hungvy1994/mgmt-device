// Kiểm: 3 tab ở Nhập/Xuất · mục Admin quản lý tài khoản · nhật ký nói rõ "bởi ai".
const fs = require('fs');
const { JSDOM, VirtualConsole } = require('jsdom');
const html = fs.readFileSync('index.html', 'utf8');
const data = JSON.parse(fs.readFileSync(process.argv[2] || 'api-data.json', 'utf8'));

const users = [
  { id: 2, username: 'admin', fullName: 'Đặng Hùng Vỹ', email: 'vydh@matbao.com',
    role: 'admin', roleLabel: 'Quản trị', isActive: true, lastLoginAt: '2026-09-17T04:19:22+00:00' },
  { id: 4, username: 'kietoan', fullName: 'Kế toán', email: '', role: 'xem',
    roleLabel: 'Chỉ xem', isActive: true, lastLoginAt: '' },
];
const audit = [{ at: '2026-09-17T04:08:11+00:00', username: 'kietoan', action: 'sua', entity: 'asset',
  entityId: 'x-1', note: '', changes: { asset_name: { cu: 'A', moi: 'B' } } }];

function chay(vai, xong) {
  const errors = [];
  const vc = new VirtualConsole();
  vc.on('jsdomError', e => errors.push(e.detail ? e.detail.stack : e.message));
  vc.on('error', (...a) => errors.push(`console.error: ${a.join(' ')}`));
  const calls = [];
  const dom = new JSDOM(html, {
    runScripts: 'dangerously', pretendToBeVisual: true, virtualConsole: vc,
    url: 'http://localhost:8084/',
    beforeParse(w) {
      w.fetch = (u, o = {}) => {
        const url = String(u);
        calls.push({ url, method: (o.method || 'GET') });
        return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(
          url === 'api/me' ? { username: vai === 'admin' ? 'admin' : 'kietoan', role: vai }
            : url === 'api/data' ? data : url === 'api/imports' ? { imports: [] }
            : url === 'api/users' ? { users, roles: [] }
            : url.startsWith('api/audit') ? { entries: audit } : { ok: true }) });
      };
      w.confirm = () => true;
      w.MGMT_DEVICE_DATA = { meta: {}, assetRows: [], historyRows: [] };
    },
  });
  setTimeout(() => xong(dom.window, errors, calls), 650);
}

const report = [];
const check = (l, ok, d = '') => report.push(`${ok ? 'PASS' : 'FAIL'}  ${l}${d ? ' — ' + d : ''}`);
const ket = [];

chay('admin', async (w, errors, calls) => {
  const $ = id => w.document.getElementById(id);
  ket.push(...errors);
  // ---- 1. Ba tab ở Nhập / Xuất ------------------------------------------
  w.document.querySelector('[data-view="data"]').click();
  const tabs = [...w.document.querySelectorAll('#dataView .tab')];
  check('mục Nhập/Xuất có đúng 3 tab', tabs.length === 3, tabs.map(t => t.textContent).join(' | '));
  check('tab đầu mở sẵn, hai tab kia ẩn',
    !$('dataStore').hidden && $('dataImportLog').hidden && $('dataAudit').hidden);
  tabs[2].click();
  check('bấm tab Nhật ký thao tác thì đổi đúng panel',
    $('dataStore').hidden && !$('dataAudit').hidden && tabs[2].classList.contains('active'));
  tabs[1].click();
  check('chỉ một panel hiện tại một thời điểm',
    [...w.document.querySelectorAll('#dataView .tab-panel')].filter(p => !p.hidden).length === 1);

  // ---- 3. Nhật ký nói rõ bởi ai -----------------------------------------
  tabs[2].click();
  const t = $('auditLog').textContent;
  check('nhật ký ghi rõ "bởi <tài khoản>"', /bởi\s*kietoan/.test(t.replace(/\s+/g, ' ')),
    t.replace(/\s+/g, ' ').slice(0, 76));

  // ---- 2. Mục Admin ------------------------------------------------------
  const nav = w.document.querySelector('[data-view="admin"]');
  check('quản trị viên thấy mục Admin', Boolean(nav) && !nav.hidden);
  nav.click();
  await new Promise(r => setTimeout(r, 150));   // renderUsers() là async
  check('có nút thêm tài khoản', Boolean($('newUser')));
  const bang = $('userCrud').textContent;
  check('bảng tài khoản hiện đủ người và vai',
    bang.includes('admin') && bang.includes('kietoan') && bang.includes('Chỉ xem'),
    bang.replace(/\s+/g, ' ').slice(0, 70));
  check('nút xoá sạch dữ liệu nằm trong mục Admin',
    $('adminView').contains($('wipeData')));
  check('sidebar không còn nút xoá sạch',
    !w.document.querySelector('.sidebar-footer #wipeData'));

  // form sửa tài khoản
  $('userCrud').querySelector('.edit-user').click();
  const form = [...w.document.querySelectorAll('.modal-backdrop')].pop();
  const names = [...form.querySelectorAll('[name]')].map(n => n.name);
  check('form tài khoản có ô chọn vai', names.includes('role'));
  const vaiOpts = [...form.querySelector('[name="role"]').options].map(o => o.value);
  check('ba vai: admin · sửa · chỉ xem',
    ['admin', 'sua', 'xem'].every(v => vaiOpts.includes(v)), vaiOpts.join(', '));
  check('sửa tài khoản có nút xoá', /Xoá tài khoản/.test(form.textContent));

  chay('xem', async (w2, errors2, calls2) => {
    await new Promise(r => setTimeout(r, 120));
    ket.push(...errors2);
    const $2 = id => w2.document.getElementById(id);
    const nav2 = w2.document.querySelector('[data-view="admin"]');
    check('tài khoản chỉ xem KHÔNG thấy mục Admin', nav2.hidden === true);
    check('tài khoản chỉ xem không gọi api/users',
      !calls2.some(c => c.url === 'api/users'));
    check('thân trang gắn dấu chỉ xem để ẩn nút ghi',
      w2.document.body.classList.contains('chi-xem'), w2.document.body.className);
    // bấm thêm tài sản thì bị chặn ở tầng giao diện, không gửi POST
    w2.document.querySelector('[data-view="assets"]').click();
    $2('newAssetBtnFull')?.click();
    check('bấm thêm tài sản không gửi POST nào',
      !calls2.some(c => c.url === 'api/assets' && c.method === 'POST'));

    console.log(report.join('\n'));
    console.log('\nlỗi runtime:', ket.length ? ket.join('\n') : 'không có');
    process.exit(report.some(l => l.startsWith('FAIL')) || ket.length ? 1 : 0);
  });
});
