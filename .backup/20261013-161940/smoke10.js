// Kiểm danh mục tài sản: bỏ cột nút, nút xoá cạnh bộ lọc, bảng cuộn trong khung.
const fs = require('fs');
const { JSDOM, VirtualConsole } = require('jsdom');

const html = fs.readFileSync('index.html', 'utf8');
const data = JSON.parse(fs.readFileSync(process.argv[2] || 'api-data.json', 'utf8'));
if (!data.assetTypes) {
  data.assetTypes = [...new Set(data.assetRows.map(a => a.asset_type).filter(Boolean))]
    .map(code => ({ code, label: code, note: '' }));
}

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
          : u === 'api/data' ? data : u === 'api/imports' ? { imports: [] } : { deleted: 2 }) });
    };
    w.confirm = () => true;
    w.MGMT_DEVICE_DATA = { meta: {}, assetRows: [], historyRows: [] };
  },
});
const w = dom.window, $ = id => w.document.getElementById(id);
const report = [];
const check = (l, ok, d = '') => report.push(`${ok ? 'PASS' : 'FAIL'}  ${l}${d ? ' — ' + d : ''}`);

setTimeout(async () => {
  w.document.querySelector('[data-view="assets"]').click();
  const table = $('assetRowsFull').closest('table');

  // ---- 1. Bỏ cột nút -----------------------------------------------------
  const heads = [...table.tHead.rows[0].cells];
  check('bảng còn 8 cột, không còn cột nút', heads.length === 8,
    `${heads.length} cột: ${heads.map(h => h.textContent.trim() || '(trống)').join(' | ')}`);
  check('cột cuối là Ngày sử dụng', heads[heads.length - 1].textContent.trim() === 'Ngày sử dụng',
    heads[heads.length - 1].textContent.trim());
  check('số col khai bằng số cột',
    table.querySelectorAll('colgroup col').length === heads.length,
    `${table.querySelectorAll('colgroup col').length} col`);
  const firstRow = $('assetRowsFull').rows[0];
  check('mỗi dòng cũng còn 8 ô', firstRow.cells.length === 8, `${firstRow.cells.length} ô`);
  check('không còn nút Xóa trong bảng',
    $('assetRowsFull').querySelectorAll('[data-action="delete"]').length === 0);
  check('không còn nút mũi tên mở hồ sơ trong bảng',
    $('assetRowsFull').querySelectorAll('.icon-button').length === 0);
  check('vẫn mở được hồ sơ bằng cách bấm tên', (() => {
    firstRow.querySelector('.asset-link').click();
    return $('detailDrawer').classList.contains('open');
  })());
  $('closeDrawer').click();

  // ---- 2. Nút xoá cạnh bộ lọc site ---------------------------------------
  const wipe = $('deleteSelected');
  check('có nút Xóa trên thanh lọc', Boolean(wipe));
  // Ý định của yêu cầu: nút Xóa nằm cuối hàng lọc, sau MỌI ô lọc — không phải dính cứng
  // vào ô lọc site, vì hàng lọc còn được thêm ô mới về sau.
  const thanh = $('siteFilterFull').parentElement;
  check('nút Xóa nằm chung thanh lọc', wipe.parentElement === thanh);
  check('nút Xóa đứng cuối hàng, sau tất cả ô lọc', thanh.lastElementChild === wipe,
    [...thanh.children].map(n => n.id || n.tagName).join(' -> '));
  check('chưa chọn gì thì nút bị khóa', wipe.disabled === true, wipe.textContent.trim());
  check('nút chỉ cách dùng khi chưa chọn', /Tick chọn/.test(wipe.title), wipe.title);

  const boxes = [...$('assetRowsFull').querySelectorAll('.row-select')].slice(0, 2);
  boxes.forEach(box => box.click());
  check('chọn 2 mục thì nút mở khóa và đếm đúng',
    !wipe.disabled && wipe.textContent.includes('2'), wipe.textContent.trim());
  const ids = boxes.map(b => b.dataset.id);
  wipe.click();
  await new Promise(r => setTimeout(r, 100));
  const sent = calls.find(c => c.url === 'api/assets/bulk-delete');
  check('bấm xóa gọi POST /api/assets/bulk-delete', Boolean(sent));
  check('gửi đúng các mã đang chọn',
    sent && ids.every(id => sent.body.ids.includes(id)) && sent.body.ids.length === 2,
    sent ? sent.body.ids.join(', ') : '(không gửi)');
  check('xóa xong thì nút khóa lại', $('deleteSelected').disabled === true);

  // ---- 3. Bảng cuộn trong khung ------------------------------------------
  const wrap = $('assetRowsFull').closest('.table-wrap');
  const style = w.getComputedStyle(wrap);
  // jsdom tính sẵn calc() ra px theo chiều cao cửa sổ -> đối chiếu bằng phép tính
  const capped = parseFloat(style.maxHeight);
  check('khung bảng cao theo màn hình (100vh trừ phần cố định)',
    Math.abs(capped - (w.innerHeight - 330)) < 1,
    `${style.maxHeight} với cửa sổ cao ${w.innerHeight}px`);
  check('thừa dòng thì cuộn trong khung', style.overflow === 'auto' || style.overflowY === 'auto',
    `overflow=${style.overflow || style.overflowY}`);
  const headStyle = w.getComputedStyle(table.tHead.rows[0].cells[1]);
  check('tiêu đề cột dính lại khi cuộn', headStyle.position === 'sticky', headStyle.position);
  check('thanh lọc và phân trang nằm ngoài vùng cuộn',
    !wrap.contains($('assetRowsFullPager')) && !wrap.contains($('siteFilterFull')));

  console.log(report.join('\n'));
  console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
  process.exit(report.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
}, 500);
