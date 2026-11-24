// FlashPLAI — logique pure du mode hors ligne (sans accès réseau ni navigateur).
// Chargée par index.html (variable globale FlashOffline) et testée par tests/offline.test.js (Node).
(function(root,factory){
  if(typeof module==='object'&&module.exports)module.exports=factory();
  else root.FlashOffline=factory();
})(typeof self!=='undefined'?self:this,function(){

  // Identifiant d'un élève sur un appareil : code de classe + prénom, casse ignorée (comme le serveur).
  function studentKey(code,name){
    return String(code||'').trim().toUpperCase()+'|'+String(name||'').trim().replace(/\s+/g,' ').toLowerCase();
  }
  function outboxKey(code,name,cardId){return studentKey(code,name)+'|'+cardId}

  function ts(v){const t=Date.parse(v);return Number.isFinite(t)?t:0}

  // Entre deux réponses sur la même carte, la plus récente gagne (égalité : la nouvelle).
  function newest(a,b){
    if(!a)return b;if(!b)return a;
    return ts(b.last_seen)>=ts(a.last_seen)?b:a;
  }

  // Progression du serveur + réponses en attente d'envoi => boîte courante de chaque carte.
  // serverProgress : [{card_id,box,last_seen}] ; pending : [{card_id,box,last_seen}]
  function currentBoxes(serverProgress,pending){
    const m={};
    for(const p of serverProgress||[])m[p.card_id]=newest(m[p.card_id],p);
    for(const p of pending||[])m[p.card_id]=newest(m[p.card_id],p);
    const out={};
    for(const id in m)out[id]={box:m[id].box,lastSeen:m[id].last_seen};
    return out;
  }

  // Cartes de l'appareil dont le serveur a une réponse plus récente (autre appareil, par exemple).
  // cards : [{id,box,lastSeen}] ; renvoie [{id,box,lastSeen}] à adopter.
  function serverNewer(cards,serverProgress){
    const byId={};for(const c of cards||[])byId[c.id]=c;
    const res=[];
    for(const p of serverProgress||[]){
      const c=byId[p.card_id];if(!c)continue;
      if(ts(p.last_seen)>ts(c.lastSeen))res.push({id:p.card_id,box:p.box,lastSeen:p.last_seen});
    }
    return res;
  }

  function chunk(list,n){const o=[];for(let i=0;i<list.length;i+=n)o.push(list.slice(i,i+n));return o}

  // Vrai si l'erreur vient d'un réseau absent ou instable (et non d'un refus du serveur).
  function isNetworkError(err){
    if(!err)return false;
    if(typeof navigator!=='undefined'&&navigator.onLine===false)return true;
    const msg=String(err.message||err);
    return err instanceof TypeError||/failed to fetch|networkerror|load failed|network request failed|fetch failed|timeout|délai/i.test(msg);
  }

  // Adresses d'images à télécharger pour le hors ligne (les images intégrées « data: » sont déjà dans la carte).
  function imageUrlsOf(cards){
    const set=new Set();
    for(const c of cards||[])for(const u of [c.q_img,c.a_img,c.qImgUrl,c.aImgUrl]){
      if(u&&/^https?:\/\//i.test(u))set.add(u);
    }
    return [...set];
  }

  function fmtSize(bytes){
    if(bytes<1024)return bytes+' o';
    if(bytes<1048576)return Math.round(bytes/1024)+' Ko';
    return (bytes/1048576).toFixed(1).replace('.',',')+' Mo';
  }

  // Une carte contient-elle une formule ($...$) : alors KaTeX doit être disponible hors ligne.
  function hasFormula(cards){
    return (cards||[]).some(c=>/\$\S(?:[^$\n]*?\S)?\$/.test((c.question||'')+' '+(c.answer||'')));
  }

  // Texte du bandeau d'état de la synchronisation (aucune phrase de comportement hors de ces cas).
  // s : {online, pending, syncedAt (ms|null), problem ('expired'|'invalid'|null)}
  function badgeText(s){
    const n=s.pending||0;
    const plur=n+' réponse'+(n>1?'s':'');
    if(s.problem==='expired'||s.problem==='invalid')
      return 'Code de classe non valide : '+plur+' non envoyée'+(n>1?'s':'')+'. Prévenir l\'enseignant.';
    if(!s.online)return 'Hors ligne'+(n?' · '+plur+' à envoyer':' · rien à envoyer');
    if(n)return plur+' à envoyer';
    if(s.syncedAt){
      const d=new Date(s.syncedAt);
      return 'Synchronisé à '+String(d.getHours()).padStart(2,'0')+' h '+String(d.getMinutes()).padStart(2,'0');
    }
    return 'En ligne';
  }

  // Comparaison d'une carte avant/après modification, pour PRÉ-COCHER la remise à zéro (l'enseignant décide).
  // Renvoie 'same' (rien de visible : casse, espaces, ponctuation finale), 'fix' (correction probable)
  // ou 'meaning' (sens probablement changé : chiffre différent, mot remplacé, texte très différent).
  function normText(s){return String(s||'').trim().replace(/\s+/g,' ').replace(/[\s.!?…:;,]+$/,'').toLowerCase()}
  function lev(a,b){
    if(a===b)return 0;if(!a.length)return b.length;if(!b.length)return a.length;
    let prev=[];for(let j=0;j<=b.length;j++)prev[j]=j;
    for(let i=1;i<=a.length;i++){
      const cur=[i];
      for(let j=1;j<=b.length;j++)cur[j]=Math.min(prev[j]+1,cur[j-1]+1,prev[j-1]+(a[i-1]===b[j-1]?0:1));
      prev=cur;
    }
    return prev[b.length];
  }
  function digitsOf(s){return (String(s||'').match(/\d+/g)||[]).join(',')}
  function fieldChange(a,b){
    const x=normText(a),y=normText(b);
    if(x===y)return 'same';
    if(digitsOf(a)!==digitsOf(b))return 'meaning';
    const d=lev(x,y),r=d/Math.max(x.length,y.length,1);
    if(d<=2)return 'fix';
    return r>=0.2?'meaning':'fix';
  }
  function changeKind(oldQ,oldA,newQ,newA){
    const q=fieldChange(oldQ,newQ),a=fieldChange(oldA,newA);
    if(q==='same'&&a==='same')return 'same';
    return (q==='meaning'||a==='meaning')?'meaning':'fix';
  }

  return{studentKey,outboxKey,newest,currentBoxes,serverNewer,chunk,isNetworkError,imageUrlsOf,fmtSize,hasFormula,badgeText,changeKind};
});
