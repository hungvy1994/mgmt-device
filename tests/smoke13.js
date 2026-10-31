// Kiểm: nút Nhân bản trên thanh chọn, cột vị trí Site+Rack, bảng kho bỏ nút, nút edit nhỏ.
const fs = require('fs');
const { JSDOM, VirtualConsole } = require('jsdom');
const html = fs.readFileSync('index.html', 'utf8');
const data = JSON.parse(fs.readFileSync(process.argv[2] || 'api-data.json', 'utf8'));
// Kho có thể đang rỗng -> tự dựng một món để kiểm bảng kho.
if (!data.assetRows.some(a => String(a.in_store || '') === '1')) {
  data.assetRows.unshift({
    asset_id: 'KHO-KIEM-01', asset_name: 'Món trong kho', asset_type: 'server',
    usage_status: 'in_stock', in_store: '1', origin: 'manual',
  });
}
if (!data.assetTypes) data.assetTypes = [{ code: 'server', label: 'Server', note: '' }];
const rack = data.locations.find(l => l.kind === 'rack');
// đảm bảo có một máy nằm trong rack để kiểm cột vị trí
const placed = data.assetRows.find(a => a.rack) || Object.assign(data.assetRows[1], {
  datacenter: rack.site, rack: rack.rack, rack_id: rack.rackId, rack_unit: '12',
  rack_label: `${rack.room} · ${rack.rack}`, in_store: '',
});

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
  w.document.querySelector('[data-view="assets"]').click();

  // ---- 2. Cột vị trí: Site + Rack, không Room, chữ thường ----------------
  $('assetSearchFull').value = placed.asset_id;
  $('assetSearchFull').dispatchEvent(new w.Event('input', { bubbles: true }));
  const cell = $('assetRowsFull').rows[0].cells[5];
  check('vị trí hiện site và mã rack',
    cell.textContent.includes(placed.datacenter) && cell.textContent.includes(placed.rack),
    cell.textContent.trim());
  const room = (placed.rack_label || '').split(' · ')[0];
  check('không hiện tên phòng máy',
    !room || room === placed.rack || !cell.textContent.includes(room),
    `phòng "${room}" · ô: ${cell.textContent.trim()}`);
  check('phần rack không bị làm mờ', cell.querySelectorAll('.cell-inline').length === 0);

  // ---- 1. Nút Nhân bản trên thanh chọn nhiều ------------------------------
  $('assetRowsFull').querySelector('.row-select').click();
  const bar = $('assetRowsFullBulk');
  const clone = bar.querySelector('.bulk-clone');
  check('thanh chọn có nút Nhân bản', Boolean(clone), clone?.textContent.trim());
  check('nút Nhân bản đứng ngay sau nút Luân chuyển',
    bar.querySelector('.bulk-move').nextElementSibling === clone);
  check('chọn 1 mục thì nhân bản dùng được', !clone.disabled);
  clone.click();
  let modal = lastModal();
  check('bấm nhân bản mở form với mã để trống',
    modal.querySelector('[name="asset_id"]').value === ''
    && /Nhân bản từ/.test(modal.querySelector('.modal-head h2').textContent),
    modal.querySelector('.modal-head h2').textContent.trim());
  modal.querySelector('.modal-close').click();
  $('assetSearchFull').value = '';
  $('assetSearchFull').dispatchEvent(new w.Event('input', { bubbles: true }));
  [...$('assetRowsFull').querySelectorAll('.row-select')].filter(b => !b.checked).slice(0, 1)
    .forEach(b => b.click());
  // Nhân bản giờ chạy được với nhiều mục -> nút vẫn mở, chỉ báo rõ sẽ nhân bản mấy cái
  const many = $('assetRowsFullBulk').querySelector('.bulk-clone');
  check('chọn nhiều thì nút vẫn dùng được và cho biết số lượng',
    !many.disabled && /\d+ mục/.test(many.textContent), many.textContent.trim());

  // ---- 3. Bảng kho bỏ nút ở từng dòng ------------------------------------
  w.document.querySelector('[data-view="store"]').click();
  const storeTable = $('storeRows').closest('table');
  check('bảng kho còn 7 cột', storeTable.tHead.rows[0].cells.length === 7,
    `${storeTable.tHead.rows[0].cells.length} cột`);
  check('số col khai bằng số cột',
    storeTable.querySelectorAll('colgroup col').length === storeTable.tHead.rows[0].cells.length);
  const actionButtons = $('storeRows').querySelectorAll('.icon-button, .table-action, .move-out');
  check('không còn nút thao tác nào trên từng dòng kho', actionButtons.length === 0,
    `${actionButtons.length} nút thao tác`);
  check('vẫn mở được hồ sơ bằng cách bấm tên', (() => {
    $('storeRows').querySelector('.asset-link')?.click();
    return $('detailDrawer').classList.contains('open');
  })());
  $('closeDrawer').click();
  check('cột cuối là Vào kho',
    storeTable.tHead.rows[0].cells[6].textContent.trim() === 'Vào kho');

  // ---- 4. Nút edit nhỏ ở vị trí và cụm -----------------------------------
  w.document.querySelector('[data-view="locations"]').click();
  const locBtn = $('locationCrud').querySelector('.row-edit .icon-button');
  const locStyle = w.getComputedStyle(locBtn);
  check('nút edit danh mục vị trí 30x25px',
    locStyle.width === '30px' && locStyle.height === '25px',
    `${locStyle.width} x ${locStyle.height}`);
  const cluBtn = $('clusterList').querySelector('.row-edit .icon-button');
  check('danh mục cụm cũng gộp còn một nút edit', Boolean(cluBtn));
  const cluStyle = w.getComputedStyle(cluBtn);
  check('nút edit danh mục cụm cũng 30x25px',
    cluStyle.width === '30px' && cluStyle.height === '25px',
    `${cluStyle.width} x ${cluStyle.height}`);
  const cluWidths = [...$('clusterList').querySelectorAll('colgroup col')].map(c => c.style.width);
  check('cột nút của bảng cụm thu về 40px', cluWidths[cluWidths.length - 1] === '40px', cluWidths.join(' '));

  cluBtn.click();
  modal = lastModal();
  check('hộp thoại cụm có khối chi tiết', Boolean(modal.querySelector('.detail-box')),
    [...modal.querySelectorAll('.detail-box dt')].map(d => d.textContent.trim()).join(' | '));
  check('hộp thoại cụm sửa được ngay', Boolean(modal.querySelector('form [name="name"]')));
  check('hộp thoại cụm có nút Xóa', Boolean(modal.querySelector('.modal-danger')),
    modal.querySelector('.modal-danger')?.textContent.trim());
  const link = modal.querySelector('[data-modal-link]');
  if (link) {
    const name = link.dataset.modalLink;
    link.click();
    check('bấm xem tài sản của cụm thì lọc sẵn và chuyển màn',
      $('assetSearchFull').value === name && $('assetsView').classList.contains('active'),
      `tìm=${$('assetSearchFull').value}`);
  }

  console.log(report.join('\n'));
  console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
  process.exit(report.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
}, 500);
