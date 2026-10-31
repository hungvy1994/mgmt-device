// Chạy toàn bộ bộ kiểm khói và tổng kết. Dùng: npm test  (cần api-data.json ở thư mục gốc)
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const goc = path.resolve(__dirname, '..');
if (!fs.existsSync(path.join(goc, 'api-data.json'))) {
  console.error('Thiếu api-data.json ở thư mục gốc — lấy bằng:');
  console.error('   curl -s -b <cookie> http://127.0.0.1:8084/api/data > api-data.json');
  process.exit(2);
}
// Thứ tự đọc từ đĩa để thêm suite mới không phải sửa file này
const suites = fs.readdirSync(__dirname)
  .filter(f => /^(smoke.*|check_.*)\.js$/.test(f))
  .sort((a, b) => (parseInt(a.replace(/\D/g, '') || '0', 10) - parseInt(b.replace(/\D/g, '') || '0', 10))
    || a.localeCompare(b));

let pass = 0, fail = 0, vo = 0;
for (const suite of suites) {
  let out = '';
  try {
    out = execFileSync('node', [path.join(__dirname, suite)], { cwd: goc, encoding: 'utf8' });
  } catch (error) {
    out = `${error.stdout || ''}${error.stderr || ''}`;
  }
  const p = (out.match(/^PASS/gm) || []).length;
  const f = (out.match(/^FAIL/gm) || []).length;
  pass += p; fail += f;
  if (!p && !f) { vo += 1; console.log(`${suite.padEnd(20)} KHÔNG CHẠY ĐƯỢC`); console.log(out.trim().split('\n').slice(-3).map(l => '    ' + l).join('\n')); continue; }
  console.log(`${suite.padEnd(20)} ${String(p).padStart(3)} PASS ${String(f).padStart(3)} FAIL`);
  if (f) console.log(out.split('\n').filter(l => l.startsWith('FAIL')).map(l => '    ' + l).join('\n'));
}
console.log(`\n${suites.length} suite · ${pass} PASS · ${fail} FAIL${vo ? ` · ${vo} không chạy được` : ''}`);
process.exit(fail || vo ? 1 : 0);
