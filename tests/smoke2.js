// Kiểm hai việc mới: (1) Site/Rack/Cụm/Trạng thái là ô chọn lấy từ danh mục,
// (2) danh mục tài sản gọn + có cột thiết bị cha + chọn được số dòng mỗi trang.
const fs = require('fs');
const { JSDOM, VirtualConsole } = require('jsdom');

const html = fs.readFileSync('index.html', 'utf8');
const data = JSON.parse(fs.readFileSync('api-data.json', 'utf8'));
// Dữ liệu thật có thể đã khớp hết cha-con -> tự dựng một nhãn cụm chưa khớp mã.
if (!data.assetRows.some(r => r.parent_reference && !data.assetRows.some(o => o.asset_id === r.parent_reference))) {
  data.assetRows.unshift({
    asset_id: 'NHAN-CUM-01', asset_name: 'Máy mang nhãn cụm', asset_type: 'server',
    usage_status: 'in_use', parent_reference: 'Cụm chưa khớp mã nào', origin: 'manual',
  });
}

const errors = [];
const vc = new VirtualConsole();
vc.on('jsdomError', e => errors.push(`jsdomError: ${e.message}`));
vc.on('error', (...a) => errors.push(`console.error: ${a.join(' ')}`));

const calls = [];
function fakeFetch(url, options = {}) {
  const method = options.method || 'GET';
  calls.push(`${method} ${url}`);
  const reply = body => Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(body) });
  if (url === 'api/me') return reply({ username: 'admin', fullName: 'Test', role: 'admin' });
  if (url === 'api/data') return reply(data);
  if (url === 'api/imports') return reply({ imports: [] });
  return reply({ ok: true, updated: 1, deleted: 1, movedAssets: 0 });
}

const dom = new JSDOM(html, {
  runScripts: 'dangerously', pretendToBeVisual: true, virtualConsole: vc,
  url: 'http://localhost:8084/',
  beforeParse(window) {
    window.fetch = fakeFetch;
    window.confirm = () => true;
    window.MGMT_DEVICE_DATA = { meta: {}, assetRows: [], historyRows: [] };
  },
});
const w = dom.window, $ = id => w.document.getElementById(id);
const report = [];
const check = (label, ok, detail = '') => report.push(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? ' — ' + detail : ''}`);
const opts = select => [...select.options].map(o => o.label);

setTimeout(() => {
  w.document.querySelector('[data-view="assets"]').click();

  // ---- (2) Danh mục tài sản ------------------------------------------------
  const head = [...w.document.querySelectorAll('#assetsView thead th')].map(th => th.textContent.trim());
  check('bảng có cột Thiết bị cha', head.includes('Thiết bị cha'), head.filter(Boolean).join(' | '));
  check('bảng ở chế độ gọn', w.document.querySelector('#assetsView table').classList.contains('compact'));
  const firstRow = w.document.querySelector('#assetRowsFull tr');
  check('số ô trong dòng khớp số cột', firstRow.querySelectorAll('td').length === head.length,
    `${firstRow.querySelectorAll('td').length} ô / ${head.length} cột`);
  check('dòng không còn khối phụ nhiều tầng', firstRow.querySelectorAll('.cell-sub').length === 0);

  // Thiết bị cha: bản ghi khớp mã -> nút mở được; nhãn chưa khớp -> chữ nghiêng mờ, vẫn hiện
  const withParentId = data.assetRows.find(r => r.parent_reference && data.assetRows.some(o => o.asset_id === r.parent_reference));
  const withLabel = data.assetRows.find(r => r.parent_reference && !data.assetRows.some(o => o.asset_id === r.parent_reference));
  $('assetSearchFull').value = withLabel.asset_id;
  $('assetSearchFull').dispatchEvent(new w.Event('input', { bubbles: true }));
  const labelCell = w.document.querySelector('#assetRowsFull tr td:nth-child(7)');
  check('nhãn cụm chưa khớp vẫn hiện, không bị ép thành cha-con',
    labelCell.querySelector('.cell-unmatched') && labelCell.textContent.includes(withLabel.parent_reference),
    labelCell.textContent.trim());
  if (withParentId) {
    $('assetSearchFull').value = withParentId.asset_id;
    $('assetSearchFull').dispatchEvent(new w.Event('input', { bubbles: true }));
    const parentCell = w.document.querySelector('#assetRowsFull tr td:nth-child(7)');
    check('mã cha đã khớp là nút mở hồ sơ',
      parentCell.querySelector('button[data-action="open"]')?.dataset.id === withParentId.parent_reference,
      parentCell.textContent.trim());
  } else {
    check('mã cha đã khớp là nút mở hồ sơ', true, 'dữ liệu không có ca nào khớp mã — bỏ qua');
  }
  $('assetSearchFull').value = '';
  $('assetSearchFull').dispatchEvent(new w.Event('input', { bubbles: true }));

  // Chọn số dòng mỗi trang
  const sizeSelect = $('assetRowsFullPageSize');
  check('phân trang có ô chọn số dòng', Boolean(sizeSelect), sizeSelect ? opts(sizeSelect).join('/') : '(không có)');
  // Số dòng hiện = min(cỡ trang, tổng số bản ghi) — kiểm theo công thức đó, đừng gõ cứng
  // con số, vì bộ dữ liệu kiểm thử có thể nhỏ hơn cỡ trang.
  const tong = data.assetRows.length;
  const dem = () => w.document.querySelectorAll('#assetRowsFull tr').length;
  check('mặc định 20 dòng mỗi trang', dem() === Math.min(20, tong), `${dem()} dòng / ${tong} bản ghi`);
  sizeSelect.value = '50';
  sizeSelect.dispatchEvent(new w.Event('change', { bubbles: true }));
  check('chọn 50 thì hiện tối đa 50 dòng', dem() === Math.min(50, tong), `${dem()} dòng / ${tong} bản ghi`);
  // pager được dựng lại sau mỗi lần đổi -> phải lấy lại đúng node mới
  const sizeSelectAgain = $('assetRowsFullPageSize');
  check('ô chọn giữ đúng giá trị sau khi render lại', sizeSelectAgain.value === '50', sizeSelectAgain.value);
  sizeSelectAgain.value = '10';
  sizeSelectAgain.dispatchEvent(new w.Event('change', { bubbles: true }));
  check('chọn 10 thì hiện 10 dòng', w.document.querySelectorAll('#assetRowsFull tr').length === 10,
    `${w.document.querySelectorAll('#assetRowsFull tr').length} dòng`);

  // ---- (1) Form tài sản: ô chọn -------------------------------------------
  $('newAssetBtnFull').click();
  const form = w.document.querySelector('.modal-backdrop form');
  const site = form.querySelector('[name="datacenter"]');
  const rack = form.querySelector('[name="rack_id"]');
  const cluster = form.querySelector('[name="cluster"]');
  const status = form.querySelector('[name="usage_status"]');
  check('Site là ô chọn', site?.tagName === 'SELECT', site ? `${site.options.length} lựa chọn` : '(không phải select)');
  check('Rack là ô chọn', rack?.tagName === 'SELECT');
  check('Cụm là ô chọn', cluster?.tagName === 'SELECT', cluster ? `${cluster.options.length - 1} cụm` : '');
  check('Trạng thái là ô chọn', status?.tagName === 'SELECT');
  check('Site lấy đúng danh mục vị trí',
    data.locations.filter(l => l.kind !== 'rack').every(l => opts(site).includes(l.site)), opts(site).join(', '));
  check('Cụm lấy đúng danh mục cụm',
    data.clusters.every(c => opts(cluster).includes(c.name)));
  check('Trạng thái lấy đúng danh mục trạng thái',
    data.statuses.every(s => opts(status).includes(s.label)));

  // Rack lọc theo site
  const rackRow = data.locations.find(l => l.kind === 'rack');
  if (rackRow) {
    site.value = rackRow.site;
    site.dispatchEvent(new w.Event('change', { bubbles: true }));
    check(`chọn site ${rackRow.site} thì rack hiện đúng`, opts(rack).some(o => o.includes(rackRow.rack)), opts(rack).join(' | '));
    const otherSite = data.locations.find(l => l.kind !== 'rack' && l.site !== rackRow.site).site;
    site.value = otherSite;
    site.dispatchEvent(new w.Event('change', { bubbles: true }));
    check(`chọn site ${otherSite} thì rack của site khác biến mất`,
      !opts(rack).some(o => o.includes(rackRow.rack)) && rack.value === '', opts(rack).join(' | '));
  }
  w.document.querySelector('.modal-backdrop .modal-close').click();

  // ---- Form vị trí ba cấp: cấp con CHỌN cấp cha ---------------------------
  w.document.querySelector('[data-view="locations"]').click();
  const kindsSeen = [...w.document.querySelectorAll('#locationCrud tbody tr')]
    .map(tr => tr.children[1].textContent.trim());
  check('bảng vị trí liệt kê đủ ba cấp',
    ['Site', 'Phòng máy', 'Rack'].every(k => kindsSeen.includes(k)), [...new Set(kindsSeen)].join(', '));

  $('newLocation').click();
  const locForm = w.document.querySelector('.modal-backdrop form');
  const shown = () => [...locForm.querySelectorAll('[data-field]')]
    .filter(n => !n.classList.contains('hidden')).map(n => n.dataset.field);
  const kindSelect = locForm.querySelector('[name="kind"]');
  check('form vị trí có ô chọn cấp', opts(kindSelect).join('/') === 'Site / Datacenter/Phòng máy/Rack', opts(kindSelect).join('/'));
  // Kho không còn là một loại site -> form site không còn ô "Loại site"
  check('cấp Site: chỉ hiện ô của site', shown().join(',') === 'kind,siteName,status', shown().join(','));

  kindSelect.value = 'room';
  kindSelect.dispatchEvent(new w.Event('change', { bubbles: true }));
  check('cấp Phòng máy: hiện ô của phòng', shown().join(',') === 'kind,site,room,roomName', shown().join(','));
  check('Phòng máy chọn site từ danh sách, không gõ',
    locForm.querySelector('[name="site"]').tagName === 'SELECT'
    && data.locations.filter(l => l.kind === 'location').every(l => opts(locForm.querySelector('[name="site"]')).includes(l.site)));

  kindSelect.value = 'rack';
  kindSelect.dispatchEvent(new w.Event('change', { bubbles: true }));
  check('cấp Rack: hiện ô của rack', shown().join(',') === 'kind,site,roomId,rack,heightU,status', shown().join(','));
  const locSite = locForm.querySelector('[name="site"]');
  const locRoom = locForm.querySelector('[name="roomId"]');
  check('Rack chọn phòng máy từ danh sách, không gõ', locRoom.tagName === 'SELECT');
  // Phải chọn phòng có mã riêng biệt: mã "—" trùng chữ với mục "— Chưa xếp phòng —",
  // còn mã trùng ở hai site thì không chứng minh được việc lọc.
  const allRooms = data.locations.filter(l => l.kind === 'room');
  const roomRow = allRooms.find(r => r.room !== '—'
    && allRooms.filter(o => o.room === r.room).length === 1
    && data.locations.some(l => l.kind === 'location' && l.site !== r.site));
  if (roomRow) {
    locSite.value = roomRow.site;
    locSite.dispatchEvent(new w.Event('change', { bubbles: true }));
    check(`chọn site ${roomRow.site} thì phòng máy của site đó hiện ra`,
      opts(locRoom).some(o => o.includes(roomRow.room)), opts(locRoom).join(' | '));
    const elsewhere = data.locations.find(l => l.kind === 'location' && l.site !== roomRow.site).site;
    locSite.value = elsewhere;
    locSite.dispatchEvent(new w.Event('change', { bubbles: true }));
    check(`chọn site ${elsewhere} thì phòng của site khác biến mất`,
      !opts(locRoom).some(o => o.includes(roomRow.room)), opts(locRoom).join(' | '));
  }
  locForm.querySelector('[name="rack"]').value = 'R-SMOKE';
  locForm.dispatchEvent(new w.Event('submit', { bubbles: true, cancelable: true }));
  check('lưu rack gửi POST /api/locations', calls.includes('POST api/locations'));

  // ---- Template XLSX ------------------------------------------------------
  w.document.querySelector('[data-view="data"]').click();
  check('trang Nhập/Xuất có nút tải template', Boolean($('downloadTemplate')));

  // ---- Danh mục cụm quản lý tập trung -------------------------------------
  w.document.querySelector('[data-view="locations"]').click();
  check('trang Vị trí & Cụm có nút Thêm cụm', Boolean($('newCluster')));
  check('bảng cụm liệt kê theo danh mục',
    data.clusters.every(c => $('clusterList').textContent.includes(c.name)));
  $('clusterList').querySelector('.edit-cluster').click();
  // form vị trí đóng sau khi await xong, nên phải lấy modal MỚI NHẤT chứ không phải cái đầu
  const openForms = [...w.document.querySelectorAll('.modal-backdrop form')];
  const clusterForm = openForms[openForms.length - 1];
  clusterForm.querySelector('[name="name"]').value = 'MBO';
  clusterForm.dispatchEvent(new w.Event('submit', { bubbles: true, cancelable: true }));
  setTimeout(() => {
    check('sửa cụm gọi PUT /api/clusters/<tên>', calls.some(c => c.startsWith('PUT api/clusters/')),
      calls.filter(c => c.includes('clusters')).join(' | ') || '(không gọi)');
    // Ba nút của bảng cụm đã gộp thành một nút edit; nút Xóa nằm TRONG hộp thoại đó.
    $('clusterList').querySelector('.edit-cluster').click();
    [...w.document.querySelectorAll('.modal-backdrop')].pop().querySelector('.modal-danger').click();
    setTimeout(() => {
      check('xóa cụm gọi DELETE /api/clusters/<tên>', calls.some(c => c.startsWith('DELETE api/clusters/')));
      console.log(report.join('\n'));
      console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
      process.exit(report.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
    }, 60);
  }, 60);
}, 400);
