// Kiểm phần sao lưu trong mục Admin: bật/tắt, lịch chạy, giữ bao nhiêu bản.
const fs = require('fs');
const { JSDOM, VirtualConsole } = require('jsdom');
const html = fs.readFileSync('index.html', 'utf8');
const data = JSON.parse(fs.readFileSync(process.argv[2] || 'api-data.json', 'utf8'));

let cfg = { enabled: true, hour: 2, minute: 30, keep: 7,
  lastRunAt: '2026-09-17T04:32:59+00:00', lastStatus: 'chạy tay · mgmt-device-20260917-043259.sql.gz' };
const files = [
  { name: 'mgmt-device-20260917-043334.sql.gz', bytes: 22723, at: '2026-09-17T04:33:34+00:00' },
  { name: 'mgmt-device-20260917-043332.sql.gz', bytes: 22700, at: '2026-09-17T04:33:32+00:00' },
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
      const url = String(u);
      if (url === 'api/backup' && (o.method || 'GET') === 'PUT') {
        gui.push(JSON.parse(o.body));
        cfg = { ...cfg, ...JSON.parse(o.body) };
        return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve({ config: cfg }) });
      }
      if (url === 'api/backup/run') {
        gui.push({ chay_ngay: true });
        return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(
          { ok: true, name: 'mgmt-device-moi.sql.gz', bytes: 23000, files }) });
      }
      return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(
        url === 'api/me' ? { username: 'admin', role: 'admin' } : url === 'api/data' ? data
          : url === 'api/imports' ? { imports: [] } : url === 'api/users' ? { users: [], roles: [] }
          : url.startsWith('api/audit') ? { entries: [] }
          : url === 'api/backup' ? { config: cfg, files, totalBytes: 45423, dir: '/backups' }
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
  w.document.querySelector('[data-view="admin"]').click();
  await new Promise(r => setTimeout(r, 200));

  check('mục Admin có phần sao lưu database', Boolean($('backupPanel')));
  check('có ô bật/tắt sao lưu tự động', Boolean($('backupEnabled')));
  check('có ô đặt lịch chạy', Boolean($('backupTime')));
  check('có ô đặt số bản giữ lại', Boolean($('backupKeep')));

  check('ô bật/tắt hiện đúng trạng thái đang lưu', $('backupEnabled').value === '1');
  check('lịch hiện đúng giờ đã lưu', $('backupTime').value === '02:30', $('backupTime').value);
  check('số bản giữ hiện đúng', $('backupKeep').value === '7', $('backupKeep').value);
  check('ô số bản có chặn khoảng hợp lệ',
    $('backupKeep').min === '1' && $('backupKeep').max === '365');

  const t = $('backupPanel').textContent;
  check('liệt kê các bản sao đang có', t.includes('mgmt-device-20260917-043334.sql.gz'));
  check('hiện dung lượng dạng người đọc được', /22(\.2)?\s?KB/.test(t), (t.match(/\d+(\.\d)?\s?KB/) || [''])[0]);
  check('nói rõ lần chạy gần nhất', /Lần gần nhất/.test(t));
  check('chỉ chỗ phục hồi ra sao', /gunzip/.test(t) && /psql/.test(t));

  // đổi cấu hình
  $('backupEnabled').value = '';
  $('backupTime').value = '23:45';
  $('backupKeep').value = '30';
  $('backupSave').click();
  await new Promise(r => setTimeout(r, 150));
  const luu = gui.find(g => 'keep' in g);
  check('lưu cấu hình gửi đúng bật/tắt, giờ, phút, số bản',
    luu && luu.enabled === false && luu.hour === 23 && luu.minute === 45 && luu.keep === 30,
    JSON.stringify(luu));

  // chạy tay
  $('backupNow').click();
  await new Promise(r => setTimeout(r, 150));
  check('nút Sao lưu ngay gọi đúng endpoint', gui.some(g => g.chay_ngay));
  // Nút sao lưu tay phải là hành động riêng, không nép trong hàng nút của form cấu hình
  const nut = $('backupNow');
  check('nút sao lưu tay đứng riêng, không chung hàng với nút Lưu cấu hình',
    nut.parentElement !== $('backupSave').parentElement,
    `${nut.parentElement.className} / ${$('backupSave').parentElement.className}`);
  check('nút sao lưu tay là nút chính, không phải nút phụ',
    nut.classList.contains('primary'), nut.className);
  check('có câu giải thích khi nào nên dùng',
    /không phụ thuộc lịch/.test(nut.closest('.toolbar-row').textContent));

  console.log(report.join('\n'));
  console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
  process.exit(report.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
}, 600);
