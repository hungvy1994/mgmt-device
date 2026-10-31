// Không có API: trang phải nói thẳng là bản chụp chỉ đọc và tắt mọi nút ghi.
const fs = require('fs');
const { JSDOM, VirtualConsole } = require('jsdom');
const html = fs.readFileSync('index.html', 'utf8');
const data = JSON.parse(fs.readFileSync('api-data.json', 'utf8'));
const errors = [];
const vc = new VirtualConsole();
vc.on('jsdomError', e => errors.push(e.message));
const dom = new JSDOM(html, {
  runScripts: 'dangerously', pretendToBeVisual: true, virtualConsole: vc,
  url: 'http://localhost:8080/',
  beforeParse(window) {
    window.fetch = () => Promise.reject(new Error('không có API'));
    window.MGMT_DEVICE_DATA = { meta: { source: 'static', assetCount: data.assetRows.length, eventCount: data.historyRows.length },
      assetRows: data.assetRows, historyRows: data.historyRows, statuses: data.statuses };
  },
});
const w = dom.window, $ = id => w.document.getElementById(id);
setTimeout(() => {
  const out = [];
  const check = (l, c, d = '') => out.push(`${c ? 'PASS' : 'FAIL'}  ${l}${d ? ' — ' + d : ''}`);
  check('màn đăng nhập báo không có database', /Không kết nối được database/.test($('loginMode').textContent), $('loginMode').textContent);
  $('loginForm').dispatchEvent(new w.Event('submit', { bubbles: true, cancelable: true }));
  setTimeout(() => {
    check('body ở chế độ chỉ đọc', w.document.body.classList.contains('read-only'));
    check('banner offline hiện', !$('offlineBanner').classList.contains('hidden'));
    check('vẫn xem được số liệu', $('mTotal').textContent === data.assetRows.length.toLocaleString('vi-VN'), $('mTotal').textContent);
    check('nguồn ghi rõ là bản chụp', /Bản chụp offline, chỉ đọc/.test($('sourceLabel').textContent), $('sourceLabel').textContent);
    const before = w.document.querySelectorAll('.modal-backdrop').length;
    $('newAssetBtn').click();
    check('bấm Thêm tài sản không mở form ghi', w.document.querySelectorAll('.modal-backdrop').length === before);
    console.log(out.join('\n'));
    console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
    process.exit(out.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
  }, 120);
}, 400);
