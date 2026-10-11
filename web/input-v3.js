/* Browser input adapter. Godot routes gestures once, regardless of event source.
 * No UA/model blacklist, no dependency on a successful touch-to-mouse emulation.
 * Trusted events continue to Godot's audio-unlock handlers (no stopPropagation).
 */
(() => {
  'use strict';
  const canvas = document.getElementById('canvas');
  const debug = new URLSearchParams(location.search).get('input_debug') === '1';
  const counts = {pointer: 0, touch: 0, mouse: 0, forwarded: 0, document: 0};
  let lastTarget = 'none';
  const pointers = new Set();
  const touches = new Set();
  let callback = null, mouseDown = false, panel = null;
  const api = window.mochiInput = {
    debug, state: null, counts,
    connectGame(fn) { callback = fn; },
    report(json) {
      try { api.state = JSON.parse(json); } catch (_) { return; }
      if (!panel) return;
      const s = api.state;
      panel.textContent = `Input v${s.version} · bridge ${s.bridge ? 'ON' : 'OFF'}\n` +
        `DOM pointer ${counts.pointer} / touch ${counts.touch} / mouse ${counts.mouse}\n` +
        `Game gestures ${s.inputs.accepted_down} · ${s.overlay || 'playing'}\n` +
        `Page presses ${counts.document} · target ${lastTarget}\n` +
        `Canvas ${canvas.width}×${canvas.height} · DPR ${devicePixelRatio}\n` +
        `Tools ${s.hammers}/${s.bombs} · selected ${s.selected || 'none'}`;
    }
  };
  if (debug) {
    for (const type of ['pointerdown', 'touchstart', 'mousedown']) {
      document.addEventListener(type, event => {
        counts.document++;
        lastTarget = event.target.id || event.target.tagName || 'unknown';
      }, {capture: true, passive: true});
    }
    panel = document.createElement('pre');
    panel.id = 'input-diagnostics';
    panel.style.cssText = 'position:fixed;left:4px;bottom:4px;z-index:20;margin:0;padding:6px;background:#fffc;color:#432;font:10px/1.4 monospace;pointer-events:none;max-width:95vw;white-space:pre-wrap';
    panel.textContent = 'Input diagnostics: waiting for game…';
    document.body.appendChild(panel);
  }
  function send(phase, event, source, id) {
    if (!callback) return;
    const rect = canvas.getBoundingClientRect();
    if (!rect.width || !rect.height) return;
    const x = (event.clientX - rect.left) * canvas.width / rect.width;
    const y = (event.clientY - rect.top) * canvas.height / rect.height;
    counts.forwarded++;
    callback(phase, x, y, source, id);
  }
  function prevent(event) { if (callback && event.cancelable) event.preventDefault(); }
  canvas.style.touchAction = 'none';
  canvas.style.userSelect = 'none';
  canvas.addEventListener('contextmenu', prevent);
  canvas.addEventListener('pointerdown', event => {
    if (event.pointerType === 'mouse' && event.button !== 0) return;
    counts.pointer++;
    pointers.add(event.pointerId);
    try { canvas.setPointerCapture(event.pointerId); } catch (_) { /* old WebViews */ }
    send('down', event, 'pointer-' + (event.pointerType || 'mouse'), event.pointerId);
    // Keep compatibility mousedown available to the engine's trusted-gesture
    // audio unlock. The game router deduplicates it; CSS blocks touch gestures.
  }, {passive: false});
  window.addEventListener('pointermove', event => {
    if (!pointers.has(event.pointerId) && event.target !== canvas) return;
    counts.pointer++;
    send('move', event, 'pointer-' + (event.pointerType || 'mouse'), event.pointerId);
  });
  for (const type of ['pointerup', 'pointercancel']) {
    window.addEventListener(type, event => {
      if (!pointers.delete(event.pointerId)) return;
      counts.pointer++;
      send(type === 'pointerup' ? 'up' : 'cancel', event, 'pointer-' + (event.pointerType || 'mouse'), event.pointerId);
    });
  }
  canvas.addEventListener('lostpointercapture', event => {
    if (pointers.delete(event.pointerId)) send('cancel', event, 'pointer-' + (event.pointerType || 'mouse'), event.pointerId);
  });
  // Register fallbacks even when PointerEvent exists: embedded browsers may
  // expose the API without delivering that particular stream to the canvas.
  for (const type of ['touchstart', 'touchmove', 'touchend', 'touchcancel']) {
    canvas.addEventListener(type, event => {
      counts.touch++;
      const phase = {touchstart: 'down', touchmove: 'move', touchend: 'up', touchcancel: 'cancel'}[type];
      for (const touch of event.changedTouches) {
        if (phase === 'down') touches.add(touch.identifier);
        if (!touches.has(touch.identifier)) continue;
        send(phase, touch, 'touch', touch.identifier);
        if (phase === 'up' || phase === 'cancel') touches.delete(touch.identifier);
      }
      prevent(event);
    }, {passive: false});
  }
  canvas.addEventListener('mousedown', event => {
    if (event.button !== 0) return;
    counts.mouse++; mouseDown = true;
    send('down', event, 'mouse', 0);
    prevent(event);
  });
  window.addEventListener('mousemove', event => {
    if (!mouseDown && event.target !== canvas) return;
    counts.mouse++;
    send('move', event, 'mouse', 0);
  });
  window.addEventListener('mouseup', event => {
    if (event.button !== 0 || !mouseDown) return;
    counts.mouse++; mouseDown = false;
    send('up', event, 'mouse', 0);
  });
  function cancel() {
    pointers.clear(); touches.clear(); mouseDown = false;
    if (callback) callback('blur', 0, 0, 'browser', -1);
  }
  window.addEventListener('blur', cancel);
  document.addEventListener('visibilitychange', () => { if (document.hidden) cancel(); });
})();
