// Kiểm: ở 7 màn, ô tìm / ô lọc / nút thao tác nằm trong hàng công cụ (.toolbar-row) của khung
// nội dung chứ không ở topbar; màn Kho không còn ghi chú và danh sách cuộn trong khung.
const fs = require('fs');
const { JSDOM, VirtualConsole } = require('jsdom');
const html = fs.readFileSync('index.html', 'utf8');
const data = JSON.parse(fs.readFileSync('api-data.json', 'utf8'));
const errors = [];
const vc = new VirtualConsole();
vc.on('jsdomError', e => errors.push(e.detail ? e.detail.stack : e.message));
vc.on('error', (...a) => errors.push(`console.error: ${a.join(' ')}`));
const dom = new JSDOM(html, {
  runScripts: 'dangerously', pretendToBeVisual: true, virtualConsole: vc,
  url: 'http://localhost:8084/',
  beforeParse(w) {
    w.fetch = u => Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(
      u === 'api/me' ? { username: 'admin', fullName: 'T', role: 'admin' }
        : u === 'api/data' ? data : u === 'api/imports' ? { imports: [] } : { ok: true }) });
    w.confirm = () => true;
    w.MGMT_DEVICE_DATA = { meta: {}, assetRows: [], historyRows: [] };
  },
});
const w = dom.window, $ = id => w.document.getElementById(id);
const report = [];
const check = (l, ok, d = '') => report.push(`${ok ? 'PASS' : 'FAIL'}  ${l}${d ? ' — ' + d : ''}`);

// màn -> các điều khiển phải nằm trong hàng công cụ của khung nội dung
const VIEWS = {
  diagram: ['diagramExpand', 'diagramCollapse'],
  store: ['storeSearch', 'storeTypeFilter', 'storeStatusFilter', 'deleteSelectedStore'],
  types: ['typeSearch', 'newType'],
  statuses: ['statusSearch', 'newStatus'],
  exports: ['newExportTemplate'],
  admin: ['newUser'],
  assets: ['exportBtn', 'newAssetBtnFull', 'assetSearchFull', 'typeFilterFull', 'deleteSelected'],
};

setTimeout(() => {
  Object.entries(VIEWS).forEach(([view, ids]) => {
    const page = $(`${view}View`);
    const top = page.querySelector('.topbar');
    const inTop = [...top.querySelectorAll('input, select, button')].map(n => n.id || n.tagName);
    check(`${view}: topbar không còn ô lọc / nút`, inTop.length === 0, inTop.join(', '));
    const lac = ids.filter(id => !$(id) || !$(id).closest('.toolbar-row') || !page.contains($(id)));
    check(`${view}: điều khiển nằm trong hàng công cụ của khung`, lac.length === 0, lac.join(', ') || ids.join(', '));
    const lech = ids.filter(id => $(id) && $(id).closest('.toolbar-row')?.firstElementChild?.contains($(id)));
    check(`${view}: điều khiển đứng bên phải, tách khỏi tiêu đề`, lech.length === 0, lech.join(', '));
  });

  // Quy ước cũ vẫn giữ: ô tìm -> ô lọc -> nút Xóa đứng cuối nhóm
  ['assetSearchFull:deleteSelected', 'storeSearch:deleteSelectedStore'].forEach(pair => {
    const [search, del] = pair.split(':');
    const group = $(search).parentElement;
    check(`${del} đứng cuối nhóm lọc`, group.lastElementChild === $(del),
      [...group.children].map(n => n.id || n.tagName).join(' -> '));
  });

  // Hàng công cụ / thanh tab đứng NGOÀI khung nội dung ở các màn dạng khung chữ
  [['types', 'typeSearch'], ['statuses', 'statusSearch'], ['locations', 'locationSearch'],
   ['locations', 'clusterSearch']].forEach(([view, id]) => {
    check(`${view}: hàng công cụ (${id}) nằm ngoài khung nội dung`,
      Boolean($(id)?.closest('.toolbar-row')) && !$(id).closest('.section-page')
        && $(`${view}View`).contains($(id)));
  });
  check('Nhập/Xuất: thanh tab nằm ngoài khung nội dung',
    Boolean($('dataView').querySelector('.tabs')) && !$('dataView').querySelector('.tabs').closest('.section-page'));

  // Vị trí & Cụm: hai tab Site / Cụm, mỗi lúc chỉ hiện một
  w.document.querySelector('[data-view="locations"]').click();
  const tabs = [...$('locationsView').querySelectorAll('.tabs .tab')];
  check('Vị trí & Cụm có đúng 2 tab Site / Cụm', tabs.map(b => b.textContent.trim()).join('|') === 'Site|Cụm',
    tabs.map(b => b.textContent.trim()).join(' | '));
  check('mặc định mở tab Site, ẩn tab Cụm', !$('locationTabSite').hidden && $('locationTabCluster').hidden);
  check('tab Site chứa danh mục vị trí, tab Cụm chứa danh mục cụm',
    $('locationTabSite').contains($('locationCrud')) && $('locationTabCluster').contains($('clusterList')));
  tabs[1].click();
  check('bấm tab Cụm thì đổi panel', $('locationTabSite').hidden && !$('locationTabCluster').hidden
    && tabs[1].classList.contains('active'));
  tabs[0].click();

  // Bỏ đoạn mô tả đầu khung nội dung ở Vị trí, Loại tài sản, Trạng thái, Nhập/Xuất
  [['locationTabSite', 'Vị trí'], ['typesView', 'Loại tài sản'], ['statusesView', 'Trạng thái'],
   ['dataStore', 'Nhập/Xuất']].forEach(([id, label]) => {
    const page = $(id).querySelector('.section-page') || $(id).closest('.section-page') || $(id);
    const dau = page.querySelector(':scope > h2 + p, :scope > p:first-child');
    check(`${label}: không còn đoạn mô tả đầu khung`, !dau, dau ? dau.textContent.slice(0, 60) : '');
  });

  // Admin: hai tab Tài khoản / Sao lưu
  w.document.querySelector('[data-view="admin"]').click();
  const adminTabs = [...$('adminView').querySelectorAll('.tabs .tab')];
  check('Admin có đúng 2 tab Tài khoản / Sao lưu',
    adminTabs.map(b => b.textContent.trim()).join('|') === 'Tài khoản|Sao lưu', adminTabs.map(b => b.textContent.trim()).join(' | '));
  check('tab Tài khoản chứa danh sách tài khoản + nút thêm',
    $('adminTabUsers').contains($('userCrud')) && $('adminTabUsers').contains($('newUser')));
  check('tab Sao lưu chứa sao lưu + vùng nguy hiểm',
    $('adminTabBackup').contains($('backupPanel')) && $('adminTabBackup').contains($('wipeData')));
  check('mặc định mở tab Tài khoản', !$('adminTabUsers').hidden && $('adminTabBackup').hidden);
  adminTabs[1]?.click();
  check('bấm tab Sao lưu thì đổi panel', $('adminTabUsers').hidden && !$('adminTabBackup').hidden);
  adminTabs[0]?.click();

  // Vị trí & Cụm, Loại tài sản: bỏ tiêu đề trong khung, dòng tiêu đề bảng đứng yên khi cuộn
  check('Vị trí & Cụm: bỏ tiêu đề "Phân bố theo site" / "Cụm vận hành"',
    !/Phân bố theo site|Cụm vận hành/.test($('locationsView').textContent));
  ['locationCrud', 'clusterList', 'typeCrud'].forEach(id => {
    const th = $(id).querySelector('thead th');
    const wrap = $(id).querySelector(':scope > .table-wrap');
    check(`${id}: thead cố định khi cuộn`, Boolean(th) && w.getComputedStyle(th).position === 'sticky'
      && wrap && w.getComputedStyle(wrap).overflow === 'auto',
      th ? `${w.getComputedStyle(th).position} / ${wrap && w.getComputedStyle(wrap).overflow}` : '(không có bảng)');
  });

  // Mã tài sản viết hoa ở mọi màn (chỉ cách hiển thị — textContent giữ mã gốc)
  const ma = data.assetRows.find(a => a.asset_id && !a.code_pending && /[a-z]/.test(a.asset_id));
  if (ma) {
    w.document.querySelector('[data-view="assets"]').click();
    const o = [...$('assetRowsFull').querySelectorAll('.asset-id')][0];
    check('danh mục tài sản: mã hiển thị viết hoa', o && w.getComputedStyle(o).textTransform === 'uppercase');
    check('mã trong DOM giữ nguyên chữ gốc (tìm kiếm / liên kết không đổi)', o && o.textContent === o.textContent.trim()
      && data.assetRows.some(a => a.asset_id === o.textContent.trim()), o ? o.textContent : '');
    check('quy tắc viết hoa khai cho đủ các loại phần tử chứa mã',
      ['.ma', '.asset-id', '.asset-link.mono', '.node-name.mono'].every(sel => html.includes(sel)));
    check('chuỗi chữ thuần (tiêu đề, confirm) đi qua maHien()', /const codeOf = asset => [^;]*maHien\(asset\.id\)/.test(html));
  }

  check('màn Kho không còn ghi chú', !$('storeNote') && !$('storeView').querySelector('.tree-note'));
  check('màn Kho cao đúng cửa sổ, danh sách cuộn trong khung',
    /#storeView\.active[^{]*\{[^}]*height:\s*calc\(100vh/.test(html)
      && /#storeView \.table-panel \.table-wrap[^{]*\{[^}]*min-height:\s*0/.test(html));

  console.log(report.join('\n'));
  console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
  process.exit(report.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
}, 600);
