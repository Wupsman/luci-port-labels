'use strict';
'require baseclass';

return baseclass.extend({
  title: '',
  load: function() {
    return fetch('/cgi-bin/port-labels.sh').then(function(r){return r.json();}).catch(function(){return {labels:{}};});
  },
  render: function(data) {
    window._plLabels = data.labels || {};
    var debounce = null;
    var saving = false;
    new MutationObserver(function(){
      if(saving) return;
      clearTimeout(debounce);
      debounce = setTimeout(function(){
        document.querySelectorAll('.ifacebox').forEach(function(el){
          var h=el.querySelector('.ifacebox-head');
          if(!h) return;
          var p=h.textContent.trim();
          if(!p.match(/^lan\d+$/)) return;
          var existing=el.querySelector('.pl-wrap');
          if(existing){
            existing.querySelector('span').textContent=window._plLabels[p]||'Label...';
            return;
          }
          var b=document.createElement('div');
          b.className='pl-wrap';
          b.style='text-align:center;margin-top:3px';
          var s=document.createElement('span');
          s.style='font-size:10px;background:#1a3a6a;color:#8abcff;padding:1px 5px;border-radius:3px;cursor:pointer;display:inline-block';
          s.textContent=window._plLabels[p]||'Label...';
          s.onclick=function(){
            var t=prompt('Label for '+p+':',window._plLabels[p]||'');
            if(t!=null){
              saving=true;
              window._plLabels[p]=t;
              s.textContent=t||'Label...';
              fetch('/cgi-bin/port-labels.sh',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({port:p,text:t})})
              .then(function(){ setTimeout(function(){ saving=false; }, 2000); });
            }
          };
          b.appendChild(s);
          el.appendChild(b);
        });
      }, 800);
    }).observe(document.body,{childList:true,subtree:true});
    return E([]);
  }
});
