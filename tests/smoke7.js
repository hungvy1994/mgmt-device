// Kiểm: cột cố định, popup xem trước khi nhập, sidebar cố định + nút xoá sạch, đổi tên.
const fs = require('fs');
const { JSDOM, VirtualConsole } = require('jsdom');

const html = fs.readFileSync('index.html', 'utf8');
const data = JSON.parse(fs.readFileSync(process.argv[2] || 'api-data.json', 'utf8'));

const errors = [];
const vc = new VirtualConsole();
vc.on('jsdomError', e => errors.push(e.detail ? e.detail.stack : e.message));
vc.on('error', (...a) => errors.push(`console.error: ${a.join(' ')}`));

const PREVIEW = {
  kind: 'assets', fileType: 'csv', rows: 4, unchanged: 1, skippedUnknown: [],
  added: [{ key: 'NEW-1', name: 'Máy mới 1', summary: 'server · ODS · in_stock' },
          { key: 'NEW-2', name: 'Máy mới 2', summary: 'disk · Kho · in_stock' }],
  updated: [
    { key: 'OLD-1', name: 'Máy cũ 1', changes: [
      { field: 'capacity', label: 'Dung lượng / cấu hình', old: '1.92TB', new: '3.84TB' },
      { field: 'datacenter', label: 'Site / Datacenter', old: 'ODS', new: 'Kho' }] },
    { key: 'OLD-2', name: 'Máy cũ 2', changes: [
      { field: 'usage_status', label: 'Trạng thái', old: 'in_use', new: 'broken' }] },
  ],
};
const calls = [];
const dom = new JSDOM(html, {
  runScripts: 'dangerously', pretendToBeVisual: true, virtualConsole: vc,
  url: 'http://localhost:8084/',
  beforeParse(w) {
    w.fetch = (u, o = {}) => {
      const isForm = o.body && typeof o.body.get === 'function';
      calls.push({ url: u, method: o.method || 'GET',
        skip: isForm ? o.body.get('skip') : null,
        body: !isForm && o.body ? JSON.parse(o.body) : null });
      return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(
        u === 'api/me' ? { username: 'admin', fullName: 'T', role: 'admin' }
          : u === 'api/data' ? data : u === 'api/imports' ? { imports: [] }
            : u === 'api/import/preview' ? PREVIEW
              : u === 'api/data/wipe' ? { scope: 'records', total: 1577, removed: {} }
                : { rows: 4, fileType: 'csv', added: 2, updated: 1, skipped: 1 }) });
    };
    w.confirm = () => true;
    w.MGMT_DEVICE_DATA = { meta: {}, assetRows: [], historyRows: [] };
  },
});
const w = dom.window, $ = id => w.document.getElementById(id);
const report = [];
const check = (l, ok, d = '') => report.push(`${ok ? 'PASS' : 'FAIL'}  ${l}${d ? ' — ' + d : ''}`);
const lastModal = () => [...w.document.querySelectorAll('.modal-backdrop')].pop();

setTimeout(async () => {
  // ---- 4. Đổi tên -------------------------------------------------------
  check('tiêu đề trang đã đổi tên', w.document.title.includes('Device Management'), w.document.title);
  const brands = [...w.document.querySelectorAll('.brand')].map(n => n.textContent.trim());
  check('thương hiệu trên sidebar và màn đăng nhập đã đổi',
    brands.length === 2 && brands.every(b => b.includes('Device Management')), brands.join(' | '));
  // Tên cũ của sản phẩm phải biến mất hẳn. Ghép chuỗi để lần đổi tên hàng loạt sau này
  // không vô tình sửa luôn cái tên đang cần tìm — đã dính một lần rồi.
  const TEN_CU = ['At' + 'las Ops', 'at' + 'las-ops'];
  const con_sot = TEN_CU.filter(t => w.document.body.innerHTML.includes(t));
  check('không còn tên sản phẩm cũ ở đâu', con_sot.length === 0, con_sot.join(', ') || 'sạch');

  // ---- 1. Cột cố định ---------------------------------------------------
  w.document.querySelector('[data-view="assets"]').click();
  const table = $('assetRowsFull').closest('table');
  const cols = [...table.querySelectorAll('colgroup col')];
  check('bảng tài sản khai bề rộng từng cột',
    cols.length === table.tHead.rows[0].cells.length, `${cols.length} col / ${table.tHead.rows[0].cells.length} cột`);
  check('mọi col đều có width', cols.every(c => c.style.width), cols.map(c => c.style.width).join(' '));
  const storeTable = (() => { w.document.querySelector('[data-view="store"]').click(); return $('storeRows').closest('table'); })();
  check('bảng kho cũng khai bề rộng',
    storeTable.querySelectorAll('colgroup col').length === storeTable.tHead.rows[0].cells.length);
  w.document.querySelector('[data-view="locations"]').click();
  const mini = $('locationCrud').querySelector('table');
  check('bảng nhỏ cũng khai bề rộng',
    mini.querySelectorAll('colgroup col').length === mini.tHead.rows[0].cells.length,
    `${mini.querySelectorAll('colgroup col').length} col / ${mini.tHead.rows[0].cells.length} cột`);

  // ---- 3. Sidebar + nút xoá sạch ---------------------------------------
  check('có nút Xoá sạch dữ liệu trên sidebar', Boolean($('wipeData')), $('wipeData')?.textContent.trim());
  $('wipeData').click();
  const wipeForm = lastModal().querySelector('form');
  check('hộp thoại xoá có chọn phạm vi và ô xác nhận',
    Boolean(wipeForm.querySelector('[name="scope"]')) && Boolean(wipeForm.querySelector('[name="confirm"]')));
  check('phạm vi nói rõ sẽ mất bao nhiêu bản ghi',
    /\d/.test(wipeForm.querySelector('[name="scope"]').options[0].textContent),
    wipeForm.querySelector('[name="scope"]').options[0].textContent.trim());
  wipeForm.querySelector('[name="confirm"]').value = 'xoa nham';
  wipeForm.dispatchEvent(new w.Event('submit', { bubbles: true, cancelable: true }));
  await new Promise(r => setTimeout(r, 60));
  check('gõ sai câu xác nhận thì không gọi API',
    !calls.some(c => c.url === 'api/data/wipe'), 'chưa gọi');
  lastModal().querySelector('[name="confirm"]').value = 'XOA SACH';
  lastModal().querySelector('form').dispatchEvent(new w.Event('submit', { bubbles: true, cancelable: true }));
  await new Promise(r => setTimeout(r, 60));
  const wipeCall = calls.find(c => c.url === 'api/data/wipe');
  check('gõ đúng thì gọi POST /api/data/wipe', Boolean(wipeCall),
    wipeCall ? JSON.stringify(wipeCall.body) : '(không gọi)');

  // ---- 2. Popup xem trước khi nhập -------------------------------------
  w.document.querySelector('[data-view="data"]').click();
  const input = $('assetCsvInput');
  const file = new w.File(['asset_id\nX'], 'thu.csv', { type: 'text/csv' });
  Object.defineProperty(input, 'files', { value: [file], configurable: true });
  input.dispatchEvent(new w.Event('change', { bubbles: true }));
  check('chọn file thì bật nút nạp', !$('applyAssetImport').disabled);
  $('applyAssetImport').click();
  await new Promise(r => setTimeout(r, 120));

  check('gọi xem trước trước khi ghi',
    calls.some(c => c.url === 'api/import/preview')
    && !calls.some(c => c.url === 'api/import/assets'), 'chưa ghi gì');
  const popup = lastModal();
  check('hiện popup xem trước', Boolean(popup?.querySelector('.preview-body')));
  const tables = [...popup.querySelectorAll('table')];
  check('popup có mục thêm mới và mục ghi đè', tables.length === 2, `${tables.length} bảng`);
  const addedRows = [...tables[0].tBodies[0].rows].map(r => r.cells[0].textContent.trim());
  check('liệt kê đúng item sẽ thêm mới',
    addedRows.join(',') === 'NEW-1,NEW-2', addedRows.join(', '));
  const heads = [...tables[1].tHead.rows[0].cells].map(c => c.textContent.trim());
  check('bảng ghi đè có 3 cột dữ liệu cũ / mới / tick bỏ qua',
    heads.join(' | ') === 'Bỏ qua | Mã | Dữ liệu cũ | Dữ liệu mới', heads.join(' | '));
  const firstRow = tables[1].tBodies[0].rows[0];
  check('cột dữ liệu cũ hiện giá trị đang có',
    firstRow.cells[2].textContent.includes('1.92TB') && firstRow.cells[2].textContent.includes('ODS'),
    firstRow.cells[2].textContent.replace(/\s+/g, ' ').trim());
  check('cột dữ liệu mới hiện giá trị sẽ ghi đè',
    firstRow.cells[3].textContent.includes('3.84TB') && firstRow.cells[3].textContent.includes('Kho'),
    firstRow.cells[3].textContent.replace(/\s+/g, ' ').trim());
  check('mỗi dòng ghi đè có ô tick bỏ qua',
    tables[1].querySelectorAll('.skip-row').length === PREVIEW.updated.length);

  const confirmBtn = popup.querySelector('#confirmImport');
  check('nút xác nhận đếm đúng số bản ghi sẽ nạp',
    confirmBtn.textContent.includes('4'), confirmBtn.textContent.trim());
  popup.querySelector('.skip-row').checked = true;
  popup.querySelector('.skip-row').dispatchEvent(new w.Event('change', { bubbles: true }));
  check('tick bỏ qua thì số đếm giảm', confirmBtn.textContent.includes('3'), confirmBtn.textContent.trim());
  popup.querySelector('#skipAll').checked = true;
  popup.querySelector('#skipAll').dispatchEvent(new w.Event('change', { bubbles: true }));
  check('bỏ qua tất cả thì chỉ còn phần thêm mới',
    confirmBtn.textContent.includes('2'), confirmBtn.textContent.trim());
  popup.querySelector('#skipAll').checked = false;
  popup.querySelector('#skipAll').dispatchEvent(new w.Event('change', { bubbles: true }));
  popup.querySelectorAll('.skip-row')[1].checked = true;
  popup.querySelectorAll('.skip-row')[1].dispatchEvent(new w.Event('change', { bubbles: true }));
  confirmBtn.click();
  await new Promise(r => setTimeout(r, 120));
  const sent = calls.find(c => c.url === 'api/import/assets');
  check('xác nhận mới gửi ghi thật', Boolean(sent));
  check('gửi kèm đúng danh sách bỏ qua',
    sent && JSON.parse(sent.skip).join(',') === 'OLD-2', sent ? sent.skip : '(không có)');
  check('kết quả nói rõ đã bỏ qua mấy bản ghi',
    /bỏ qua 1 theo lựa chọn/.test($('importResult').textContent),
    $('importResult').textContent.trim().slice(0, 100));

  console.log(report.join('\n'));
  console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
  process.exit(report.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
}, 500);
