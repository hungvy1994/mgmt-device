// Kiểm mục "Phòng ban khác": danh sách mẫu, bộ sửa mẫu, khuôn lấy dữ liệu và bảng đổi từ vựng.
const fs = require('fs');
const { JSDOM, VirtualConsole } = require('jsdom');
const html = fs.readFileSync('index.html', 'utf8');
const data = JSON.parse(fs.readFileSync(process.argv[2] || 'api-data.json', 'utf8'));

const MAU = [
  { id: 4, name: 'Kiểm kê thiết bị SA → ERP', note: 'nạp thẳng vào ERP', fileName: 'erp.xlsx',
    sheetName: 'Dữ liệu làm sạch sẽ up lên ERP', headerRows: 2, scope: {},
    maps: { trang_thai_erp: { in_use: 'Đang sử dụng', '*': '' } },
    colDefs: [
      { header1: 'PHÂN LOẠI TÀI SẢN', header2: 'Equipment/Equipment Category/Category Name',
        mau: 'Thiết Bị System Admin', bang: '', kieu: 'chu' },
      { header1: 'MÃ TÀI SẢN', header2: 'Equipment/Product Information/Serial Number',
        mau: '$ma_hien_thi', bang: '', kieu: 'chu' },
      { header1: 'TRẠNG THÁI', header2: 'Equipment/Equipment state',
        mau: '${usage_status|trang_thai_erp}', bang: '', kieu: 'chu' },
    ] },
  { id: 5, name: 'Kiểm kê hàng trong kho', note: '', fileName: 'kho.xlsx', sheetName: 'Tồn kho',
    headerRows: 1, scope: { in_store: '1' }, maps: {},
    colDefs: [{ header1: 'STT', header2: '', mau: '$stt', bang: '', kieu: 'so' }] },
];
const TRUONG = [
  { ten: 'asset_id', mo_ta: 'Cột của tài sản' },
  { ten: 'asset_name', mo_ta: 'Cột của tài sản' },
  { ten: 'cluster', mo_ta: 'Cột của tài sản' },
  { ten: 'ma_hien_thi', mo_ta: 'Mã tài sản, để trống nếu là mã tạm' },
  { ten: 'site', mo_ta: 'Tên site' },
];
const gui = [];

const errors = [];
const vc = new VirtualConsole();
vc.on('jsdomError', e => errors.push(e.detail ? e.detail.stack : e.message));
vc.on('error', (...a) => errors.push(`console.error: ${a.join(' ')}`));
const dom = new JSDOM(html, {
  runScripts: 'dangerously', pretendToBeVisual: true, virtualConsole: vc,
  url: 'http://localhost:8084/',
  beforeParse(w) {
    w.fetch = (u, o = {}) => {
      const url = String(u), method = o.method || 'GET';
      if (url === 'api/export-templates/preview') {
        gui.push({ xem_truoc: JSON.parse(o.body) });
        return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve({
          headers: [['A', 'B'], ['a2', 'b2']], rows: [['x', ''], ['y', 'z']], total: 1232, shown: 2 }) });
      }
      if (url.startsWith('api/export-templates') && (method === 'POST' || method === 'PUT')) {
        const body = JSON.parse(o.body);
        gui.push({ luu: body, method });
        return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve({ template: body }) });
      }
      if (url.startsWith('api/export-templates/') && method === 'DELETE') {
        gui.push({ xoa: url });
        return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve({ deleted: 'x' }) });
      }
      return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(
        url === 'api/me' ? { username: 'admin', role: 'admin' } : url === 'api/data' ? data
          : url === 'api/imports' ? { imports: [] } : url === 'api/users' ? { users: [], roles: [] }
          : url.startsWith('api/audit') ? { entries: [] }
          : url === 'api/export-templates' ? { templates: MAU, fields: TRUONG }
          : { ok: true }) });
    };
    w.confirm = () => true;
    w.MGMT_DEVICE_DATA = { meta: {}, assetRows: [], historyRows: [] };
  },
});
const w = dom.window, $ = id => w.document.getElementById(id);
const report = [];
const check = (l, ok, d = '') => report.push(`${ok ? 'PASS' : 'FAIL'}  ${l}${d ? ' — ' + d : ''}`);

setTimeout(async () => {
  const nut = w.document.querySelector('[data-view="exports"]');
  check('thanh điều hướng có mục Phòng ban khác', Boolean(nut));
  check('mục nằm cạnh Nhập / Xuất, không lẫn vào Admin',
    Boolean(nut) && nut.previousElementSibling?.dataset.view === 'data');
  nut.click();
  await new Promise(r => setTimeout(r, 200));

  check('mở ra màn riêng', $('exportsView').classList.contains('active'));
  const ds = $('exportList').textContent;
  check('liệt kê từng mẫu theo tên', ds.includes('Kiểm kê thiết bị SA → ERP') && ds.includes('Kiểm kê hàng trong kho'));
  check('nói rõ mỗi mẫu có bao nhiêu cột', ds.includes('3 cột') && ds.includes('1 cột'));
  check('nói rõ số dòng tiêu đề', ds.includes('2 dòng tiêu đề'));
  check('nói rõ phạm vi lấy dữ liệu', ds.includes('toàn bộ tài sản') && ds.includes('chỉ hàng trong kho'));
  check('mỗi mẫu có nút xuất file riêng',
    w.document.querySelectorAll('#exportList [data-xuat]').length === 2);

  // ---- mở bộ sửa mẫu
  w.document.querySelector('#exportList [data-sua="4"]').click();
  await new Promise(r => setTimeout(r, 120));
  check('bấm Sửa thì mở bộ khai mẫu', !$('exportEditPane').classList.contains('hidden'));
  check('danh sách tạm ẩn đi, không chồng lên nhau', $('exportListPane').classList.contains('hidden'));
  check('điền sẵn tên mẫu đang sửa', $('exName').value === 'Kiểm kê thiết bị SA → ERP', $('exName').value);
  check('điền sẵn tên sheet', $('exSheet').value === 'Dữ liệu làm sạch sẽ up lên ERP');
  check('điền sẵn số dòng tiêu đề', $('exHeaderRows').value === '2');

  const hang = w.document.querySelectorAll('#exportCols tbody tr');
  check('hiện đủ số cột của mẫu', hang.length === 3, `${hang.length}`);
  check('đánh nhãn cột kiểu Excel để đối chiếu với file bên nhận',
    hang[0].querySelector('.mono').textContent === 'A' && hang[2].querySelector('.mono').textContent === 'C');
  check('hiện đúng khuôn lấy dữ liệu',
    hang[1].querySelector('[name=mau]').value === '$ma_hien_thi');
  check('khuôn hằng số giữ nguyên chữ, không bị coi là trường',
    hang[0].querySelector('[name=mau]').value === 'Thiết Bị System Admin');

  // bảng đổi từ vựng hiện dạng đọc được
  const maps = $('exMaps').value;
  check('bảng đổi từ vựng hiện dạng đọc được', /\[trang_thai_erp\]/.test(maps) && /in_use = Đang sử dụng/.test(maps));

  // ---- thêm cột KHÔNG được làm mất phần đang gõ dở
  $('exName').value = 'Tên vừa sửa';
  hang[2].querySelector('[name=h1]').value = 'TIÊU ĐỀ VỪA GÕ';
  $('exAddCol').click();
  await new Promise(r => setTimeout(r, 80));
  check('thêm cột thì có thêm một dòng', w.document.querySelectorAll('#exportCols tbody tr').length === 4);
  check('thêm cột KHÔNG làm mất tên đang gõ dở', $('exName').value === 'Tên vừa sửa', $('exName').value);
  check('thêm cột KHÔNG làm mất tiêu đề đang gõ dở',
    w.document.querySelectorAll('#exportCols tbody tr')[2].querySelector('[name=h1]').value === 'TIÊU ĐỀ VỪA GÕ');

  // ---- chèn trường vào khuôn bằng cách bấm chip
  const oKhuon = w.document.querySelectorAll('#exportCols tbody tr')[3].querySelector('[name=mau]');
  oKhuon.focus();
  w.document.querySelector('#exFields [data-truong="cluster"]').click();
  check('bấm tên trường thì chèn vào ô khuôn đang sửa', oKhuon.value === '$cluster', oKhuon.value);

  // ---- đưa cột lên
  w.document.querySelectorAll('#exportCols [data-len]')[1].click();
  await new Promise(r => setTimeout(r, 80));
  check('nút ↑ đổi được thứ tự cột',
    w.document.querySelectorAll('#exportCols tbody tr')[0].querySelector('[name=h1]').value === 'MÃ TÀI SẢN');

  // ---- xem trước
  $('exPreview').click();
  await new Promise(r => setTimeout(r, 150));
  const xt = gui.find(g => g.xem_truoc);
  check('xem trước gửi cả khai báo đang sửa, không cần lưu trước', Boolean(xt));
  check('xem trước xin đúng số dòng mẫu', xt && xt.xem_truoc.limit === 10);
  check('xem trước dựng bảng đúng số dòng tiêu đề',
    $('exPreviewBox').querySelectorAll('thead tr').length === 2);
  check('xem trước nói rõ đang xem mấy dòng trên tổng bao nhiêu',
    /1.232/.test($('exPreviewBox').textContent), $('exPreviewBox').textContent.slice(0, 60));
  check('ô trống trong xem trước hiện Null chứ không bỏ trắng',
    $('exPreviewBox').querySelector('tbody .nul') !== null);

  // ---- lưu
  $('exMaps').value = '[moi]\nabc = XYZ\n* =';
  $('exSave').click();
  await new Promise(r => setTimeout(r, 150));
  const luu = gui.find(g => g.luu);
  check('lưu gửi phương thức PUT khi sửa mẫu đã có', luu && luu.method === 'PUT', luu && luu.method);
  check('lưu gửi tên mẫu vừa sửa', luu && luu.luu.name === 'Tên vừa sửa');
  check('bảng đổi từ vựng được đọc từ chữ thành cặp giá trị',
    luu && luu.luu.maps.moi && luu.luu.maps.moi.abc === 'XYZ', JSON.stringify(luu && luu.luu.maps));
  check('giữ được dòng * làm giá trị mặc định',
    luu && luu.luu.maps.moi && luu.luu.maps.moi['*'] === '');
  check('lưu gửi đủ các cột', luu && luu.luu.col_defs.length === 4, luu && String(luu.luu.col_defs.length));
  check('mỗi cột gửi đủ tiêu đề, khuôn, bảng đổi và kiểu ô',
    luu && luu.luu.col_defs.every(c => 'header1' in c && 'header2' in c && 'mau' in c && 'bang' in c && 'kieu' in c));
  check('phạm vi gửi kèm', luu && luu.luu.scope && 'in_store' in luu.luu.scope);
  check('lưu xong quay lại danh sách', !$('exportListPane').classList.contains('hidden'));

  // ---- mẫu mới
  $('newExportTemplate').click();
  await new Promise(r => setTimeout(r, 100));
  check('nút Thêm mẫu mở bộ khai trống', $('exName').value === '' && !$('exportEditPane').classList.contains('hidden'));
  check('mẫu mới có sẵn một cột để khỏi bắt đầu từ bảng rỗng',
    w.document.querySelectorAll('#exportCols tbody tr').length === 1);

  check('không có lỗi JS nào', errors.length === 0, errors.join(' | ').slice(0, 200));
  report.forEach(line => console.log(line));
  const fail = report.filter(line => line.startsWith('FAIL')).length;
  console.log(`\n${report.length - fail} PASS · ${fail} FAIL`);
  process.exit(fail ? 1 : 0);
}, 400);
