// 网页版试玩冒烟：打开导出的 index.html，等 [boot]，按一串键，每步截图。
// 用法：node tools/web_play.js <url> <输出目录> "key:Enter wait:1500 shot:map hold:ArrowDown:600 ..."
//   key:<键>        按一下（Playwright 的键名：Enter、Space、KeyZ、ArrowDown、Escape……）
//   hold:<键>:<毫秒> 按住一段时间
//   wait:<毫秒>     等
//   shot:<名字>     截图到 <输出目录>/<名字>.png
//   click:<x>:<y>   点一下画面上的坐标
const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  const [url, out, script] = process.argv.slice(2);
  fs.mkdirSync(out, { recursive: true });
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const p = await b.newPage({ viewport: { width: 1280, height: 720 } });
  const logs = [];
  p.on('console', m => logs.push(m.text()));
  p.on('pageerror', e => logs.push('PAGEERROR ' + e.message));
  await p.goto(url);
  const t0 = Date.now();
  while (Date.now() - t0 < 90000 && !logs.some(l => l.includes('[boot]'))) await p.waitForTimeout(500);
  await p.waitForTimeout(1500);
  await p.mouse.click(640, 360);   // 让画布拿到焦点
  for (const step of (script || '').split(/\s+/).filter(Boolean)) {
    const [k, a, c] = step.split(':');
    if (k === 'key') await p.keyboard.press(a);
    else if (k === 'hold') { await p.keyboard.down(a); await p.waitForTimeout(+c); await p.keyboard.up(a); }
    else if (k === 'wait') await p.waitForTimeout(+a);
    else if (k === 'shot') await p.screenshot({ path: `${out}/${a}.png` });
    else if (k === 'click') await p.mouse.click(+a, +c);
  }
  console.log(logs.filter(l => /boot|node|ERROR|error|PAGEERROR|战斗|地方/i.test(l)).slice(0, 40).join('\n'));
  await b.close();
})();
