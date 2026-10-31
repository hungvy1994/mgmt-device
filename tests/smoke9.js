// Kiểm: danh mục Loại tài sản, và cách hiển thị danh sách item.
const fs = require('fs');
const { JSDOM, VirtualConsole } = require('jsdom');

const html = fs.readFileSync('index.html', 'utf8');
const data = JSON.parse(fs.readFileSync(process.argv[2] || 'api-data.json', 'utf8'));
// Cần một bản ghi vừa đứng trong rack vừa mang tên cụm để kiểm cột Vị trí bỏ cụm.
if (!data.assetRows.some(a => a.rack_label && a.cluster)) {
  const inRack = data.assetRows.find(a => a.rack_label) || {};
  data.assetRows.unshift(Object.assign({}, inRack, {
    asset_id: 'VITRI-CUM-01', asset_name: 'Máy có cụm', cluster: 'Cụm kiểm thử', origin: 'manual',
  }));
}
if (!data.assetTypes) {
  // fixture cũ chưa có danh mục loại -> dựng từ chính dữ liệu để chạy được
  data.assetTypes = [...new Set(data.assetRows.map(a => a.asset_type).filter(Boolean))]
    .map(code => ({ code, label: code === 'server' ? 'Server' : code, note: '' }));
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
          : u === 'api/data' ? data : u === 'api/imports' ? { imports: [] } : { ok: true, movedAssets: 0 }) });
    };
    w.confirm = () => true;
    w.MGMT_DEVICE_DATA = { meta: {}, assetRows: [], historyRows: [] };
  },
});
const w = dom.window, $ = id => w.document.getElementById(id);
const report = [];
const check = (l, ok, d = '') => report.push(`${ok ? 'PASS' : 'FAIL'}  ${l}${d ? ' — ' + d : ''}`);
const lastModal = () => [...w.document.querySelectorAll('.modal-backdrop')].pop();
const opts = s => [...s.options].map(o => o.label);

setTimeout(async () => {
  // ---- 1. Danh mục Loại tài sản -----------------------------------------
  check('có mục Loại tài sản trên thanh điều hướng',
    Boolean(w.document.querySelector('[data-view="types"]')));
  w.document.querySelector('[data-view="types"]').click();
  const rows = [...$('typeCrud').querySelectorAll('tbody tr')];
  check('liệt kê đủ loại trong danh mục', rows.length === data.assetTypes.length,
    `${rows.length} dòng / ${data.assetTypes.length} loại`);
  const head = [...$('typeCrud').querySelectorAll('thead th')].map(t => t.textContent.trim());
  check('bảng có mã, tên, ghi chú, số tài sản',
    head.filter(Boolean).join(' | ') === 'Mã | Tên hiển thị | Ghi chú | Tài sản',
    head.filter(Boolean).join(' | '));
  const serverRow = rows.find(r => r.cells[0].textContent.trim() === 'server');
  const realCount = data.assetRows.filter(a => a.asset_type === 'server').length;
  check('đếm đúng số tài sản mỗi loại',
    serverRow.cells[3].textContent.trim() === realCount.toLocaleString('vi-VN'),
    `${serverRow.cells[3].textContent.trim()} / ${realCount}`);
  check('bảng loại sắp xếp được', Boolean($('typeCrud').querySelector('thead th').dataset.sort));

  $('newType').click();
  let form = lastModal().querySelector('form');
  check('form thêm loại có mã, tên, ghi chú',
    ['code', 'label', 'note'].every(n => form.querySelector(`[name="${n}"]`)));
  form.querySelector('[name="code"]').value = 'ups';
  form.querySelector('[name="label"]').value = 'Bộ lưu điện';
  form.dispatchEvent(new w.Event('submit', { bubbles: true, cancelable: true }));
  await new Promise(r => setTimeout(r, 80));
  const created = calls.find(c => c.url === 'api/asset-types' && c.method === 'POST');
  check('thêm loại gọi POST /api/asset-types', Boolean(created),
    created ? JSON.stringify(created.body) : '(không gọi)');

  $('typeCrud').querySelector('.edit-type').click();
  form = lastModal().querySelector('form');
  form.querySelector('[name="label"]').value = 'Máy chủ';
  form.dispatchEvent(new w.Event('submit', { bubbles: true, cancelable: true }));
  await new Promise(r => setTimeout(r, 80));
  check('sửa loại gọi PUT /api/asset-types/<mã>',
    calls.some(c => c.url.startsWith('api/asset-types/') && c.method === 'PUT'));
  $('typeCrud').querySelector('.delete-type').click();
  await new Promise(r => setTimeout(r, 80));
  check('xóa loại gọi DELETE /api/asset-types/<mã>',
    calls.some(c => c.url.startsWith('api/asset-types/') && c.method === 'DELETE'));

  // form tài sản lấy loại từ danh mục, không phải bảng cứng
  w.document.querySelector('[data-view="assets"]').click();
  $('newAssetBtnFull').click();
  const typeSelect = lastModal().querySelector('[name="asset_type"]');
  check('form tài sản lấy loại từ danh mục',
    data.assetTypes.every(t => opts(typeSelect).includes(t.label)),
    `${typeSelect.options.length} lựa chọn`);
  lastModal().querySelector('.modal-close').click();

  // ---- 2. Hiển thị danh sách item ---------------------------------------
  const table = $('assetRowsFull').closest('table');
  const widths = [...table.querySelectorAll('colgroup col')].map(c => c.style.width);
  check('mọi cột vẫn khai bề rộng', widths.every(Boolean), widths.join(' '));

  const idCell = $('assetRowsFull').rows[0].cells[2];
  const idStyle = w.getComputedStyle(idCell.querySelector('.asset-id'));
  check('mã tài sản không còn bị làm mờ',
    idStyle.color !== 'rgb(119, 131, 126)' && !/var\(--muted\)/.test(idStyle.color),
    `màu ${idStyle.color}, đậm ${idStyle.fontWeight}`);

  // thiết bị cha: có thì hiện, không có thì để trống hẳn
  const noParent = data.assetRows.find(a => !a.parent_reference);
  $('assetSearchFull').value = noParent.asset_id;
  $('assetSearchFull').dispatchEvent(new w.Event('input', { bubbles: true }));
  const emptyCell = $('assetRowsFull').rows[0].cells[6];
  check('không có thiết bị cha thì ô để trống, không hiện Null',
    emptyCell.textContent.trim() === '', `«${emptyCell.textContent.trim()}»`);
  const withParent = data.assetRows.find(a => a.parent_reference);
  $('assetSearchFull').value = withParent.asset_id;
  $('assetSearchFull').dispatchEvent(new w.Event('input', { bubbles: true }));
  const parentCell = $('assetRowsFull').rows[0].cells[6];
  check('có thiết bị cha thì vẫn hiện',
    parentCell.textContent.trim() === withParent.parent_reference, parentCell.textContent.trim());

  // vị trí = site + rack, không kèm cụm
  const withRack = data.assetRows.find(a => a.rack_label && a.cluster);
  if (withRack) {
    $('assetSearchFull').value = withRack.asset_id;
    $('assetSearchFull').dispatchEvent(new w.Event('input', { bubbles: true }));
    const place = $('assetRowsFull').rows[0].cells[5].textContent.trim();
    check('vị trí hiện site + mã rack, không kèm cụm cũng không kèm phòng máy',
      place.includes(withRack.datacenter) && place.includes(withRack.rack)
      && !place.includes(withRack.cluster), place);
  } else {
    const withCluster = data.assetRows.find(a => a.cluster && a.datacenter);
    $('assetSearchFull').value = withCluster.asset_id;
    $('assetSearchFull').dispatchEvent(new w.Event('input', { bubbles: true }));
    const place = $('assetRowsFull').rows[0].cells[5].textContent.trim();
    check('vị trí không còn kèm cụm',
      place.includes(withCluster.datacenter) && !place.includes(withCluster.cluster),
      `${place} (cụm ${withCluster.cluster})`);
  }

  console.log(report.join('\n'));
  console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
  process.exit(report.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
}, 500);
