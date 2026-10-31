// Kiểm: ESC đóng từng lớp một, từ trên xuống.
const fs = require('fs');
const { JSDOM, VirtualConsole } = require('jsdom');
const html = fs.readFileSync('index.html', 'utf8');
const data = JSON.parse(fs.readFileSync(process.argv[2] || 'api-data.json', 'utf8'));
if (!data.assetTypes) data.assetTypes = [{ code: 'server', label: 'Server', note: '' }];

const errors = [];
const vc = new VirtualConsole();
vc.on('jsdomError', e => errors.push(e.detail ? e.detail.stack : e.message));
vc.on('error', (...a) => errors.push(`console.error: ${a.join(' ')}`));
const dom = new JSDOM(html, { runScripts: 'dangerously', pretendToBeVisual: true, virtualConsole: vc,
  url: 'http://localhost:8084/',
  beforeParse(w) {
    w.fetch = u => Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(
      u === 'api/me' ? { username: 'admin', fullName: 'T', role: 'admin' }
        : u === 'api/data' ? data : u === 'api/imports' ? { imports: [] } : { ok: true }) });
    w.confirm = () => true;
    w.MGMT_DEVICE_DATA = { meta: {}, assetRows: [], historyRows: [] };
  } });
const w = dom.window, $ = id => w.document.getElementById(id);
const report = [];
const check = (l, ok, d = '') => report.push(`${ok ? 'PASS' : 'FAIL'}  ${l}${d ? ' — ' + d : ''}`);
const esc = () => w.document.dispatchEvent(new w.KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
const modals = () => w.document.querySelectorAll('.modal-backdrop').length;
const drawerOpen = () => $('detailDrawer').classList.contains('open');

setTimeout(() => {
  w.document.querySelector('[data-view="assets"]').click();

  // ---- hai lớp: hồ sơ chi tiết + form sửa --------------------------------
  $('assetRowsFull').rows[0].querySelector('.asset-link').click();
  check('mở hồ sơ chi tiết', drawerOpen());
  $('drawerEdit').click();
  check('mở tiếp form sửa tài sản', modals() === 1 && drawerOpen(),
    `${modals()} hộp thoại · hồ sơ ${drawerOpen() ? 'mở' : 'đóng'}`);

  esc();
  check('ESC lần 1 đóng form sửa, hồ sơ chi tiết VẪN MỞ',
    modals() === 0 && drawerOpen(),
    `${modals()} hộp thoại · hồ sơ ${drawerOpen() ? 'mở' : 'đóng'}`);
  esc();
  check('ESC lần 2 mới đóng hồ sơ chi tiết', !drawerOpen());
  esc();
  check('ESC khi không còn lớp nào thì không lỗi gì', modals() === 0 && !drawerOpen());

  // ---- ba lớp: hồ sơ + form sửa + xác nhận khác --------------------------
  $('assetRowsFull').rows[0].querySelector('.asset-link').click();
  $('drawerTransfer').click();
  $('drawerClone').click();   // mở thêm một hộp thoại nữa chồng lên
  check('chồng được ba lớp', modals() === 2 && drawerOpen(), `${modals()} hộp thoại`);
  esc();
  check('ESC đóng đúng lớp trên cùng trước', modals() === 1 && drawerOpen());
  esc();
  check('ESC tiếp tục đóng lớp kế', modals() === 0 && drawerOpen());
  esc();
  check('ESC cuối cùng đóng hồ sơ', !drawerOpen());

  // ---- ESC khi con trỏ đang ở trong ô nhập -------------------------------
  $('newAssetBtnFull').click();
  const input = w.document.querySelector('.modal-backdrop [name="asset_name"]');
  input.focus();
  input.dispatchEvent(new w.KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
  check('ESC lúc đang gõ trong ô vẫn đóng hộp thoại', modals() === 0);

  // ---- hộp thoại mở từ mục khác cũng nghe ESC ----------------------------
  w.document.querySelector('[data-view="locations"]').click();
  $('locationCrud').querySelector('.edit-location').click();
  check('mở hộp thoại ở mục Vị trí & Cụm', modals() === 1);
  esc();
  check('ESC đóng được hộp thoại đó', modals() === 0);

  console.log(report.join('\n'));
  console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
  process.exit(report.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
}, 500);
