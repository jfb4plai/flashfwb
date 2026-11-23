// Service worker FlashPLAI : met en cache uniquement la coquille de l'app.
// Les données (Supabase) ne passent jamais par ce cache : sans réseau, les paquets ne se chargent pas.
const CACHE='flashplai-shell-v1';
const SHELL=['/','/index.html','/config.js','/plai-logo.jpg','/icon-192.png','/manifest.webmanifest'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(CACHE).then(c=>c.addAll(SHELL)).then(()=>self.skipWaiting()))});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()))});
self.addEventListener('fetch',e=>{
  const u=new URL(e.request.url);
  if(e.request.method!=='GET'||u.origin!==location.origin)return;
  // réseau d'abord (version à jour), cache en secours hors-ligne
  e.respondWith(fetch(e.request).then(r=>{const cp=r.clone();caches.open(CACHE).then(c=>c.put(e.request,cp));return r}).catch(()=>caches.match(e.request).then(m=>m||caches.match('/index.html'))));
});
