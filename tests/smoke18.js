// Kiểm: nhân bản chạy được với cả một lẫn nhiều tài sản đang chọn.
const fs = require('fs');
const { JSDOM, VirtualConsole } = require('jsdom');
const html = fs.readFileSync('index.html', 'utf8');
const data = JSON.parse(fs.readFileSync(process.argv[2] || 'api-data.json', 'utf8'));
if (!data.assetTypes) data.assetTypes = [{ code: 'server', label: 'Server', note: '' }];

const errors = [];
const vc = new VirtualConsole();
vc.on('jsdomError', e => errors.push(e.detail ? e.detail.stack : e.message));
vc.on('error', (...a) => errors.push(`console.error: ${a.join(' ')}`));
const calls = [];
const dom = new JSDOM(html, { runScripts: 'dangerously', pretendToBeVisual: true, virtualConsole: vc,
  url: 'http://localhost:8084/',
  beforeParse(w) {
    w.fetch = (u, o = {}) => { calls.push({ url: u, method: o.method || 'GET',
        body: o.body && typeof o.body === 'string' ? JSON.parse(o.body) : null });
      return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(
        u === 'api/me' ? { username: 'admin', fullName: 'T', role: 'admin' }
          : u === 'api/data' ? data : u === 'api/imports' ? { imports: [] }
            : { asset: { asset_id: 'CHUA-GAN-0001' } }) }); };
    w.confirm = () => true;
    w.MGMT_DEVICE_DATA = { meta: {}, assetRows: [], historyRows: [] };
  } });
const w = dom.window, $ = id => w.document.getElementById(id);
const report = [];
const check = (l, ok, d = '') => report.push(`${ok ? 'PASS' : 'FAIL'}  ${l}${d ? ' — ' + d : ''}`);
const lastModal = () => [...w.document.querySelectorAll('.modal-backdrop')].pop();
const posts = () => calls.filter(c => c.url === 'api/assets' && c.method === 'POST');

setTimeout(async () => {
  w.document.querySelector('[data-view="assets"]').click();

  // ---- một tài sản: vẫn mở form để điền mã --------------------------------
  $('assetRowsFull').querySelector('.row-select').click();
  let clone = $('assetRowsFullBulk').querySelector('.bulk-clone');
  check('nút Nhân bản không còn bị khóa khi chọn 1', !clone.disabled, clone.textContent.trim());
  clone.click();
  check('chọn 1 thì mở form để điền mã',
    Boolean(lastModal()?.querySelector('[name="asset_id"]'))
    && /Nhân bản từ/.test(lastModal().querySelector('.modal-head h2').textContent));
  lastModal().querySelector('.modal-close').click();

  // ---- nhiều tài sản: nhân bản hàng loạt ----------------------------------
  const boxes = [...$('assetRowsFull').querySelectorAll('.row-select')].slice(0, 3);
  boxes.filter(b => !b.checked).forEach(b => b.click());
  const chosen = [...$('assetRowsFull').querySelectorAll('.row-select:checked')].map(b => b.dataset.id);
  clone = $('assetRowsFullBulk').querySelector('.bulk-clone');
  check('chọn nhiều thì nút vẫn dùng được', !clone.disabled, clone.textContent.trim());
  check('nút cho biết sẽ nhân bản mấy mục', clone.textContent.includes(String(chosen.length)),
    clone.textContent.trim());
  const before = posts().length;
  clone.click();
  await new Promise(r => setTimeout(r, 200));
  const made = posts().slice(before);
  check(`gửi đúng ${chosen.length} lệnh tạo mới`, made.length === chosen.length,
    `${made.length} lệnh`);
  check('mỗi bản sao để trống mã (hệ thống cấp mã tạm)',
    made.every(c => !c.body.asset_id), made.map(c => `«${c.body.asset_id}»`).join(' '));
  check('mỗi bản sao để trống vị trí U',
    made.every(c => !c.body.rack_unit), made.map(c => `«${c.body.rack_unit}»`).join(' '));
  check('các thông tin khác chép nguyên từ bản gốc', made.every((c, i) => {
    const source = data.assetRows.find(a => a.asset_id === chosen[i]);
    return c.body.asset_name === source.asset_name && c.body.asset_type === source.asset_type;
  }), made.map(c => c.body.asset_name?.slice(0, 18)).join(' | '));
  check('nhân bản xong thì bỏ chọn hết',
    $('assetRowsFull').querySelectorAll('.row-select:checked').length === 0);

  // ---- màn Kho cũng vậy ---------------------------------------------------
  w.document.querySelector('[data-view="store"]').click();
  const storeBoxes = [...$('storeRows').querySelectorAll('.row-select')].slice(0, 2);
  if (storeBoxes.length === 2) {
    storeBoxes.forEach(b => b.click());
    const storeClone = $('storeRowsBulk').querySelector('.bulk-clone');
    check('màn Kho: nhân bản nhiều mục cũng dùng được', !storeClone.disabled,
      storeClone.textContent.trim());
    const mark = posts().length;
    storeClone.click();
    await new Promise(r => setTimeout(r, 200));
    check('màn Kho gửi đúng số lệnh tạo mới', posts().length - mark === 2,
      `${posts().length - mark} lệnh`);
  } else {
    check('màn Kho: nhân bản nhiều mục cũng dùng được', true, 'kho không đủ 2 dòng — bỏ qua');
  }

  console.log(report.join('\n'));
  console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
  process.exit(report.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
}, 500);
