// Kiểm nhật ký thao tác: ai sửa gì, lúc nào, giá trị cũ là gì — trong hồ sơ tài sản và ở màn Dữ liệu.
const fs = require('fs');
const { JSDOM, VirtualConsole } = require('jsdom');
const html = fs.readFileSync('index.html', 'utf8');
const data = JSON.parse(fs.readFileSync(process.argv[2] || 'api-data.json', 'utf8'));
const target = data.assetRows.find(a => a.asset_id && !a.code_pending) || data.assetRows[0];

const entries = [
  { at: '2026-09-17T04:08:11+00:00', username: 'admin', action: 'sua', entity: 'asset',
    entityId: target.asset_id, note: '',
    changes: { asset_name: { cu: 'Tên cũ', moi: 'Tên mới' }, usage_status: { cu: 'in_use', moi: 'broken' } } },
  { at: '2026-09-17T04:07:02+00:00', username: 'admin', action: 'them', entity: 'asset',
    entityId: target.asset_id, note: 'mã do hệ thống cấp tạm',
    changes: { asset_id: { cu: null, moi: target.asset_id } } },
  { at: '2026-09-17T04:00:00+00:00', username: 'admin', action: 'xoa_sach', entity: 'data',
    entityId: 'records', note: 'xóa sạch phạm vi «records», tổng 12 bản ghi', changes: {} },
];

const errors = [];
const vc = new VirtualConsole();
vc.on('jsdomError', e => errors.push(e.detail ? e.detail.stack : e.message));
vc.on('error', (...a) => errors.push(`console.error: ${a.join(' ')}`));
const asked = [];
const dom = new JSDOM(html, {
  runScripts: 'dangerously', pretendToBeVisual: true, virtualConsole: vc,
  url: 'http://localhost:8084/',
  beforeParse(w) {
    w.fetch = u => {
      const url = String(u);
      asked.push(url);
      if (url.startsWith('api/audit')) {
        const rieng = url.includes('entity=asset');
        return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(
          { entries: rieng ? entries.filter(e => e.entity === 'asset') : entries }) });
      }
      return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(
        url === 'api/me' ? { username: 'admin', role: 'admin' } : url === 'api/data' ? data
          : url === 'api/imports' ? { imports: [] } : { ok: true }) });
    };
    w.confirm = () => true;
    w.MGMT_DEVICE_DATA = { meta: {}, assetRows: [], historyRows: [] };
  },
});
const w = dom.window, $ = id => w.document.getElementById(id);
const report = [];
const check = (l, ok, d = '') => report.push(`${ok ? 'PASS' : 'FAIL'}  ${l}${d ? ' — ' + d : ''}`);

setTimeout(async () => {
  // ---- 1. Nhật ký của riêng một tài sản, trong hồ sơ --------------------
  w.document.querySelector('[data-view="assets"]').click();
  $('assetSearchFull').value = target.asset_id;
  $('assetSearchFull').dispatchEvent(new w.Event('input', { bubbles: true }));
  $('assetRowsFull').rows[0].querySelector('.asset-link').click();
  await new Promise(r => setTimeout(r, 120));

  check('hồ sơ tài sản có mục Nhật ký thao tác', Boolean($('drawerAudit')));
  const hoiRieng = asked.find(u => u.startsWith('api/audit') && u.includes('entity=asset'));
  check('chỉ hỏi nhật ký CỦA TÀI SẢN ĐANG XEM, không tải cả kho',
    Boolean(hoiRieng) && hoiRieng.includes(encodeURIComponent(target.asset_id)), hoiRieng || '(không hỏi)');

  const t = $('drawerAudit').textContent;
  check('nói rõ ai thao tác', t.includes('admin'));
  check('nói rõ làm gì, bằng tiếng Việt', /Sửa/.test(t) && /Thêm/.test(t), t.slice(0, 60).replace(/\s+/g, ' '));
  check('hiện GIÁ TRỊ CŨ và giá trị mới', t.includes('Tên cũ') && t.includes('Tên mới'));
  check('ô trống hiện rõ là trống, không để khoảng trắng đánh lừa', t.includes('∅'));
  check('có ghi chú khi thao tác cần giải thích', t.includes('mã do hệ thống cấp tạm'));

  // ---- 2. Nhật ký chung ở màn Dữ liệu -----------------------------------
  w.document.querySelector('[data-view="data"]').click();
  await new Promise(r => setTimeout(r, 140));
  check('màn Dữ liệu có nhật ký thao tác chung', Boolean($('auditLog')));
  const g = $('auditLog').textContent;
  check('nhật ký chung gồm cả thao tác không phải tài sản',
    /Xóa sạch dữ liệu/.test(g), g.slice(0, 70).replace(/\s+/g, ' '));
  check('nhật ký chung nói rõ phạm vi việc nguy hiểm',
    g.includes('12 bản ghi'), (g.match(/tổng[^·]*/) || [''])[0].slice(0, 50));

  console.log(report.join('\n'));
  console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
  process.exit(report.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
}, 600);
