/* GOYANA v196 — layout fixes for small phones (320–360px wide).
 * Visual design unchanged; only stops fields/buttons from overflowing the
 * screen edge on narrow phones. Found by auditing all pages at 320/360/412/768/1280px. */
(function () {
  if (document.getElementById('goyana-v196')) return;
  var css = [
    /* Penambahan/Pengurangan Kas: Jumlah field ran 33px off-screen */
    '.cash-field-row{grid-template-columns:18px minmax(0,1fr)!important}',
    '.cash-field-row>*{min-width:0!important}',
    '.cash-input,.cash-input-group{max-width:100%!important;min-width:0!important;box-sizing:border-box!important}',
    '.cash-input input{min-width:0!important;width:100%!important}',
    /* Tutup Kasir: denomination counters (−/+) clipped in the right column */
    '.kc137-den{grid-template-columns:repeat(2,minmax(0,1fr))!important}',
    '.kc137-den>*{min-width:0!important;box-sizing:border-box!important}',
    '.kc137-den input{min-width:0!important;width:100%!important}',
    /* Ralat & Log: role switch pushed "Kasir" off-screen */
    '.rl139-seg{flex-wrap:wrap;max-width:100%;min-width:0}',
    '@media (max-width:360px){.rl139-seg button{padding:6px 7px!important}}'
  ].join('\n');
  var style = document.createElement('style');
  style.id = 'goyana-v196';
  style.textContent = css;
  document.head.appendChild(style);
})();
