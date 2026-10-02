/* GOYANA v198 — perbaikan alur Tambah Transaksi.
 * Langkah 1 "Cari nama / no handphone" sebelumnya tidak menyaring daftar pelanggan. */
(function () {
  'use strict';
  function norm(s) { return String(s || '').toLowerCase().replace(/\s+/g, ' ').trim(); }
  function digits(s) { return String(s || '').replace(/\D/g, '').replace(/^62/, '0'); }
  function filterCustomers() {
    var stage = document.getElementById('f61-customer');
    var input = stage && stage.querySelector('.f61-search input');
    if (!input) return;
    var q = norm(input.value), qd = digits(input.value), shown = 0;
    stage.querySelectorAll('.f61-person').forEach(function (p) {
      var name = norm((p.querySelector('b') || {}).textContent);
      var text = norm(p.textContent);
      var ok = !q || name.indexOf(q) >= 0 || text.indexOf(q) >= 0 || (qd.length >= 3 && digits(p.textContent).indexOf(qd) >= 0);
      p.style.display = ok ? '' : 'none';
      if (ok) shown++;
    });
    var empty = stage.querySelector('.f61-empty198');
    if (q && !shown) {
      if (!empty) {
        empty = document.createElement('p');
        empty.className = 'f61-empty198';
        empty.style.cssText = 'text-align:center;color:#8f98a4;font-size:13px;margin:28px 12px';
        stage.appendChild(empty);
      }
      empty.textContent = 'Pelanggan "' + input.value.trim() + '" tidak ditemukan';
      empty.hidden = false;
    } else if (empty) empty.hidden = true;
  }
  document.addEventListener('input', function (e) {
    if (e.target && e.target.closest && e.target.closest('#f61-customer .f61-search')) filterCustomers();
  }, true);
  function watch() {
    var stage = document.getElementById('f61-customer');
    if (!stage) return;
    // The list is re-rendered when the page opens; keep the typed filter applied.
    new MutationObserver(function (list) {
      if (list.some(function (m) { return m.type === 'childList' && !(m.target.classList && m.target.classList.contains('f61-empty198')); })) filterCustomers();
    }).observe(stage, { childList: true });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', watch); else watch();
  window.GoyanaFlowFix198 = { filterCustomers: filterCustomers };
})();
