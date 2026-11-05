// 网页版冒烟：打开导出的 index.html，等到控制台出现 [boot]，截一张图。
// 用法：先在导出目录起 http 服务，再 node tools/web_smoke.js http://localhost:8765/index.html 截图.png
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const p = await b.newPage({ viewport: { width: 1280, height: 720 } });
  const logs = [];
  p.on('console', m => logs.push(m.text()));
  p.on('pageerror', e => logs.push('PAGEERROR ' + e.message));
  await p.goto(process.argv[2]);
  const t0 = Date.now();
  while (Date.now() - t0 < 60000 && !logs.some(l => l.includes('[boot]'))) await p.waitForTimeout(500);
  await p.waitForTimeout(1500);
  await p.screenshot({ path: process.argv[3] });
  console.log(logs.filter(l => /boot|ERROR|error|PAGEERROR/i.test(l)).slice(0, 20).join('\n'));
  await b.close();
})();
