#!/usr/bin/env bash
# Runs the School Mode client assertions against dist/school.html.
#   bash docs/tests/run-school-client.sh
# No browser and no network: the page's script block is evaluated against
# minimal DOM/fetch stubs, so this only exercises pure logic and markup.
set -euo pipefail
cd "$(dirname "$0")/../.."
node -e '
const fs=require("fs");
let src=fs.readFileSync("dist/school.html","utf8")
  .match(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/)[1];
src=src.replace(/const sb = window\.supabase[^\n]*\n/,"const sb=null;\n").replace(/^boot\(\);$/m,"");
global.localStorage={getItem:()=>null,setItem(){},removeItem(){}};
global.sessionStorage={getItem:()=>null,setItem(){},removeItem(){}};
global.location={search:"",pathname:"/",origin:"x"}; global.history={replaceState(){}};
global.window={supabase:{createClient:()=>null},scrollTo(){},open(){}};
global.document={querySelector:()=>({textContent:"",classList:{add(){},remove(){},toggle(){}},value:"",style:{setProperty(){},removeProperty(){}},innerHTML:""}),
  createElement:()=>({getContext:()=>new Proxy({},{get:()=>()=>{}}),toDataURL:()=>"data:,",style:{},dataset:{}}),
  body:{appendChild(){},classList:{toggle(){}},style:{setProperty(){},removeProperty(){}}},
  querySelectorAll:()=>[],getElementById:()=>null,addEventListener(){}};
global.fetch=async()=>({ok:true,status:200,json:async()=>({})});
new Function("require", src+"\n;\n"+fs.readFileSync("docs/tests/school-client.test.js","utf8"))(require);
'
