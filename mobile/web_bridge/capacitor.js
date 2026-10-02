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
  /* ---------- native Flutter pages ----------
   * Beranda is drawn by Flutter (lib/native/home_page.dart). The HTML page keeps
   * running underneath and stays the source of truth: Flutter shows its native
   * Beranda only while #home is the active page and nothing covers it, and every
   * native tap clicks the same HTML element, so behaviour is identical. */
  function txt(sel) { var e = document.querySelector(sel); return e ? (e.innerText || e.textContent || '').trim() : ''; }
  function homeModel() {
    var badge = document.getElementById('today187-badge');
    var labels = Array.prototype.map.call(document.querySelectorAll('#home .gy155-stats > div > span'), function (e) { return e.textContent.trim(); });
    return {
      statIn: txt('#gy155-in'), statReady: txt('#gy155-progress'), statLate: txt('#gy155-ready'),
      labelIn: labels[0] || '', labelReady: labels[1] || '', labelLate: labels[2] || '',
      today: txt('#gy155-today'), todayLabel: txt('#home .gy155-omset span'),
      badge: badge ? badge.textContent.trim() : '', showBadge: !!(badge && visible(badge)),
      slides: Array.prototype.map.call(document.querySelectorAll('#home .gy155-slide'), function (s) {
        return { brand: (s.querySelector('.gy155-slide-brand') || {}).textContent || '',
          title: (s.querySelector('.gy155-slide-title') || {}).innerText || '', sub: (s.querySelector('.gy155-slide-sub') || {}).textContent || '' };
      }),
      helpTitle: txt('#home .help100 b'), helpText: txt('#home .help100 small')
    };
  }
  function coveringOverlay() {
    // Overlays are body children or dialog/sheet/modal/overlay elements; checking only those keeps this cheap.
    var list = document.querySelectorAll('body > *, [role="dialog"], [class*="sheet"], [class*="modal"], [class*="overlay"], .show');
    for (var i = 0; i < list.length; i++) {
      var el = list[i];
      if (el.closest('#home') || el.closest('#gy156-nav') || el.classList.contains('page')) continue;
      var s = getComputedStyle(el);
      if (s.position !== 'fixed' || s.display === 'none' || s.visibility === 'hidden' || s.opacity === '0') continue;
      var r = el.getBoundingClientRect();
      if (r.width >= innerWidth * 0.9 && r.height >= innerHeight * 0.5) return el;
    }
    return null;
  }
  function colors(el) {
    if (!el) return null;
    var s = getComputedStyle(el);
    return { t: (el.innerText || el.textContent || '').replace(/\s+/g, ' ').trim(), bg: s.backgroundColor, c: s.color };
  }
  function shown(el) { return !!el && visible(el) && getComputedStyle(el).display !== 'none'; }
  function ordersModel() {
    var search = document.getElementById('g62-order-search'), auto = document.getElementById('au133btn');
    var cards = document.querySelectorAll('#orders .g62-ordercard'), list = [];
    for (var i = 0; i < cards.length && list.length < 300; i++) {
      var c = cards[i];
      if (getComputedStyle(c).display === 'none') continue;
      var top = c.querySelector('.g62-order-top'), body = c.querySelector('.g62-order-body');
      var strong = body && body.querySelector('strong'), em = strong && strong.querySelector('em');
      var amount = strong ? Array.prototype.filter.call(strong.childNodes, function (n) { return n.nodeType === 3; }).map(function (n) { return n.textContent; }).join('').trim() : '';
      var row = c.querySelector('.oa91'), next = row && row.querySelector('.next91');
      var gender = body && body.querySelector('.female,.v82-female') ? 'female' : 'male';
      list.push({
        i: i, id: (((top && top.querySelector('b')) || {}).textContent || '').trim(),
        dur: shown(top && top.querySelector('span')) ? colors(top.querySelector('span')) : null,
        status: shown(top && top.querySelector('i')) ? colors(top.querySelector('i')) : null,
        name: ((body && body.querySelector('div b')) || {}).textContent || '',
        lines: Array.prototype.filter.call(body ? body.querySelectorAll('div small') : [], shown).map(function (e) { return e.textContent.trim(); }),
        amount: amount, pay: shown(em) ? colors(em) : null, gender: gender,
        auto: shown(row && row.querySelector('.auto133')) ? colors(row.querySelector('.auto133')) : null,
        chips: Array.prototype.filter.call(row ? row.querySelectorAll('.chip91') : [], shown).map(colors),
        action: shown(next) ? colors(next) : null
      });
    }
    var empty = document.querySelector('#orders .g62-orderlist .empty176, #orders .empty108, #orders .g62-empty');
    return {
      title: txt('#orders .g62-top b'), auto: auto ? { t: txt('#au133btn span'), on: auto.classList.contains('on') } : null,
      search: search ? search.value : '', placeholder: search ? search.placeholder : '',
      tabs: Array.prototype.map.call(document.querySelectorAll('#orders .g62-tabs button'), function (b) {
        return { t: (b.childNodes[0] && b.childNodes[0].textContent || '').trim(), n: ((b.querySelector('i') || {}).textContent || '').trim(), on: b.classList.contains('on') };
      }),
      cards: list, empty: shown(empty) ? empty.textContent.trim() : ''
    };
  }
  function svgOf(el) { var g = el && el.querySelector('svg'); return g ? g.outerHTML : ''; }
  function field(input) { return input ? { v: input.value, ph: input.placeholder || '' } : null; }
  // Tambah Transaksi: langkah 1 (pilih pelanggan) dan 2 (layanan) native; durasi, jumlah, opsi & pembayaran tetap sheet HTML.
  function addorderModel() {
    var stage = document.querySelector('#addorder .f61-stage.active'), id = stage && stage.id;
    var m = { title: txt('#flow61-title'), step: txt('#flow61-step'), stage: id === 'f61-customer' ? 'customer' : id === 'f61-services' ? 'services' : '' };
    if (m.stage === 'customer') {
      var add = stage.querySelector('.f61-addcustomer');
      m.search = field(stage.querySelector('.f61-search input'));
      m.add = add && shown(add) ? add.textContent.replace(/^\s*[+＋]\s*/, '').trim() : '';
      m.people = [];
      var ps = stage.querySelectorAll('.f61-person');
      for (var i = 0; i < ps.length && m.people.length < 300; i++) {
        if (!shown(ps[i])) continue;
        m.people.push({ i: i, name: ((ps[i].querySelector('div b') || {}).textContent || '').trim(), avatar: svgOf(ps[i].querySelector('span')),
          lines: Array.prototype.filter.call(ps[i].querySelectorAll('div small'), shown).map(function (e) { return e.textContent.trim(); }),
          btn: ((ps[i].querySelector('button') || {}).textContent || 'Pilih').trim() });
      }
      var none = stage.querySelector('.empty116, .empty108, .f61-empty, .empty');
      m.empty = shown(none) ? none.textContent.trim() : '';
    } else if (m.stage === 'services') {
      var bar = stage.querySelector('.f61-customerbar');
      m.customer = { name: ((bar && bar.querySelector('b')) || {}).textContent || '', sub: txt('#f61-duration-label'), avatar: svgOf(bar && bar.querySelector('span')) };
      m.durations = Array.prototype.map.call(document.querySelectorAll('#dur116 button'), function (b) {
        return { t: ((b.querySelector('b') || {}).textContent || '').trim(), s: ((b.querySelector('small') || {}).textContent || '').trim(), on: b.classList.contains('on') };
      });
      m.search = field(document.getElementById('q116'));
      m.cats = Array.prototype.map.call(document.querySelectorAll('#catnav120 button'), function (b) {
        return { t: b.textContent.trim(), on: b.classList.contains('on'), svg: svgOf(b) };
      });
      m.items = [];
      var all = document.querySelectorAll('#list116 .sv116'), idx = new Map();
      for (var k = 0; k < all.length; k++) idx.set(all[k], k);
      document.querySelectorAll('#list116 .cat116').forEach(function (cat) {
        if (!shown(cat)) return;
        var h = cat.querySelector('.cat116-h');
        if (h) m.items.push({ h: 1, svg: svgOf(h), t: ((h.querySelector('b') || {}).textContent || '').trim(), s: ((h.querySelector('small') || {}).textContent || '').replace(/\s+/g, ' ').trim() });
        cat.querySelectorAll('.sv116').forEach(function (sv) {
          if (!shown(sv) || m.items.length > 400) return;
          m.items.push({ i: idx.get(sv), svg: svgOf(sv), t: ((sv.querySelector('b') || {}).textContent || '').trim(),
            s: ((sv.querySelector('small') || {}).textContent || '').trim(), btn: ((sv.querySelector('em') || {}).textContent || '').trim(), on: sv.classList.contains('in') });
        });
      });
      var empty = document.querySelector('#list116 .empty116');
      m.empty = shown(empty) ? empty.textContent.trim() : '';
      var foot = document.getElementById('f61-service-footer');
      m.footer = foot ? { name: ((foot.querySelector('div > b')) || {}).textContent || '', sum: ((foot.querySelector('div > small')) || {}).textContent || '',
        label: txt('#f61-service-footer .f61-total small'), total: txt('#f61-total'), btn: ((foot.querySelector(':scope > button')) || {}).textContent || '' } : null;
      if (m.footer) m.footer.sum = m.footer.sum.replace(/\s+/g, ' ').trim();
    } else return null; // unknown stage: leave it to the HTML page
    return m;
  }
  // Pelanggan: daftar & database native; ranking (podium) tetap HTML saat dibuka.
  function customersModel() {
    var rank = document.getElementById('rk138');
    if (rank && shown(rank) && rank.getBoundingClientRect().height > 10) return null;
    var page = document.getElementById('customers');
    var db = document.getElementById('cust59-db'), dbBtn = page.querySelector('.cust59-dbbtn');
    var dep = page.querySelector('.depositshortcut180'), add = page.querySelector('.cust59-add');
    var crm = page.querySelector('.crm130-entry'), rk = document.getElementById('rk138btn');
    var m = {
      title: txt('#customers .cust59-head b'), sub: txt('#customers .cust59-head small'),
      search: field(document.getElementById('cust59-search')),
      deposit: shown(dep) ? dep.textContent.trim() : '', add: shown(add) ? add.textContent.replace(/^\s*[+＋]\s*/, '').trim() : '',
      db: dbBtn ? { t: txt('#customers .cust59-dbbtn b'), s: txt('#customers .cust59-dbbtn small'), open: !!db && db.classList.contains('show') } : null,
      rank: shown(rk) ? { t: txt('#rk138btn b'), s: txt('#rk138btn small'), icon: txt('#rk138btn > span') } : null,
      crm: shown(crm) ? { t: ((crm.querySelector('b') || {}).childNodes[0] || {}).textContent || '', badge: txt('#customers .crm130-entry em'), s: txt('#customers .crm130-entry small'), icon: txt('#customers .crm130-entry > span') } : null,
      rows: [], empty: '', pager: null
    };
    if (m.crm) m.crm.t = m.crm.t.trim();
    if (m.db && m.db.open) {
      m.dbTitle = txt('#customers .cust59-dbhead b'); m.dbSub = txt('#customers .cust59-dbhead small'); m.filter = txt('#customers .cust59-dbhead button');
      var rows = db.querySelectorAll('.cust59-row');
      for (var i = 0; i < rows.length && m.rows.length < 200; i++) {
        var r = rows[i];
        if (!shown(r)) continue;
        var smalls = Array.prototype.filter.call(r.querySelectorAll('div small'), function (e) { return shown(e) && !e.classList.contains('sp138'); });
        var bal = r.querySelector('.balance180');
        m.rows.push({ i: i, name: ((r.querySelector('div b') || {}).textContent || '').trim(), avatar: svgOf(r.querySelector('.av126')),
          lines: smalls.map(function (e) { return e.textContent.trim(); }), spend: ((r.querySelector('.sp138') || {}).textContent || '').trim(),
          orders: ((r.querySelector(':scope > strong') || {}).textContent || '').trim(), last: ((r.querySelector(':scope > time') || {}).textContent || '').trim(),
          balance: bal && shown(bal) ? ((bal.querySelector('span') || {}).textContent || '').trim() : '', topup: bal && shown(bal) ? ((bal.querySelector('button') || {}).textContent || '').trim() : '',
          edit: shown(r.querySelector('.gy154-edit')) ? r.querySelector('.gy154-edit').textContent.trim() : '' });
      }
      var empty = db.querySelector('.empty176');
      m.empty = shown(empty) ? empty.textContent.trim() : '';
      var pg = document.getElementById('pg138'), pp = document.getElementById('pg138-p'), pn = document.getElementById('pg138-n');
      if (shown(pg) && pp && pn && (!pp.disabled || !pn.disabled)) m.pager = { prev: pp.textContent.trim(), next: pn.textContent.trim(), info: txt('#pg138-i'), canPrev: !pp.disabled, canNext: !pn.disabled };
    }
    return m;
  }
  // Laporan: ringkasan & daftar laporan native; detail laporan, tanggal kustom dan halaman kas tetap HTML.
  function reportsModel() {
    var root = document.querySelector('#reports .rp170');
    if (!root) return null;
    var cus = root.querySelector('.rp170-cus');
    if (shown(cus)) return null; // date inputs: leave to HTML
    function all(sel, fn) { return Array.prototype.filter.call(root.querySelectorAll(sel), shown).map(fn); }
    var hero = root.querySelector('.rp170-hero'), outlet = document.querySelector('#reports .g62-outlet');
    var items = root.querySelectorAll('.rp170-it'), idx = new Map();
    for (var k = 0; k < items.length; k++) idx.set(items[k], k);
    var empty = root.querySelector('.rp170-empty');
    return {
      title: txt('#reports .g62-top b'), outlet: shown(outlet) ? outlet.textContent.trim() : '',
      periods: Array.prototype.map.call(root.querySelectorAll('.rp170-per button'), function (b) { return { t: b.textContent.trim(), on: b.classList.contains('on') }; }),
      hero: shown(hero) ? { label: ((hero.querySelector('small')) || {}).textContent || '', big: ((hero.querySelector('.big')) || {}).textContent || '', sub: ((hero.querySelector('.sub')) || {}).textContent || '',
        pm: Array.prototype.map.call(hero.querySelectorAll('.pm > div'), function (d) { return { t: ((d.querySelector('span')) || {}).textContent || '', v: ((d.querySelector('b')) || {}).textContent || '' }; }) } : null,
      kpis: all('.rp170-kp button', function (b) {
        var i = b.querySelector('small i');
        return { icon: i ? i.textContent.trim() : '', bg: i ? getComputedStyle(i).backgroundColor : '', t: ((b.querySelector('small')) || {}).textContent.replace(i ? i.textContent : '', '').trim(),
          v: ((b.querySelector('b')) || {}).textContent || '', s: ((b.querySelector('em')) || {}).textContent || '' };
      }),
      quick: all('.rp170-qa button', function (b) { var sp = b.querySelector('span'); return { icon: sp ? sp.textContent.trim() : '', bg: sp ? getComputedStyle(sp).backgroundColor : '', t: b.textContent.replace(sp ? sp.textContent : '', '').trim() }; }),
      search: field(document.getElementById('rp170-q')),
      cats: Array.prototype.map.call(root.querySelectorAll('.rp170-cat button'), function (b) { var c = getComputedStyle(b); return { t: b.textContent.trim(), on: b.classList.contains('on'), bg: c.backgroundColor, c: c.color }; }),
      sections: all('.rp170-sec', function (sec) {
        return { t: ((sec.querySelector('h4')) || {}).textContent || '', items: Array.prototype.filter.call(sec.querySelectorAll('.rp170-it'), shown).map(function (it) {
          var ic = it.querySelector('.ic');
          return { i: idx.get(it), icon: ic ? ic.textContent.trim() : '', bg: ic ? getComputedStyle(ic).backgroundColor : '', t: ((it.querySelector('.tx b')) || {}).textContent || '',
            s: ((it.querySelector('.tx small')) || {}).textContent || '', v: ((it.querySelector('.vl')) || {}).textContent || '' };
        }) };
      }).filter(function (sec) { return sec.items.length; }),
      empty: shown(empty) ? empty.textContent.trim() : ''
    };
  }
  // Pengaturan: grup akordeon, kartu sinkron, kartu paket & keluar akun native; halaman tujuan tetap HTML.
  function settingsModel() {
    var root = document.querySelector('#settings .g62-settings');
    if (!root) return null;
    function t(el, sel) { var e = el && el.querySelector(sel); return e ? e.textContent.replace(/\s+/g, ' ').trim() : ''; }
    var sync = document.getElementById('sync197'), url = sync && sync.querySelector('.s197-url'), save = sync && sync.querySelector('.s197-save'), now = sync && sync.querySelector('.s197-now');
    var dot = sync && sync.querySelector('.s197-dot');
    var acct = root.querySelector('.acct92'), lo = root.querySelector('.lo167'), tut = document.getElementById('tutorial189-open');
    var groups = Array.prototype.slice.call(document.querySelectorAll('#st178 > .setting178'));
    return {
      title: txt('#settings .g62-top b'),
      sync: shown(sync) ? { dot: dot ? getComputedStyle(dot).backgroundColor : '', t: t(sync, 'b'), line: t(sync, '.s197-line'), who: t(sync, '.s197-who'),
        url: shown(url) ? field(url) : null, save: shown(save) ? save.textContent.trim() : '', now: shown(now) ? now.textContent.trim() : '' } : null,
      groups: groups.map(function (g, i) {
        if (!shown(g)) return null;
        var btn = g.querySelector(':scope > button'), body = g.querySelector('.st171-b'), ic = g.querySelector('.icon178');
        var open = !!btn && btn.getAttribute('aria-expanded') === 'true' && shown(body);
        return { i: i, svg: svgOf(ic), icon: ic && !ic.querySelector('svg') ? ic.textContent.trim() : '', t: t(g, '.text178 b'), s: t(g, '.text178 small'),
          accordion: !!body, open: open,
          items: open ? Array.prototype.map.call(body.querySelectorAll(':scope > button'), function (b, j) {
            if (!shown(b)) return null;
            var badge = b.querySelector('b em'), name = b.querySelector('b');
            return { j: j, icon: t(b, ':scope > span'), t: name ? Array.prototype.filter.call(name.childNodes, function (n) { return n !== badge; }).map(function (n) { return n.textContent; }).join('').trim() : '',
              badge: badge ? badge.textContent.trim() : '', s: t(b, 'small') };
          }).filter(Boolean) : [] };
      }).filter(Boolean),
      acct: shown(acct) ? { badge: t(acct, '.acct92-badge'), t: t(acct, '.acct92-top b'), s: t(acct, '.acct92-top small'), go: shown(acct.querySelector('.acct117-go')) ? t(acct, '.acct117-go') : '',
        stats: Array.prototype.filter.call(acct.querySelectorAll('.acct92-stats span'), shown).map(function (e) { return e.textContent.replace(/\s+/g, ' ').trim(); }),
        acts: Array.prototype.map.call(acct.querySelectorAll('.acct92-act button'), function (b) { return shown(b) ? b.textContent.trim() : ''; }),
        link: shown(acct.querySelector('.acct92-link')) ? t(acct, '.acct92-link') : '' } : null,
      logout: shown(lo) ? lo.textContent.trim() : '', version: txt('#settings .st171-ver'), tutorial: shown(tut) ? tut.textContent.trim() : ''
    };
  }
  // Kas Masuk / Pengeluaran: formulir native; nilai ditulis ke input HTML yang sama, tombol simpan memakai logika HTML.
  function cashModel(id) {
    return function () {
      var page = document.getElementById(id);
      var sel = page && page.querySelector('select.cash-input'), amt = page && page.querySelector('.cash-input-group input');
      var note = page && page.querySelector('.cash-form-wrap > label:nth-child(3) input'), btn = page && page.querySelector('.cash-submit');
      if (!sel || !amt || !note || !btn) return null;
      return {
        title: txt('#' + id + ' .subhead b'), heading: txt('#' + id + ' .report-title-line b'),
        stats: Array.prototype.filter.call(page.querySelectorAll('.cash-stat-list .report-stat-row'), shown).map(function (r) {
          var ic = r.querySelector('.report-stat-icon'), left = r.querySelector('.report-stat-left');
          return { icon: ic ? ic.textContent.trim() : '', kind: ic && ic.classList.contains('noncash') ? 'noncash' : 'cash',
            t: left ? left.textContent.replace(ic ? ic.textContent : '', '').trim() : '', v: ((r.querySelector('strong')) || {}).textContent || '' };
        }),
        type: { v: sel.value, options: Array.prototype.map.call(sel.options, function (o) { return o.textContent.trim(); }), index: sel.selectedIndex },
        amount: field(amt), note: field(note), submit: btn.textContent.trim(), subtract: btn.classList.contains('subtract')
      };
    };
  }
  function cashcloseModel() {
    var page = document.getElementById('cashclose');
    function text(el) { return el ? el.textContent.replace(/\s+/g, ' ').trim() : ''; }
    function input(el) { return el ? { sel: '#' + el.id, v: el.value, ph: el.placeholder || '', multiline: el.tagName === 'TEXTAREA' } : null; }
    var sections = Array.prototype.map.call(page.querySelectorAll('.kc137 > .card'), function (card) {
      return {
        title: text(card.querySelector('h4')), sub: text(card.querySelector('p.s')),
        methods: Array.prototype.map.call(card.querySelectorAll('.kc137-pm > div'), function (e) { return { t: text(e.querySelector('small')), v: text(e.querySelector('b')), s: text(e.querySelector('i')), c: getComputedStyle(e.querySelector('b')).color }; }),
        unpaid: text(card.querySelector('.kc137-unpaid')),
        rows: Array.prototype.map.call(card.querySelectorAll('.kc137-ln'), function (e) { return { t: text(e.querySelector('span')), v: text(e.querySelector('b')), input: input(e.querySelector('input')), c: e.querySelector('b') ? getComputedStyle(e.querySelector('b')).color : '' }; }),
        denominations: Array.prototype.map.call(card.querySelectorAll('#kc-den label'), function (e, i) { return { i: i, t: text(e.querySelector('span')), v: e.querySelector('input').value }; }),
        physical: input(card.querySelector('#kc-phys')),
        diff: colors(card.querySelector('#kc-diff')),
        reconcile: Array.prototype.map.call(card.querySelectorAll('.kc137-rec'), function (e) { return { t: text(e.querySelector('b')), s: text(e.querySelector('small')), input: input(e.querySelector('input')), badge: colors(e.querySelector('em')) }; }),
        note: input(card.querySelector('textarea')),
        history: Array.prototype.map.call(card.querySelectorAll('.kc137-hist'), function (e) { return { date: text(e.querySelector('.d')), t: text(e.querySelector('div b')), s: text(e.querySelector('div small')), badge: colors(e.querySelector('em')) }; }),
        empty: text(card.querySelector('.lb137-empty'))
      };
    });
    return { title: txt('#cashclose .subhead b'), date: txt('#kc-date'), total: txt('#kc-omset'), label: txt('#cashclose .kc137-hero .r small:last-child'), status: txt('#cashclose .kc137-hero .st'), meta: txt('#kc-meta1') + ' · ' + txt('#kc-meta2'), sections: sections, submit: txt('#cashclose .kc137-go') };
  }
  // HTML toast notifications ("… ditambahkan") are drawn by Flutter while a native page covers the WebView.
  function toastText() {
    var t = document.querySelector('#toast90.show, .toast.show');
    return t && visible(t) ? t.textContent.replace(/\s+/g, ' ').trim() : '';
  }
  window.__goyanaCovering = coveringOverlay;
  var NATIVE = { home: homeModel, orders: ordersModel, addorder: addorderModel, customers: customersModel, reports: reportsModel, settings: settingsModel, cashclose: cashcloseModel, cashin: cashModel('cashin'), cashout: cashModel('cashout') };
  var pageTimer = 0, lastPage = '';
  function reportPage() {
    pageTimer = 0;
    var page = document.querySelector('.page.active'), id = page && page.id;
    var native = !!id && NATIVE.hasOwnProperty(id) && !coveringOverlay();
    var model = native ? NATIVE[id]() : null;
    if (!model) native = false;
    var msg = JSON.stringify({ event: 'native', page: native ? id : null, model: model, toast: native ? toastText() : '' });
    if (msg === lastPage) return;
    lastPage = msg;
    try { window.GoyanaNative.postMessage(msg); } catch (e) {}
  }
  function scheduleHome() { if (!pageTimer) pageTimer = setTimeout(reportPage, 80); }
  window.__goyanaHomeRefresh = function () { lastPage = ''; scheduleHome(); };
  window.__goyanaTap = function (sel, index, child) {
    var list = document.querySelectorAll(sel), el = list[index || 0];
    if (el && child) el = el.querySelector(child);
    if (el) el.click();
    scheduleHome();
    return !!el;
  };
  window.__goyanaSearch = function (sel, value) {
    var el = document.querySelector(sel);
    if (!el) return false;
    el.value = value;
    ['input', 'keyup', 'change'].forEach(function (type) { el.dispatchEvent(new Event(type, { bubbles: true })); });
    scheduleHome();
    return true;
  };
  function watchHome() {
    new MutationObserver(scheduleHome).observe(document.body, { subtree: true, childList: true, attributes: true, attributeFilter: ['class', 'hidden', 'style'], characterData: true });
    scheduleHome();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', watchHome); else watchHome();

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
