// Service worker FlashPLAI v2 : l'app démarre sans réseau.
// - Coquille de l'app + bibliothèques (Supabase, KaTeX) préchargées dans CACHE.
// - Les données (Supabase) ne passent JAMAIS par ce cache : elles sont gardées dans IndexedDB par l'app (index.html).
// - Les images d'autres sites (ARASAAC...) sont gardées par l'app dans IMG (bouton « Préparer pour le hors ligne ») ;
//   ce worker les relit de IMG avant d'aller sur le réseau.
const CACHE='flashplai-shell-v3';
const IMG='flashplai-img-v1';
const FONTS=['AMS-Regular','Caligraphic-Bold','Caligraphic-Regular','Fraktur-Bold','Fraktur-Regular','Main-Bold','Main-BoldItalic','Main-Italic','Main-Regular','Math-BoldItalic','Math-Italic','SansSerif-Bold','SansSerif-Italic','SansSerif-Regular','Script-Regular','Size1-Regular','Size2-Regular','Size3-Regular','Size4-Regular','Typewriter-Regular'];
const SHELL=['/','/index.html','/config.js','/offline-core.js','/plai-logo.jpg','/icon-192.png','/icon-512.png','/manifest.webmanifest',
  '/vendor/supabase.js','/vendor/katex/katex.min.js','/vendor/katex/katex.min.css',
  ...FONTS.map(f=>'/vendor/katex/fonts/KaTeX_'+f+'.woff2')];
const TIMEOUT_MS=4000; // réseau lent : on sert la copie locale au bout de 4 s

self.addEventListener('install',e=>{e.waitUntil(caches.open(CACHE).then(c=>c.addAll(SHELL)).then(()=>self.skipWaiting()))});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==CACHE&&k!==IMG).map(k=>caches.delete(k)))).then(()=>self.clients.claim()))});

function networkFirst(req){
  return new Promise(resolve=>{
    let done=false;
    const fromCache=()=>caches.match(req,{ignoreSearch:true}).then(m=>m||(req.mode==='navigate'?caches.match('/index.html'):undefined));
    const timer=setTimeout(()=>{fromCache().then(m=>{if(m&&!done){done=true;resolve(m)}})},TIMEOUT_MS);
    fetch(req).then(r=>{
      clearTimeout(timer);
      if(r.ok){const cp=r.clone();caches.open(CACHE).then(c=>c.put(req,cp)).catch(()=>{})}
      if(!done){done=true;resolve(r)}
    }).catch(()=>{
      clearTimeout(timer);
      fromCache().then(m=>{if(!done){done=true;resolve(m||Response.error())}});
    });
  });
}

self.addEventListener('fetch',e=>{
  const req=e.request;
  if(req.method!=='GET')return;
  const u=new URL(req.url);
  if(u.origin===location.origin){e.respondWith(networkFirst(req));return}
  // Image d'un autre site : copie locale d'abord (préparée par l'app), sinon réseau
  if(req.destination==='image'){
    e.respondWith(caches.open(IMG).then(c=>c.match(req.url)).then(m=>m||fetch(req)));
  }
});
