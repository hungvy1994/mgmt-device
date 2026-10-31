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
// Sơ đồ chỉ vẽ một site mỗi lần (mỗi site một tab) -> mở đúng tab của máy gốc chứa tài sản.
const rootOf = a => { let cur = a; const seen = new Set();
  while (cur.parent_reference && byId.has(cur.parent_reference) && !seen.has(cur.asset_id)) {
    seen.add(cur.asset_id); cur = byId.get(cur.parent_reference); }
  return cur; };
const component = attached.find(a => byId.get(a.parent_reference).datacenter !== a.datacenter) || attached[0];

const openTabOf = a => {
  const site = rootOf(a).datacenter;
  const tabs = [...$('diagramTabs').querySelectorAll('[data-site-tab]')];
  (tabs.find(t => t.childNodes[0].textContent.trim() === site)
    || tabs.find(t => /chưa ghi site/i.test(t.textContent)) || tabs[0])?.click();
};

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
    openTabOf(sample);
    const node = [...$('diagramTree').querySelectorAll('.node')].find(n => n.textContent.includes(sample.asset_id));
    if (node) node.click();
    check('hồ sơ chi tiết ghi rack kèm U',
      /U\d+/.test($('drawerMeta').textContent), $('drawerMeta').textContent.match(/.{0,20}U\d+.{0,10}/)?.[0] || '(không thấy)');
    $('closeDrawer').click();
  }

  // ---- Sơ đồ: xếp theo U ------------------------------------------------
  w.document.querySelector('[data-view="diagram"]').click();
  const siteTabs = [...$('diagramTabs').querySelectorAll('[data-site-tab]')];
  const unitTags = siteTabs.reduce((sum, t) => { t.click(); return sum + $('diagramTree').querySelectorAll('.node-unit').length; }, 0);
  check('node có vị trí U hiện nhãn U', unitTags >= placed.length,
    `${unitTags} nhãn / ${placed.length} thiết bị có U`);

  // lấy thứ tự U trong một cột rack có thiết bị ghi U
  if (placed.length) openTabOf(placed[0]);
  const tree = $('diagramTree');
  const rackUl = [...tree.querySelectorAll('.rack-col.is-rack .rack-body > ul')]
    .find(ul => ul.querySelectorAll(':scope > li > .node .node-unit').length >= 2)
    || tree.querySelector('.rack-col.is-rack .rack-body > ul');
  const units = [...(rackUl?.children || [])]
    .map(li => li.querySelector(':scope > .node .node-unit')?.textContent.trim())
    .filter(Boolean).map(u => Number(u.slice(1)));
  check('trong rack xếp theo U từ trên xuống',
    units.length >= 2 && units.every((u, i) => i === 0 || u <= units[i - 1]),
    units.map(u => `U${u}`).join(' → ') || '(rack chưa có thiết bị ghi U)');
  const allRows = [...(rackUl?.children || [])]
    .map(li => li.querySelector(':scope > .node .node-unit')?.textContent.trim() || '');
  check('thiết bị chưa ghi U xếp xuống dưới',
    allRows.filter(Boolean).length === 0 || allRows.indexOf('') === -1
      || allRows.slice(allRows.indexOf('')).every(v => v === ''),
    allRows.map(v => v || '—').join(' '));

  // ---- Sơ đồ: linh kiện lồng dưới thiết bị cha --------------------------
  if (component) {
    const parentId = component.parent_reference;
    openTabOf(component);
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
    $('diagramCollapse').click();
  } else {
    check('linh kiện hiện dưới thiết bị cha trong sơ đồ', true, 'dữ liệu không có cặp cha-con — bỏ qua');
  }

  console.log(report.join('\n'));
  console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
  process.exit(report.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
}, 500);
