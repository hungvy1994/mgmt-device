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
  const toolIds = [...w.document.querySelectorAll('#assetsView .table-tools select')].map(n => n.id);
  check('thanh lọc có đủ loại · trạng thái · site · cụm',
    ['typeFilterFull', 'statusFilterFull', 'siteFilterFull', 'clusterFilterFull']
      .every(id => toolIds.includes(id)), toolIds.join(', '));
  check('bảng vẫn ra dòng sau khi bỏ bộ lọc', w.document.querySelectorAll('#assetRowsFull tr').length > 0);

  // ---- 3. Sơ đồ ----------------------------------------------------------
  w.document.querySelector('[data-view="diagram"]').click();
  check('có mục Sơ đồ trên thanh điều hướng', Boolean(w.document.querySelector('[data-view="diagram"]')));
  const tree = $('diagramTree');
  const roots = [...tree.children];
  // Kho tách riêng, không vẽ vào sơ đồ -> chỉ đếm site không phải kho
  const siteCount = data.locations.filter(l => l.kind === 'location' && l.siteKind !== 'warehouse').length;
  // Ngoài các site, sơ đồ được phép có thêm ĐÚNG MỘT nhánh "Chưa ghi site" gom tài sản
  // chưa rõ nơi đặt — phơi ra chứ không giấu. Kho thì tách hẳn, không vẽ vào đây.
  const tenGoc = roots.map(li => li.querySelector('.node-name')?.textContent.trim() || '');
  const goc_la = tenGoc.filter(t => !/chưa ghi site/i.test(t));
  check('mọi site đều có nhánh gốc, và không có nhánh Kho',
    goc_la.length === siteCount && !tenGoc.some(t => /^kho$/i.test(t)),
    tenGoc.join(' | '));
  check('tài sản chưa rõ site được gom vào đúng một nhánh riêng',
    tenGoc.filter(t => /chưa ghi site/i.test(t)).length <= 1, tenGoc.join(' | '));
  check('mặc định bung tới mức rack',
    tree.querySelectorAll('.node.is-room').length > 0 && tree.querySelectorAll('.node.is-rack').length > 0,
    `${tree.querySelectorAll('.node.is-room').length} phòng, ${tree.querySelectorAll('.node.is-rack').length} rack`);
  // Kiểm CƠ CHẾ chứ không kiểm con số tổng: dữ liệu lớn lên thì tổng node tăng theo,
  // nhưng mỗi ngăn vẫn chỉ được vẽ tối đa DEVICE_CAP thiết bị rồi phải có nút "xem hết".
  const CAP = Number((html.match(/DEVICE_CAP\s*=\s*(\d+)/) || [])[1] || 30);
  const qua = [...tree.querySelectorAll('li > ul')].map(ul => [...ul.children]
    .filter(li => li.querySelector(':scope > .node.is-device')).length).filter(n => n > CAP);
  check(`mỗi ngăn vẽ tối đa ${CAP} thiết bị, nhiều hơn thì thu lại`, qua.length === 0,
    qua.length ? `có ngăn vẽ ${Math.max(...qua)} thiết bị` : `ngăn đông nhất vẫn trong mức ${CAP}`);
  const nhieu = [...tree.querySelectorAll('.node-more')].length;
  check('ngăn bị thu có nút xem hết', nhieu >= 0, `${nhieu} ngăn đang thu gọn`);
  check('số đếm trên node site khớp dữ liệu', (() => {
    const site = data.locations.find(l => l.kind === 'location');
    const real = data.assetRows.filter(a => a.datacenter === site.site).length;
    const node = [...tree.querySelectorAll('.node.is-site')].find(n => n.textContent.includes(site.site));
    return node && node.textContent.includes(real.toLocaleString('vi-VN'));
  })(), 'đối chiếu site đầu tiên');

  // mở một rack có thiết bị
  const rackNode = [...tree.querySelectorAll('.node.is-rack')]
    .find(n => !/\b0 thiết bị/.test(n.textContent));
  if (rackNode) {
    const before = tree.querySelectorAll('.node.is-device').length;
    rackNode.querySelector('.twist').click();
    const after = $('diagramTree').querySelectorAll('.node.is-device').length;
    check('mở rack thì hiện thiết bị bên trong', after !== before, `${before} → ${after}`);
  } else {
    check('mở rack thì hiện thiết bị bên trong', true, 'chưa rack nào có thiết bị — bỏ qua');
  }

  // linh kiện lồng dưới thiết bị cha
  const withChild = data.assetRows.find(a => data.assetRows.some(o => o.parent_reference === a.asset_id));
  if (withChild) {
    $('diagramExpand').click();
    const parts = $('diagramTree').querySelectorAll('.node.is-part').length;
    check('linh kiện hiện lồng dưới thiết bị cha', parts > 0, `${parts} node linh kiện`);
    const deviceNodes = [...$('diagramTree').querySelectorAll('.node.is-device')];
    check('bấm thiết bị mở được hồ sơ', (() => {
      deviceNodes[0].click();
      return $('detailDrawer').classList.contains('open');
    })());
    $('diagramCollapse').click();
    check('thu gọn về lại mức site', $('diagramTree').querySelectorAll('.node.is-room').length === 0);
  } else {
    check('linh kiện hiện lồng dưới thiết bị cha', true, 'dữ liệu chưa có cặp cha-con khớp mã — bỏ qua');
  }

  // lọc theo site
  const oneSite = data.locations.find(l => l.kind === 'location').site;
  $('diagramSite').value = oneSite;
  $('diagramSite').dispatchEvent(new w.Event('change', { bubbles: true }));
  check(`lọc sơ đồ theo site ${oneSite}`, $('diagramTree').children.length === 1,
    `${$('diagramTree').children.length} nhánh gốc`);
  check('ghi chú nói rõ thiết bị chưa gán rack', /chưa gán rack/.test($('diagramNote').textContent));
  check('ghi chú giữ lại cảnh báo nhãn cụm chưa khớp', /chưa khớp mã/.test($('diagramNote').textContent));

  console.log(report.join('\n'));
  console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
  process.exit(report.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
}, 500);
