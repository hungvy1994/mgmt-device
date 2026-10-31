// Kiểm: đụng mã giữa hai nguồn KHÔNG bị gộp vào "ghi đè", và hộp xem trước nói rõ mất gì.
const fs = require('fs');
const path = require('path');
const { JSDOM, VirtualConsole } = require('jsdom');
const html = fs.readFileSync('index.html', 'utf8');
const data = JSON.parse(fs.readFileSync(process.argv[2] || 'api-data.json', 'utf8'));

// Bản xem trước giả lập đúng hình dạng API trả về khi có đụng mã
const preview = {
  kind: 'assets', fileType: 'csv', rows: 3, unchanged: 0, skippedUnknown: [],
  added: [{ key: 'moi-01', name: 'Ổ mới', summary: 'disk · Kho' }],
  updated: [{ key: 'cu-01', name: 'Máy cũ', changes: [{ field: 'asset_name', label: 'Tên', old: 'A', new: 'B' }] }],
  conflicts: [{
    key: 'ssd-240-001', name: 'Ổ cứng SSD 240GB', incoming: 'Ổ cứng 2.5" 240G Samsung',
    reason: 'mã này đang là «Ổ cứng SSD 240GB» lắp trong svr-p07-u23, nguồn host_772d.csv — file đang nhập có nguồn TỔNG HỢP',
  }],
};

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
      calls.push(String(u));
      return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(
        u === 'api/me' ? { username: 'admin', role: 'admin' } : u === 'api/data' ? data
          : u === 'api/imports' ? { imports: [] } : u === 'api/import/preview' ? preview : { ok: true }) });
    };
    w.confirm = () => true;
    w.MGMT_DEVICE_DATA = { meta: {}, assetRows: [], historyRows: [] };
  },
});
const w = dom.window;
const report = [];
const check = (l, ok, d = '') => report.push(`${ok ? 'PASS' : 'FAIL'}  ${l}${d ? ' — ' + d : ''}`);

setTimeout(async () => {
  // Gọi thẳng hộp xem trước với bản giả lập trên
  // Đi đúng đường người dùng: màn Dữ liệu -> chọn file -> bấm nạp -> hộp xem trước hiện ra
  w.document.querySelector('[data-view="data"]').click();
  const input = w.document.getElementById('assetCsvInput');
  const file = new w.File(['asset_id\n'], 'so-excel.csv', { type: 'text/csv' });
  Object.defineProperty(input, 'files', { value: [file], configurable: true });
  input.dispatchEvent(new w.Event('change', { bubbles: true }));
  w.document.getElementById('applyAssetImport').click();
  await new Promise(r => setTimeout(r, 120));
  const box = [...w.document.querySelectorAll('.modal-backdrop')].pop();
  check('chọn file rồi bấm nạp thì hiện hộp xem trước', Boolean(box));
  if (!box) { console.log(report.join('\n')); process.exit(1); }
  const text = box.textContent;

  check('có mục riêng cho đụng mã, không gộp vào ghi đè',
    /Đụng mã/.test(text) && /KHÔNG nạp/i.test(text), text.slice(0, 90).replace(/\s+/g, ' '));
  check('dòng tóm tắt đếm riêng số ca đụng mã',
    /1 đụng mã/.test(text), (text.match(/Đọc[^.]*\./) || [''])[0].slice(0, 110));
  check('nói rõ mã đó đang là tài sản nào và lắp ở đâu',
    text.includes('svr-p07-u23') && text.includes('Ổ cứng SSD 240GB'));
  check('nói rõ file đang muốn ghi cái gì vào', text.includes('240G Samsung'));
  check('giải thích cùng mã ở hai nguồn là hai vật khác nhau',
    /hai vật khác nhau/.test(text));

  // Đụng mã không được có ô tick "bỏ qua" — nó vốn đã không nạp, tick thêm là thừa và gây hiểu nhầm
  const rows = [...box.querySelectorAll('.mini-table tbody tr')];
  const conflictRow = rows.find(tr => tr.textContent.includes('svr-p07-u23'));
  check('dòng đụng mã không có ô tick bỏ qua',
    conflictRow && !conflictRow.querySelector('input[type="checkbox"]'));
  const ticks = [...box.querySelectorAll('.skip-row')];
  check('chỉ dòng ghi đè mới có ô tick', ticks.length === preview.updated.length,
    `${ticks.length} ô tick / ${preview.updated.length} dòng ghi đè`);

  const confirm = box.querySelector('#confirmImport');
  check('nút nạp chỉ đếm phần thật sự sẽ nạp, không tính đụng mã',
    /2 bản ghi/.test(confirm.textContent), confirm.textContent.trim());

  console.log(report.join('\n'));
  console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
  process.exit(report.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
}, 600);
