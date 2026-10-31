// Kiểm bốn việc: luân chuyển kèm linh kiện, mặc định trạng thái khi về kho,
// Kho tách riêng khỏi sơ đồ, và màn quản lý kho.
const fs = require('fs');
const { JSDOM, VirtualConsole } = require('jsdom');

const html = fs.readFileSync('index.html', 'utf8');
const data = JSON.parse(fs.readFileSync(process.argv[2] || require('path').join(__dirname, 'fixture-move.json'), 'utf8'));

const errors = [];
const vc = new VirtualConsole();
vc.on('jsdomError', e => errors.push(e.detail ? e.detail.stack : e.message));
vc.on('error', (...a) => errors.push(`console.error: ${a.join(' ')}`));

const calls = [];
const dom = new JSDOM(html, {
  runScripts: 'dangerously', pretendToBeVisual: true, virtualConsole: vc,
  url: 'http://localhost:8084/',
  beforeParse(w) {
    w.fetch = (u, o = {}) => {
      calls.push({ url: u, method: o.method || 'GET', body: o.body ? JSON.parse(o.body) : null });
      return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(
        u === 'api/me' ? { username: 'admin', fullName: 'T', role: 'admin' }
          : u === 'api/data' ? data : u === 'api/imports' ? { imports: [] }
            : { moved: 3, devices: 1, parts: 2, location: 'Kho', status: 'in_stock', warehouse: true }) });
    };
    w.confirm = () => true;
    w.MGMT_DEVICE_DATA = { meta: {}, assetRows: [], historyRows: [] };
  },
});
const w = dom.window, $ = id => w.document.getElementById(id);
const report = [];
const check = (l, ok, d = '') => report.push(`${ok ? 'PASS' : 'FAIL'}  ${l}${d ? ' — ' + d : ''}`);
const opts = s => [...s.options].map(o => o.label);

// Kho là cờ in_store trên tài sản, KHÔNG phải một site.
const byId = new Map(data.assetRows.map(a => [a.asset_id, a]));
const stored = data.assetRows.filter(a => a.in_store);
const withParts = data.assetRows.find(a => !a.parent_reference && !a.in_store
  && data.assetRows.some(o => o.parent_reference === a.asset_id));

setTimeout(() => {
  // ---- 3. Kho không nằm trong sơ đồ -------------------------------------
  w.document.querySelector('[data-view="diagram"]').click();
  check('sơ đồ không có nhánh nào tên Kho',
    ![...$('diagramTree').children].some(li => /kho/i.test(li.querySelector('.node-name').textContent)),
    [...$('diagramTree').children].map(li => li.querySelector('.node-name').textContent.trim()).join(', '));
  check('bộ lọc site của sơ đồ không có mục Kho', !opts($('diagramSite')).some(o => /^kho$/i.test(o)),
    opts($('diagramSite')).join(', '));
  check('ghi chú sơ đồ trỏ sang màn Kho',
    new RegExp(`${stored.length.toLocaleString('vi-VN')} tài sản đang nằm trong kho`).test($('diagramNote').textContent),
    $('diagramNote').textContent.match(/[^.]*nằm trong kho[^.]*/)?.[0]?.slice(0, 80) || '(không có)');

  // ---- 3+4. Màn quản lý kho ---------------------------------------------
  check('có mục Kho trên thanh điều hướng', Boolean(w.document.querySelector('[data-view="store"]')));
  w.document.querySelector('[data-view="store"]').click();
  const rows = [...$('storeRows').querySelectorAll('tr')];
  const inStore = stored.filter(a => !a.parent_reference);
  check('bảng kho chỉ liệt kê thiết bị có cờ in_store', rows.length > 0 && rows.every(tr => {
    const id = tr.querySelector('.asset-id')?.textContent.trim();
    return !id || Boolean(byId.get(id).in_store);
  }), `${rows.length} dòng / ${inStore.length} thiết bị trong kho`);
  check('màn Kho không còn ô chọn kho nào', !$('storeSite'));
  check('linh kiện không đứng thành dòng riêng trong kho', rows.every(tr => {
    const id = tr.querySelector('.asset-id')?.textContent.trim();
    return !id || !byId.get(id).parent_reference;
  }));
  const srvRow = rows.find(tr => tr.querySelector('.asset-id')?.textContent.trim() === 'TEST-MV-SRV');
  if (srvRow) {
    check('cột Linh kiện đi kèm liệt kê đúng',
      srvRow.children[5].textContent.includes('TEST-MV-DISK'), srvRow.children[5].textContent.trim());
    check('cột Vào kho lấy từ lịch sử',
      /\d{2}\/\d{2}\/\d{4}/.test(srvRow.children[6].textContent), srvRow.children[6].textContent.trim());
  }
  check('màn kho có số liệu tổng quan', $('storeMetrics').querySelectorAll('.metric').length === 4);
  check('từng dòng kho không còn nút thao tác nào',
    $('storeRows').querySelectorAll('.icon-button, .table-action').length === 0);

  // ---- 1+2. Form luân chuyển --------------------------------------------
  w.document.querySelector('[data-view="assets"]').click();
  const target = withParts ? withParts.asset_id : data.assetRows[0].asset_id;
  $('assetSearchFull').value = target;
  $('assetSearchFull').dispatchEvent(new w.Event('input', { bubbles: true }));
  $('assetRowsFull').querySelector('[data-action="open"]').click();
  check('hồ sơ chi tiết có nút Luân chuyển', Boolean($('drawerTransfer')));
  $('drawerTransfer').click();
  const form = w.document.querySelector('.modal-backdrop form');
  const names = [...form.querySelectorAll('[name]')].map(n => n.name);
  check('form luân chuyển có đủ ngày, vị trí, mô tả',
    ['event_date', 'datacenter', 'room_id', 'rack_id', 'rack_unit', 'usage_status', 'notes']
      .every(n => names.includes(n)), names.join(', '));
  check('ngày mặc định là hôm nay',
    form.querySelector('[name="event_date"]').value === new Date().toISOString().slice(0, 10));
  const subtitle = w.document.querySelector('.modal-backdrop .modal-head p').textContent;
  if (withParts) {
    const kids = data.assetRows.filter(a => a.parent_reference === withParts.asset_id);
    check('form kể tên linh kiện sẽ đi cùng',
      kids.every(k => subtitle.includes(k.asset_id)), subtitle.slice(0, 110));
    check('form nói rõ cách để lại linh kiện', /tháo nó ra trước/.test(subtitle));
  }
  // chọn kho -> trạng thái tự thành "trong kho"
  const siteSelect = form.querySelector('[name="datacenter"]');
  const statusSelect = form.querySelector('[name="usage_status"]');
  siteSelect.value = '__store__';
  siteSelect.dispatchEvent(new w.Event('change', { bubbles: true }));
  check('ô Chuyển tới có mục Trong kho', opts(siteSelect).some(o => /Trong kho/.test(o)), opts(siteSelect).join(', '));
  check('chọn Kho thì trạng thái tự về "Trong kho"', statusSelect.value === 'in_stock', statusSelect.value);
  check('chọn Kho thì ẩn phòng máy / rack / vị trí U',
    ['room_id', 'rack_id', 'rack_unit'].every(n =>
      form.querySelector(`[data-field="${n}"]`).classList.contains('hidden')));
  const other = data.locations.find(l => l.kind === 'location').site;
  siteSelect.value = other;
  siteSelect.dispatchEvent(new w.Event('change', { bubbles: true }));
  check(`chọn ${other} thì không ép trạng thái`, statusSelect.value !== 'in_stock', statusSelect.value);

  form.querySelector('[name="notes"]').value = 'thu hồi';
  siteSelect.value = '__store__';
  siteSelect.dispatchEvent(new w.Event('change', { bubbles: true }));
  form.dispatchEvent(new w.Event('submit', { bubbles: true, cancelable: true }));

  setTimeout(() => {
    const sent = calls.find(c => c.url === 'api/assets/transfer');
    check('bấm Lưu gửi POST /api/assets/transfer', Boolean(sent));
    check('gửi đúng mã tài sản, đích là kho, ngày và mô tả',
      sent && sent.body.ids.includes(target) && sent.body.in_store === '1' && !sent.body.datacenter
      && sent.body.notes === 'thu hồi' && Boolean(sent.body.event_date),
      sent ? JSON.stringify(sent.body).slice(0, 130) : '(không gửi)');
    check('về kho thì gửi kèm trạng thái in_stock', sent && sent.body.usage_status === 'in_stock',
      sent ? String(sent.body.usage_status) : '');

    // ---- Nút hàng loạt --------------------------------------------------
    $('assetSearchFull').value = '';
    $('assetSearchFull').dispatchEvent(new w.Event('input', { bubbles: true }));
    [...$('assetRowsFull').querySelectorAll('.row-select')].slice(0, 2).forEach(box => box.click());
    const bar = $('assetRowsFullBulk');
    check('thanh chọn nhiều có nút Luân chuyển', Boolean(bar.querySelector('.bulk-move')));
    check('thanh chọn nhiều có nút Chuyển về kho', Boolean(bar.querySelector('.bulk-store')));
    bar.querySelector('.bulk-store').click();
    const storeForm = [...w.document.querySelectorAll('.modal-backdrop form')].pop();
    check('Chuyển về kho chỉ có đúng một đích là Kho',
      opts(storeForm.querySelector('[name="datacenter"]')).join(',') === 'Kho',
      opts(storeForm.querySelector('[name="datacenter"]')).join(', '));
    check('chuyển nhiều máy thì ẩn ô vị trí U',
      storeForm.querySelector('[data-field="rack_unit"]').classList.contains('hidden'),
      `đang chọn ${w.document.querySelectorAll('#assetRowsFull .row-select:checked').length} máy`);

    console.log(report.join('\n'));
    console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
    process.exit(report.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
  }, 80);
}, 500);
