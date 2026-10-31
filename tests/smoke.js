// Smoke test: nạp index.html trong jsdom, giả lập API bằng dữ liệu thật lấy từ server,
// rồi bấm thử các nút thêm / sửa / xóa để xem trang có ném lỗi và có gọi đúng endpoint không.
const fs = require('fs');
const { JSDOM, VirtualConsole } = require('jsdom');

const html = fs.readFileSync('index.html', 'utf8');
const data = JSON.parse(fs.readFileSync('api-data.json', 'utf8'));
// Ảnh chụp thật có thể không còn sự kiện nào -> tự dựng một sự kiện để kiểm nút xóa.
if (!(data.historyRows || []).length) {
  data.historyRows = [{
    event_id: '9001', asset_id: data.assetRows[0].asset_id, event_sequence: 1,
    event_type: 'transfer', event_date: '2026-09-01', location: 'CMC Tân Thuận',
    notes: 'sự kiện dựng cho kiểm thử', origin: 'manual',
  }];
}

const errors = [];
const virtualConsole = new VirtualConsole();
virtualConsole.on('jsdomError', error => errors.push(`jsdomError: ${error.message}`));
virtualConsole.on('error', (...args) => errors.push(`console.error: ${args.join(' ')}`));

const calls = [];
function fakeFetch(url, options = {}) {
  const method = options.method || 'GET';
  calls.push(`${method} ${url}`);
  const reply = body => Promise.resolve({
    ok: true, status: 200, json: () => Promise.resolve(body),
  });
  if (url === 'api/me') return reply({ username: 'admin', fullName: 'Test', role: 'admin' });
  if (url === 'api/data') return reply(data);
  if (url === 'api/imports') return reply({ imports: [
    { kind: 'assets', fileName: 'x.xlsx', fileType: 'xlsx', rows: 3, added: 1, updated: 2, skipped: 0, username: 'admin', at: '2026-09-14T03:00:00+00:00' },
  ] });
  if (url.startsWith('api/assets/') && method === 'DELETE') return reply({ deleted: 'x', deletedEvents: 2 });
  if (url.startsWith('api/events/') && method === 'DELETE') return reply({ deleted: 1 });
  return reply({ ok: true, updated: 1, deleted: 1 });
}

const dom = new JSDOM(html, {
  runScripts: 'dangerously', pretendToBeVisual: true, virtualConsole,
  url: 'http://localhost:8084/',
  beforeParse(window) {
    window.fetch = fakeFetch;
    window.confirm = () => true;
    window.MGMT_DEVICE_DATA = { meta: {}, assetRows: [], historyRows: [] };
    window.URL.createObjectURL = () => 'blob:x';
    window.URL.revokeObjectURL = () => {};
  },
});

const { window } = dom;
const $ = id => window.document.getElementById(id);

setTimeout(() => {
  const report = [];
  const check = (label, condition, detail = '') =>
    report.push(`${condition ? 'PASS' : 'FAIL'}  ${label}${detail ? ' — ' + detail : ''}`);

  check('vào thẳng app sau khi /api/me trả 200', $('appShell') && !$('appShell').className.includes('hidden'));
  check('thoát chế độ chỉ đọc khi có API', !window.document.body.classList.contains('read-only'));
  check('banner offline ẩn', $('offlineBanner').classList.contains('hidden'));
  check('tổng tài sản lấy từ API', $('mTotal').textContent === data.assetRows.length.toLocaleString('vi-VN'),
    `hiển thị ${$('mTotal').textContent}, dữ liệu ${data.assetRows.length}`);
  check('dòng nguồn nói về database', /Database Postgres/.test($('sourceLabel').textContent),
    $('sourceLabel').textContent);
  check('không còn nhắc file xlsx như nguồn', !/BAO CAO/.test(window.document.body.textContent));
  check('bảng tài sản có dòng', $('assetRows').querySelectorAll('tr').length > 0);

  // Trang Nhập / Xuất
  window.document.querySelector('[data-view="data"]').click();
  check('đã bỏ đoạn mô tả đầu khung Nơi lưu dữ liệu', !$('datasetSource'));
  check('có nút xuất XLSX', Boolean($('exportAssetsXlsx') && $('exportHistoryXlsx')));
  check('input nhận cả xlsx', $('assetCsvInput').getAttribute('accept').includes('.xlsx'));

  setTimeout(() => {
    check('nhật ký nhập hiện dòng', /x\.xlsx/.test($('importLog').textContent), $('importLog').textContent.slice(0, 60));

    // Mở hồ sơ một tài sản rồi bấm Sửa -> gửi PUT
    const first = data.assetRows[0].asset_id;
    window.document.querySelector('[data-view="assets"]').click();
    const openButton = $('assetRowsFull').querySelector('[data-action="open"]');
    openButton.click();
    check('mở được hồ sơ chi tiết', $('detailDrawer').classList.contains('open'));
    check('ghi rõ bản ghi từ đâu vào', /Nạp từ file|Nhập tay/.test($('drawerMetaNote').textContent),
      $('drawerMetaNote').textContent);

    $('drawerEdit').click();
    const form = window.document.querySelector('.modal-backdrop form');
    check('form sửa mở ra', Boolean(form));
    check('form có đủ trường', form.querySelectorAll('[name]').length >= 21,
      `${form.querySelectorAll('[name]').length} trường`);
    check('form dùng tên cột API', Boolean(form.querySelector('[name="purchase_invoice"]')));
    form.dispatchEvent(new window.Event('submit', { bubbles: true, cancelable: true }));

    setTimeout(() => {
      check('bấm Lưu gửi PUT /api/assets', calls.some(c => c.startsWith(`PUT api/assets/${first}`)),
        calls.filter(c => c.includes('api/assets')).join(' | ') || '(không gọi)');

      // Xóa một sự kiện lịch sử
      const eventButton = $('drawerTimeline').querySelector('.delete-event');
      if (eventButton) eventButton.click();
      setTimeout(() => {
        check('xóa sự kiện gọi DELETE /api/events/<id>',
          calls.some(c => /^DELETE api\/events\/\d+$/.test(c)),
          calls.filter(c => c.includes('api/events')).join(' | ') || '(không có sự kiện để xóa)');

        // Thêm trạng thái
        window.document.querySelector('[data-view="statuses"]').click();
        $('newStatus').click();
        const statusForm = window.document.querySelector('.modal-backdrop form');
        statusForm.querySelector('[name="code"]').value = 'tmp';
        statusForm.querySelector('[name="label"]').value = 'Tam';
        statusForm.dispatchEvent(new window.Event('submit', { bubbles: true, cancelable: true }));
        setTimeout(() => {
          check('thêm trạng thái gọi POST /api/statuses', calls.includes('POST api/statuses'));

          // Thêm vị trí
          window.document.querySelector('[data-view="locations"]').click();
          $('newLocation').click();
          const locationForm = window.document.querySelector('.modal-backdrop form');
          locationForm.querySelector('[name="siteName"]').value = 'Site tam';
          locationForm.dispatchEvent(new window.Event('submit', { bubbles: true, cancelable: true }));
          setTimeout(() => {
            check('thêm vị trí gọi POST /api/locations', calls.includes('POST api/locations'));
            check('danh mục vị trí lấy từ API', $('locationCrud').textContent.includes(data.locations[0].site));

            console.log(report.join('\n'));
            console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
            console.log('\ntất cả lời gọi API:\n ' + [...new Set(calls)].join('\n '));
            process.exit(report.some(line => line.startsWith('FAIL')) || errors.length ? 1 : 0);
          }, 60);
        }, 60);
      }, 60);
    }, 60);
  }, 80);
}, 400);
