// Kiểm: báo trùng ngay trong form, mã để trống -> "Chưa gán mã", nhân bản nhanh.
const fs = require('fs');
const { JSDOM, VirtualConsole } = require('jsdom');

const html = fs.readFileSync('index.html', 'utf8');
const data = JSON.parse(fs.readFileSync(process.argv[2] || 'api-data.json', 'utf8'));
if (!data.assetTypes) {
  data.assetTypes = [...new Set(data.assetRows.map(a => a.asset_type).filter(Boolean))]
    .map(code => ({ code, label: code, note: '' }));
}
// dựng sẵn một bản ghi chưa gán mã và một máy chiếm sẵn U trong rack
const rack = data.locations.find(l => l.kind === 'rack');
data.assetRows.unshift({
  asset_id: 'CHUA-GAN-0009', code_pending: '1', asset_name: 'Máy chưa biết mã',
  asset_type: 'server', usage_status: 'in_stock', in_store: '1', origin: 'manual',
});
const holder = data.assetRows.find(a => a.rack_id === rack?.rackId && a.rack_unit);
const occupied = holder || (rack ? Object.assign(data.assetRows[1], {
  datacenter: rack.site, rack: rack.rack, rack_id: rack.rackId, rack_unit: '21', rack_label: rack.rack,
}) : null);

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
      calls.push({ url: u, method: o.method || 'GET', body: o.body && typeof o.body === 'string' ? JSON.parse(o.body) : null });
      return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(
        u === 'api/me' ? { username: 'admin', fullName: 'T', role: 'admin' }
          : u === 'api/data' ? data : u === 'api/imports' ? { imports: [] }
            : { asset: { asset_id: 'MOI-01' } }) });
    };
    w.confirm = () => true;
    w.MGMT_DEVICE_DATA = { meta: {}, assetRows: [], historyRows: [] };
  },
});
const w = dom.window, $ = id => w.document.getElementById(id);
const report = [];
const check = (l, ok, d = '') => report.push(`${ok ? 'PASS' : 'FAIL'}  ${l}${d ? ' — ' + d : ''}`);
const lastModal = () => [...w.document.querySelectorAll('.modal-backdrop')].pop();
const errorOf = (form, name) => form.querySelector(`[data-field="${name}"] .field-error`)?.textContent || '';
const submit = form => form.dispatchEvent(new w.Event('submit', { bubbles: true, cancelable: true }));

setTimeout(async () => {
  w.document.querySelector('[data-view="assets"]').click();

  // ---- 2. Mã để trống -> hiển thị "Chưa gán mã" --------------------------
  $('assetSearchFull').value = 'CHUA-GAN-0009';
  $('assetSearchFull').dispatchEvent(new w.Event('input', { bubbles: true }));
  const pendingCell = $('assetRowsFull').rows[0].cells[2];
  check('bảng hiện "Chưa gán mã", không phơi mã tạm ra',
    pendingCell.textContent.includes('Chưa gán mã') && !pendingCell.textContent.includes('CHUA-GAN'),
    pendingCell.textContent.trim());
  $('assetRowsFull').rows[0].querySelector('.asset-link').click();
  check('hồ sơ chi tiết cũng ghi "Chưa gán mã"',
    $('drawerEyebrow').textContent.includes('Chưa gán mã'), $('drawerEyebrow').textContent.trim());
  $('drawerEdit').click();
  let form = lastModal().querySelector('form');
  check('sửa bản ghi chưa gán mã thì ô mã để TRỐNG, không điền mã tạm',
    form.querySelector('[name="asset_id"]').value === '',
    `«${form.querySelector('[name="asset_id"]').value}»`);
  check('ô mã không còn bắt buộc, có gợi ý để trống',
    !form.querySelector('[name="asset_id"]').required
    && /Để trống/.test(form.querySelector('[name="asset_id"]').placeholder),
    form.querySelector('[name="asset_id"]').placeholder);
  lastModal().querySelector('.modal-close').click();

  // ---- 1. Kiểm trùng ngay trong form -------------------------------------
  $('newAssetBtnFull').click();
  form = lastModal().querySelector('form');
  const code = form.querySelector('[name="asset_id"]');
  const taken = data.assetRows.find(a => !a.code_pending).asset_id;
  code.value = taken;
  code.dispatchEvent(new w.Event('input', { bubbles: true }));
  check('gõ mã đã có là báo lỗi ngay, chưa cần bấm Lưu',
    /đã là của/.test(errorOf(form, 'asset_id')), errorOf(form, 'asset_id'));
  check('ô sai được tô khác đi',
    form.querySelector('[data-field="asset_id"]').classList.contains('has-error'));
  code.value = 'MA-CHUA-AI-DUNG';
  code.dispatchEvent(new w.Event('input', { bubbles: true }));
  check('sửa lại mã khác thì lỗi biến mất', errorOf(form, 'asset_id') === '');

  // tên bỏ trống -> chặn; tên trùng -> cho qua
  form.querySelector('[name="asset_name"]').value = '';
  submit(form);
  await new Promise(r => setTimeout(r, 60));
  check('thiếu tên tài sản thì báo ngay dưới ô tên',
    /bắt buộc/.test(errorOf(form, 'asset_name')), errorOf(form, 'asset_name'));
  check('chưa gửi gì khi form còn lỗi', !calls.some(c => c.url === 'api/assets' && c.method === 'POST'));

  if (occupied) {
    form.querySelector('[name="asset_name"]').value = 'Máy trùng tên';   // tên trùng vẫn cho
    const place = form.querySelector('[name="datacenter"]');
    place.value = occupied.datacenter;
    place.dispatchEvent(new w.Event('change', { bubbles: true }));
    const rackSelect = form.querySelector('[name="rack_id"]');
    rackSelect.value = occupied.rack_id;
    rackSelect.dispatchEvent(new w.Event('change', { bubbles: true }));
    const unit = form.querySelector('[name="rack_unit"]');
    unit.value = occupied.rack_unit;
    unit.dispatchEvent(new w.Event('input', { bubbles: true }));
    check(`gõ vị trí U đã có máy (${occupied.rack_unit}) là báo ngay`,
      /đang là chỗ của/.test(errorOf(form, 'rack_unit')), errorOf(form, 'rack_unit'));
    // Tìm ô U thật sự còn trống trong đúng rack đó, đừng gõ cứng một con số
    const taken = new Set(data.assetRows
      .filter(a => a.rack_id === occupied.rack_id && a.rack_unit)
      // máy 2U ở U42 chiếm cả U43 -> tính cả dải U, không chỉ U bắt đầu
      .flatMap(a => Array.from({ length: Math.max(Number(a.rack_size_u) || 1, 1) },
        (_, i) => String(Number(a.rack_unit) + i))));
    let free = 1; while (taken.has(String(free)) && free < 60) free += 1;
    unit.value = String(free);
    unit.dispatchEvent(new w.Event('input', { bubbles: true }));
    check(`đổi sang U trống (U${free}) thì lỗi biến mất`, errorOf(form, 'rack_unit') === '',
      errorOf(form, 'rack_unit'));
  }
  lastModal().querySelector('.modal-close').click();

  // ---- 3. Nhân bản nhanh --------------------------------------------------
  const source = data.assetRows.find(a => !a.code_pending && a.asset_name);
  $('assetSearchFull').value = source.asset_id;
  $('assetSearchFull').dispatchEvent(new w.Event('input', { bubbles: true }));
  $('assetRowsFull').rows[0].querySelector('.asset-link').click();
  check('hồ sơ chi tiết có nút Nhân bản', Boolean($('drawerClone')), $('drawerClone')?.textContent.trim());
  $('drawerClone').click();
  form = lastModal().querySelector('form');
  check('tiêu đề nói rõ đang nhân bản từ bản nào',
    // mã hiển thị viết hoa -> so không phân biệt hoa thường
    lastModal().querySelector('.modal-head h2').textContent.toLowerCase().includes(source.asset_id.toLowerCase()),
    lastModal().querySelector('.modal-head h2').textContent.trim());
  check('mã để trống để điền mã mới', form.querySelector('[name="asset_id"]').value === '');
  check('vị trí U để trống vì không được trùng', form.querySelector('[name="rack_unit"]').value === '');
  check('tên và các thông tin khác chép nguyên',
    form.querySelector('[name="asset_name"]').value === source.asset_name
    && form.querySelector('[name="asset_type"]').value === source.asset_type,
    `${form.querySelector('[name="asset_name"]').value} · ${form.querySelector('[name="asset_type"]').value}`);
  form.querySelector('[name="asset_id"]').value = 'BAN-SAO-01';
  submit(form);
  await new Promise(r => setTimeout(r, 80));
  const created = calls.find(c => c.url === 'api/assets' && c.method === 'POST');
  check('lưu bản nhân bản gọi POST (tạo mới), không phải PUT', Boolean(created));
  check('gửi mã mới và giữ nguyên thông tin gốc',
    created && created.body.asset_id === 'BAN-SAO-01' && created.body.asset_name === source.asset_name,
    created ? `${created.body.asset_id} · ${created.body.asset_name}` : '(không gửi)');

  console.log(report.join('\n'));
  console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
  process.exit(report.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
}, 500);
