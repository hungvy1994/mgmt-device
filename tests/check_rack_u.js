// Kiểm ba cách hiển thị trong cột rack của sơ đồ:
//   1. thiết bị 2U/3U hiện dải U (U42-43), thiết bị 1U hoặc chưa khai số U hiện một U
//   2. trạng thái là chấm tròn màu, không còn nhãn chữ
//   3. có gạch ngang ngăn giữa các thiết bị cha, linh kiện bên trong không bị ngăn
// Dùng fixture riêng (gán số U lên bản sao fixture-30) để không phụ thuộc dữ liệu thật.
const fs = require('fs');
const path = require('path');
const { JSDOM, VirtualConsole } = require('jsdom');
const html = fs.readFileSync('index.html', 'utf8');
const data = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixture-30.json'), 'utf8'));

// Lấy hai thiết bị có U trong cùng một rack: một cái khai 2U, một cái để trống số U.
const inRack = data.assetRows.filter(a => a.rack_unit && a.rack_id && !a.parent_reference);
const byRack = {};
inRack.forEach(a => { (byRack[a.rack_id] = byRack[a.rack_id] || []).push(a); });
const pair = Object.values(byRack).find(list => list.length >= 2) || [];
// Máy thấp hơn khai 2U (máy cao nhất có thể đang ở đỉnh rack, khai 2U là tràn rack).
const [mot, hai] = pair.sort((a, b) => Number(b.rack_unit) - Number(a.rack_unit));
if (hai) hai.rack_size_u = 2;

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

setTimeout(() => {
  w.document.querySelector('[data-view="diagram"]').click();
  const tabs = [...$('diagramTabs').querySelectorAll('[data-site-tab]')];
  const tab = tabs.find(t => t.childNodes[0].textContent.trim() === (hai || {}).datacenter) || tabs[0];
  tab.click();
  const nodeOf = id => [...$('diagramTree').querySelectorAll('.node')]
    .find(n => n.querySelector('.node-name')?.textContent.trim() === id);

  // ---- 1. dải U -----------------------------------------------------------
  check('fixture có hai thiết bị cùng rack để kiểm', Boolean(hai && mot),
    hai ? `${hai.asset_id} · ${mot.asset_id}` : '(không có)');
  if (hai && mot) {
    const u = Number(hai.rack_unit);
    const badge = nodeOf(hai.asset_id)?.querySelector('.node-unit')?.textContent.trim();
    check('thiết bị 2U hiện U đầu và U cuối', badge === `U${u}-${u + 1}`, badge || '(không thấy)');
    const badge1 = nodeOf(mot.asset_id)?.querySelector('.node-unit')?.textContent.trim();
    check('thiết bị chưa khai số U chỉ hiện một U', badge1 === `U${mot.rack_unit}`, badge1 || '(không thấy)');
  }

  // ---- 2. chấm trạng thái -------------------------------------------------
  const tree = $('diagramTree');
  const devices = [...tree.querySelectorAll('.node.is-device')];
  check('mỗi thiết bị có một chấm trạng thái',
    devices.length > 0 && devices.every(n => n.querySelectorAll('.status-dot').length === 1),
    `${devices.length} thiết bị`);
  check('sơ đồ không còn nhãn trạng thái bằng chữ', tree.querySelectorAll('.tag').length === 0,
    `${tree.querySelectorAll('.tag').length} nhãn`);
  const live = devices.map(n => n.querySelector('.status-dot'))
    .find(d => d.getAttribute('aria-label') === 'Đang vận hành');
  check('đang vận hành là chấm màu xanh',
    Boolean(live) && live.classList.contains('live') && /1f9d6b/i.test(html.match(/\.status-dot\.live\s*\{[^}]*\}/)?.[0] || ''),
    live ? live.className : '(không có thiết bị đang vận hành)');
  check('rê chuột vào chấm thấy tên trạng thái',
    devices.every(n => (n.querySelector('.status-dot')?.getAttribute('title') || '').length > 0));
  const legend = $('diagramStatusLegend');
  check('có chú giải màu trạng thái', legend && legend.querySelectorAll('.status-dot').length > 0,
    legend ? legend.textContent.trim() : '(không có)');

  // ---- 4. mã viết hoa khi hiển thị, dữ liệu giữ nguyên ---------------------
  if (hai) {
    const name = nodeOf(hai.asset_id)?.querySelector('.node-name');
    check('mã thiết bị hiển thị viết hoa', name && w.getComputedStyle(name).textTransform === 'uppercase',
      name ? w.getComputedStyle(name).textTransform : '(không thấy)');
    check('mã trong dữ liệu không bị đổi', name && name.textContent.trim() === hai.asset_id);
  }

  // ---- 5. khung sơ đồ cố định, không có khối ghi chú ------------------------
  check('không còn khối ghi chú dưới sơ đồ', !$('diagramNote') && !$('diagramView').querySelector('.tree-note'));
  check('màn Sơ đồ cao đúng cửa sổ, nội dung cuộn trong khung',
    /#diagramView\.active\s*\{[^}]*height:\s*calc\(100vh/.test(html)
      && /#diagramView \.tree-wrap\s*\{[^}]*min-height:\s*0/.test(html)
      && w.getComputedStyle($('diagramView').querySelector('.tree-wrap')).overflow === 'auto');

  // ---- 3. gạch ngang giữa các thiết bị cha --------------------------------
  const col = [...tree.querySelectorAll('.rack-body > .tree')].find(ul => ul.children.length >= 2);
  if (col) {
    const [first, second] = col.children;
    const line = li => w.getComputedStyle(li).borderTopStyle;
    check('thiết bị cha thứ hai trở đi có gạch ngang phía trên', line(second) === 'solid', line(second));
    check('thiết bị đầu cột không có gạch thừa', line(first) !== 'solid', line(first));
  } else {
    check('thiết bị cha thứ hai trở đi có gạch ngang phía trên', false, 'không cột nào có 2 thiết bị');
  }
  $('diagramExpand').click();
  const part = $('diagramTree').querySelector('.rack-body .node.is-part');
  const partLi = part && part.closest('li');
  check('linh kiện bên trong máy không bị gạch ngăn',
    !partLi || w.getComputedStyle(partLi).borderTopStyle !== 'solid', partLi ? '' : 'không có linh kiện');

  console.log(report.join('\n'));
  console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
  process.exit(report.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
}, 600);
