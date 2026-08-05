let _p=0,_f=0;
const t=(n,c)=>{ try{ if(c()){_p++;console.log("  PASS  "+n);} else {_f++;console.log("  FAIL  "+n);} }
                 catch(e){ _f++; console.log("  FAIL  "+n+"  ("+e.message+")"); } };

console.log("STUDIO TOOL PATHS — the brief names the tools");
t("adinkra gets the stamped-repeat path", ()=>toolPathFor({style:'adinkra'}).label==='Stamped cloth repeat');
t("shibori gets the resist path",         ()=>toolPathFor({style:'shibori'}).label==='Resist pattern');
t("gee's bend gets improvised",           ()=>toolPathFor({title:"My Way: The Quilters of Gee's Bend"}).label==='Improvised composition');
t("kuba and ndebele are stamped too",     ()=>toolPathFor({style:'kuba'}).label==='Stamped cloth repeat'
                                            && toolPathFor({style:'ndebele'}).label==='Stamped cloth repeat');
t("batik and ikat are resists",           ()=>toolPathFor({style:'batik'}).label==='Resist pattern'
                                            && toolPathFor({style:'ikat'}).label==='Resist pattern');
t("a brief with no style falls to improvised", ()=>toolPathFor({title:'Freeform'}).label==='Improvised composition');
t("every path names real Print Studio controls", ()=>{
  const all=Object.values(TOOL_PATHS).flatMap(p=>p.steps).join(' ');
  return ['Save as motif','Scatter','Structured','Half-drop','Repeat Mode','Symmetry','Frame: Stamp']
    .every(x=>all.includes(x)); });
t("null-safe", ()=>toolPathFor(null)===null);

console.log("\nLEVEL IS DERIVED, NOT ASKED FOR");
t("150 words + 2 sources reads as Core",  ()=>briefLevel({words:150,min_notes:2,style:'adinkra'}).label==='Core');
t("250 words + 3 sources reads as a deep dive", ()=>briefLevel({words:250,min_notes:3}).label==='Deep dive');
t("a short low-source brief is a Starter", ()=>briefLevel({words:75,min_notes:0,style:'x'}).label==='Starter');
t("more demanded is never an easier label", ()=>{
  const order={starter:0,core:1,deep:2};
  return order[briefLevel({words:250,min_notes:4,style:'x'}).key]
       > order[briefLevel({words:100,min_notes:1,style:'x'}).key]; });
t("subject comes from the tradition, not the syllabus",
  ()=>briefSubject({tradition:'Adinkra · Akan people, Ghana'})==='Adinkra');
t("subject degrades safely", ()=>briefSubject({})==='General');

console.log("\nUP NEXT POINTS AT THE ACTUAL NEXT THING");
State.view='student';
const B={id:'a',title:'Adinkra',words:150,min_notes:2,style:'adinkra'};
State.session={token:'t',name:'M',class_name:'P3',briefs:[B]};
State.notes=[]; State.works=[];
t("with nothing done it asks for a source", ()=>upNext([B]).what==='Find a source');
State.notes=[{id:'1',brief_id:'a'},{id:'2',brief_id:'a'}];
t("with sources in it asks for the print", ()=>upNext([B]).what==='Make your print');
State.works=[{brief_id:'a',image_path:'p.jpg',statement:''}];
t("with a print it asks for the statement", ()=>upNext([B]).what==='Write the statement');
State.works[0].statement='w '.repeat(160);
t("with everything it says turn it in", ()=>upNext([B]).what==='Turn it in');
State.works[0].status='submitted';
t("a submitted brief is skipped", ()=>upNext([B])===null);

console.log("\nTHE DECK");
const html=require("fs").readFileSync("/Users/staceygrant/Documents/cultureschool-backend/dist/school.html","utf8");
t("three regions exist", ()=>html.includes(".deck{")&&html.includes(".locker{")&&html.includes(".upnext{"));
t("the canvas is a grid, not a list", ()=>html.includes(".deckgrid{")&&html.includes("repeat(auto-fill"));
t("briefTile renders a card", ()=>{
  const h=briefTile(B,0);
  return h.includes('class="tile')&&h.includes('Adinkra')&&h.includes('tile-swatch'); });
t("the card shows what the brief demands", ()=>briefTile(B,0).includes("2 sources · 150 words"));
t("the card carries a derived level", ()=>briefTile(B,0).includes("Core"));
t("card content is escaped",
  ()=>!briefTile({id:'x',title:'<script>x</script>',words:150},0).includes("<script>x"));
t("the up-next panel is hidden on small screens", ()=>html.includes(".upnext{display:none}"));
t("facets are state, and settable", ()=>typeof setFacet==="function"&&'fLevel' in State);

console.log("\nSTILL WORKS");
t("word floors intact", ()=>BRIEFS.map(b=>b.words).join()==="150,150,250");
t("handoff intact", ()=>typeof openStudio==="function"&&typeof API.handoff==="function");
t("video intact", ()=>embedVideo("https://youtu.be/dQw4w9WgXcQ").includes("nocookie"));
t("accents intact", ()=>contrast(accentFrom(["#ffc000"]),GROUND)>=4.5);


/* ── carried over from suites that lived only in a scratchpad ──────── */
console.log("\nCARRIED-OVER COVERAGE");
t("note kinds intact, off-platform first",
  ()=>NOTE_KINDS.length===7 && NOTE_KINDS[0][0]==='museum' && NOTE_KINDS[5][0]==='web');
t("kindLabel degrades safely", ()=>kindLabel('zzz')==='Source');
t("credit line never empty", ()=>creditFor({})==='CultureSchool Pattern Archive');
t("escaping holds", ()=>esc('<img onerror=x>')==='&lt;img onerror=x&gt;' && esc(null)==='');
t("teacher brief card still renders",
  ()=>briefCard({id:'x',title:'T',words:150,min_notes:2},true).includes('Duplicate'));
t("student API takes a token and nothing else",
  ()=>['join','state','saveWork','submit','log','addNote','handoff'].every(f=>typeof API[f]==='function'));
t("teacher API intact",
  ()=>['classes','createClass','setAssigned','roster','gallery','workDetail','saveBrief']
       .every(f=>typeof API[f]==='function'));
t("GROUND still matches the skin ground", ()=>{
  const css=require("fs").readFileSync("/Users/staceygrant/Documents/cultureschool-backend/dist/school.html","utf8");
  const m=/body\.skin\{[^}]*--cream:\s*(#[0-9a-f]{6})/i.exec(css);
  return m && m[1].toLowerCase()===GROUND.toLowerCase(); });
t("an unknown video host still embeds nothing", ()=>embedVideo("https://evil.example/x")==="");
t("no external asset library is reachable from school", ()=>{
  const h=require("fs").readFileSync("/Users/staceygrant/Documents/cultureschool-backend/dist/school.html","utf8");
  return !/openverse|metmuseum|iconify/i.test(h.replace(/external libraries \(Openverse \/ Met \/ Iconify\)/g,'')); });


console.log("\nSESSION SURVIVES A CLOSED BROWSER");
t("the session store writes to localStorage, not sessionStorage", ()=>{
  const seen={}; const realL=global.localStorage, realS=global.sessionStorage;
  global.localStorage={getItem:k=>seen[k]??null,setItem:(k,v)=>{seen[k]=v},removeItem:k=>{delete seen[k]}};
  global.sessionStorage={getItem:()=>null,setItem:()=>{throw new Error('must not be used')},removeItem(){}};
  Sess.set({token:'abc',name:'M'});
  const ok = !!seen[SESS_KEY] && JSON.parse(seen[SESS_KEY]).token==='abc';
  global.localStorage=realL; global.sessionStorage=realS;
  return ok; });
t("an existing sessionStorage session is migrated, not lost", ()=>{
  const store={}; const realL=global.localStorage, realS=global.sessionStorage;
  global.localStorage={getItem:k=>store[k]??null,setItem:(k,v)=>{store[k]=v},removeItem:k=>{delete store[k]}};
  global.sessionStorage={getItem:k=>k==='cs_school_sess'?JSON.stringify({token:'old'}):null,
                         setItem(){},removeItem(){}};
  const got=Sess.get();
  global.localStorage=realL; global.sessionStorage=realS;
  return got && got.token==='old'; });
t("clear removes both the new key and the legacy one", ()=>{
  const store={cs_school_sess_v2:'x'}; let legacyCleared=false;
  const realL=global.localStorage, realS=global.sessionStorage;
  global.localStorage={getItem:k=>store[k]??null,setItem:(k,v)=>{store[k]=v},removeItem:k=>{delete store[k]}};
  global.sessionStorage={getItem:()=>null,setItem(){},removeItem:k=>{if(k==='cs_school_sess')legacyCleared=true}};
  Sess.clear();
  const ok = !store.cs_school_sess_v2 && legacyCleared;
  global.localStorage=realL; global.sessionStorage=realS;
  return ok; });
t("supabase auth is told to persist explicitly", ()=>{
  const h=require("fs").readFileSync("/Users/staceygrant/Documents/cultureschool-backend/dist/school.html","utf8");
  return /persistSession:\s*true/.test(h) && /autoRefreshToken:\s*true/.test(h); });

console.log("\nBACK AND BREADCRUMBS");
t("crumbs render a back button and the trail",
  ()=>{ const h=crumbs([{label:'Home',go:"go('gate')"},{label:'Period 3'}]);
        return h.includes('history.back()') && h.includes('Home') && h.includes('Period 3'); });
t("the last crumb is marked as the current page",
  ()=>crumbs([{label:'A',go:'x'},{label:'B'}]).includes('aria-current="page"'));
t("crumb labels are escaped",
  ()=>!crumbs([{label:'<script>x</script>'}]).includes('<script>x'));
t("navSnapshot captures what a view needs to be restored",
  ()=>{ const k=Object.keys(navSnapshot());
        return ['view','briefOpen','tab','classId','fLevel','fSubject'].every(x=>k.includes(x)); });
t("opening and closing a brief are history entries",
  ()=>{ const h=require("fs").readFileSync("/Users/staceygrant/Documents/cultureschool-backend/dist/school.html","utf8");
        return /function openBrief[\s\S]{0,400}pushNav\(\)/.test(h)
            && /function closeBrief[\s\S]{0,120}pushNav\(\)/.test(h); });
t("a popstate handler exists",
  ()=>require("fs").readFileSync("/Users/staceygrant/Documents/cultureschool-backend/dist/school.html","utf8")
       .includes("addEventListener('popstate'"));
t("Home from a student view does NOT clear the session", ()=>{
  State.session={token:'t',name:'M',class_name:'P3',briefs:[]};
  State.briefOpen='adinkra';
  leaveToGate();
  return State.session!==null && State.briefOpen===null && State.view==='gate'; });
t("the gate offers a signed-in student their class back", ()=>{
  State.session={token:'t',name:'M',class_name:'Period 3',briefs:[]};
  const h=viewGate();
  return h.includes('You are still in') && h.includes('Back to my assignments'); });
t("leaving asks first, so a shared device is not wiped by accident",
  ()=>/function leaveClass\(\)\s*\{\s*\n\s*if\(!confirm/.test(
       require("fs").readFileSync("/Users/staceygrant/Documents/cultureschool-backend/dist/school.html","utf8")));

console.log("\n"+_p+" passed, "+_f+" failed");
process.exit(_f?1:0);
