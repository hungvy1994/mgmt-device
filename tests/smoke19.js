// Kiểm: Kho không còn là site trong danh mục vị trí, và các danh sách đều lọc được.
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
const rowsOf = id => [...($(id).tagName === 'TBODY' ? $(id).rows : $(id).querySelectorAll('tbody tr'))];
const fire = (node, type) => node.dispatchEvent(new w.Event(type, { bubbles: true }));

setTimeout(() => {
  // ---- 1. Kho không phải site -------------------------------------------
  w.document.querySelector('[data-view="locations"]').click();
  const locText = $('locationCrud').textContent;
  check('danh mục vị trí không còn dòng nào tên Kho', !/\bKho\b/.test(locText),
    (locText.match(/Kho/g) || []).length + ' lần xuất hiện');
  const siteOptions = [...$('siteFilterFull').options].map(o => o.textContent);
  check('bộ lọc site của danh mục tài sản cũng không có Kho',
    !siteOptions.some(t => t.trim() === 'Kho'), siteOptions.join(' | '));

  // ---- 2. Lọc danh mục vị trí -------------------------------------------
  const truoc = rowsOf('locationCrud').length;
  $('locationKindFilter').value = 'rack';
  fire($('locationKindFilter'), 'change');
  const chiRack = rowsOf('locationCrud');
  check('lọc cấp Rack chỉ còn rack', chiRack.length > 0 && chiRack.length < truoc
    && chiRack.every(tr => tr.textContent.includes('Rack')), `${chiRack.length}/${truoc} dòng`);
  $('locationKindFilter').value = 'all';
  fire($('locationKindFilter'), 'change');
  check('bỏ lọc thì về đủ', rowsOf('locationCrud').length === truoc);
  const mauSite = data.locations.find(l => l.kind === 'rack');
  if (mauSite) {
    $('locationSearch').value = mauSite.rack.toLowerCase();   // gõ thường, dữ liệu hoa
    fire($('locationSearch'), 'input');
    check('ô tìm vị trí không phân biệt hoa thường',
      rowsOf('locationCrud').length > 0 && rowsOf('locationCrud').length < truoc,
      `tìm "${mauSite.rack.toLowerCase()}" -> ${rowsOf('locationCrud').length} dòng`);
    $('locationSearch').value = '';
    fire($('locationSearch'), 'input');
  }

  // ---- 3. Lọc kho --------------------------------------------------------
  w.document.querySelector('[data-view="store"]').click();
  const khoTruoc = rowsOf('storeRows').length;
  const loai = [...$('storeTypeFilter').options].filter(o => o.value !== 'all');
  check('kho có ô lọc loại, chỉ liệt kê loại thực sự có trong kho', loai.length > 0,
    loai.map(o => o.textContent).join(' | ').slice(0, 70));
  const tt = [...$('storeStatusFilter').options].filter(o => o.value !== 'all');
  check('kho có ô lọc trạng thái', tt.length > 0, tt.map(o => o.textContent).join(' | ').slice(0, 70));
  if (loai.length) {
    $('storeTypeFilter').value = loai[0].value;
    fire($('storeTypeFilter'), 'change');
    const sau = rowsOf('storeRows');
    check(`lọc kho theo loại "${loai[0].value}" chạy đúng`,
      sau.length > 0 && sau.every(tr => tr.textContent.length > 0), `${sau.length} dòng`);
    $('storeTypeFilter').value = 'all';
    fire($('storeTypeFilter'), 'change');
    check('bỏ lọc kho thì về đủ', rowsOf('storeRows').length === khoTruoc,
      `${rowsOf('storeRows').length} / ${khoTruoc}`);
  }

  // ---- 4. Lọc trạng thái và loại tài sản ---------------------------------
  w.document.querySelector('[data-view="statuses"]').click();
  const ttTruoc = rowsOf('statusCrud').length;
  $('statusSearch').value = 'kho';
  fire($('statusSearch'), 'input');
  check('lọc danh mục trạng thái', rowsOf('statusCrud').length < ttTruoc,
    `${rowsOf('statusCrud').length}/${ttTruoc}`);
  w.document.querySelector('[data-view="types"]').click();
  const ltTruoc = rowsOf('typeCrud').length;
  $('typeSearch').value = 'disk';
  fire($('typeSearch'), 'input');
  check('lọc danh mục loại tài sản', rowsOf('typeCrud').length < ltTruoc,
    `${rowsOf('typeCrud').length}/${ltTruoc}`);

  console.log(report.join('\n'));
  console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
  process.exit(report.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
}, 600);
