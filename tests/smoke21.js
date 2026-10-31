// Kiểm: cụm và vị trí là hai chiều độc lập — lọc theo cụm được, và cụm không suy ra vị trí.
const fs = require('fs');
const { JSDOM, VirtualConsole } = require('jsdom');
const html = fs.readFileSync('index.html', 'utf8');
const data = JSON.parse(fs.readFileSync(process.argv[2] || 'api-data.json', 'utf8'));

// Dựng sẵn tình huống NHIỀU–NHIỀU: một cụm trải hai tủ, một tủ phục vụ hai cụm.
const racks = data.locations.filter(l => l.kind === 'rack').slice(0, 2);
if (racks.length === 2) {
  const [r1, r2] = racks;
  data.assetRows.unshift(
    { asset_id: 'cum-a-1', asset_name: 'Máy cụm A ở tủ 1', asset_type: 'server', cluster: 'CumA',
      usage_status: 'in_use', datacenter: r1.site, rack: r1.rack, rack_id: r1.rackId, rack_label: r1.rack },
    { asset_id: 'cum-a-2', asset_name: 'Máy cụm A ở tủ 2', asset_type: 'server', cluster: 'CumA',
      usage_status: 'in_use', datacenter: r2.site, rack: r2.rack, rack_id: r2.rackId, rack_label: r2.rack },
    { asset_id: 'cum-b-1', asset_name: 'Máy cụm B ở tủ 1', asset_type: 'server', cluster: 'CumB',
      usage_status: 'in_use', datacenter: r1.site, rack: r1.rack, rack_id: r1.rackId, rack_label: r1.rack },
    { asset_id: 'chua-cum-1', asset_name: 'Máy chưa gán cụm', asset_type: 'server', usage_status: 'in_use' },
  );
  data.clusters = [...(data.clusters || []), { name: 'CumA', note: '' }, { name: 'CumB', note: '' }];
}

const errors = [];
const vc = new VirtualConsole();
vc.on('jsdomError', e => errors.push(e.detail ? e.detail.stack : e.message));
vc.on('error', (...a) => errors.push(`console.error: ${a.join(' ')}`));
const dom = new JSDOM(html, {
  runScripts: 'dangerously', pretendToBeVisual: true, virtualConsole: vc,
  url: 'http://localhost:8084/',
  beforeParse(w) {
    w.fetch = u => Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(
      u === 'api/me' ? { username: 'admin', role: 'admin' } : u === 'api/data' ? data
        : u === 'api/imports' ? { imports: [] } : { ok: true }) });
    w.confirm = () => true;
    w.MGMT_DEVICE_DATA = { meta: {}, assetRows: [], historyRows: [] };
  },
});
const w = dom.window, $ = id => w.document.getElementById(id);
const report = [];
const check = (l, ok, d = '') => report.push(`${ok ? 'PASS' : 'FAIL'}  ${l}${d ? ' — ' + d : ''}`);
const fire = (n, t) => n.dispatchEvent(new w.Event(t, { bubbles: true }));
const rows = () => [...$('assetRowsFull').rows];

setTimeout(() => {
  w.document.querySelector('[data-view="assets"]').click();
  const pick = $('clusterFilterFull');
  check('danh mục tài sản có ô lọc theo cụm', Boolean(pick));
  if (!pick) { console.log(report.join('\n')); process.exit(1); }

  const opts = [...pick.options].map(o => o.value);
  check('ô lọc liệt kê cụm từ DANH MỤC, không phải từ giá trị đang dùng',
    data.clusters.every(c => opts.includes(c.name)), opts.slice(0, 5).join(' | '));
  check('có lối chọn "chưa gán cụm" — đây là tập cần xử lý tay',
    opts.includes('__none__'),
    [...pick.options].find(o => o.value === '__none__')?.textContent || '(không có)');

  if (racks.length === 2) {
    // Một cụm trải HAI tủ: lọc theo cụm phải ra cả hai, không bị bó vào một tủ
    pick.value = 'CumA'; fire(pick, 'change');
    const a = rows().map(tr => tr.textContent);
    check('một cụm trải nhiều tủ: lọc ra đủ máy ở cả hai tủ',
      a.length === 2 && a.some(t => t.includes(racks[0].rack)) && a.some(t => t.includes(racks[1].rack)),
      `${a.length} dòng`);

    // Một tủ phục vụ HAI cụm: lọc site không được kéo theo cụm
    pick.value = 'all'; fire(pick, 'change');
    const site = $('siteFilterFull');
    site.value = racks[0].site; fire(site, 'change');
    const cums = new Set(rows().map(tr => tr.textContent).filter(t => /Máy cụm/.test(t))
      .map(t => (t.match(/cụm ([AB])/) || [])[1]));
    check('một tủ phục vụ nhiều cụm: lọc theo site không ép về một cụm',
      cums.size >= 2, `thấy ${cums.size} cụm trong cùng site`);
    site.value = 'all'; fire(site, 'change');

    // Lọc "chưa gán cụm"
    pick.value = '__none__'; fire(pick, 'change');
    const none = rows().map(tr => tr.textContent);
    check('lọc "chưa gán cụm" chỉ ra tài sản không có cụm',
      none.length > 0 && none.every(t => !/Máy cụm [AB]/.test(t)), `${none.length} dòng`);
    pick.value = 'all'; fire(pick, 'change');
  }

  // Cột Vị trí KHÔNG được hiện cụm — cụm không phải vị trí
  $('assetSearchFull').value = 'cum-a-1'; fire($('assetSearchFull'), 'input');
  const viTri = rows()[0]?.cells[5]?.textContent || '';
  check('cột Vị trí không kèm tên cụm', !viTri.includes('CumA'), `«${viTri.trim()}»`);

  console.log(report.join('\n'));
  console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
  process.exit(report.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
}, 600);
