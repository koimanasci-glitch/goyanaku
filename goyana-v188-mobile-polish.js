/* Compact handover controls, accessible receipt dismissal and blue brand symbol. */
(()=>{'use strict';
if(window.GY188)return;window.GY188=1;
function compact(){document.querySelectorAll('#orders .oa91 button,#orders .oa91 .chip91,#od91-next').forEach(el=>{const walker=document.createTreeWalker(el,NodeFilter.SHOW_TEXT);let n;while((n=walker.nextNode())){const text=n.textContent.replace(/Antar ke Pelanggan/gi,'Antar').replace(/Sudah Dijemput/gi,'Jemput').replace(/Jemput ke Pelanggan|Jemput Pelanggan|Penjemputan/gi,'Jemput');if(text!==n.textContent)n.textContent=text}})}
function boot(){
const css=document.createElement('style');css.textContent=`
#orders .g62-ordercard .oa91:not(#x1#x2#x3#x4#x5#x6#x7#x8#x9#x10#x11#x12#x13){flex-wrap:wrap!important;gap:6px!important;box-sizing:border-box!important}
#orders .oa91>*,#orders .oa91 button{min-width:0!important;max-width:100%!important;box-sizing:border-box!important}
#orders .oa91 .next91:not(#x1#x2#x3#x4#x5#x6#x7#x8#x9#x10#x11#x12#x13){flex-shrink:0!important;padding:0 12px!important;white-space:nowrap!important}
#wa131 .wa188-header{position:sticky;top:-1px;z-index:2;display:flex;align-items:center;justify-content:space-between;gap:10px;background:#fff;padding:12px 0;border-bottom:1px solid #edf0f3}
#wa131 .wa188-header h3{margin:0!important}#wa131 .wa188-back,#wa131 .wa188-bottom{border:1px solid #e1e5eb;background:#fff;color:#303945;border-radius:10px;padding:10px 14px;font:inherit;font-size:13px;cursor:pointer}
#wa131 .wa188-bottom{width:100%;margin-top:12px;margin-bottom:env(safe-area-inset-bottom,0px)}
body .gy155-brand .gy155-logo:not(#x1#x2#x3#x4#x5#x6#x7#x8#x9#x10#x11#x12#x13),body #lg167-logo{width:34px!important;height:34px!important;flex:0 0 34px!important;border-radius:10px!important;background:#fff!important;display:grid!important;place-items:center!important}
body .gy155-brand .gy155-logo svg,body #lg167-logo svg{width:24px!important;height:24px!important;display:block!important}
body .gy155-brand strong:not(#x1#x2#x3#x4#x5#x6#x7#x8#x9#x10#x11#x12#x13){font-size:31px!important;line-height:34px!important;font-weight:500!important;letter-spacing:.2px!important;margin:0!important;color:#fff!important}
@media(max-width:340px){body .gy155-brand strong:not(#x1#x2#x3#x4#x5#x6#x7#x8#x9#x10#x11#x12#x13){font-size:28px!important}}
`;document.head.appendChild(css);
const box=document.querySelector('#wa131 .wa131-box'),title=box?.querySelector('h3');if(title){const header=document.createElement('div');header.className='wa188-header';const back=document.createElement('button');back.type='button';back.className='wa188-back';back.textContent='‹ Kembali';back.onclick=()=>closeSheet91('wa131');title.before(header);header.append(title,back);const bottom=back.cloneNode(true);bottom.className='wa188-bottom';bottom.textContent='Kembali';bottom.onclick=back.onclick;box.appendChild(bottom);box.addEventListener('keydown',e=>{if(e.key==='Escape'){closeSheet91('wa131');e.stopPropagation()}})}
// Vector artwork keeps the supplied blue ribbon symbol crisp at phone resolutions.
const symbol='<svg viewBox="0 0 64 64" role="img" aria-label="Logo Goyana"><path fill="#37afea" d="M8 16 16 8 32 24 48 8 56 16 40 32 56 48 48 56 32 40 16 56 8 48 24 32Z"/><path fill="#168fda" d="m16 24 8-8 32 32-8 8Z"/><path fill="#63cef0" d="m8 40 8-8 24 24-8 8Z" transform="translate(0 -8)"/></svg>';
document.querySelectorAll('.gy155-logo,#lg167-logo').forEach(el=>el.innerHTML=symbol);
compact();let queued=false;const schedule=()=>{if(queued)return;queued=true;requestAnimationFrame(()=>{queued=false;compact()})};new MutationObserver(schedule).observe(document.getElementById('orders'),{subtree:true,childList:true,characterData:true});new MutationObserver(schedule).observe(document.getElementById('g62-order-detail'),{subtree:true,childList:true,characterData:true});window.compactHandover188=compact;
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot);else boot();
})();
