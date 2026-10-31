// Kiểm: màn Kho có đủ thao tác chọn như danh mục tài sản, và lịch sử sử dụng 3 dòng.
const fs = require('fs');
const { JSDOM, VirtualConsole } = require('jsdom');
const html = fs.readFileSync('index.html', 'utf8');
const data = JSON.parse(fs.readFileSync(process.argv[2] || require('path').join(__dirname, 'fixture-move.json'), 'utf8'));
if (!data.assetTypes) data.assetTypes = [{ code: 'server', label: 'Server', note: '' }];

const errors = [];
const vc = new VirtualConsole();
vc.on('jsdomError', e => errors.push(e.detail ? e.detail.stack : e.message));
vc.on('error', (...a) => errors.push(`console.error: ${a.join(' ')}`));
const calls = [];
const dom = new JSDOM(html, { runScripts: 'dangerously', pretendToBeVisual: true, virtualConsole: vc,
  url: 'http://localhost:8084/',
  beforeParse(w) {
    w.fetch = (u, o = {}) => { calls.push({ url: u, method: o.method || 'GET' });
      return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(
        u === 'api/me' ? { username: 'admin', fullName: 'T', role: 'admin' }
          : u === 'api/data' ? data : u === 'api/imports' ? { imports: [] } : { deleted: 1 }) }); };
    w.confirm = () => true;
    w.MGMT_DEVICE_DATA = { meta: {}, assetRows: [], historyRows: [] };
  } });
const w = dom.window, $ = id => w.document.getElementById(id);
const report = [];
const check = (l, ok, d = '') => report.push(`${ok ? 'PASS' : 'FAIL'}  ${l}${d ? ' — ' + d : ''}`);
const lastModal = () => [...w.document.querySelectorAll('.modal-backdrop')].pop();

setTimeout(async () => {
  // ---- 1. Kho: thao tác chọn giống danh mục tài sản ----------------------
  w.document.querySelector('[data-view="store"]').click();
  const wipe = $('deleteSelectedStore');
  check('màn Kho có nút Xóa trên thanh công cụ', Boolean(wipe));
  // Bố cục giống danh mục tài sản: ô tìm -> các ô lọc -> nút Xóa đứng cuối cùng hàng.
  const thanh = $('storeSearch').parentElement;
  check('nút Xóa nằm chung thanh công cụ với ô tìm kiếm', wipe.parentElement === thanh);
  check('nút Xóa đứng cuối hàng, sau các ô lọc', thanh.lastElementChild === wipe,
    [...thanh.children].map(n => n.id || n.tagName).join(' -> '));
  check('chưa chọn gì thì nút khóa', wipe.disabled === true, wipe.textContent.trim());

  $('storeRows').querySelector('.row-select').click();
  const bar = $('storeRowsBulk');
  const labels = [...bar.querySelectorAll('button')].map(b => b.textContent.trim());
  check('thanh chọn của Kho có đủ Luân chuyển / Nhân bản / Sửa',
    labels.some(l => /luân chuyển/i.test(l)) && labels.some(l => /nhân bản/i.test(l))
    && labels.some(l => /^Sửa/.test(l)), labels.join(' | '));
  check('nút Nhân bản đứng ngay sau nút Luân chuyển',
    bar.querySelector('.bulk-move').nextElementSibling === bar.querySelector('.bulk-clone'));
  check('chọn 1 thì nút Xóa mở khóa và đếm đúng',
    !wipe.disabled && wipe.textContent.includes('1'), wipe.textContent.trim());

  bar.querySelector('.bulk-clone').click();
  check('nhân bản từ màn Kho mở form với mã trống',
    lastModal().querySelector('[name="asset_id"]').value === ''
    && /Nhân bản từ/.test(lastModal().querySelector('.modal-head h2').textContent));
  lastModal().querySelector('.modal-close').click();

  wipe.click();
  await new Promise(r => setTimeout(r, 100));
  check('bấm Xóa ở màn Kho gọi POST /api/assets/bulk-delete',
    calls.some(c => c.url === 'api/assets/bulk-delete'));

  // ---- 2. Lịch sử sử dụng: 3 dòng, nút nhỏ ở cuối ------------------------
  w.document.querySelector('[data-view="assets"]').click();
  const withEvents = data.historyRows[0].asset_id;
  $('assetSearchFull').value = withEvents;
  $('assetSearchFull').dispatchEvent(new w.Event('input', { bubbles: true }));
  $('assetRowsFull').rows[0].querySelector('.asset-link').click();
  const item = $('drawerTimeline').querySelector('.timeline-item');
  check('mở được lịch sử của tài sản', Boolean(item));
  const body = item.querySelector('.timeline-body');
  check('mỗi sự kiện có phần nội dung và phần nút tách bạch',
    Boolean(body) && Boolean(item.querySelector('.timeline-tools')));
  const lines = [...body.children].filter(n => !n.classList.contains('flag-row'));
  check('nội dung gồm 3 dòng: ngày, vị trí, mô tả',
    body.querySelector('.timeline-date') && body.querySelectorAll('.timeline-line').length >= 2,
    `${body.children.length} dòng: ${[...body.children].map(n => n.className).join(' | ')}`);
  check('dòng đầu là ngày sự kiện',
    body.firstElementChild.classList.contains('timeline-date'),
    body.firstElementChild.textContent.trim());
  const tools = item.querySelector('.timeline-tools');
  check('hai nút nằm ở CUỐI item', item.lastElementChild === tools);
  const buttons = [...tools.querySelectorAll('button')];
  check('còn đúng hai nút', buttons.length === 2, buttons.map(b => b.textContent.trim()).join(' '));
  const size = w.getComputedStyle(buttons[0]);
  check('nút đã thu nhỏ', size.width === '26px' && size.height === '22px',
    `${size.width} x ${size.height}`);
  check('nút vẫn sửa được sự kiện', (() => {
    buttons[0].click();
    return Boolean(lastModal().querySelector('[name="event_date"]'));
  })());
  lastModal().querySelector('.modal-close').click();
  check('đối tượng sử dụng vẫn hiện, không bị mất',
    !data.historyRows.some(e => e.asset_id === withEvents && e.usage_object)
    || /timeline-aside/.test($('drawerTimeline').innerHTML),
    data.historyRows.find(e => e.asset_id === withEvents)?.usage_object || '(sự kiện này không có)');

  console.log(report.join('\n'));
  console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
  process.exit(report.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
}, 500);
