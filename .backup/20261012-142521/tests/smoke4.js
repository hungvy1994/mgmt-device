// Kiểm hai việc mới: linh kiện lắp vào thiết bị phải hiện dưới thiết bị đó trong sơ đồ,
// và thiết bị trong rack phải xếp theo vị trí U từ trên xuống.
const fs = require('fs');
const { JSDOM, VirtualConsole } = require('jsdom');

const html = fs.readFileSync('index.html', 'utf8');
const data = JSON.parse(fs.readFileSync(process.argv[2] || require('path').join(__dirname, 'fixture-u.json'), 'utf8'));

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

const byId = new Map(data.assetRows.map(a => [a.asset_id, a]));
const placed = data.assetRows.filter(a => a.rack_unit);
const attached = data.assetRows.filter(a => a.parent_reference && byId.has(a.parent_reference));
// ưu tiên ca linh kiện nằm khác site với máy cha — đó mới là ca dễ sai
const component = attached.find(a => byId.get(a.parent_reference).datacenter !== a.datacenter) || attached[0];

setTimeout(() => {
  // ---- Ô Vị trí U trong form tài sản ------------------------------------
  w.document.querySelector('[data-view="assets"]').click();
  $('newAssetBtnFull').click();
  const form = w.document.querySelector('.modal-backdrop form');
  const unit = form.querySelector('[name="rack_unit"]');
  check('form tài sản có ô Vị trí U', Boolean(unit) && unit.type === 'number');
  check('ô Vị trí U đứng ngay sau ô Rack',
    form.querySelector('[data-field="rack_id"]').nextElementSibling?.dataset.field === 'rack_unit');
  w.document.querySelector('.modal-backdrop .modal-close').click();

  // hồ sơ chi tiết ghi cả rack lẫn U
  if (placed.length) {
    const sample = placed[0];
    w.document.querySelector('[data-view="diagram"]').click();
    const node = [...$('diagramTree').querySelectorAll('.node')].find(n => n.textContent.includes(sample.asset_id));
    if (node) node.click();
    check('hồ sơ chi tiết ghi rack kèm U',
      /U\d+/.test($('drawerMeta').textContent), $('drawerMeta').textContent.match(/.{0,20}U\d+.{0,10}/)?.[0] || '(không thấy)');
    $('closeDrawer').click();
  }

  // ---- Sơ đồ: xếp theo U ------------------------------------------------
  w.document.querySelector('[data-view="diagram"]').click();
  const tree = $('diagramTree');
  check('node có vị trí U hiện nhãn U', tree.querySelectorAll('.node-unit').length >= placed.length,
    `${tree.querySelectorAll('.node-unit').length} nhãn / ${placed.length} thiết bị có U`);

  // lấy thứ tự U trong rack đang mở
  const rackLi = [...tree.querySelectorAll('.node.is-rack')]
    .map(n => n.parentElement).find(li => li.querySelector(':scope > ul'));
  const units = [...(rackLi?.querySelector(':scope > ul')?.children || [])]
    .map(li => li.querySelector(':scope > .node .node-unit')?.textContent.trim())
    .filter(Boolean).map(u => Number(u.slice(1)));
  check('trong rack xếp theo U từ trên xuống',
    units.length >= 2 && units.every((u, i) => i === 0 || u <= units[i - 1]),
    units.map(u => `U${u}`).join(' → ') || '(rack chưa có thiết bị ghi U)');
  const allRows = [...(rackLi?.querySelector(':scope > ul')?.children || [])]
    .map(li => li.querySelector(':scope > .node .node-unit')?.textContent.trim() || '');
  check('thiết bị chưa ghi U xếp xuống dưới',
    allRows.filter(Boolean).length === 0 || allRows.indexOf('') === -1
      || allRows.slice(allRows.indexOf('')).every(v => v === ''),
    allRows.map(v => v || '—').join(' '));

  // ---- Sơ đồ: linh kiện lồng dưới thiết bị cha --------------------------
  if (component) {
    const parentId = component.parent_reference;
    $('diagramExpand').click();
    const parts = [...$('diagramTree').querySelectorAll('.node.is-part')];
    check('linh kiện hiện dưới thiết bị cha trong sơ đồ',
      parts.some(n => n.textContent.includes(component.asset_id)),
      `${parts.length} node linh kiện`);
    // đúng là nằm TRONG nhánh của máy cha, không phải trôi nổi chỗ khác
    const partNode = parts.find(n => n.textContent.includes(component.asset_id));
    const ancestor = partNode?.closest('li')?.parentElement?.closest('li')
      ?.querySelector(':scope > .node .node-name')?.textContent.trim() || '';
    check('linh kiện nằm đúng trong nhánh của máy cha', ancestor === parentId,
      `cha trực tiếp: ${ancestor || '(không tìm thấy)'}`);
    const different = byId.get(parentId).datacenter !== component.datacenter;
    if (different) {
      check('linh kiện ở site khác vẫn ghi rõ hồ sơ ghi đâu',
        /hồ sơ ghi ở/.test(partNode.textContent), partNode.textContent.trim().slice(0, 70));
    }
    check('ghi chú giải thích số đếm khi linh kiện nằm khác chỗ hồ sơ',
      !different || /số đếm mỗi nhánh tính theo chỗ đang hiện/.test($('diagramNote').textContent));
    $('diagramCollapse').click();
  } else {
    check('linh kiện hiện dưới thiết bị cha trong sơ đồ', true, 'dữ liệu không có cặp cha-con — bỏ qua');
  }

  // Không bản ghi nào rơi vào khoảng trống: linh kiện ghi ở kho nhưng lắp trong máy ở
  // nơi khác thì màn Kho phải kể tên nó ra, vì nó không thành dòng trong bảng.
  const siteOfPart = component && byId.get(component.parent_reference).datacenter !== component.datacenter
    ? component.datacenter : '';
  const stores = data.locations.filter(l => l.kind === 'location' && l.siteKind === 'warehouse').map(l => l.site);
  if (siteOfPart && stores.includes(siteOfPart)) {
    w.document.querySelector('[data-view="store"]').click();
    check(`màn Kho kể tên linh kiện ghi ở ${siteOfPart} nhưng đang lắp nơi khác`,
      $('storeNote').textContent.includes(component.asset_id),
      $('storeNote').textContent.match(/[^.]*đang lắp trong thiết bị[^.]*/)?.[0]?.slice(0, 95) || '(không có)');
  }

  console.log(report.join('\n'));
  console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
  process.exit(report.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
}, 500);
