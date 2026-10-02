/*
 * GOYANA Flutter: local data in SQLite instead of the WebView's small localStorage.
 *
 * Loaded first in <head> (Flutter build only). MainActivity.kt exposes
 * window.GoyanaStore (synchronous, backed by an SQLite database on the phone).
 * window.localStorage is replaced by an object with the same API, so all
 * existing app code keeps working unchanged. Existing localStorage data is
 * copied into SQLite once.
 */
(function () {
  'use strict';
  var native = window.GoyanaStore;
  if (!native || window.__goyanaStore) return;
  var MIGRATED = '__goyana_sqlite_migrated';
  var cache = {};
  try { cache = JSON.parse(native.all() || '{}') || {}; } catch (e) { cache = {}; }

  if (!cache[MIGRATED]) {
    var old = {};
    try {
      var ls = window.localStorage;
      for (var i = 0; i < ls.length; i++) { var k = ls.key(i); if (k != null && !(k in cache)) old[k] = ls.getItem(k); }
    } catch (e) { /* no old data */ }
    old[MIGRATED] = new Date().toISOString();
    native.setMany(JSON.stringify(old));
    Object.keys(old).forEach(function (k) { cache[k] = old[k]; });
  }

  function keys() { return Object.keys(cache).filter(function (k) { return k !== MIGRATED; }); }
  function notify(key) { try { window.dispatchEvent(new CustomEvent('goyana-storage', { detail: { key: key } })); } catch (e) {} }

  var api = {
    getItem: function (k) { k = String(k); return Object.prototype.hasOwnProperty.call(cache, k) && k !== MIGRATED ? cache[k] : null; },
    setItem: function (k, v) {
      k = String(k); v = String(v);
      if (cache[k] === v) return;
      if (!native.set(k, v)) throw new DOMException('Penyimpanan HP penuh', 'QuotaExceededError');
      cache[k] = v; notify(k);
    },
    removeItem: function (k) { k = String(k); if (!(k in cache)) return; native.remove(k); delete cache[k]; notify(k); },
    clear: function () { keys().forEach(function (k) { native.remove(k); delete cache[k]; }); notify(null); },
    key: function (i) { var list = keys(); return i >= 0 && i < list.length ? list[i] : null; }
  };

  var store = new Proxy(api, {
    get: function (t, k) {
      if (k === 'length') return keys().length;
      if (k in t) return t[k];
      return typeof k === 'string' ? t.getItem(k) === null ? undefined : t.getItem(k) : undefined;
    },
    set: function (t, k, v) { if (typeof v === 'function' || k in t) t[k] = v; else t.setItem(k, v); return true; },
    has: function (t, k) { return k in t || (typeof k === 'string' && t.getItem(k) !== null); },
    deleteProperty: function (t, k) { t.removeItem(k); return true; },
    ownKeys: function () { return keys(); },
    getOwnPropertyDescriptor: function (t, k) {
      var v = t.getItem(k);
      return v === null ? undefined : { value: v, enumerable: true, configurable: true, writable: true };
    }
  });

  Object.defineProperty(window, 'localStorage', { configurable: true, get: function () { return store; } });
  window.__goyanaStore = { engine: 'sqlite', keys: keys };
})();
