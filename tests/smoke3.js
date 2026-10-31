// Kiểm ba việc: thứ tự danh mục vị trí, bộ lọc ở danh mục tài sản, và sơ đồ hạ tầng.
const fs = require('fs');
const { JSDOM, VirtualConsole } = require('jsdom');

const html = fs.readFileSync('index.html', 'utf8');
const data = JSON.parse(fs.readFileSync(process.argv[2] || 'api-data.json', 'utf8'));

const errors = [];
const vc = new VirtualConsole();
vc.on('jsdomError', e => errors.push(e.detail ? e.detail.stack : e.message));
vc.on('error', (...a) => errors.push(`console.error: ${a.join(' ')}`));

const dom = new JSDOM(html, {
  runScripts: 'dangerously', pretendToBeVisual: true, virtualConsole: vc,
  url: 'http://localhost:8084/',
  beforeParse(w) {
    w.fetch = (url) => Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(
      url === 'api/me' ? { username: 'admin', fullName: 'T', role: 'admin' }
        : url === 'api/data' ? data : url === 'api/imports' ? { imports: [] } : { ok: true }) });
    w.confirm = () => true;
    w.MGMT_DEVICE_DATA = { meta: {}, assetRows: [], historyRows: [] };
  },
});
const w = dom.window, $ = id => w.document.getElementById(id);
const report = [];
const check = (l, ok, d = '') => report.push(`${ok ? 'PASS' : 'FAIL'}  ${l}${d ? ' — ' + d : ''}`);
const opts = s => [...s.options].map(o => o.label);

setTimeout(() => {
  // ---- 1. Vị trí & Cụm: gom theo phân loại ------------------------------
  w.document.querySelector('[data-view="locations"]').click();
  const kinds = [...w.document.querySelectorAll('#locationCrud tbody tr')].map(tr => tr.children[1].textContent.trim());
  const order = ['Site', 'Phòng máy', 'Rack'];
  const grouped = kinds.every((k, i) => i === 0 || order.indexOf(k) >= order.indexOf(kinds[i - 1]));
  check('danh mục vị trí gom theo phân loại Site → Phòng máy → Rack', grouped, kinds.join(' , '));

  // ---- 2. Danh mục tài sản: bộ lọc --------------------------------------
  w.document.querySelector('[data-view="assets"]').click();
  const siteFilter = $('siteFilterFull');
  const siteNames = data.locations.filter(l => l.kind === 'location').map(l => l.site);
  const roomRackNames = data.locations.filter(l => l.kind !== 'location').map(l => l.room || l.rack);
  check('bộ lọc Site chỉ liệt kê site',
    siteNames.every(n => opts(siteFilter).includes(n))
    && !roomRackNames.some(n => n && opts(siteFilter).includes(n)),
    opts(siteFilter).join(', '));
  check('đã bỏ bộ lọc bản ghi', !$('flagFilterFull'));
  // Kiểm ĐÚNG những ô lọc cần có, không đếm cứng con số — thêm bộ lọc mới là chuyện bình thường
  const toolIds = [...w.document.querySelectorAll('#assetsView .filter-group select')].map(n => n.id);
  check('thanh lọc có đủ loại · trạng thái · site · cụm',
    ['typeFilterFull', 'statusFilterFull', 'siteFilterFull', 'clusterFilterFull']
      .every(id => toolIds.includes(id)), toolIds.join(', '));
  check('bảng vẫn ra dòng sau khi bỏ bộ lọc', w.document.querySelectorAll('#assetRowsFull tr').length > 0);

  // ---- 3. Sơ đồ: mỗi site một tab, mỗi rack một cột --------------------
  w.document.querySelector('[data-view="diagram"]').click();
  check('có mục Sơ đồ trên thanh điều hướng', Boolean(w.document.querySelector('[data-view="diagram"]')));
  const tabs = () => [...$('diagramTabs').querySelectorAll('[data-site-tab]')];
  const tabName = t => t.childNodes[0].textContent.trim();
  const openTab = t => { t.click(); return $('diagramTree'); };
  const siteCount = data.locations.filter(l => l.kind === 'location' && l.siteKind !== 'warehouse').length;
  // Ngoài các site, được phép có thêm ĐÚNG MỘT tab "Chưa ghi site" gom tài sản chưa rõ
  // nơi đặt — phơi ra chứ không giấu. Kho thì tách hẳn, không vẽ vào đây.
  const tenTab = tabs().map(tabName);
  check('mỗi site một tab, và không có tab Kho',
    tenTab.filter(t => !/chưa ghi site/i.test(t)).length === siteCount && !tenTab.some(t => /^kho$/i.test(t)),
    tenTab.join(' | '));
  check('tài sản chưa rõ site được gom vào đúng một tab riêng',
    tenTab.filter(t => /chưa ghi site/i.test(t)).length <= 1, tenTab.join(' | '));
  check('chỉ một tab đang chọn và chỉ vẽ một site',
    tabs().filter(t => t.classList.contains('active')).length === 1);

  // Rack thành cột hàng ngang, rack cùng phòng đứng liền nhau, tên phòng nằm trên tên rack
  const racksOf = site => data.locations.filter(l => l.kind === 'rack' && l.site === site);
  const many = data.locations.filter(l => l.kind === 'location')
    .find(site => new Set(racksOf(site.site).map(r => r.roomId)).size > 1);
  if (many) {
    const tree = openTab(tabs().find(t => tabName(t) === many.site));
    const cols = [...tree.querySelectorAll('.rack-col.is-rack')];
    check(`site ${many.site}: mỗi rack một cột`, cols.length === racksOf(many.site).length,
      `${cols.length} cột / ${racksOf(many.site).length} rack`);
    const roomOfCol = cols.map(c => c.querySelector('.rack-room')?.textContent.trim() || '');
    const runs = roomOfCol.filter((r, i) => i === 0 || r !== roomOfCol[i - 1]);
    check('rack cùng phòng đứng liền nhau', runs.length === new Set(roomOfCol).size, runs.join(' → '));
    check('tên phòng hiện ngay trên tên rack', cols.every(c => {
      const room = c.querySelector('.rack-head .rack-room'), name = c.querySelector('.rack-head .rack-title');
      return room && name && room.compareDocumentPosition(name) & w.Node.DOCUMENT_POSITION_FOLLOWING;
    }));
    check('mỗi phòng một nhóm cột', tree.querySelectorAll('.room-group').length >= new Set(roomOfCol).size,
      `${tree.querySelectorAll('.room-group').length} nhóm`);
  } else {
    check('rack cùng phòng đứng liền nhau', true, 'không site nào có nhiều phòng — bỏ qua');
  }

  // Kiểm CƠ CHẾ chứ không kiểm con số tổng: mỗi cột chỉ vẽ tối đa DEVICE_CAP thiết bị.
  const CAP = Number((html.match(/DEVICE_CAP\s*=\s*(\d+)/) || [])[1] || 30);
  const qua = tabs().flatMap(t => [...openTab(t).querySelectorAll('.rack-body > ul')]
    .map(ul => [...ul.children].filter(li => li.querySelector(':scope > .node.is-device')).length))
    .filter(n => n > CAP);
  check(`mỗi cột vẽ tối đa ${CAP} thiết bị, nhiều hơn thì thu lại`, qua.length === 0,
    qua.length ? `có cột vẽ ${Math.max(...qua)} thiết bị` : `cột đông nhất vẫn trong mức ${CAP}`);
  check('số đếm trên tab site khớp dữ liệu', (() => {
    const site = data.locations.find(l => l.kind === 'location');
    const real = data.assetRows.filter(a => a.datacenter === site.site).length;
    const tab = tabs().find(t => tabName(t) === site.site);
    return tab && tab.querySelector('.tab-count').textContent.trim() === real.toLocaleString('vi-VN');
  })(), 'đối chiếu site đầu tiên');

  // linh kiện lồng dưới thiết bị cha
  const withChild = data.assetRows.find(a => !a.in_store
    && data.assetRows.some(o => o.parent_reference === a.asset_id));
  if (withChild) {
    const tab = tabs().find(t => tabName(t) === withChild.datacenter) || tabs().find(t => /chưa ghi site/i.test(tabName(t)));
    openTab(tab);
    $('diagramExpand').click();
    const parts = $('diagramTree').querySelectorAll('.node.is-part').length;
    check('linh kiện hiện lồng dưới thiết bị cha', parts > 0, `${parts} node linh kiện`);
    const deviceNodes = [...$('diagramTree').querySelectorAll('.node.is-device')];
    check('bấm thiết bị mở được hồ sơ', (() => {
      deviceNodes[0].click();
      return $('detailDrawer').classList.contains('open');
    })());
    $('diagramCollapse').click();
    check('thu gọn thì ẩn linh kiện, cột rack vẫn còn',
      $('diagramTree').querySelectorAll('.node.is-part').length === 0
        && $('diagramTree').querySelectorAll('.rack-col').length > 0);
  } else {
    check('linh kiện hiện lồng dưới thiết bị cha', true, 'dữ liệu chưa có cặp cha-con khớp mã — bỏ qua');
  }

  check('đã bỏ khối ghi chú dưới sơ đồ', !$('diagramNote'));

  console.log(report.join('\n'));
  console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
  process.exit(report.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
}, 500);
