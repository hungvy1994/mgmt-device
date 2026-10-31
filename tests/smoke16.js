// Kiểm: form trong hộp thoại bóp sát lại, và nội dung mỗi mục cuộn trong khung.
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
const lastModal = () => [...w.document.querySelectorAll('.modal-backdrop')].pop();
const px = v => parseFloat(v) || 0;

setTimeout(() => {
  // ---- 1. Form trong hộp thoại ------------------------------------------
  w.document.querySelector('[data-view="assets"]').click();
  $('newAssetBtnFull').click();
  const modal = lastModal();
  const form = modal.querySelector('form');
  const card = w.getComputedStyle(modal.querySelector('.modal-card'));
  check('viền hộp thoại hẹp lại', px(card.paddingTop) <= 22 && px(card.paddingLeft) <= 24,
    `padding ${card.padding || card.paddingTop + ' ' + card.paddingLeft}`);
  // jsdom không phân giải shorthand gap -> đọc thẳng luật trong stylesheet
  const css = w.document.querySelector('style').textContent;
  const gapOf = selector => {
    const rule = new RegExp(`\\${selector}\\s*\\{[^}]*?gap:\\s*([^;]+);`).exec(css);
    return rule ? rule[1].trim() : '(không thấy)';
  };
  const gridGap = gapOf('.modal-grid');
  check('khoảng cách giữa các trường nhỏ lại',
    px(gridGap.split(/\s+/)[0]) <= 10, `gap ${gridGap}`);
  const field = w.getComputedStyle(form.querySelector('.field'));
  check('trường không còn margin dưới cộng dồn với gap',
    px(field.marginBottom) === 0, `margin-bottom ${field.marginBottom}`);
  const fieldGap = gapOf('.modal-form .field');
  check('nhãn và ô nhập sát nhau hơn', px(fieldGap) <= 5, `gap ${fieldGap}`);
  const input = w.getComputedStyle(form.querySelector('input[name="asset_id"]'));
  check('ô nhập thấp lại', px(input.paddingTop) <= 8, `padding ${input.paddingTop} ${input.paddingLeft}`);
  const head = w.getComputedStyle(modal.querySelector('.modal-head'));
  check('tiêu đề hộp thoại bớt khoảng trống dưới', px(head.marginBottom) <= 14, head.marginBottom);
  const actions = w.getComputedStyle(form.querySelector('.form-actions'));
  check('hàng nút sát form hơn', px(actions.marginTop) <= 16, actions.marginTop);

  // màn đăng nhập KHÔNG bị bóp theo
  const loginField = w.getComputedStyle($('loginScreen').querySelector('.field'));
  check('màn đăng nhập vẫn giữ khoảng thở cũ', px(loginField.marginBottom) >= 18,
    `margin-bottom ${loginField.marginBottom}`);
  modal.querySelector('.modal-close').click();

  // ---- 2. Nội dung mỗi mục cuộn trong khung ------------------------------
  const views = [['Vị trí & Cụm', 'locations'], ['Sơ đồ', 'diagram'],
                 ['Loại tài sản', 'types'], ['Trạng thái', 'statuses'], ['Nhập / Xuất', 'data']];
  views.forEach(([label, view]) => {
    w.document.querySelector(`[data-view="${view}"]`).click();
    const page = $(`${view}View`);
    const box = page.querySelector('.section-page') || page.querySelector('.tree-wrap');
    if (!box) return check(`${label}: có khung nội dung`, false, '(không tìm thấy)');
    const style = w.getComputedStyle(box);
    const capped = px(style.maxHeight);
    check(`${label}: khung nội dung cao theo màn hình`,
      capped > 0 && capped < w.innerHeight, `max-height ${style.maxHeight} / cửa sổ ${w.innerHeight}px`);
    check(`${label}: thừa nội dung thì cuộn trong khung`, style.overflow === 'auto',
      `overflow ${style.overflow}`);
  });

  // bảng danh mục tài sản vẫn giữ cách cũ
  w.document.querySelector('[data-view="assets"]').click();
  const wrap = w.getComputedStyle($('assetRowsFull').closest('.table-wrap'));
  check('danh mục tài sản vẫn cuộn như trước', wrap.overflow === 'auto' && px(wrap.maxHeight) > 0,
    `max-height ${wrap.maxHeight}`);

  console.log(report.join('\n'));
  console.log('\nlỗi runtime:', errors.length ? errors.join('\n') : 'không có');
  process.exit(report.some(l => l.startsWith('FAIL')) || errors.length ? 1 : 0);
}, 500);
