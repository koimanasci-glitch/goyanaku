/*
 * GOYANA Flutter bridge.
 *
 * Replaces Capacitor inside the Flutter app so index.html and every
 * goyana-v*.js patch run unchanged. The page keeps calling
 * Capacitor.registerPlugin('GoyanaDevice' | 'Geolocation' | 'LocalNotifications'),
 * and each call is forwarded to Flutter through the GoyanaNative channel.
 *
 * It also fills gaps of a plain Android WebView so the app behaves like a
 * native app: downloads, sharing files, printing, clipboard, geolocation and
 * the hardware back button.
 *
 * Outside the Flutter app (normal browser, Playwright tests) window.GoyanaNative
 * does not exist and this file does nothing, so the web build stays identical.
 */
(function () {
  'use strict';
  if (!window.GoyanaNative || window.__goyanaNative) return;

  var seq = 0;
  var pending = {};

  function call(plugin, method, args) {
    return new Promise(function (resolve, reject) {
      var id = ++seq;
      pending[id] = { resolve: resolve, reject: reject };
      try {
        window.GoyanaNative.postMessage(JSON.stringify({ id: id, plugin: plugin, method: method, args: args || {} }));
      } catch (e) {
        delete pending[id];
        reject(e);
      }
    });
  }

  window.__goyanaNative = {
    call: call,
    finish: function (id, ok, value) {
      var p = pending[id];
      if (!p) return;
      delete pending[id];
      if (ok) p.resolve(value == null ? {} : value);
      else p.reject(new Error(value || 'Perintah perangkat gagal'));
    }
  };

  function plugin(name) {
    return new Proxy({}, {
      get: function (_, method) {
        if (typeof method !== 'string' || method === 'then') return undefined;
        if (method === 'addListener') {
          return function () { return Promise.resolve({ remove: function () { return Promise.resolve(); } }); };
        }
        return function (args) { return call(name, method, args); };
      }
    });
  }

  var plugins = {
    GoyanaDevice: plugin('GoyanaDevice'),
    Geolocation: plugin('Geolocation'),
    LocalNotifications: plugin('LocalNotifications'),
    Share: plugin('Share'),
    App: plugin('App')
  };

  window.Capacitor = {
    isNativePlatform: function () { return true; },
    getPlatform: function () { return 'android'; },
    isPluginAvailable: function (name) { return Object.prototype.hasOwnProperty.call(plugins, name); },
    registerPlugin: function (name) { return plugins[name] || (plugins[name] = plugin(name)); },
    Plugins: plugins
  };

  /* ---------- helpers ---------- */
  function blobToBase64(blob) {
    return new Promise(function (resolve, reject) {
      var r = new FileReader();
      r.onload = function () { var s = String(r.result); resolve(s.slice(s.indexOf(',') + 1)); };
      r.onerror = function () { reject(r.error); };
      r.readAsDataURL(blob);
    });
  }
  function hrefToFile(href, fallbackName) {
    return fetch(href).then(function (r) { return r.blob(); }).then(function (b) {
      return blobToBase64(b).then(function (data) {
        return { name: fallbackName || 'goyana-file', mime: b.type || 'application/octet-stream', data: data };
      });
    });
  }

  /* ---------- downloads: <a download> with blob:/data: links ---------- */
  function saveAnchor(a) {
    var href = a.href || '';
    if (!/^(blob:|data:)/.test(href)) return false;
    var name = a.getAttribute('download') || 'goyana-file';
    hrefToFile(href, name).then(function (f) { return call('Files', 'save', f); })
      .catch(function (e) { console.warn('GOYANA download gagal', e); });
    return true;
  }
  var nativeClick = HTMLAnchorElement.prototype.click;
  HTMLAnchorElement.prototype.click = function () {
    if (this.hasAttribute('download') && saveAnchor(this)) return;
    return nativeClick.call(this);
  };
  document.addEventListener('click', function (e) {
    var a = e.target && e.target.closest && e.target.closest('a[download]');
    if (a && saveAnchor(a)) e.preventDefault();
  }, true);

  /* ---------- sharing text and files ---------- */
  navigator.canShare = function () { return true; };
  navigator.share = function (data) {
    data = data || {};
    var files = Array.prototype.slice.call(data.files || []);
    return Promise.all(files.map(function (f) {
      return blobToBase64(f).then(function (b64) { return { name: f.name || 'goyana-file', mime: f.type || 'application/octet-stream', data: b64 }; });
    })).then(function (list) {
      return call('Files', 'share', { title: data.title || '', text: data.text || '', url: data.url || '', files: list });
    }).then(function () { return undefined; });
  };

  /* ---------- clipboard ---------- */
  try {
    var clip = {
      writeText: function (text) { return call('Clipboard', 'write', { text: String(text == null ? '' : text) }).then(function () {}); },
      readText: function () { return call('Clipboard', 'read', {}).then(function (r) { return (r && r.text) || ''; }); }
    };
    Object.defineProperty(navigator, 'clipboard', { configurable: true, get: function () { return clip; } });
  } catch (e) { /* keep WebView clipboard */ }

  /* ---------- geolocation through the native GPS ---------- */
  try {
    var geo = {
      getCurrentPosition: function (ok, fail, opts) {
        call('Geolocation', 'getCurrentPosition', opts || {}).then(ok, function (e) {
          if (fail) fail({ code: 2, message: e.message, PERMISSION_DENIED: 1, POSITION_UNAVAILABLE: 2, TIMEOUT: 3 });
        });
      },
      watchPosition: function (ok, fail, opts) { geo.getCurrentPosition(ok, fail, opts); return 0; },
      clearWatch: function () {}
    };
    Object.defineProperty(navigator, 'geolocation', { configurable: true, get: function () { return geo; } });
  } catch (e) { /* keep WebView geolocation */ }

  /* ---------- printing (invoice page and receipt iframes) ---------- */
  function printDocument(doc, title) {
    var html = '<!doctype html>' + doc.documentElement.outerHTML;
    return call('Print', 'html', { html: html, title: title || doc.title || 'GOYANA' })
      .catch(function (e) { if (window.toast90) window.toast90(e.message); });
  }
  window.print = function () { printDocument(document, 'GOYANA'); };
  function patchWindow(w) {
    try {
      if (w && w !== window && !w.__goyanaPrint) {
        w.__goyanaPrint = true;
        w.print = function () { printDocument(w.document, 'Struk GOYANA'); };
      }
    } catch (e) { /* cross-origin frame */ }
    return w;
  }
  // Receipts are printed from a hidden iframe: patch its window on access.
  var frameWindow = Object.getOwnPropertyDescriptor(HTMLIFrameElement.prototype, 'contentWindow');
  if (frameWindow && frameWindow.get) {
    Object.defineProperty(HTMLIFrameElement.prototype, 'contentWindow', {
      configurable: true,
      enumerable: frameWindow.enumerable,
      get: function () { return patchWindow(frameWindow.get.call(this)); }
    });
  }

  /* ---------- hardware back button ---------- */
  function visible(el) {
    if (!el || !el.getClientRects().length) return false;
    var s = getComputedStyle(el);
    return s.display !== 'none' && s.visibility !== 'hidden' && s.opacity !== '0';
  }
  var CLOSE = /^(×|✕|✖|&times;|Batal|Tutup|Kembali|‹|←)$/;
  function closeButton(box) {
    var list = box.querySelectorAll('.modal-x,.cancel,.close,[data-close],[aria-label="Tutup"],[aria-label="Kembali"],button');
    for (var i = 0; i < list.length; i++) {
      var b = list[i];
      if (!visible(b) || b.disabled) continue;
      if (b.matches('.modal-x,.cancel,.close,[data-close],[aria-label="Tutup"],[aria-label="Kembali"]') || CLOSE.test((b.textContent || '').trim())) return b;
    }
    return null;
  }
  function topOverlay() {
    var best = null, bestZ = -Infinity;
    var all = document.body ? document.body.querySelectorAll('*') : [];
    for (var i = 0; i < all.length; i++) {
      var el = all[i];
      if (el.classList.contains('page') || el.id === 'lg167' || el.id === 'boot180') continue;
      var s = getComputedStyle(el);
      if (s.position !== 'fixed' || s.display === 'none' || s.visibility === 'hidden') continue;
      var r = el.getBoundingClientRect();
      if (r.width < innerWidth * 0.9 || r.height < innerHeight * 0.9) continue;
      var z = parseInt(s.zIndex, 10) || 0;
      if (z >= bestZ && closeButton(el)) { best = el; bestZ = z; }
    }
    return best;
  }
  window.__goyanaBack = function () {
    try {
      var login = document.getElementById('lg167');
      if (login && login.classList.contains('show') && visible(login)) return 'exit';
      var overlay = topOverlay();
      if (overlay) { closeButton(overlay).click(); return 'handled'; }
      var page = document.querySelector('.page.active');
      if (page && page.id !== 'home') {
        var back = page.querySelector('.back');
        if (back && visible(back)) back.click();
        else if (typeof window.openPage === 'function') window.openPage('home');
        return 'handled';
      }
    } catch (e) { console.warn('GOYANA back', e); }
    return 'exit';
  };
})();
