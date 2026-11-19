// Genera dati/comuni-extra.js: aggiunge a MAP.ap i comuni di COMUNI con i confini openpolis,
// proiettati come i comuni già presenti in dati/mappa.js. Uso: node strumenti/aggiungi-comuni.mjs
import fs from 'node:fs';

const COMUNI=[
  ['Fermo','FM'],['Pedaso','FM'],['Porto San Giorgio','FM'],['Monte San Pietrangeli','FM'],['Magliano di Tenna','FM'],
  ['Montegranaro','FM'],['Montegiorgio','FM'],["Sant'Elpidio a Mare",'FM'],['Amandola','FM'],['Montelparo','FM'],
  ['Santa Vittoria in Matenano','FM'],['Smerillo','FM'],['Montefalcone Appennino','FM'],['Montefortino','FM'],
];
const PROV={AP:'044',FM:'109',TE:'067'};
const SRC=p=>`https://raw.githubusercontent.com/openpolis/geojson-italy/master/geojson/limits_P_${+p}_municipalities.geojson`;
const MAPPA=new URL('../dati/mappa.js',import.meta.url), OUT=new URL('../dati/comuni-extra.js',import.meta.url);
const MAXRES=1;

const MAP=JSON.parse(fs.readFileSync(MAPPA,'utf8').trim().replace(/^const MAP=/,'').replace(/;$/,''));
const norm=s=>s.normalize('NFC').replace(/[’`´]/g,"'").replace(/\s+/g,' ').trim().toLowerCase();

const feats={};
for(const p of new Set([...MAP.ap.map(c=>c.id.slice(0,3)),...COMUNI.map(([,s])=>PROV[s])])){
  const r=await fetch(SRC(p)); if(!r.ok) throw new Error(`${SRC(p)}: HTTP ${r.status}`);
  for(const f of (await r.json()).features) feats[f.properties.com_istat_code]=f;
}
const rings=g=>g.type==='Polygon'?g.coordinates:g.type==='MultiPolygon'?g.coordinates.flat():null;

// UTM 33N (WGS84), serie di Krüger. Il prototipo usa questa proiezione con sola scala e traslazione.
const utm=(()=>{ const a=6378137,f=1/298.257223563,n=f/(2-f),A=a/(1+n)*(1+n*n/4+n**4/64),e=Math.sqrt(f*(2-f)),r=Math.PI/180;
  const al=[n/2-2*n*n/3+5*n**3/16,13*n*n/48-3*n**3/5,61*n**3/240];
  return ([lon,lat])=>{ const p=lat*r,l=(lon-15)*r,t=Math.sinh(Math.atanh(Math.sin(p))-e*Math.atanh(e*Math.sin(p)));
    const xi=Math.atan2(t,Math.cos(l)),eta=Math.atanh(Math.sin(l)/Math.sqrt(1+t*t)); let E=eta,N=xi;
    al.forEach((c,j)=>{ E+=c*Math.cos(2*(j+1)*xi)*Math.sinh(2*(j+1)*eta); N+=c*Math.sin(2*(j+1)*xi)*Math.cosh(2*(j+1)*eta); });
    return [0.9996*A*E,0.9996*A*N]; }; })();
const fit=(u,v)=>{ const n=u.length,su=u.reduce((a,b)=>a+b),sv=v.reduce((a,b)=>a+b); let suu=0,suv=0;
  for(let i=0;i<n;i++){ suu+=u[i]*u[i]; suv+=u[i]*v[i]; } const k=(n*suv-su*sv)/(n*suu-su*su); return [k,(sv-k*su)/n]; };
const ptsOf=d=>[...d.matchAll(/(-?[\d.]+),(-?[\d.]+)/g)].map(m=>[+m[1],+m[2]]);

// I path del prototipo sono semplificati: ogni vertice è un vertice openpolis. Primo passo dai bb,
// poi minimi quadrati sulle coppie vertice SVG / vertice openpolis più vicino.
const ref=MAP.ap.map(c=>{ const f=feats[c.id]; if(!f) throw new Error(`${c.id} ${c.nome}: assente in openpolis`);
  return {c,src:rings(f.geometry).flat().map(utm),pts:ptsOf(c.d)}; });
let T;
{ const E=[],X=[],N=[],Y=[];
  for(const {c,src} of ref){ const es=src.map(p=>p[0]),ns=src.map(p=>p[1]);
    E.push(Math.min(...es),Math.max(...es)); X.push(c.bb[0],c.bb[2]); N.push(Math.max(...ns),Math.min(...ns)); Y.push(c.bb[1],c.bb[3]); }
  T=[fit(E,X),fit(N,Y)]; }
const proj=p=>{ const [E,N]=utm(p); return [T[0][0]*E+T[0][1],T[1][0]*N+T[1][1]]; };
let res=[];
for(let it=0;it<6;it++){
  const E=[],X=[],N=[],Y=[]; res=[];
  for(const {src,pts} of ref){ const q=src.map(([e,n])=>[T[0][0]*e+T[0][1],T[1][0]*n+T[1][1]]);
    for(const p of pts){ let bi=0,bd=Infinity; q.forEach((s,i)=>{ const d=Math.hypot(s[0]-p[0],s[1]-p[1]); if(d<bd){ bd=d; bi=i; } });
      res.push(bd); E.push(src[bi][0]); X.push(p[0]); N.push(src[bi][1]); Y.push(p[1]); } }
  T=[fit(E,X),fit(N,Y)];
}
res.sort((a,b)=>a-b);
console.log(`trasformazione: x=${T[0][0]}·E+${T[0][1]}, y=${T[1][0]}·N+${T[1][1]} (UTM 33N)`);
console.log(`residuo su ${res.length} vertici di ${ref.length} comuni: max ${res.at(-1).toFixed(3)}, mediana ${res[res.length>>1].toFixed(3)}`);
if(res.at(-1)>MAXRES) throw new Error(`residuo massimo ${res.at(-1).toFixed(3)} > ${MAXRES}: la proiezione non corrisponde`);

const r1=v=>Math.round(v*10)/10;
const inside=(p,R)=>{ let c=false; for(const r of R) for(let i=0,j=r.length-1;i<r.length;j=i++){ const [xi,yi]=r[i],[xj,yj]=r[j];
  if((yi>p[1])!==(yj>p[1])&&p[0]<(xj-xi)*(p[1]-yi)/(yj-yi)+xi) c=!c; } return c; };
const segd=(p,a,b)=>{ const dx=b[0]-a[0],dy=b[1]-a[1],t=Math.max(0,Math.min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/(dx*dx+dy*dy||1)));
  return Math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dy); };
const depth=(p,R)=>{ let m=Infinity; for(const r of R) for(let i=1;i<r.length;i++) m=Math.min(m,segd(p,r[i-1],r[i])); return inside(p,R)?m:-m; };
// Come nel prototipo: baricentro, oppure il punto più vicino al baricentro con distanza dal bordo
// almeno il 90% di quella del punto più interno.
function pinOf(R,bb){
  let a=0,x=0,y=0;
  for(const r of R) for(let i=1;i<r.length;i++){ const [x0,y0]=r[i-1],[x1,y1]=r[i],k=x0*y1-x1*y0; a+=k; x+=(x0+x1)*k; y+=(y0+y1)*k; }
  const c=[x/(3*a),y/(3*a)],s=.5,nx=Math.floor((bb[2]-bb[0])/s)+1,ny=Math.floor((bb[3]-bb[1])/s)+1,D=[];
  for(let i=0;i<nx;i++) for(let j=0;j<ny;j++) D.push(depth([bb[0]+i*s,bb[1]+j*s],R));
  const min=.9*D.reduce((m,v)=>Math.max(m,v),-Infinity);
  if(depth(c,R)>=min) return c.map(r1);
  // La distanza dal bordo varia al più quanto lo spostamento: scarta i punti fini vicini a un nodo grosso troppo esterno.
  const fine=[];
  for(let i=0;i<=nx*5;i++) for(let j=0;j<=ny*5;j++){ const p=[r1(bb[0]+i/10),r1(bb[1]+j/10)];
    if(p[0]<=bb[2]&&p[1]<=bb[3]&&D[Math.min(nx-1,Math.round(i/5))*ny+Math.min(ny-1,Math.round(j/5))]+s>=min) fine.push([Math.hypot(p[0]-c[0],p[1]-c[1]),p]); }
  return fine.sort((p,q)=>p[0]-q[0]).map(p=>p[1]).find(p=>depth(p,R)>=min);
}

const ids=new Set(MAP.ap.map(c=>c.id)),add=[];
for(const [nome,sig] of COMUNI){
  const f=Object.values(feats).find(f=>f.properties.prov_istat_code===PROV[sig]&&norm(f.properties.name)===norm(nome));
  if(!f) throw new Error(`${nome} (${sig}): comune non trovato in openpolis`);
  const id=f.properties.com_istat_code;
  if(ids.has(id)) throw new Error(`${nome} (${sig}): id ${id} già presente`); ids.add(id);
  const R=rings(f.geometry).map(r=>r.map(p=>proj(p).map(r1)).filter((p,i,a)=>!i||p[0]!==a[i-1][0]||p[1]!==a[i-1][1]));
  const all=R.flat(),xs=all.map(p=>p[0]),ys=all.map(p=>p[1]);
  const bb=[Math.min(...xs),Math.min(...ys),Math.max(...xs),Math.max(...ys)];
  if(bb[0]<0||bb[1]<0||bb[2]>MAP.W||bb[3]>MAP.H) throw new Error(`${nome}: fuori dalla mappa ${bb}`);
  const pin=pinOf(R,bb);
  if(!pin||!inside(pin,R)) throw new Error(`${nome}: pin fuori dal poligono`);
  add.push({id,nome:f.properties.name,d:R.map(r=>'M'+r.map(p=>p.join(',')).join('L')+'Z').join(''),bb,pin});
  console.log(`${id} ${f.properties.name}: ${all.length} vertici, ${R.length} anelli`);
}
const apbb=[...MAP.ap,...add].reduce((u,{bb})=>[Math.min(u[0],bb[0]),Math.min(u[1],bb[1]),Math.max(u[2],bb[2]),Math.max(u[3],bb[3])],[Infinity,Infinity,-Infinity,-Infinity]);
const out=`// Generato da strumenti/aggiungi-comuni.mjs. Non modificare a mano.\nMAP.ap.push(${add.map(c=>JSON.stringify(c)).join(',\n')});\nMAP.apbb=${JSON.stringify(apbb)};\n`;
fs.writeFileSync(OUT,out);
console.log(`${add.length} comuni, apbb ${JSON.stringify(apbb)}, ${out.length} byte → dati/comuni-extra.js`);
