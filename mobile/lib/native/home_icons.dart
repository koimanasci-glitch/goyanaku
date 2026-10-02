// SVG icons of the Beranda page, copied from index.html (#home). Stroke/fill
// attributes that the HTML sets through CSS are written inline here.
// ignore_for_file: constant_identifier_names

const svgLogo =
    '<svg viewBox="0 0 64 64"><path fill="#37afea" d="M8 16 16 8 32 24 48 8 56 16 40 32 56 48 48 56 32 40 16 56 8 48 24 32Z"/><path fill="#168fda" d="m16 24 8-8 32 32-8 8Z"/><path fill="#63cef0" d="m8 40 8-8 24 24-8 8Z" transform="translate(0 -8)"/></svg>';

const svgScan =
    '<svg viewBox="0 0 24 24" fill="none"><path d="M3 8V5a2 2 0 0 1 2-2h3M16 3h3a2 2 0 0 1 2 2v3M21 16v3a2 2 0 0 1-2 2h-3M8 21H5a2 2 0 0 1-2-2v-3" stroke="#1E7BE0" stroke-width="2.2" stroke-linecap="round"/><rect x="6.5" y="6.5" width="4" height="4" rx=".6" stroke="#1E7BE0" stroke-width="1.8"/><rect x="13.5" y="6.5" width="4" height="4" rx=".6" stroke="#1E7BE0" stroke-width="1.8"/><rect x="6.5" y="13.5" width="4" height="4" rx=".6" stroke="#1E7BE0" stroke-width="1.8"/><path d="M13.5 13.5h1.5v1.5h-1.5zM16 16h1.5v1.5H16zM13.5 16.5h1v1h-1zM16.5 13.5h1v1h-1z" fill="#1E7BE0"/></svg>';

/// Topbar flower pattern (30x30 tile), from the CSS background-image.
const svgTopbarPattern =
    '<svg xmlns="http://www.w3.org/2000/svg" width="30" height="30" viewBox="0 0 30 30"><g fill="#fff" fill-opacity=".16"><g transform="rotate(45 15 15)"><ellipse cx="15" cy="10" rx="2.4" ry="4.3"/><ellipse cx="15" cy="20" rx="2.4" ry="4.3"/><ellipse cx="10" cy="15" rx="4.3" ry="2.4"/><ellipse cx="20" cy="15" rx="4.3" ry="2.4"/></g><g transform="rotate(45 0 0)"><ellipse cx="0" cy="-5" rx="2.4" ry="4.3"/><ellipse cx="0" cy="5" rx="2.4" ry="4.3"/><ellipse cx="-5" cy="0" rx="4.3" ry="2.4"/><ellipse cx="5" cy="0" rx="4.3" ry="2.4"/></g><g transform="rotate(45 30 0)"><ellipse cx="30" cy="-5" rx="2.4" ry="4.3"/><ellipse cx="30" cy="5" rx="2.4" ry="4.3"/><ellipse cx="25" cy="0" rx="4.3" ry="2.4"/><ellipse cx="35" cy="0" rx="4.3" ry="2.4"/></g><g transform="rotate(45 0 30)"><ellipse cx="0" cy="25" rx="2.4" ry="4.3"/><ellipse cx="0" cy="35" rx="2.4" ry="4.3"/><ellipse cx="-5" cy="30" rx="4.3" ry="2.4"/><ellipse cx="5" cy="30" rx="4.3" ry="2.4"/></g><g transform="rotate(45 30 30)"><ellipse cx="30" cy="25" rx="2.4" ry="4.3"/><ellipse cx="30" cy="35" rx="2.4" ry="4.3"/><ellipse cx="25" cy="30" rx="4.3" ry="2.4"/><ellipse cx="35" cy="30" rx="4.3" ry="2.4"/></g></g><g fill="#F4583E" fill-opacity=".55"><circle cx="15" cy="15" r="1.2"/><circle cx="0" cy="0" r="1.2"/><circle cx="30" cy="0" r="1.2"/><circle cx="0" cy="30" r="1.2"/><circle cx="30" cy="30" r="1.2"/><circle cx="18.75" cy="18.75" r="0.9"/><circle cx="11.25" cy="18.75" r="0.9"/><circle cx="11.25" cy="11.25" r="0.9"/><circle cx="18.75" cy="11.25" r="0.9"/><circle cx="3.75" cy="3.75" r="0.9"/><circle cx="-3.75" cy="3.75" r="0.9"/><circle cx="-3.75" cy="-3.75" r="0.9"/><circle cx="3.75" cy="-3.75" r="0.9"/><circle cx="33.75" cy="3.75" r="0.9"/><circle cx="26.25" cy="3.75" r="0.9"/><circle cx="26.25" cy="-3.75" r="0.9"/><circle cx="33.75" cy="-3.75" r="0.9"/><circle cx="3.75" cy="33.75" r="0.9"/><circle cx="-3.75" cy="33.75" r="0.9"/><circle cx="-3.75" cy="26.25" r="0.9"/><circle cx="3.75" cy="26.25" r="0.9"/><circle cx="33.75" cy="33.75" r="0.9"/><circle cx="26.25" cy="33.75" r="0.9"/><circle cx="26.25" cy="26.25" r="0.9"/><circle cx="33.75" cy="26.25" r="0.9"/></g></svg>';

const svgSlides = [
  '<svg width="118" height="98" viewBox="0 0 118 98"><defs><linearGradient id="botBody" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#e9f2f8"/></linearGradient></defs><ellipse cx="70" cy="88" rx="30" ry="5" fill="#000" opacity=".07"/><rect x="45" y="25" width="46" height="42" rx="16" fill="url(#botBody)" stroke="#d3e0e8"/><circle cx="59" cy="44" r="4" fill="#6eaecb"/><circle cx="77" cy="44" r="4" fill="#6eaecb"/><path d="M59 55c5 4 13 4 18 0" fill="none" stroke="#7d94a3" stroke-width="2" stroke-linecap="round"/><rect x="63" y="15" width="10" height="11" rx="5" fill="#dfeaf0"/><circle cx="68" cy="14" r="4" fill="#f3b574"/><path d="M41 39H27c-6 0-10 4-10 10v8c0 6 4 10 10 10h5l8 7-2-7h3" fill="#ffffff" opacity=".92"/><circle cx="25" cy="53" r="2.2" fill="#75b3cf"/><circle cx="32" cy="53" r="2.2" fill="#75b3cf"/><circle cx="39" cy="53" r="2.2" fill="#75b3cf"/></svg>',
  '<svg width="118" height="98" viewBox="0 0 118 98"><ellipse cx="67" cy="88" rx="31" ry="5" fill="#000" opacity=".07"/><rect x="34" y="22" width="55" height="47" rx="11" fill="#fff" opacity=".95"/><rect x="42" y="31" width="11" height="28" rx="4" fill="#f1b477"/><rect x="58" y="39" width="11" height="20" rx="4" fill="#96c9bc"/><rect x="74" y="26" width="8" height="33" rx="4" fill="#89b7d1"/><circle cx="30" cy="71" r="13" fill="#fff" opacity=".94"/><path d="M30 64v14M23 71h14" stroke="#df9b5e" stroke-width="2.6" stroke-linecap="round"/><path d="M45 19l10-6 10 6 10-6 10 6" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round"/><circle cx="45" cy="19" r="3" fill="#fff"/><circle cx="55" cy="13" r="3" fill="#fff"/><circle cx="65" cy="19" r="3" fill="#fff"/><circle cx="75" cy="13" r="3" fill="#fff"/><circle cx="85" cy="19" r="3" fill="#fff"/></svg>',
  '<svg width="118" height="98" viewBox="0 0 118 98"><ellipse cx="67" cy="88" rx="31" ry="5" fill="#000" opacity=".07"/><rect x="35" y="20" width="50" height="56" rx="12" fill="#fff" opacity=".95"/><circle cx="60" cy="38" r="10" fill="#f3c4a3"/><path d="M46 64c1-11 6-17 14-17s13 6 14 17" fill="#91a5d4"/><circle cx="87" cy="29" r="12" fill="#fff" opacity=".92"/><path d="M82 29l3 3 6-7" fill="none" stroke="#7890c6" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/><rect x="19" y="29" width="17" height="8" rx="4" fill="#fff" opacity=".9"/><rect x="16" y="42" width="20" height="8" rx="4" fill="#fff" opacity=".8"/><rect x="20" y="55" width="16" height="8" rx="4" fill="#fff" opacity=".7"/></svg>',
];

const svgTileAdd =
    '<svg viewBox="0 0 48 48"><path d="M12 5h24v38l-4-3-4 3-4-3-4 3-4-3-4 3z" fill="#fff" stroke="#cfd8e3" stroke-width="1.5"/><path d="M17 15h14M17 22h14M17 29h8" fill="none" stroke="#87949e" stroke-width="2.2" stroke-linecap="round"/><circle cx="35" cy="34" r="9" fill="#e7354a"/><path d="M35 29v10M30 34h10" stroke="#fff" stroke-width="2.6" stroke-linecap="round"/></svg>';

const svgTileSearch =
    '<svg viewBox="0 0 48 48"><rect x="8" y="7" width="26" height="32" rx="4" fill="#f0f3f5" stroke="#cbd2d7"/><path d="M14 16h14M14 22h10M14 28h7" stroke="#8a98a1" stroke-width="2.2" stroke-linecap="round"/><circle cx="31" cy="31" r="8" fill="#fff" stroke="#e7354a" stroke-width="2.5"/><path d="m37 37 6 6" stroke="#e7354a" stroke-width="3" stroke-linecap="round"/></svg>';

const svgQr =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#E7354A" stroke-width="1.6"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><path d="M14 14h3v3h-3zM19 19h2M19 14v3M14 20h3"/></svg>';

String _stroke(String color, String body) =>
    '<svg viewBox="0 0 24 24" fill="none" stroke="$color" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round">$body</svg>';

final svgStatIn = _stroke('#527EB4', '<path d="M4 5h16v14H4zM4 12h5l1 3h4l1-3h5"/><path d="M12 3v6m-3-3 3 3 3-3"/>');
final svgStatReady = _stroke('#449879', '<path d="M5 4h14v16H5zM9 3h6v3H9zM8 13l3 3 5-6"/>');
final svgStatLate = _stroke('#C28642', '<circle cx="12" cy="12" r="8"/><path d="M12 7v5l3 2"/>');

const svgHelp =
    '<svg viewBox="0 0 48 48"><circle cx="24" cy="24" r="19" fill="#22b35e"/><path d="M14 25v-2a10 10 0 0 1 20 0v2" stroke="#fff" stroke-width="3" fill="none"/><rect x="11" y="23" width="6" height="9" rx="3" fill="#fff"/><rect x="31" y="23" width="6" height="9" rx="3" fill="#fff"/><path d="M34 32c0 3-3 5-7 5" stroke="#fff" stroke-width="2.2" fill="none" stroke-linecap="round"/><circle cx="25.5" cy="37" r="2" fill="#fff"/></svg>';

const _navBodies = [
  '<path d="M3 10.5 12 3l9 7.5"/><path d="M5 9.5V21h14V9.5"/><path d="M10 21v-6h4v6"/>',
  '<rect x="5" y="3" width="14" height="18" rx="2"/><path d="M9 8h6M9 12h6M9 16h4"/>',
  '<path d="M4 20h16M6 16v-5M12 16V7M18 16V3"/>',
  '<circle cx="12" cy="12" r="4"/><path d="M12 1.5v3M12 19.5v3M1.5 12h3M19.5 12h3M4.57 4.57l2.12 2.12m10.62 10.62 2.12 2.12M19.43 4.57l-2.12 2.12M6.69 17.31l-2.12 2.12"/>',
];

/// Bottom navigation icon. Active Beranda is a filled house with a white door (as in the CSS).
String navIcon(int i, bool active) {
  if (active && i == 0) {
    return '<svg viewBox="0 0 24 24" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">'
        '<path d="M3 10.5 12 3l9 7.5" fill="#E8493F" stroke="#E8493F"/><path d="M5 9.5V21h14V9.5" fill="#E8493F" stroke="#E8493F"/>'
        '<path d="M10 21v-6h4v6" fill="#fff" stroke="#fff"/></svg>';
  }
  final color = active ? '#E8493F' : '#9AA0AC';
  return '<svg viewBox="0 0 24 24" fill="none" stroke="$color" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">${_navBodies[i]}</svg>';
}
