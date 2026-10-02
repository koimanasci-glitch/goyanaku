/* GOYANA sync core — loaded first in <head>, before the app reads its data.
 *
 * Maps the app's existing local storage (unchanged) to server records and back.
 * Records downloaded from the server are staged in "goyana-sync-inbox" and merged
 * here on the next page start, before any app script runs, so the app always
 * starts from merged data and never overwrites it with an older in-memory copy.
 */
(function () {
  'use strict';
  var API = '__GOYANA_API_URL__';
  var LS = window.localStorage;
  function read(k, d) { try { var v = LS.getItem(k); return v == null ? d : JSON.parse(v); } catch (e) { return d; } }
  function raw(k) { try { return LS.getItem(k); } catch (e) { return null; } }
  function write(k, v) { LS.setItem(k, JSON.stringify(v)); }

  // Stable JSON (sorted keys) so the same data always gives the same fingerprint.
  function canon(v) {
    if (v === null || typeof v !== 'object') return JSON.stringify(v === undefined ? null : v);
    if (Array.isArray(v)) return '[' + v.map(canon).join(',') + ']';
    return '{' + Object.keys(v).filter(function (k) { return v[k] !== undefined; }).sort()
      .map(function (k) { return JSON.stringify(k) + ':' + canon(v[k]); }).join(',') + '}';
  }
  function hash(s) { var h = 2166136261; for (var i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); } return (h >>> 0).toString(36) + ':' + s.length; }

  function normPhone(p) { var n = String(p || '').replace(/\D/g, ''); if (n.indexOf('0') === 0) n = '62' + n.slice(1); return n; }
  function customerKey(c) { var p = normPhone(c.phone); return p ? 'phone:' + p : 'name:' + String(c.name || '').trim().toLowerCase(); }
  function orderId(r) { return String((r && r.fields && r.fields[1] && r.fields[1][0]) || '').trim(); }
  function activeOutlet() { return read('goyana-active-outlet180', '') || ''; }

  var BUSINESS = 'goyana-business177', SERVICES = 'goyana-services158', STOCK = 'goyana-stock181',
      COURIERS = 'goyana-couriers181', OUTLETS = 'goyana-outlets180';
  var SETTINGS = ['goyana-transport183', 'goyana-qris-text', 'goyana-qris-image'];
  var STOCK_PARTS = { stock_items: 'items', stock_ledger: 'ledger', stock_suppliers: 'suppliers', stock_purchases: 'purchases', stock_recipes: 'recipes' };
  var WATCHED = [BUSINESS, SERVICES, STOCK, COURIERS, OUTLETS].concat(SETTINGS);

  function idOf(x) { return x && (x.id || x.key) ? String(x.id || x.key) : hash(canon(x)); }

  /** Current local data as {collection: {key: {outlet, data}}}. */
  function extract() {
    var out = {}, b = read(BUSINESS, {}) || {};
    function put(c, k, outlet, data) { if (!k) return; (out[c] = out[c] || {})[k] = { outlet: outlet || null, data: data }; }
    (b.orders || []).forEach(function (r) {
      var id = orderId(r); if (!id) return;
      put('orders', id, r.dataset && r.dataset.outlet180, { card: r, detail: (b.details || {})[id] || null });
    });
    (b.customers || []).forEach(function (c) { if (c && c.name) put('customers', customerKey(c), null, c); });
    var dep = b.deposits178 || {};
    Object.keys(dep).forEach(function (k) { put('deposits', k, null, dep[k]); });
    var kas = b.kas;
    if (kas && ((kas.sales || []).length || (kas.ins || []).length || (kas.outs || []).length || kas.start)) {
      put('kas', activeOutlet() + '|' + (kas.kasir || ''), activeOutlet(), kas);
    }
    (read(SERVICES, []) || []).forEach(function (s) { if (s && s.key) put('services', String(s.key), null, s); });
    (read(COURIERS, []) || []).forEach(function (c) { put('couriers', idOf(c), null, c); });
    var st = read(STOCK, null);
    if (st) Object.keys(STOCK_PARTS).forEach(function (c) { (st[STOCK_PARTS[c]] || []).forEach(function (x) { put(c, idOf(x), null, x); }); });
    (read(OUTLETS, []) || []).forEach(function (o) { if (o && /^srv-\d+$/.test(o.id)) put('outlet_profiles', o.id, null, o); });
    SETTINGS.forEach(function (k) { var v = raw(k); if (v != null && v !== '') put('settings', k, null, v); });
    return out;
  }

  /** Merge server records into local storage (deleted = remove). */
  function apply(records) {
    if (!records || !records.length) return 0;
    var b = read(BUSINESS, {}) || {}, bChanged = false;
    b.orders = b.orders || []; b.customers = b.customers || []; b.details = b.details || {}; b.deposits178 = b.deposits178 || {};
    var services = read(SERVICES, []) || [], couriers = read(COURIERS, []) || [], stock = read(STOCK, null), outlets = read(OUTLETS, []) || [];
    var touched = {};
    function upsert(list, key, keyFn, value, del) {
      var i = list.findIndex(function (x) { return keyFn(x) === key; });
      if (del) { if (i >= 0) list.splice(i, 1); return; }
      if (i >= 0) list[i] = value; else list.push(value);
    }
    records.forEach(function (r) {
      var del = !!r.deleted, d = r.data;
      switch (r.collection) {
        case 'orders':
          upsert(b.orders, r.key, orderId, d && d.card, del);
          if (del) delete b.details[r.key]; else if (d && d.detail) b.details[r.key] = d.detail;
          bChanged = true; break;
        case 'customers': upsert(b.customers, r.key, customerKey, d, del); bChanged = true; break;
        case 'deposits': if (del) delete b.deposits178[r.key]; else b.deposits178[r.key] = d; bChanged = true; break;
        case 'kas':
          // Only restore this phone's own cash drawer (e.g. after reinstall); other drawers stay on the server.
          var mine = activeOutlet() + '|' + ((b.kas && b.kas.kasir) || (d && d.kasir) || '');
          var empty = !b.kas || !((b.kas.sales || []).length || (b.kas.ins || []).length || (b.kas.outs || []).length);
          if (!del && r.key === mine && empty) { b.kas = d; bChanged = true; }
          break;
        case 'services': upsert(services, r.key, function (x) { return String(x.key); }, d, del); touched[SERVICES] = services; break;
        case 'couriers': upsert(couriers, r.key, idOf, d, del); touched[COURIERS] = couriers; break;
        case 'outlet_profiles': upsert(outlets, r.key, function (x) { return x.id; }, d, del); touched[OUTLETS] = outlets; break;
        case 'settings': if (SETTINGS.indexOf(r.key) >= 0) { if (del) LS.removeItem(r.key); else LS.setItem(r.key, d); } break;
        default:
          if (STOCK_PARTS[r.collection]) {
            stock = stock || { items: [], ledger: [], suppliers: [], purchases: [], recipes: [] };
            var part = stock[STOCK_PARTS[r.collection]] = stock[STOCK_PARTS[r.collection]] || [];
            upsert(part, r.key, idOf, d, del); touched[STOCK] = stock;
          }
      }
    });
    if (bChanged) {
      b.orders = b.orders.filter(Boolean).sort(function (x, y) {
        return String((y.dataset || {}).created177 || '').localeCompare(String((x.dataset || {}).created177 || ''));
      });
      write(BUSINESS, b);
    }
    Object.keys(touched).forEach(function (k) { write(k, touched[k]); });
    return records.length;
  }

  function fingerprint(rec) { return hash(canon({ o: rec.outlet || null, d: rec.data })); }

  /** Apply staged server records, then remember their fingerprints so they are not pushed back. */
  function applyInbox() {
    var inbox = read('goyana-sync-inbox', null);
    if (!inbox || !inbox.length) return 0;
    try {
      apply(inbox);
      var state = read('goyana-sync-state', { cursor: 0, recs: {} }), now = extract();
      inbox.forEach(function (r) {
        var ck = r.collection + '|' + r.key, local = now[r.collection] && now[r.collection][r.key];
        if (r.deleted) state.recs[ck] = { rev: r.rev, h: null };
        else state.recs[ck] = { rev: r.rev, h: local ? fingerprint(local) : null };
      });
      write('goyana-sync-state', state);
      LS.removeItem('goyana-sync-inbox');
      return inbox.length;
    } catch (e) {
      console.warn('GOYANA sync: data masuk gagal diterapkan', e);
      return 0;
    }
  }

  window.GoyanaSyncCore = {
    api: function () { return String(raw('goyana-api-url') || API || '').replace(/\/+$/, '').replace('__GOYANA_API_URL__', ''); },
    read: read, write: write, canon: canon, hash: hash, extract: extract, apply: apply,
    fingerprint: fingerprint, applyInbox: applyInbox, watched: WATCHED, customerKey: customerKey
  };
  window.GoyanaSyncCore.applied = applyInbox();
})();
