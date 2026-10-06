/* Approved brand-only header changes; Flutter renders the word as Text. */
(function(){
 'use strict';
 function boot(){
 var style=document.createElement('style');
 style.textContent='.gy155-logo:not(#a#b#c#d#e#f#g#h#i#j#k#l#m#n#o#p){background:transparent!important;box-shadow:none!important;border:0!important}.gy155-logo img{display:block;width:34px;height:34px;object-fit:contain}.gy155-brand strong:not(#a#b#c#d#e#f#g#h#i#j#k#l#m#n#o#p){font-size:31px!important;font-weight:500!important;letter-spacing:.2px!important;line-height:34px!important}';
 document.head.appendChild(style);
 document.querySelectorAll('.gy155-logo').forEach(function(e){e.innerHTML='<img src="branding/mark.png" alt="">'});
 document.querySelectorAll('.gy155-brand strong').forEach(function(e){e.textContent='Goyana'});
 var splash=document.getElementById('boot180');if(splash){var old=splash.querySelector('svg');if(old)old.outerHTML='<img src="branding/mark.png" alt="" width="70" height="70">';var word=splash.querySelector('strong');if(word)word.textContent='Goyana';splash.style.background='#ff493c';splash.style.color='white'}
 var login=document.getElementById('lg167-logo');if(login)login.innerHTML='<img src="branding/mark.png" alt="Goyana" style="width:100%;height:100%;object-fit:contain">';
 }
 if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot);else boot();
})();
