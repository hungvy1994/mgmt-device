// Kiểm: thanh chọn nhiều nổi trên cạnh dưới bảng (không đẩy nội dung), và màn Trạng thái
// đã bỏ mục chữ nguyên văn.
const fs = require('fs');
const { JSDOM, VirtualConsole } = require('jsdom');
const html = fs.readFileSync('index.html', 'utf8');
const data = JSON.parse(fs.readFileSync(process.argv[2] || 'api-data.json', 'utf8'));
if (!data.assetTypes) data.assetTypes = [{ code: 'server', label: 'Server', note: '' }];

const errors = [];
const vc = new VirtualConsole();
vc.on('jsdomError', e => errors.push(e.detail ? e.detail.stack : e.message));
vc.on('error', (...a) => errors.push(`console.error: ${a.join(' ')}`));
const dom = new JSDOM(html, { runScripts: 'dangerously', pretendToBeVisual: true, virtualConsole: vc,
  url: 'http://localhost:8084/',
  beforeParse(w) {
    w.fetch = u => Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(
      u === 'api/me' ? { username: 'admin', fullName: 'T', role: 'admin' }
        : u === 'api/data' ? data : u === 'api/imports' ? { imports: [] } : { ok: true }) });
    w.confirm = () => true;
    w.MGMT_DEVICE_DATA = { meta: {}, assetRows: [], historyRows: [] };
  } });
const w = dom.window, $ = id => w.document.getElementById(id);
const report = [];
const check = (l, ok, d = '') => report.push(`${ok ? 'PASS' : 'FAIL'}  ${l}${d ? ' — ' + d : ''}`);

setTimeout(() => {
  // ---- 1. Thanh chọn nhiều ----------------------------------------------
  const cases = [['Tổng quan', 'overview', 'assetRows'],
                 ['Danh mục tài sản', 'assets', 'assetRowsFull'],
                 ['Kho', 'store', 'storeRows']];
  cases.forEach(([label, view, body]) => {
    w.document.querySelector(`[data-view="${view}"]`).click();
    const bar = $(`${body}Bulk`);
    const wrap = $(body).closest('.table-wrap');
    check(`${label}: thanh chọn nằm TRONG khung bảng`, wrap.contains(bar));
    check(`${label}: nằm sau bảng, bám cạnh dưới`,
      bar.previousElementSibling?.tagName === 'TABLE');
    const style = w.getComputedStyle(bar);
    check(`${label}: dính cạnh dưới, không chiếm chỗ trong dòng chảy`,
      style.position === 'sticky' && style.bottom === '0px',
      `position=${style.position} bottom=${style.bottom}`);
    check(`${label}: chưa chọn gì thì ẩn hẳn`, style.display === 'none' && !bar.classList.contains('show'));

    // chọn một dòng -> bảng và phân trang KHÔNG bị đẩy đi đâu
    const box = $(body).querySelector('.row-select');
    if (box) {
      const before = $(body).rows.length;
      box.click();
      check(`${label}: chọn rồi thì thanh hiện ra`, bar.classList.contains('show'));
      check(`${label}: số dòng của bảng không đổi`, $(body).rows.length === before,
        `${before} → ${$(body).rows.length}`);
        check(`${label}: phân trang vẫn nằm ngoài khung bảng`,
        !wrap.contains($(`${body}Pager`)));
      const wrapStyle = w.getComputedStyle(wrap);
      check(`${label}: khung bảng có cuộn nên thanh không chiếm chỗ`,
        wrapStyle.overflow === 'auto' && parseFloat(wrapStyle.maxHeight) > 0,
        `overflow=${wrapStyle.overflow} max=${wrapStyle.maxHeight}`);
      box.click();
    }
  });

  // ---- 2. Màn Trạng thái bỏ mục chữ nguyên văn ---------------------------
  w.document.querySelector('[data-view="statuses"]').click();
  check('không còn mục "Chữ nguyên văn"', !$('statusRawList') && !$('statusRawNote'));
  check('không còn tiêu đề của mục đó',
    !/Chữ nguyên văn/.test($('statusesView').textContent),
    $('statusesView').textContent.match(/.{0,30}nguyên văn.{0,20}/)?.[0] || '(sạch)');
  check('danh mục trạng thái vẫn còn nguyên',
    $('statusCrud').querySelectorAll('tbody tr').length === data.statuses.length,
    `${$('statusCrud').querySelectorAll('tbody tr').length} dòng`);
  check('vẫn sửa được trạng thái', Boolean($('statusCrud').querySelector('.edit-status')));

  console.log(report.join('\n'));
  console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
  process.exit(report.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
}, 500);
