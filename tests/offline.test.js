// Tests de la logique hors ligne de FlashPLAI. Lancer : node tests/offline.test.js
const assert=require('assert');
const F=require('../offline-core.js');
let n=0;
function t(name,fn){try{fn();n++;console.log('ok   '+name)}catch(e){console.error('ECHEC '+name+'\n  '+e.message);process.exitCode=1}}

t('clé élève : casse, espaces et code normalisés',()=>{
  assert.strictEqual(F.studentKey(' fwb-ab12 ','  Sophie   Dupont '),'FWB-AB12|sophie dupont');
  assert.strictEqual(F.studentKey('FWB-AB12','SOPHIE DUPONT'),F.studentKey('fwb-ab12','sophie dupont'));
});

t('clé de file : une entrée par carte et par élève',()=>{
  assert.notStrictEqual(F.outboxKey('FWB-AB12','Léa','c1'),F.outboxKey('FWB-AB12','Léa','c2'));
  assert.strictEqual(F.outboxKey('FWB-AB12','Léa','c1'),F.outboxKey('fwb-ab12','léa','c1'));
});

t('la réponse la plus récente gagne',()=>{
  const a={card_id:'c1',box:3,last_seen:'2026-11-24T10:00:00Z'};
  const b={card_id:'c1',box:1,last_seen:'2026-11-24T11:00:00Z'};
  assert.strictEqual(F.newest(a,b),b);assert.strictEqual(F.newest(b,a),b);
  assert.strictEqual(F.newest(null,a),a);
});

t('égalité d\'horodatage : la nouvelle réponse l\'emporte',()=>{
  const a={card_id:'c1',box:3,last_seen:'2026-11-24T10:00:00Z'};
  const b={card_id:'c1',box:2,last_seen:'2026-11-24T10:00:00Z'};
  assert.strictEqual(F.newest(a,b),b);
});

t('boîtes courantes : serveur + file en attente',()=>{
  const server=[{card_id:'c1',box:2,last_seen:'2026-11-24T10:00:00Z'},{card_id:'c2',box:3,last_seen:'2026-11-24T10:00:00Z'}];
  const pending=[{card_id:'c1',box:3,last_seen:'2026-11-24T12:00:00Z'},{card_id:'c3',box:1,last_seen:'2026-11-24T12:00:00Z'},
                 {card_id:'c2',box:1,last_seen:'2026-11-24T09:00:00Z'}];
  const r=F.currentBoxes(server,pending);
  assert.strictEqual(r.c1.box,3);          // l'attente est plus récente
  assert.strictEqual(r.c2.box,3);          // l'attente est plus ancienne : le serveur reste
  assert.strictEqual(r.c3.box,1);          // carte connue seulement de l'appareil
});

t('boîtes courantes : entrées vides',()=>{
  assert.deepStrictEqual(F.currentBoxes(undefined,undefined),{});
  assert.deepStrictEqual(F.currentBoxes([],[]),{});
});

t('adopter le serveur seulement s\'il est plus récent',()=>{
  const cards=[{id:'c1',box:1,lastSeen:'2026-11-24T10:00:00Z'},{id:'c2',box:2,lastSeen:null},{id:'c3',box:3,lastSeen:'2026-11-24T10:00:00Z'}];
  const server=[{card_id:'c1',box:3,last_seen:'2026-11-24T11:00:00Z'},   // plus récent
                {card_id:'c2',box:1,last_seen:'2026-11-23T11:00:00Z'},   // appareil sans date : le serveur sert
                {card_id:'c3',box:1,last_seen:'2026-11-24T09:00:00Z'},   // plus ancien : on garde l'appareil
                {card_id:'zz',box:1,last_seen:'2026-11-24T09:00:00Z'}];  // carte supprimée : ignorée
  const r=F.serverNewer(cards,server);
  assert.deepStrictEqual(r.map(x=>x.id).sort(),['c1','c2']);
  assert.strictEqual(r.find(x=>x.id==='c1').box,3);
});

t('découpage en lots',()=>{
  assert.deepStrictEqual(F.chunk([1,2,3,4,5],2),[[1,2],[3,4],[5]]);
  assert.deepStrictEqual(F.chunk([],200),[]);
});

t('erreur réseau reconnue, refus du serveur non',()=>{
  assert.ok(F.isNetworkError(new TypeError('Failed to fetch')));
  assert.ok(F.isNetworkError({message:'NetworkError when attempting to fetch resource.'}));
  assert.ok(F.isNetworkError({message:'Délai dépassé (30s)'}));
  assert.ok(!F.isNetworkError({message:'permission denied for function flash_student_sync',code:'42501'}));
  assert.ok(!F.isNetworkError(null));
});

t('adresses d\'images : http(s) seulement, sans doublon',()=>{
  const cards=[{qImgUrl:'https://static.arasaac.org/a.png',aImgUrl:'data:image/png;base64,AAA'},
               {q_img:'https://static.arasaac.org/a.png',a_img:'http://x/b.jpg'},{q_img:null}];
  assert.deepStrictEqual(F.imageUrlsOf(cards).sort(),['http://x/b.jpg','https://static.arasaac.org/a.png']);
});

t('taille lisible',()=>{
  assert.strictEqual(F.fmtSize(512),'512 o');
  assert.strictEqual(F.fmtSize(2048),'2 Ko');
  assert.strictEqual(F.fmtSize(2.5*1048576),'2,5 Mo');
});

t('formules détectées, prix en euros non',()=>{
  assert.ok(F.hasFormula([{question:'Aire',answer:'$c^2$'}]));
  assert.ok(!F.hasFormula([{question:'Prix',answer:'5 € et 6 €'}]));
  assert.ok(!F.hasFormula([{question:'a',answer:'b'}]));
});

t('bandeau : quatre états',()=>{
  assert.strictEqual(F.badgeText({online:false,pending:0}),'Hors ligne · rien à envoyer');
  assert.strictEqual(F.badgeText({online:false,pending:12}),'Hors ligne · 12 réponses à envoyer');
  assert.strictEqual(F.badgeText({online:true,pending:1}),'1 réponse à envoyer');
  assert.ok(/^Synchronisé à \d\d h \d\d$/.test(F.badgeText({online:true,pending:0,syncedAt:Date.now()})));
  assert.ok(/non valide/.test(F.badgeText({online:true,pending:3,problem:'expired'})));
});

console.log('\n'+n+' tests passés'+(process.exitCode?' — AVEC ÉCHECS':''));
