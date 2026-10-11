// Run against a local Web export or the production URL. Uses isolated storage.
// NODE_PATH must include Playwright; MOCHI_CHROME optionally selects Chrome.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const base = process.argv[2] || 'http://127.0.0.1:8150/';
const smoke = process.argv.includes('--smoke');
const errors = [];
const sleep = ms => new Promise(r => setTimeout(r, ms));
(async () => {
  const browser = await chromium.launch({headless: true, args:['--autoplay-policy=user-gesture-required'], executablePath: process.env.MOCHI_CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
  try {
    async function launch(viewport, touch, dpr, mode = '') {
      const context = await browser.newContext({viewport, hasTouch: touch, isMobile: touch, deviceScaleFactor: dpr});
      const page = await context.newPage();
      await page.addInitScript(() => {
        window.testAudioContexts=[];
        const Original=window.AudioContext;
        if(Original) window.AudioContext=new Proxy(Original,{construct(target,args){const ctx=new target(...args);window.testAudioContexts.push(ctx);return ctx;}});
      });
      page.on('pageerror', e => errors.push(e.message));
      page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
      if (mode) await page.route('**/*', async route => {
        if (route.request().resourceType() !== 'document') return route.continue();
        const response = await route.fetch();
        const html = (await response.text()).replace('const engine=new Engine(config);', `config.args=['--','--capture-mode=${mode}'];const engine=new Engine(config);`);
        await route.fulfill({response, body: html});
      });
      await page.goto(base + '?input_debug=1', {waitUntil: 'domcontentloaded'});
      await page.waitForSelector('#cover', {state: 'detached', timeout: 90000});
      await page.waitForFunction(() => window.mochiInput?.state?.bridge, {timeout: 20000});
      // A 540x960 logical game letterboxed proportionally inside the canvas.
      async function coords(x, y) {
        const r = await page.locator('#canvas').boundingBox();
        const scale = Math.min(r.width / 540, r.height / 960);
        return [r.x + (r.width - 540 * scale) / 2 + x * scale, r.y + (r.height - 960 * scale) / 2 + y * scale];
      }
      async function tap(x, y) {
        const [cx, cy] = await coords(x, y);
        await (touch ? page.touchscreen.tap(cx, cy) : page.mouse.click(cx, cy));
        await sleep(200);
      }
      const state = () => page.evaluate(() => window.mochiInput.state);
      return {page, context, coords, tap, state};
    }
    const devices = [['phone',390,844,true,3], ['tablet',768,1024,true,2], ['desktop',1440,810,false,1]];
    for (const [name, width, height, touch, dpr] of (smoke ? devices.slice(0,1) : devices)) {
      const {page, context, coords, tap, state} = await launch({width,height}, touch, dpr);
      const initial = await state();
      assert.equal(initial.version, '3.0');
      for (const [key, y] of [['sound',332], ['music',383]]) {
        await tap(505, y);
        assert(await page.evaluate(()=>window.testAudioContexts.some(ctx=>ctx.state==='running')), name+' engine audio unlocked on trusted gesture');
        assert.equal((await state())[key], !initial[key], name + ' single ' + key + ' toggle');
        await sleep(700);
        assert.equal((await state())[key], !initial[key], name + ' stays toggled');
        await tap(505,y);
        assert.equal((await state())[key], initial[key], name + ' restores ' + key);
      }
      await tap(505,230);
      assert.equal((await state()).hammers + (await state()).bombs,1,name + ' gift grants once');
      // Rapid genuine taps are not swallowed by a time-based blanket debounce.
      const [gx,gy] = await coords(505,230);
      for (let i=0;i<4;i++) await (touch ? page.touchscreen.tap(gx,gy) : page.mouse.click(gx,gy));
      await sleep(250);
      assert.equal((await state()).hammers + (await state()).bombs,5,name + ' rapid gifts grant exactly five total');
      await tap(270,230);
      assert.equal((await state()).drops,1,name + ' dropping works');
      await sleep(1900);
      let s = await state();
      const tool = s.hammers > 0 ? 'hammer' : 'bomb';
      const total = s.hammers + s.bombs;
      await tap(35,tool==='hammer'?176:245);
      assert.equal((await state()).selected,tool,name + ' tool remains selected');
      s=await state();
      assert.equal(s.animals.length,1);
      await tap(s.animals[0].x,s.animals[0].y);
      s=await state();
      assert.equal(s.animals.length,0,name + ' tool actually removes animal');
      assert.equal(s.hammers+s.bombs,total-1,name + ' consumes one tool');
      assert.equal(s.drops,1,name + ' no unintended drop');
      await page.screenshot({path:'/private/tmp/mochi-v3-'+name+'.png'});
      console.log(JSON.stringify({name,dpr,bridge:s.bridge,counts:s.inputs,pass:true}));
      if(name==='phone') {
        await page.setViewportSize({width:844,height:390});
        await sleep(600);
        const inventory=s.hammers+s.bombs;
        await tap(505,230);
        s=await state();
        assert.equal(s.hammers+s.bombs,inventory+1,'coordinate mapping follows viewport/orientation changes');
      }
      await context.close();
    }
    if(smoke) {assert.deepEqual(errors,[]);console.log('LIVE PHONE SMOKE PASSED');return;}
    // Explicit independent DOM fallbacks, with no PointerEvent stream.
    {
      const {page,context,state,coords}=await launch({width:390,height:844},true,3);
      const [x,y]=await coords(505,230);
      const dispatch = async source => {
        await page.evaluate(({source,x,y})=>{
          const c=document.getElementById('canvas');
          if(source==='mouse') {
            for(const type of ['mousedown','mouseup']) c.dispatchEvent(new MouseEvent(type,{clientX:x,clientY:y,button:0,bubbles:true,cancelable:true}));
          } else {
            const t=new Touch({identifier:19,target:c,clientX:x,clientY:y});
            c.dispatchEvent(new TouchEvent('touchstart',{touches:[t],targetTouches:[t],changedTouches:[t],bubbles:true,cancelable:true}));
            c.dispatchEvent(new TouchEvent('touchend',{touches:[],targetTouches:[],changedTouches:[t],bubbles:true,cancelable:true}));
          }
        },{source,x,y});
        await sleep(200);
      };
      await dispatch('mouse');
      assert.equal((await state()).hammers+(await state()).bombs,1,'mouse-only fallback');
      await sleep(550);
      await dispatch('touch');
      assert.equal((await state()).hammers+(await state()).bombs,2,'touch-only fallback');
      await dispatch('mouse');
      assert.equal((await state()).hammers+(await state()).bombs,2,'compatibility mouse after touch deduplicated');
      const [px,py]=await coords(270,230);
      await page.evaluate(({x,y})=>{
        const c=document.getElementById('canvas');
        for(const type of ['pointerdown','pointercancel']) c.dispatchEvent(new PointerEvent(type,{clientX:x,clientY:y,pointerId:42,pointerType:'touch',bubbles:true,cancelable:true}));
      },{x:px,y:py});
      await sleep(200);
      assert.equal((await state()).drops,0,'pointer cancellation does not drop an animal');
      await context.close();
      console.log('PASS independent DOM mouse/touch fallbacks and compatibility duplicate');
    }
    {
      const {page,context,tap,state}=await launch({width:390,height:844},true,3,'revive');
      let s=await state(); assert.equal(s.overlay,'gameover'); assert.equal(s.animals.length,5);
      const keep = s.animals.filter(a=>!a.spilled && a.bottom>=422).map(a=>a.id).sort();
      await page.screenshot({path:'/private/tmp/mochi-v3-revive-before.png'});
      await tap(270,708);
      s=await state();
      assert.equal(s.revives,1); assert.equal(s.overlay,''); assert(s.settling>0);
      assert.deepEqual(s.animals.map(a=>a.id).sort(),keep,'revive actual shape filtering');
      assert.equal(s.score,1500); assert.equal(s.coins,150); assert.equal(s.hammers,2); assert.equal(s.bombs,1);
      await page.screenshot({path:'/private/tmp/mochi-v3-revive-after.png'});
      await sleep(1300);
      assert.equal((await state()).settling,0);
      await context.close();
      console.log('PASS real browser revive cleanup and one-second settling');
    }
    {
      const {page,context,tap,state}=await launch({width:540,height:960},true,1,'shop-limit');
      let s=await state(); assert.equal(s.overlay,'shop'); assert.equal(s.coins,5100);
      await page.screenshot({path:'/private/tmp/mochi-v3-shop.png'});
      await tap(197,470); s=await state(); assert.equal(s.coins,4600); assert.equal(s.hammers,5);
      await tap(341,470); s=await state(); assert.equal(s.coins,3700); assert.equal(s.bombs,5);
      await context.close();
      console.log('PASS purchases beyond old cap charge 500/900 exactly once');
    }
    assert.deepEqual(errors,[],'browser console/runtime errors');
    console.log('ALL BROWSER V3 CHECKS PASSED');
  } finally { await browser.close(); }
})().catch(e=>{console.error(e);process.exitCode=1});
