// Kiểm tĩnh trên index.html những lỗi giao diện KHÔNG lộ ra khi chạy test chức năng:
// id trùng, bảng thiếu <col>, và chữ dài bị cắt mà không có dấu ba chấm.
const fs = require('fs');
const html = fs.readFileSync('index.html', 'utf8');
const report = [];
const check = (l, ok, d = '') => report.push(`${ok ? 'PASS' : 'FAIL'}  ${l}${d ? ' — ' + d : ''}`);

// --- 1. id trùng. Đã mắc một lần: thêm id="exportNote" trong khi màn Nhập/Xuất đã có sẵn,
// getElementById trả về phần tử của màn kia nên số đếm "3 mẫu" ghi nhầm sang chỗ khác.
const dem = {};
for (const m of html.matchAll(/id=["'`]([A-Za-z][\w-]*)["'`]/g)) dem[m[1]] = (dem[m[1]] || 0) + 1;
const trung = Object.entries(dem).filter(([, n]) => n > 1);
check('không có id nào bị trùng', trung.length === 0,
  trung.map(([k, n]) => `${k} x${n}`).join(', '));

// --- 2. mỗi <colgroup> phải có đúng số <col> bằng số <th> của bảng đó.
// CLAUDE.md: thiếu một <col> là cả bảng lệch cột.
const bang = [];
const re = /<colgroup>([\s\S]*?)<\/colgroup>([\s\S]*?)<\/thead>/g;
for (const m of html.matchAll(re)) {
  const col = (m[1].match(/<col\b/g) || []).length;
  const th = (m[2].match(/<th\b/g) || []).length;
  bang.push({ col, th });
}
check('tìm thấy các bảng có khai colgroup', bang.length > 0, `${bang.length} bảng`);
const lech = bang.filter(b => b.col !== b.th);
check('mọi bảng có số <col> khớp số <th>', lech.length === 0,
  lech.map(b => `col=${b.col} th=${b.th}`).join(', '));

// --- 3. chữ dài trong ô bảng phải cắt KÈM dấu ba chấm.
// text-overflow chỉ ăn vào chữ nằm trực tiếp trong ô; tên/mã tài sản nằm trong <button>
// nên từng bị cắt phăng — "svr-d12-u34" hiện thành "svr-d12-u3", trông y như mã đủ.
const luat = html.match(/table\.compact \.cell-clip > button \{[^}]*\}/);
check('có luật cắt chữ cho nút nằm trong ô bảng', Boolean(luat));
check('luật đó có text-overflow: ellipsis', Boolean(luat && /text-overflow:\s*ellipsis/.test(luat[0])));
check('luật đó có max-width để nút chịu co lại', Boolean(luat && /max-width:\s*100%/.test(luat[0])));

// --- 4. ô nhập trong bảng khai mẫu phải ép width 100%, không thì giữ 185px mặc định
// của trình duyệt rồi tràn đè sang cột bên cạnh.
const oNhap = html.match(/#exportCols input, #exportCols select \{[^}]*\}/);
check('ô nhập trong bảng cột bị ép về đúng bề rộng cột', Boolean(oNhap));
check('ô nhập đó dùng border-box để padding không đội bề rộng',
  Boolean(oNhap && /box-sizing:\s*border-box/.test(oNhap[0])));

// --- 5. hàng nút: phần chữ phải co lại thay vì đẩy nút xuống dòng.
check('phần chữ của toolbar-row được phép co lại',
  /\.toolbar-row > div:first-child \{[^}]*min-width:\s*0/.test(html));
check('có nhóm nút không tự xuống dòng', /\.nut-nhom \{[^}]*flex:\s*0 0 auto/.test(html));

// --- 6. ghi chú dài trong danh sách mẫu phải gói lại, không đẩy nút rơi xuống.
check('ghi chú mẫu được gói lại số dòng cố định',
  /\.mau-ghi-chu \{[^}]*-webkit-line-clamp/.test(html));

// --- 7. khối Xuất dữ liệu KHÔNG được nằm trong khung nhập file (khung đó căn giữa).
const zone = html.match(/zone\.innerHTML = `([\s\S]*?)`;/);
check('khối xuất dữ liệu đã tách khỏi khung nhập file',
  Boolean(zone) && !/Xuất dữ liệu/.test(zone[1]));

report.forEach(l => console.log(l));
const fail = report.filter(l => l.startsWith('FAIL')).length;
console.log(`\n${report.length - fail} PASS · ${fail} FAIL`);
process.exit(fail ? 1 : 0);
