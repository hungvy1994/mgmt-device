// Kiểm bảng Vị trí & Cụm: bề rộng mới, một nút Edit gộp chi tiết + sửa + xoá.
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
    w.fetch = (u, o = {}) => { calls.push({ url: u, method: o.method || 'GET' });
      return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(
        u === 'api/me' ? { username: 'admin', fullName: 'T', role: 'admin' }
          : u === 'api/data' ? data : u === 'api/imports' ? { imports: [] } : { ok: true }) }); };
    w.confirm = () => true;
    w.MGMT_DEVICE_DATA = { meta: {}, assetRows: [], historyRows: [] };
  } });
const w = dom.window, $ = id => w.document.getElementById(id);
const report = [];
const check = (l, ok, d = '') => report.push(`${ok ? 'PASS' : 'FAIL'}  ${l}${d ? ' — ' + d : ''}`);
const lastModal = () => [...w.document.querySelectorAll('.modal-backdrop')].pop();

setTimeout(async () => {
  w.document.querySelector('[data-view="locations"]').click();
  const table = $('locationCrud').querySelector('table');
  const widths = [...table.querySelectorAll('colgroup col')].map(c => c.style.width);
  check('bề rộng đúng bộ số mới',
    widths.join(' ') === '15% 9% 15% 10% 10% 10% 10% 40px', widths.join(' '));

  const rows = [...table.tBodies[0].rows];
  check('mỗi dòng chỉ còn MỘT nút',
    rows.every(r => r.lastElementChild.querySelectorAll('button').length === 1),
    `${rows[0].lastElementChild.querySelectorAll('button').length} nút/dòng`);
  check('không còn nút Xem / Sửa / Xóa rời',
    !table.querySelector('.view-site, .delete-location') && Boolean(table.querySelector('.edit-location')));

  // site có tài sản -> mở Edit xem đủ chi tiết
  const siteRow = rows.find(r => r.cells[1].textContent.trim() === 'Site'
    && Number(r.cells[4].textContent.replace(/\D/g, '')) > 0);
  siteRow.querySelector('.edit-location').click();
  const modal = lastModal();
  check('bấm Edit mở hộp thoại có khối chi tiết', Boolean(modal.querySelector('.detail-box')));
  const labels = [...modal.querySelectorAll('.detail-box dt')].map(d => d.textContent.trim());
  check('chi tiết đủ cấp, thuộc, số tài sản',
    ['Cấp', 'Thuộc', 'Tài sản', 'Đang vận hành', 'Cần chú ý'].every(l => labels.includes(l)),
    labels.join(' | '));
  const total = siteRow.cells[4].textContent.trim();
  const shown = [...modal.querySelectorAll('.detail-box dd')].map(d => d.textContent.trim());
  check('số tài sản trong chi tiết khớp với bảng', shown.includes(total), `${shown.join(' | ')} / bảng ${total}`);
  check('vẫn sửa được ngay trong hộp thoại đó',
    Boolean(modal.querySelector('form [name="siteName"]')));
  check('có nút Xóa ngay trong hộp thoại', Boolean(modal.querySelector('.modal-danger')),
    modal.querySelector('.modal-danger')?.textContent.trim());
  check('có lối xem tài sản của site', Boolean(modal.querySelector('[data-modal-link]')),
    modal.querySelector('[data-modal-link]')?.textContent.trim());

  // bấm xem tài sản -> nhảy sang danh mục đã lọc sẵn
  const site = modal.querySelector('[data-modal-link]').dataset.modalLink;
  modal.querySelector('[data-modal-link]').click();
  check('bấm xem tài sản thì lọc sẵn theo site và chuyển màn',
    $('siteFilterFull').value === site && $('assetsView').classList.contains('active'),
    `lọc=${$('siteFilterFull').value}`);

  // nút Xóa trong hộp thoại gọi đúng API
  w.document.querySelector('[data-view="locations"]').click();
  const rackRow = [...$('locationCrud').querySelectorAll('tbody tr')]
    .find(r => r.cells[1].textContent.trim() === 'Rack');
  rackRow.querySelector('.edit-location').click();
  lastModal().querySelector('.modal-danger').click();
  await new Promise(r => setTimeout(r, 80));
  check('bấm Xóa trong hộp thoại gọi DELETE /api/locations/<mã>',
    calls.some(c => c.url.startsWith('api/locations/') && c.method === 'DELETE'),
    calls.filter(c => c.url.includes('locations')).map(c => `${c.method} ${c.url}`).join(' | ') || '(không gọi)');
  check('hộp thoại đóng sau khi xóa', !w.document.querySelector('.modal-backdrop'));

  console.log(report.join('\n'));
  console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
  process.exit(report.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
}, 500);
