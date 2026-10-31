// Kiểm: 117 ổ mới lồng đúng dưới máy cha trong sơ đồ, không rơi ra "nơi khác".
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
setTimeout(() => {
  w.document.querySelector('[data-view="diagram"]').click();
  // Mỗi site một tab, chỉ vẽ tab đang chọn -> mở từng tab, bung hết, gom lại toàn bộ cây.
  const board = w.document.createElement('div');
  [...$('diagramTabs').querySelectorAll('[data-site-tab]')].forEach((_, i) => {
    $('diagramTabs').querySelectorAll('[data-site-tab]')[i].click();
    $('diagramExpand').click();
    $('diagramTree').querySelectorAll('[data-show-all]').forEach(b => b.click());
    board.appendChild($('diagramTree').cloneNode(true));
  });
  const full = board.textContent;
  check('sơ đồ vẽ được, không rỗng', full.length > 200, `${full.length} ký tự`);

  // Kỳ vọng suy từ chính dữ liệu: MỌI máy có linh kiện đều phải lồng đủ trong sơ đồ.
  const kids = {};
  data.assetRows.forEach(a => {
    const parent = a.parent_reference;
    if (parent && data.assetRows.some(o => o.asset_id === parent)) {
      (kids[parent] = kids[parent] || []).push(a.asset_id);
    }
  });
  const parents = Object.keys(kids);
  check('dữ liệu có quan hệ cha-con để kiểm', parents.length > 0, `${parents.length} máy có linh kiện`);
  const wrong = [];
  parents.forEach(host => {
    const name = [...board.querySelectorAll('.node-name')]
      .find(el => el.textContent.trim() === host);
    const after = name && name.closest('li');
    const inside = after ? after.querySelector('ul')?.textContent || '' : '';
    const missing = kids[host].filter(id => !inside.includes(id));
    if (missing.length) wrong.push(`${host} thiếu ${missing.length}/${kids[host].length}`);
  });
  check(`cả ${parents.length} máy đều lồng đủ linh kiện dưới máy cha`, wrong.length === 0,
    wrong.slice(0, 5).join(' · '));
  const total = parents.reduce((sum, h) => sum + kids[h].length, 0);
  // Đếm theo chính danh sách mã con, đừng gõ cứng tiền tố — mỗi tủ lại thêm loại ổ mới
  const tree = full;
  const absent = parents.flatMap(h => kids[h]).filter(id => !tree.includes(id));
  check(`tổng ${total} linh kiện đều có mặt trong sơ đồ`, absent.length === 0,
    absent.length ? `thiếu ${absent.length}: ${absent.slice(0, 4).join(', ')}` : `${total} đủ`);

  console.log(report.join('\n'));
  console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
  process.exit(report.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
}, 600);
