/* GOYANA v197 — sinkronisasi ke server pusat (Laravel).
 * Aktif hanya jika alamat server diisi (saat build atau di Pengaturan → Sinkronisasi).
 * Tanpa server, aplikasi tetap bekerja offline seperti sebelumnya.
 */
(function () {
  'use strict';
  var core = window.GoyanaSyncCore;
  if (!core || window.GoyanaSync) return;
  var LS = window.localStorage;
  var AUTH = 'goyana-sync-auth', STATE = 'goyana-sync-state', INBOX = 'goyana-sync-inbox', OUTBOX = 'goyana-sync-outbox', DEVICE = 'goyana-sync-device';
  var status = { phase: 'idle', pending: 0, last: null, error: '', rejected: '' };
  var busy = false, timer = null, lastTouch = Date.now(), reloadTimer = null;
  var $ = function (id) { return document.getElementById(id); };
  function toast(m) { if (window.toast90) window.toast90(m); }
  function uuid() { return (crypto.randomUUID ? crypto.randomUUID() : 'd' + Date.now().toString(36) + Math.random().toString(36).slice(2)); }
  function device() { var d = LS.getItem(DEVICE); if (!d) { d = uuid(); LS.setItem(DEVICE, d); } return d; }
  function auth() { var a = core.read(AUTH, null); return a && a.token && (!a.expires_at || new Date(a.expires_at) > new Date()) ? a : null; }
  function state() { var s = core.read(STATE, null); return s && s.recs ? s : { cursor: 0, recs: {} }; }

  function request(method, path, body) {
    var a = auth(), headers = { 'Accept': 'application/json' };
    if (body) headers['Content-Type'] = 'application/json';
    if (a) headers.Authorization = 'Bearer ' + a.token;
    return fetch(core.api() + '/api' + path, { method: method, headers: headers, body: body ? JSON.stringify(body) : undefined })
      .then(function (r) {
        return r.json().catch(function () { return {}; }).then(function (j) {
          if (r.status === 401) { LS.removeItem(AUTH); throw new Error('Sesi berakhir. Masuk lagi.'); }
          if (!r.ok) throw new Error(j.message || (j.errors && Object.values(j.errors)[0][0]) || 'Server menolak (' + r.status + ')');
          return j;
        });
      });
  }

  // ---------- outlets: local outlet ids become server ids (srv-<id>) ----------
  function replaceDeep(v, from, to) {
    if (v === from) return to;
    if (Array.isArray(v)) return v.map(function (x) { return replaceDeep(x, from, to); });
    if (v && typeof v === 'object') { var o = {}; Object.keys(v).forEach(function (k) { o[k === from ? to : k] = replaceDeep(v[k], from, to); }); return o; }
    return v;
  }
  function mapOutlets(me) {
    var local = core.read('goyana-outlets180', []) || [], changed = false;
    me.outlets.forEach(function (s) {
      var id = 'srv-' + s.id;
      if (local.some(function (o) { return o.id === id; })) return;
      var legacy = local.find(function (o) { return !/^srv-\d+$/.test(o.id); });
      if (legacy) {
        var old = legacy.id;
        core.watched.concat(['goyana-active-outlet180']).forEach(function (k) {
          var v = core.read(k, undefined); if (v === undefined) return;
          var nv = replaceDeep(v, old, id); if (JSON.stringify(nv) !== JSON.stringify(v)) core.write(k, nv);
        });
        local = core.read('goyana-outlets180', []) || [];
        local.forEach(function (o) { if (o.id === id && !o.name) o.name = s.name; });
      } else {
        local.push({ id: id, name: s.name, address: '', phone: '', logo: '' });
      }
      changed = true;
    });
    if (changed) core.write('goyana-outlets180', local);
    var active = core.read('goyana-active-outlet180', '');
    var allowed = me.outlets.map(function (s) { return 'srv-' + s.id; });
    if (me.user.role !== 'owner' || allowed.indexOf(active) < 0) {
      if (allowed[0] && active !== allowed[0] && (me.user.role !== 'owner' || !/^srv-/.test(active))) { core.write('goyana-active-outlet180', allowed[0]); changed = true; }
    }
    return changed;
  }

  // ---------- sync cycle ----------
  function pendingChanges() {
    var now = core.extract(), st = state(), inbox = core.read(INBOX, []) || [], staged = {};
    inbox.forEach(function (r) { staged[r.collection + '|' + r.key] = 1; });
    var list = [];
    Object.keys(now).forEach(function (c) {
      Object.keys(now[c]).forEach(function (k) {
        var ck = c + '|' + k, rec = now[c][k], h = core.fingerprint(rec), known = st.recs[ck];
        if (staged[ck] || (known && known.h === h)) return;
        list.push({ ck: ck, h: h, collection: c, key: k, outlet: rec.outlet, data: rec.data, deleted: false, base_rev: known ? known.rev : 0 });
      });
    });
    Object.keys(st.recs).forEach(function (ck) {
      var i = ck.indexOf('|'), c = ck.slice(0, i), k = ck.slice(i + 1), known = st.recs[ck];
      if (!known.h || staged[ck] || (now[c] && now[c][k])) return;
      list.push({ ck: ck, h: null, collection: c, key: k, outlet: null, data: null, deleted: true, base_rev: known.rev });
    });
    return list;
  }

  function pull() {
    var st = state(), got = [];
    function page(cursor) {
      return request('GET', '/sync/pull?cursor=' + cursor).then(function (j) {
        var cur = state();
        j.records.forEach(function (r) {
          var known = cur.recs[r.collection + '|' + r.key];
          if (!known || known.rev < r.rev) got.push(r);
        });
        status.readOnly = !!j.read_only;
        if (got.length) {
          var inbox = core.read(INBOX, []) || [], byKey = {};
          inbox.concat(got).forEach(function (r) { byKey[r.collection + '|' + r.key] = r; });
          core.write(INBOX, Object.keys(byKey).map(function (k) { return byKey[k]; }));
          got = [];
        }
        cur.cursor = j.cursor; core.write(STATE, cur);
        return j.more ? page(j.cursor) : null;
      });
    }
    return page(st.cursor || 0);
  }

  function push() {
    var changes = pendingChanges(), outbox = core.read(OUTBOX, {}) || {};
    status.pending = changes.length;
    if (!changes.length) return Promise.resolve();
    if (status.readOnly) { status.rejected = 'Paket berakhir: perubahan di HP ini belum terkirim.'; return Promise.resolve(); }
    changes.forEach(function (c) { var prev = outbox[c.ck]; c.op_id = prev && prev.h === c.h ? prev.op : uuid(); outbox[c.ck] = { h: c.h, op: c.op_id }; });
    core.write(OUTBOX, outbox);
    var batches = [];
    for (var i = 0; i < changes.length; i += 100) batches.push(changes.slice(i, i + 100));
    return batches.reduce(function (p, batch) {
      return p.then(function () {
        return request('POST', '/sync/push', { device_id: device(), changes: batch.map(function (c) {
          return { op_id: c.op_id, collection: c.collection, key: c.key, outlet: c.outlet, data: c.data, deleted: c.deleted, base_rev: c.base_rev };
        }) }).then(function (j) {
          var st = state(), ob = core.read(OUTBOX, {}) || {}, conflicts = [], rejected = '';
          j.results.forEach(function (res, i) {
            var c = batch[i];
            if (res.status === 'applied') { st.recs[c.ck] = { rev: res.rev, h: c.h }; delete ob[c.ck]; }
            else if (res.status === 'conflict') { conflicts.push(res.record); delete ob[c.ck]; }
            else rejected = res.message || 'Sebagian data ditolak server';
          });
          core.write(STATE, st); core.write(OUTBOX, ob);
          if (conflicts.length) {
            var inbox = core.read(INBOX, []) || [];
            core.write(INBOX, inbox.concat(conflicts));
          }
          if (rejected && rejected !== status.rejected) toast(rejected);
          status.rejected = rejected;
        });
      });
    }, Promise.resolve()).then(function () { status.pending = pendingChanges().length; });
  }

  var running = null;
  function cycle() {
    // A sync already running: wait for it, then run once more so the caller sees fresh state.
    if (running) return running.then(function () { return running || cycle(); });
    if (!core.api() || !auth()) { render(); return Promise.resolve(); }
    if (!navigator.onLine) { status.phase = 'offline'; status.pending = pendingChanges().length; render(); return Promise.resolve(); }
    busy = true; status.phase = 'syncing'; render();
    running = pull().then(push).then(function () {
      status.phase = 'ok'; status.error = ''; status.last = new Date();
    }).catch(function (e) {
      status.phase = navigator.onLine ? 'error' : 'offline'; status.error = e.message;
      try { status.pending = pendingChanges().length; } catch (_) {}
    }).then(function () { busy = false; running = null; render(); scheduleReload(); });
    return running;
  }

  // Apply downloaded data by restarting the page when the user is not in the middle of something.
  function idle() {
    if (document.querySelector('.sheet91.show,.flow-modal.show,.f61-overlay.show,.qty116.show,#g62-order-detail.show,#lg167.show')) return false;
    var a = document.activeElement;
    if (a && /^(INPUT|TEXTAREA|SELECT)$/.test(a.tagName)) return false;
    var page = document.querySelector('.page.active');
    if (page && ['home', 'orders', 'customers', 'reports', 'settings', 'datacenter'].indexOf(page.id) < 0) return false;
    return Date.now() - lastTouch > 6000;
  }
  function scheduleReload() {
    if (reloadTimer || !(core.read(INBOX, []) || []).length) return;
    reloadTimer = setInterval(function () {
      if (!(core.read(INBOX, []) || []).length) { clearInterval(reloadTimer); reloadTimer = null; return; }
      if (document.visibilityState === 'visible' && idle()) { clearInterval(reloadTimer); location.reload(); }
    }, 2000);
  }
  ['pointerdown', 'keydown', 'touchstart'].forEach(function (ev) { document.addEventListener(ev, function () { lastTouch = Date.now(); }, true); });

  // Local writes trigger a quick sync (WebView storage via Storage.prototype, SQLite store via event).
  window.addEventListener('goyana-storage', function (e) {
    var k = e.detail && e.detail.key;
    if (k && core.watched.indexOf(k) >= 0) { clearTimeout(timer); timer = setTimeout(cycle, 2500); }
    if (k === 'goyana-logged-out' && LS.getItem(k) === '1') logout();
  });
  var setItem = Storage.prototype.setItem;
  Storage.prototype.setItem = function (k, v) {
    setItem.call(this, k, v);
    if (this === LS && core.watched.indexOf(k) >= 0) { clearTimeout(timer); timer = setTimeout(cycle, 2500); }
    if (this === LS && k === 'goyana-logged-out' && v === '1') logout();
  };

  // ---------- login (reuses the existing login screen) ----------
  function login(email, password) {
    if (!/@/.test(email)) return Promise.reject(new Error('Gunakan email akun GOYANA untuk masuk ke server.'));
    return request('POST', '/session', { email: email, password: password }).then(function (s) {
      core.write(AUTH, { token: s.token, expires_at: s.expires_at });
      return request('GET', '/me');
    }).then(function (me) {
      var a = auth(); a.user = me.user; a.business = me.business; a.outlets = me.outlets; a.email = email; core.write(AUTH, a);
      return mapOutlets(me);
    });
  }
  function logout() {
    var a = auth();
    if (a && core.api()) request('DELETE', '/session').catch(function () {});
    LS.removeItem(AUTH); render();
  }
  // The login button/Enter key are intercepted (capture phase) so this works no matter
  // which earlier patch replaced window.login167 (v189 shows a "server belum terhubung" note).
  var loggingIn = false;
  function serverLogin() {
    var u = (($('lg167-u') || {}).value || '').trim(), p = ($('lg167-p') || {}).value || '';
    if (!u) { toast('Isi email akun GOYANA'); return; }
    if (!p) { toast('Isi password'); return; }
    if (loggingIn) return;
    loggingIn = true; toast('Masuk ke server…');
    login(u.toLowerCase(), p).then(function (outletsChanged) {
      try { LS.removeItem('goyana-logged-out'); } catch (e) {}
      var l = $('lg167'); if (l) l.classList.remove('show');
      if ($('lg167-p')) $('lg167-p').value = '';
      toast('Berhasil masuk · data disinkronkan');
      return cycle().then(function () { if (outletsChanged || (core.read(INBOX, []) || []).length) location.reload(); });
    }).catch(function (e) { toast(e.message); }).then(function () { loggingIn = false; });
  }
  function intercept(e) {
    if (!core.api()) return;
    var btn = e.type === 'click' && e.target.closest && e.target.closest('#lg167 button');
    if (btn && /^\s*Daftar\s*$/.test(btn.textContent)) {
      e.preventDefault(); e.stopImmediatePropagation();
      window.open(core.api() + '/register', '_blank'); toast('Daftar di halaman web, lalu masuk dengan email tersebut'); return;
    }
    var forgot = e.type === 'click' && e.target.closest && e.target.closest('#lg167 button, #lg167 a');
    if (forgot && /Lupa password/i.test(forgot.textContent)) {
      e.preventDefault(); e.stopImmediatePropagation();
      window.open(core.api() + '/forgot-password', '_blank'); toast('Buat password baru lewat link yang dikirim ke email'); return;
    }
    var go = e.type === 'click' && e.target.closest && e.target.closest('#lg167 .go');
    var enter = e.type === 'keydown' && e.key === 'Enter' && e.target.id === 'lg167-p';
    if (!go && !enter) return;
    e.preventDefault(); e.stopImmediatePropagation(); serverLogin();
  }
  document.addEventListener('click', intercept, true);
  document.addEventListener('keydown', intercept, true);
  // With a server, outlets come from the account: the local "isi nama outlet" setup must not cover the login.
  function guardOnboarding() {
    var ob = $('ob189'); if (!ob || !core.api()) return;
    var hideIfLoggedOut = function () { if (!auth() && !ob.hidden && $('lg167') && $('lg167').classList.contains('show')) ob.hidden = true; };
    new MutationObserver(hideIfLoggedOut).observe(ob, { attributes: true, attributeFilter: ['hidden'] });
    hideIfLoggedOut();
  }
  function loginNote() {
    var n = document.querySelector('#lg167 .auth189-note');
    if (n && core.api()) n.textContent = 'Masuk dengan email dan password akun GOYANA. Data tersinkron ke server.';
    var u = $('lg167-u'); if (u && core.api()) u.placeholder = 'Email akun GOYANA';
  }

  // ---------- status card in Pengaturan ----------
  function fmt(d) { return d ? d.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }) : ''; }
  function render() {
    var box = $('sync197'); if (!box) return;
    var a = auth(), api = core.api(), line, color;
    if (!api) { line = 'Belum terhubung ke server · data hanya di HP ini'; color = '#9AA0A6'; }
    else if (!a) { line = 'Belum masuk · data hanya di HP ini'; color = '#E8A23A'; }
    else if (status.phase === 'offline') { line = 'Offline · ' + status.pending + ' data menunggu sinkronisasi'; color = '#E8A23A'; }
    else if (status.phase === 'error') { line = 'Sinkronisasi bermasalah · ' + status.error; color = '#E8493F'; }
    else if (status.phase === 'syncing') { line = 'Menyinkronkan…'; color = '#1E7BE0'; }
    else if (status.pending) { line = status.pending + ' data menunggu sinkronisasi' + (status.rejected ? ' · ' + status.rejected : ''); color = '#E8A23A'; }
    else { line = 'Online · semua data tersinkron' + (status.last ? ' · ' + fmt(status.last) : ''); color = '#1BA672'; }
    box.querySelector('.s197-dot').style.background = color;
    box.querySelector('.s197-line').textContent = line;
    box.querySelector('.s197-who').textContent = a && a.user ? a.user.name + ' · ' + a.user.role_label + (a.business ? ' · ' + a.business.name : '') : '';
    box.querySelector('.s197-server').hidden = !!api && !!a;
    box.querySelector('.s197-now').hidden = !a;
  }
  function mount() {
    var host = document.querySelector('#settings .content');
    if (!host || $('sync197')) return;
    var box = document.createElement('div');
    box.id = 'sync197';
    box.style.cssText = 'background:#fff;border:1px solid #EEF0F3;border-radius:14px;padding:12px 14px;margin:0 0 12px;font-size:13px';
    box.innerHTML = '<div style="display:flex;align-items:center;gap:8px"><i class="s197-dot" style="width:9px;height:9px;border-radius:50%;flex:0 0 auto"></i>' +
      '<b style="font-size:13.5px">Sinkronisasi server</b></div><div class="s197-line" style="margin-top:4px;color:#5B5F6E"></div>' +
      '<div class="s197-who" style="color:#9AA0A6;font-size:12px"></div>' +
      '<div class="s197-server" style="margin-top:8px"><input class="s197-url" inputmode="url" placeholder="https://app.goyana.id" style="width:100%;box-sizing:border-box;height:38px;border:1px solid #E6E8EC;border-radius:10px;padding:0 10px;font:inherit">' +
      '<button type="button" class="s197-save" style="margin-top:6px;height:34px;border:0;border-radius:10px;padding:0 14px;background:#E8493F;color:#fff;font:inherit;font-weight:700">Simpan & masuk</button></div>' +
      '<button type="button" class="s197-now" style="margin-top:8px;height:34px;border:1px solid #E6E8EC;border-radius:10px;padding:0 14px;background:#fff;font:inherit;font-weight:700">Sinkronkan sekarang</button>';
    host.insertBefore(box, host.firstChild);
    box.querySelector('.s197-url').value = LS.getItem('goyana-api-url') || core.api();
    box.querySelector('.s197-save').onclick = function () {
      var url = box.querySelector('.s197-url').value.trim().replace(/\/+$/, '');
      if (!/^https?:\/\//.test(url)) return toast('Isi alamat server, contoh https://app.goyana.id');
      LS.setItem('goyana-api-url', url);
      if (!auth()) { var l = $('lg167'); if (l) l.classList.add('show'); }
      render(); cycle();
    };
    box.querySelector('.s197-now').onclick = function () { cycle(); };
    render();
  }

  window.GoyanaSync = { cycle: cycle, status: status, login: login, logout: logout, pending: pendingChanges, device: device };
  mount(); loginNote(); setTimeout(loginNote, 1500);
  window.GoyanaSync.serverLogin = serverLogin;
  if (core.api() && !auth()) { var l = $('lg167'); if (l) l.classList.add('show'); }
  guardOnboarding(); setTimeout(guardOnboarding, 1200);
  if (core.applied) toast('Data terbaru dari server sudah dimuat');
  window.addEventListener('online', function () { cycle(); });
  window.addEventListener('offline', function () { status.phase = 'offline'; render(); });
  document.addEventListener('visibilitychange', function () { if (document.visibilityState === 'visible') cycle(); });
  setInterval(cycle, 20000);
  setTimeout(cycle, 1500);
})();
