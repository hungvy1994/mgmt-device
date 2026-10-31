// Kiểm sắp xếp theo cột trên các danh sách.
const fs = require('fs');
const { JSDOM, VirtualConsole } = require('jsdom');

const html = fs.readFileSync('index.html', 'utf8');
const data = JSON.parse(fs.readFileSync(process.argv[2] || require('path').join(__dirname, 'fixture-move.json'), 'utf8'));

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
        : u === 'api/data' ? data : u === 'api/imports' ? { imports: [
          { kind: 'assets', fileName: 'b.xlsx', fileType: 'xlsx', rows: 3, added: 1, updated: 2, skipped: 0, username: 'admin', at: '2026-09-12T03:00:00+00:00' },
          { kind: 'assets', fileName: 'a.csv', fileType: 'csv', rows: 9, added: 5, updated: 4, skipped: 1, username: 'admin', at: '2026-09-14T03:00:00+00:00' },
        ] } : { ok: true }) });
    w.confirm = () => true;
    w.MGMT_DEVICE_DATA = { meta: {}, assetRows: [], historyRows: [] };
  },
});
const w = dom.window, $ = id => w.document.getElementById(id);
const report = [];
const check = (l, ok, d = '') => report.push(`${ok ? 'PASS' : 'FAIL'}  ${l}${d ? ' — ' + d : ''}`);
const column = (bodyId, index) => [...$(bodyId).rows].map(tr => tr.cells[index]?.textContent.trim() || '');
const heads = bodyId => [...$(bodyId).closest('table').tHead.rows[0].cells];
const sortedUp = list => list.every((v, i) => i === 0 || String(list[i - 1]).localeCompare(String(v), 'vi', { numeric: true, sensitivity: 'base' }) <= 0);

setTimeout(() => {
  // ---- Danh mục tài sản --------------------------------------------------
  w.document.querySelector('[data-view="assets"]').click();
  const headCells = heads('assetRowsFull');
  const labels = headCells.filter(th => th.dataset.sort).map(th => th.textContent.trim());
  check('mọi cột dữ liệu của danh mục tài sản bấm sắp xếp được',
    labels.length === 7, `${labels.length} cột: ${labels.join(' | ')}`);
  // Bảng đã bỏ cột nút -> chỉ còn cột chọn là không sắp xếp, mọi cột dữ liệu đều sắp được
  check('cột chọn không sắp xếp, mọi cột còn lại sắp được',
    !headCells[0].dataset.sort && headCells.slice(1).every(th => th.dataset.sort),
    headCells.map(th => th.dataset.sort || '(không sắp)').join(' | '));

  const idHead = headCells.find(th => th.dataset.sort === 'id');
  idHead.click();
  const asc = column('assetRowsFull', 2);
  check('bấm lần 1: tăng dần', sortedUp(asc), asc.slice(0, 3).join(' , '));
  check('có dấu mũi tên lên trên tiêu đề', idHead.classList.contains('asc'));
  idHead.click();
  const desc = column('assetRowsFull', 2);
  check('bấm lần 2: giảm dần', sortedUp([...desc].reverse()), desc.slice(0, 3).join(' , '));
  check('dấu mũi tên đổi thành xuống', idHead.classList.contains('desc'));
  idHead.click();
  check('bấm lần 3: về thứ tự gốc',
    !idHead.classList.contains('asc') && !idHead.classList.contains('desc')
    && column('assetRowsFull', 2)[0] === data.assetRows[0].asset_id,
    column('assetRowsFull', 2)[0]);

  // sắp xếp trên TOÀN BỘ dữ liệu, không chỉ trang đang xem
  idHead.click();
  const firstPage = column('assetRowsFull', 2);
  const globalMin = data.assetRows.map(a => a.asset_id)
    .sort((a, b) => a.localeCompare(b, 'vi', { numeric: true, sensitivity: 'base' }))[0];
  check('sắp xếp trên toàn bộ dữ liệu chứ không riêng trang đang xem',
    firstPage[0] === globalMin, `${firstPage[0]} (nhỏ nhất toàn bộ: ${globalMin})`);
  check('đổi cột sắp xếp thì quay về trang 1',
    $('assetRowsFullPager').textContent.includes('Trang 1'), $('assetRowsFullPager').textContent.trim().slice(0, 40));

  // ô trống xuống cuối bất kể chiều
  const parentHead = headCells.find(th => th.dataset.sort === 'parent');
  parentHead.click();
  const parentsAsc = column('assetRowsFull', 6);
  parentHead.click();
  const parentsDesc = column('assetRowsFull', 6);
  check('ô trống (Null) luôn xuống cuối, cả khi sắp giảm dần',
    parentsAsc[0] !== 'Null' && parentsDesc[0] !== 'Null',
    `tăng: ${parentsAsc[0]} · giảm: ${parentsDesc[0]}`);

  // ---- Bảng kho ----------------------------------------------------------
  w.document.querySelector('[data-view="store"]').click();
  const storeHeads = heads('storeRows').filter(th => th.dataset.sort);
  check('bảng kho cũng sắp xếp được', storeHeads.length === 6,
    `${storeHeads.length} cột: ${storeHeads.map(th => th.textContent.trim()).join(' | ')}`);
  const partsHead = storeHeads.find(th => th.dataset.sort === 'parts');
  partsHead.click(); partsHead.click();
  const topRow = $('storeRows').rows[0];
  check('sắp theo số linh kiện: thiết bị có linh kiện lên đầu',
    topRow.cells[5].textContent.trim() !== 'Null', topRow.cells[5].textContent.trim());

  // ---- Bảng nhỏ ----------------------------------------------------------
  w.document.querySelector('[data-view="locations"]').click();
  const locHead = $('locationCrud').querySelector('table thead th');
  check('bảng danh mục vị trí sắp xếp được', Boolean(locHead.dataset.sort));
  const before = [...$('locationCrud').querySelectorAll('tbody tr')].map(tr => tr.cells[0].textContent.trim());
  locHead.click();
  const after = [...$('locationCrud').querySelectorAll('tbody tr')].map(tr => tr.cells[0].textContent.trim());
  check('bấm tiêu đề vị trí thì sắp lại theo cột đó', sortedUp(after) && after.join() !== before.join(),
    after.slice(0, 4).join(' , '));
  locHead.click(); locHead.click();
  check('bảng nhỏ cũng quay về thứ tự gốc ở lần bấm thứ 3',
    [...$('locationCrud').querySelectorAll('tbody tr')].map(tr => tr.cells[0].textContent.trim()).join() === before.join());

  const clusterHead = $('clusterList').querySelector('table thead th');
  check('bảng cụm sắp xếp được', Boolean(clusterHead.dataset.sort));
  const statusHead = (() => { w.document.querySelector('[data-view="statuses"]').click(); return $('statusCrud').querySelector('table thead th'); })();
  check('bảng trạng thái sắp xếp được', Boolean(statusHead.dataset.sort));
  // Mục "Chữ nguyên văn" đã bỏ khỏi màn Trạng thái -> kiểm bảng Loại tài sản thay vào đó
  const typeHead = (() => { w.document.querySelector('[data-view="types"]').click(); return $('typeCrud').querySelector('table thead th'); })();
  check('bảng loại tài sản sắp xếp được', Boolean(typeHead?.dataset.sort));

  w.document.querySelector('[data-view="data"]').click();
  setTimeout(() => {
    const logHead = $('importLog').querySelector('table thead th');
    check('nhật ký nhập sắp xếp được', Boolean(logHead?.dataset.sort));
    if (logHead) {
      const fileHead = $('importLog').querySelectorAll('table thead th')[1];
      fileHead.click();
      const names = [...$('importLog').querySelectorAll('tbody tr')].map(tr => tr.cells[1].textContent.trim());
      check('sắp theo tên file chạy đúng', names[0].startsWith('a.csv'), names.join(' , '));
    }
    console.log(report.join('\n'));
    console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
    process.exit(report.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
  }, 80);
}, 500);
