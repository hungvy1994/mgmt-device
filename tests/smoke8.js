// Kiểm nút "Chuyển vào kho" ngay trong form luân chuyển.
const fs = require('fs');
const { JSDOM, VirtualConsole } = require('jsdom');

const html = fs.readFileSync('index.html', 'utf8');
const data = JSON.parse(fs.readFileSync(process.argv[2] || require('path').join(__dirname, 'fixture-move.json'), 'utf8'));

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
      calls.push({ url: u, method: o.method || 'GET', body: o.body && typeof o.body === 'string' ? JSON.parse(o.body) : null });
      return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(
        u === 'api/me' ? { username: 'admin', fullName: 'T', role: 'admin' }
          : u === 'api/data' ? data : u === 'api/imports' ? { imports: [] }
            : { moved: 3, devices: 1, parts: 2, location: 'Kho', status: 'in_stock', warehouse: true }) });
    };
    w.confirm = () => true;
    w.MGMT_DEVICE_DATA = { meta: {}, assetRows: [], historyRows: [] };
  },
});
const w = dom.window, $ = id => w.document.getElementById(id);
const report = [];
const check = (l, ok, d = '') => report.push(`${ok ? 'PASS' : 'FAIL'}  ${l}${d ? ' — ' + d : ''}`);
const lastModal = () => [...w.document.querySelectorAll('.modal-backdrop')].pop();

// Kho là cờ in_store trên tài sản, không phải một site nào cả.
const STORE_LABEL = 'Kho';
const target = data.assetRows.find(a => !a.parent_reference && !a.in_store
  && data.assetRows.some(o => o.parent_reference === a.asset_id));

function finish() {
  console.log(report.join('\n'));
  console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
  process.exit(report.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
}

setTimeout(async () => {
  w.document.querySelector('[data-view="assets"]').click();
  $('assetSearchFull').value = target.asset_id;
  $('assetSearchFull').dispatchEvent(new w.Event('input', { bubbles: true }));
  $('assetRowsFull').querySelector('[data-action="open"]').click();
  $('drawerTransfer').click();

  const form = lastModal().querySelector('form');
  const shortcut = form.querySelector('#transferToStore');
  check('form luân chuyển có nút Chuyển vào kho', Boolean(shortcut), shortcut?.textContent.trim());
  check('nút ghi rõ đích là kho', shortcut.textContent.includes('kho'), shortcut.textContent.trim());
  const kids = data.assetRows.filter(a => a.parent_reference === target.asset_id);
  check('chú thích nút nói rõ linh kiện đi kèm',
    shortcut.title.includes(String(kids.length)) && /Trong kho/.test(shortcut.title), shortcut.title);
  const subtitle = lastModal().querySelector('.modal-head p').textContent;
  check('phụ đề nói cả cụm sẽ sang trạng thái Trong kho',
    /cả thiết bị lẫn linh kiện đi kèm đều chuyển sang trạng thái Trong kho/.test(subtitle));

  // đang ở site thường, chưa phải kho
  check('trước khi bấm, đích vẫn là site hiện tại',
    form.querySelector('[name="datacenter"]').value !== '__store__',
    form.querySelector('[name="datacenter"]').value);

  shortcut.click();
  await new Promise(r => setTimeout(r, 120));

  const sent = calls.find(c => c.url === 'api/assets/transfer');
  check('bấm nút là gửi luân chuyển luôn, không phải bấm thêm Lưu', Boolean(sent));
  check('gửi đúng mã tài sản', sent && sent.body.ids.includes(target.asset_id),
    sent ? sent.body.ids.join(',') : '(không gửi)');
  check('đích là kho, không phải một site', sent && sent.body.in_store === '1' && !sent.body.datacenter,
    sent ? `in_store=${sent.body.in_store} datacenter=${sent.body.datacenter || '(trống)'}` : '');
  check('kèm trạng thái Trong kho', sent && sent.body.usage_status === 'in_stock', sent?.body.usage_status);
  check('bỏ hết phòng máy / rack / vị trí U',
    sent && !sent.body.room_id && !sent.body.rack_id && !sent.body.rack_unit,
    sent ? `room=${sent.body.room_id!==''?sent.body.room_id:'-'} rack=${sent.body.rack_id!==''?sent.body.rack_id:'-'} U=${sent.body.rack_unit!==''?sent.body.rack_unit:'-'}` : '');
  check('vẫn có ngày luân chuyển', sent && Boolean(sent.body.event_date), sent?.body.event_date);
  check('popup đóng sau khi gửi', !w.document.querySelector('.modal-backdrop form [name="datacenter"]'));

  // mở từ nút "Chuyển về kho" hàng loạt thì không nhân đôi nút
  w.document.querySelector('[data-view="assets"]').click();
  $('assetRowsFull').querySelector('.row-select').click();
  $('assetRowsFullBulk').querySelector('.bulk-store').click();
  check('mở sẵn ở chế độ về kho thì không thêm nút trùng',
    !lastModal().querySelector('#transferToStore'));

  finish();
}, 500);
