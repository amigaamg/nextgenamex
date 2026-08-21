/* ---------- STATE ---------- */
let S = {
  session:null, role:null, facility:null, screen:null,
  patient:PATIENTS[0], encounter:ENCOUNTERS[0],
  ccs:[], facts:{}, risk:{temp:36.8,hr:80,rr:18,spo2:98,sbp:118,dbp:76},
  exam:{general:'',respiratory:'',cardio:'',abdomen:''},
  inv:{cbc:'',crp:'',cxr:''}, reviewed:{cbc:false,crp:false,cxr:false},
  dx:'', dxCode:'', dxConf:0,
  plan:{admit:'Treat ambulatory',meds:[],obs:''},
  step:2, stepDone:[0,1], qEdit:null, ptab:'overview', savedAt:null, audit:[],
  actFilter:'All', tasksDone:{}, opsView:'queues', notifSeen:0, friDrill:false,
  roundIdx:0, clinicSel:0, intelOpen:true, taskCat:'All', tlFilter:'All', dcCheck:{}, admCheck:{}
};
window.S = S;
const auditLog = (msg)=>{ S.audit.unshift({t:new Date().toLocaleTimeString('en-GB',{hour:'2-digit',minute:'2-digit'}), msg}); };
/* Load / persist the active encounter's clinical state — one patient, one story */
function loadEnc(e){
  const d=e.d||ENC_DEFAULTS();
  S.ccs=d.ccs.slice(); S.facts=Object.assign({},d.facts); S.risk=Object.assign({},d.risk);
  S.exam=Object.assign({},d.exam); S.inv=Object.assign({},d.inv); S.reviewed=Object.assign({},d.reviewed);
  S.dx=d.dx; S.dxCode=d.dxCode; S.dxConf=d.dxConf; S.plan=Object.assign({admit:'',meds:[],obs:''},d.plan);
  S.step=d.step; S.stepDone=d.stepDone.slice();
}
function saveEnc(){
  if(!S.encounter) return;
  const d=S.encounter.d=S.encounter.d||ENC_DEFAULTS();
  d.ccs=S.ccs.slice(); d.facts=Object.assign({},S.facts); d.risk=Object.assign({},S.risk);
  d.exam=Object.assign({},S.exam); d.inv=Object.assign({},S.inv); d.reviewed=Object.assign({},S.reviewed);
  d.dx=S.dx; d.dxCode=S.dxCode; d.dxConf=S.dxConf; d.plan=Object.assign({},S.plan);
  d.step=S.step; d.stepDone=S.stepDone.slice();
  S.savedAt=new Date().toLocaleTimeString('en-GB',{hour:'2-digit',minute:'2-digit'});
  persistSession();
}
const ccText = ()=>S.ccs.map(c=>c.text+(c.dur?' ('+c.dur+')':'')).join('; ')||'';
window.SccText = ccText;

/* ---------- MINI ROUTER ---------- */
const $=id=>document.getElementById(id);
function go(name){
  ['landing','auth','facility'].forEach(v=>$( 'view-'+v ).classList.toggle('hide', v!==name));
  const shell=$('shell');
  const isPublic = ['landing','auth','facility'].includes(name);
  shell.classList.toggle('hide', isPublic);
  $('demoBanner').style.display='flex';
  if(!isPublic){ S.screen=name; renderShell(); renderScreen(name); }
  window.scrollTo(0,0);
  toggleSidebar(false);
}
function scrollToFeatures(){ document.getElementById('features').scrollIntoView({behavior:'smooth'}); }

/* ---------- SHELL NAV ---------- */
const NAV = [
  {g:'Overview', items:[
    {id:'dashboard', label:'Command Center', icon:'M4 13h6V4H4Zm10 7h6v-9h-6Zm-10 0h6v-5H4Zm10-13v4h6V4Z'},
    {id:'activity', label:'Activity', icon:'M3 12h4l2 6 4-14 2 8h6'},
    {id:'tasks', label:'My Tasks', icon:'M9 4h6m-6 0a2 2 0 0 0-2 2v14h10V6a2 2 0 0 0-2-2m-6 0a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2'}
  ]},
  {g:'People', items:[
    {id:'patients', label:'Patients', icon:'M3 20c0-3 3-5 6-5s6 2 6 5M16 4a3 3 0 0 1 0 6M19 15c2 0 3 1.5 3 3', count:7},
    {id:'register', label:'Register Patient', icon:'M12 5v14M5 12h14'}
  ]},
  {g:'Clinical', items:[
    {id:'encounters', label:'Encounters', icon:'M12 8v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z', count:6},
    {id:'encounter', label:'Encounter Workspace', icon:'M3 12h4l2 6 4-14 2 8h6', active:true},
    {id:'coding', label:'ICD-11 Coding', icon:'M8 5h8M8 12h8M8 19h8M12 5v14M5 5h14v14H5Z'}
  ]},
  {g:'Operations', items:[
    {id:'ops', label:'Operations', icon:'M3 7h18M3 7v10a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V7M7 3l-4 4M17 3l4 4'},
    {id:'diagnostics', label:'Laboratory & Imaging', icon:'M6 3v12M6 21v-6M18 3v6M18 21v-3M6 9h12M6 15h12'},
    {id:'pharmacy', label:'Pharmacy', icon:'M12 3 5 6v6c0 4 3 7 7 9 4-2 7-5 7-9V6Z'},
    {id:'telemedicine', label:'Telemedicine', icon:'M4 6h11v9H4ZM15 9l5-3v9l-5-3Z'},
    {id:'billing', label:'Billing & Claims', icon:'M5 3h14v18l-2-1-2 1-2-1-2 1-2-1-2 1Z'}
  ]},
  {g:'System', items:[
    {id:'reports', label:'Reports / HMIS', icon:'M4 20h16M6 20V8l6-4 6 4v12M9 12h.01M15 12h.01M9 16h.01M15 16h.01'},
    {id:'research', label:'Research', icon:'M9 3v18M15 3v18M3 7h18M3 17h18', count:3},
    {id:'integrations', label:'Integrations', icon:'M12 3a9 9 0 1 0 9 9M12 3v8l6 4', count:8},
    {id:'documents', label:'Documents', icon:'M6 2h9l4 4v16H6ZM15 6V2l4 4M9 12h6M9 16h6'},
    {id:'governance', label:'Governance & Audit', icon:'M12 2l8 4v6c0 5-3.5 8.5-8 10-4.5-1.5-8-5-8-10V6Z'}
  ]}
];

/* ---------- ROLE-AWARE NAV ---------- */
const NAVS = {
  clinical: NAV,
  admin: [
    {g:'Command Center', items:[
      {id:'dashboard', label:'Facility Command Center', icon:'M4 13h6V4H4Zm10 7h6v-9h-6Zm-10 0h6v-5H4Zm10-13v4h6V4Z'},
      {id:'exec', label:'Executive Overview', icon:'M3 3v18h18M7 14l4-4 3 3 5-6'},
      {id:'clinicalops', label:'Clinical Operations Monitor', icon:'M3 7h18M3 7v10a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V7M7 3l-4 4M17 3l4 4'}
    ]},
    {g:'Enterprise', items:[
      {id:'integrations', label:'Enterprise Integrations', icon:'M12 3a9 9 0 1 0 9 9M12 3v8l6 4', count:8},
      {id:'hmis', label:'HMIS Connection', icon:'M4 20h16M6 20V8l6-4 6 4v12M9 12h.01M15 12h.01M9 16h.01M15 16h.01'},
      {id:'national', label:'National Data Readiness', icon:'M12 2a10 10 0 1 0 10 10A10 10 0 0 0 12 2Z M12 8v6M12 17h.01'},
      {id:'migration', label:'Data Migration', icon:'M3 12h18M3 12l4-4M3 12l4 4M21 12l-4-4M21 12l-4 4'},
      {id:'ecosystem', label:'Facility Ecosystem', icon:'M12 3a9 9 0 1 0 9 9M12 3v8l6 4M12 21a9 9 0 0 0 7-12'}
    ]},
    {g:'Command', items:[
      {id:'workforce', label:'Workforce Command', icon:'M3 20c0-3 3-5 6-5s6 2 6 5M16 4a3 3 0 0 1 0 6M19 15c2 0 3 1.5 3 3'},
      {id:'workforceanalytics', label:'Workforce Analytics', icon:'M3 3v18h18M7 14l4-4 3 3 5-6'},
      {id:'financial', label:'Financial', icon:'M5 3h14v18l-2-1-2 1-2-1-2 1-2-1-2 1Z'},
      {id:'quality', label:'Quality · Safety & Governance', icon:'M12 2l8 4v6c0 5-3.5 8.5-8 10-4.5-1.5-8-5-8-10V6Z'},
      {id:'security', label:'Security Center', icon:'M12 2l8 4v6c0 5-3.5 8.5-8 10-4.5-1.5-8-5-8-10V6ZM9 12l2 2 4-4'}
    ]},
    {g:'Configure', items:[
      {id:'provision', label:'Provision Staff & Roles', icon:'M12 5v14M5 12h14'},
      {id:'organizations', label:'Organizations', icon:'M12 3a9 9 0 1 0 9 9M12 3v8l6 4M3 12h6'},
      {id:'services', label:'Service Catalogues', icon:'M9 5h6m-6 0a2 2 0 0 0-2 2v14h10V7a2 2 0 0 0-2-2m-6 0a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2'},
      {id:'infrastructure', label:'Infrastructure', icon:'M3 21h18M5 21V5l6-3 8 5v14M9 9h.01M9 13h.01M9 17h.01'},
      {id:'assets', label:'Asset Intelligence', icon:'M12 2l8 4v6c0 5-3.5 8.5-8 10-4.5-1.5-8-5-8-10V6Z M12 8v5M12 17h.01'},
      {id:'identity', label:'Hospital Identity', icon:'M12 12a4 4 0 1 0-4-4 4 4 0 0 0 4 4Zm0 2c-4 0-8 2-8 5v1h16v-1c0-3-4-5-8-5Z'}
    ]},
    {g:'Intelligence & Ecosystems', items:[
      {id:'education', label:'Clinical Education', icon:'M12 3 2 9l10 6 10-6ZM6 11v5c2 1.5 4 2.5 6 2.5s4-1 6-2.5v-5'},
      {id:'communications', label:'Communications', icon:'M4 6h11v9H4ZM15 9l5-3v9l-5-3Z'},
      {id:'protocols', label:'Protocol Centers', icon:'M9 3v18M15 3v18M3 7h18M3 17h18'},
      {id:'intel', label:'Clinical Intelligence', icon:'M12 2l3 4h4v4l3 2-3 2v4h-4l-3 4-3-4H5v-4l-3-2 3-2V6h4Z'},
      {id:'execintel', label:'Executive Intelligence', icon:'M3 3v18h18M7 14l4-4 3 3 5-6'},
      {id:'researchintel', label:'Research Intelligence', icon:'M9 3v18M15 3v18M3 7h18M3 17h18', count:3},
      {id:'marketplace', label:'Marketplace', icon:'M4 7h16M10 7V4h4v3M5 7l1 13h12l1-13'}
    ]},
    {g:'People & Clinical', items:[
      {id:'patients', label:'Patients', icon:'M3 20c0-3 3-5 6-5s6 2 6 5M16 4a3 3 0 0 1 0 6M19 15c2 0 3 1.5 3 3', count:7},
      {id:'register', label:'Register Patient', icon:'M12 5v14M5 12h14'},
      {id:'encounters', label:'Encounters', icon:'M12 8v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z', count:6},
      {id:'coding', label:'ICD-11 Coding', icon:'M8 5h8M8 12h8M8 19h8M12 5v14M5 5h14v14H5Z'},
      {id:'reports', label:'Reports / HMIS', icon:'M4 20h16M6 20V8l6-4 6 4v12M9 12h.01M15 12h.01M9 16h.01M15 16h.01'},
      {id:'governance', label:'Governance & Audit', icon:'M12 2l8 4v6c0 5-3.5 8.5-8 10-4.5-1.5-8-5-8-10V6Z'}
    ]},
    {g:'Operations', items:[
      {id:'ops', label:'Operations', icon:'M3 7h18M3 7v10a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V7M7 3l-4 4M17 3l4 4'},
      {id:'diagnostics', label:'Laboratory & Imaging', icon:'M6 3v12M6 21v-6M18 3v6M18 21v-3M6 9h12M6 15h12'},
      {id:'pharmacy', label:'Pharmacy', icon:'M12 3 5 6v6c0 4 3 7 7 9 4-2 7-5 7-9V6Z'},
      {id:'telemedicine', label:'Telemedicine', icon:'M4 6h11v9H4ZM15 9l5-3v9l-5-3Z'},
      {id:'billing', label:'Billing & Claims', icon:'M5 3h14v18l-2-1-2 1-2-1-2 1-2-1-2 1Z'}
    ]},
    {g:'Builder & Settings', items:[
      {id:'builder', label:'Hospital Builder', icon:'M3 21h18M5 21V5l6-3 8 5v14'},
      {id:'invitations', label:'Invitation Links & Roster', icon:'M4 6h11v9H4ZM15 9l5-3v9l-5-3Z'},
      {id:'stafflogins', label:'Auto-create Staff Logins', icon:'M12 2l3 4h4v4l3 2-3 2v4h-4l-3 4-3-4H5v-4l-3-2 3-2V6h4Z'}
    ]}
  ],
  clinician: [
    {g:'Today', items:[
      {id:'dashboard', label:'Today\'s Work', icon:'M3 12h4l2 6 4-14 2 8h6'},
      {id:'ward', label:'Ward 4A', icon:'M5 21V7l7-4 7 4v14', count:5},
      {id:'round', label:'Daily Ward Round', icon:'M12 8v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z'},
      {id:'handover', label:'Handover', icon:'M4 6h11v9H4ZM15 9l5-3v9l-5-3Z'}
    ]},
    {g:'Work', items:[
      {id:'clinic', label:'Clinic', icon:'M3 20c0-3 3-5 6-5s6 2 6 5M16 4a3 3 0 0 1 0 6M19 15c2 0 3 1.5 3 3'},
      {id:'results', label:'Results', icon:'M9 3v18M15 3v18M3 7h18M3 17h18'},
      {id:'tasks', label:'My Tasks', icon:'M9 4h6m-6 0a2 2 0 0 0-2 2v14h10V6a2 2 0 0 0-2-2m-6 0a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2'},
      {id:'patients', label:'Patients', icon:'M3 20c0-3 3-5 6-5s6 2 6 5M16 4a3 3 0 0 1 0 6M19 15c2 0 3 1.5 3 3', count:7}
    ]},
    {g:'Record', items:[
      {id:'encounters', label:'Encounters', icon:'M12 8v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z', count:6},
      {id:'encounter', label:'Encounter Workspace', icon:'M3 12h4l2 6 4-14 2 8h6'},
      {id:'coding', label:'ICD-11 Coding', icon:'M8 5h8M8 12h8M8 19h8M12 5v14M5 5h14v14H5Z'}
    ]},
    {g:'Operations', items:[
      {id:'ops', label:'Operations', icon:'M3 7h18M3 7v10a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V7M7 3l-4 4M17 3l4 4'},
      {id:'pharmacy', label:'Pharmacy', icon:'M12 3 5 6v6c0 4 3 7 7 9 4-2 7-5 7-9V6Z'},
      {id:'telemedicine', label:'Telemedicine', icon:'M4 6h11v9H4ZM15 9l5-3v9l-5-3Z'},
      {id:'billing', label:'Billing & Claims', icon:'M5 3h14v18l-2-1-2 1-2-1-2 1-2-1-2 1Z'}
    ]},
    {g:'System', items:[
      {id:'reports', label:'Reports / HMIS', icon:'M4 20h16M6 20V8l6-4 6 4v12M9 12h.01M15 12h.01M9 16h.01M15 16h.01'},
      {id:'documents', label:'Documents', icon:'M6 2h9l4 4v16H6ZM15 6V2l4 4'},
      {id:'governance', label:'Governance & Audit', icon:'M12 2l8 4v6c0 5-3.5 8.5-8 10-4.5-1.5-8-5-8-10V6Z'},
      {id:'integrations', label:'Integrations', icon:'M12 3a9 9 0 1 0 9 9M12 3v8l6 4', count:8}
    ]}
  ],
  lab: [
    {g:'Worklist', items:[
      {id:'diagnostics', label:'Laboratory Worklist', icon:'M6 3v12M6 21v-6M18 3v6M18 21v-3M6 9h12M6 15h12', count:12},
      {id:'diagnostics', label:'Pending Orders', icon:'M3 12h4l2 6 4-14 2 8h6'},
      {id:'diagnostics', label:'Results Entry', icon:'M9 3v18M15 3v18M3 7h18M3 17h18'}
    ]},
    {g:'Quality', items:[
      {id:'reports', label:'Workload Reports', icon:'M4 20h16M6 20V8l6-4 6 4v12M9 12h.01M15 12h.01M9 16h.01M15 16h.01'},
      {id:'governance', label:'Quality Control', icon:'M12 2l8 4v6c0 5-3.5 8.5-8 10-4.5-1.5-8-5-8-10V6Z'}
    ]}
  ],
  pharmacy: [
    {g:'Dispensing', items:[
      {id:'pharmacy', label:'Dispensing Queue', icon:'M12 3 5 6v6c0 4 3 7 7 9 4-2 7-5 7-9V6Z', count:5},
      {id:'pharmacy', label:'Pending Prescriptions', icon:'M3 12h4l2 6 4-14 2 8h6'},
      {id:'pharmacy', label:'Medication History', icon:'M12 8v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z'}
    ]},
    {g:'Inventory', items:[
      {id:'pharmacy', label:'Stock Levels', icon:'M6 2h9l4 4v16H6ZM15 6V2l4 4'},
      {id:'reports', label:'Dispensing Reports', icon:'M4 20h16M6 20V8l6-4 6 4v12M9 12h.01M15 12h.01'}
    ]}
  ],
  patient: [
    {g:'My Health', items:[
      {id:'portal', label:'My Health', icon:'M12 3 5 6v6c0 4 3 7 7 9 4-2 7-5 7-9V6Z'},
      {id:'portal', label:'My Visits', icon:'M12 8v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z', count:4},
      {id:'portal', label:'My Results', icon:'M9 3v18M15 3v18M3 7h18M3 17h18'},
      {id:'portal', label:'My Documents', icon:'M6 2h9l4 4v16H6ZM15 6V2l4 4'}
    ]},
    {g:'Care', items:[
      {id:'portal', label:'Appointments', icon:'M7 3v4M17 3v4M3 10h18M5 5h14a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2Z'},
      {id:'portal', label:'Messages', icon:'M4 6h11v9H4ZM15 9l5-3v9l-5-3Z', count:2}
    ]}
  ]
};
const navFor = ()=> NAVS[S.role] || NAV;

function renderShell(){
  const nav=$('nav');
  const role = ROLES.find(r=>r.id===S.role);
  const fac = FACILITIES.find(f=>f.id===S.facility);
  $('brandFacility').textContent = fac?fac.code:'—';
  $('userBadge').textContent = role?role.def:'User';
  $('facBtn').innerHTML = (fac?fac.code:'—') + ' <span class="caret">▼</span>';
  updateNotifDot();
  if(nav.dataset.role!==S.role){
    nav.dataset.role=S.role;
    nav.innerHTML = navFor().map(sec=>`
      <div class="nav-section">${sec.g}</div>
      ${sec.items.map(it=>`
        <button class="nav-item" data-nav="${it.id}" onclick="go('${it.id}')">
          <svg class="ic" viewBox="0 0 24 24"><path d="${it.icon}"/></svg>
          ${it.label}
          ${it.count?`<span class="badge badge-sky" style="margin-left:auto">${it.count}</span>`:''}
        </button>`).join('')}
    `).join('');
  }
}


/* ---------- PATIENT SELECT ---------- */
function selectPatient(mrn){
  const p=PATIENTS.find(x=>x.mrn===mrn); if(!p) return;
  saveEnc();
  S.patient=p;
  const e=ENCOUNTERS.find(x=>x.mrn===mrn && x.status!=='Completed') || ENCOUNTERS.find(x=>x.mrn===mrn) || null;
  if(e){ S.encounter=e; loadEnc(e); }
  else { S.encounter=null; S.ccs=[]; S.facts={}; }
}
function selectPatientMRN(mrn){ if(!mrn) return; selectPatient(mrn); }
function setOpsView(v){ S.opsView=v; renderScreen('ops'); }


/* ---------- NOTIFICATIONS DRAWER ---------- */
const notifDotHtml = ()=>NOTIFICATIONS.length-S.notifSeen>0?`<span class="notif-dot show"></span>`:'';
function updateNotifDot(){ const d=$('notifDot'); if(d) d.className='notif-dot'+(NOTIFICATIONS.length-S.notifSeen>0?' show':''); }
function openDrawer(html){
  $('drawerBox').innerHTML=html;
  $('drawerOv').classList.add('show');
}
function closeDrawer(){ $('drawerOv').classList.remove('show'); }
function showNotifications(){
  const unread=NOTIFICATIONS.length-S.notifSeen;
  S.notifSeen=NOTIFICATIONS.length; updateNotifDot();
  openDrawer(`
    <div class="drawer-h">
      <h3>Notifications</h3>
      ${unread>0?`<span class="badge badge-red">${unread} new</span>`:''}
      <button class="btn btn-icon" onclick="closeDrawer()"><svg class="ic" viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg></button>
    </div>
    <div class="drawer-b">
      <div class="small muted" style="margin-bottom:var(--sp3)">Grouped by type — tap to go to the destination.</div>
      ${['Results','Clinical','Tasks','Operations','System'].map(grp=>{
        const items=NOTIFICATIONS.filter(n=>n.type===grp);
        if(!items.length) return '';
        return `<div class="notif-group"><div class="notif-gtitle">${grp}</div>
          ${items.map(n=>`<button class="notif-item" onclick="closeDrawer();go('${n.go}')">
            <span class="notif-ic" style="background:${n.color}15;color:${n.color}">${n.type==='Results'?'R':n.type==='Clinical'?'!':n.type==='Tasks'?'✓':n.type==='Operations'?'↺':'⚙'}</span>
            <span class="grow"><b>${n.text}</b><div class="tiny muted">${n.time} · ${n.go}</div></span>
            <span class="muted">›</span></button>`).join('')}
        </div>`;
      }).join('')}
    </div>
    <div class="drawer-f"><button class="btn btn-outline btn-block" onclick="closeDrawer();go('activity')">View full activity →</button></div>`);
}
function notifGo(id){
  const n=NOTIFICATIONS.find(x=>x.id===id); if(!n) return;
  closeDrawer(); go(n.go);
}
function reviewResult(test){
  const labels={cbc:'CBC',crp:'CRP',cxr:'Chest X-ray'};
  S.reviewed[test]=true;
  auditLog(labels[test]||test+' results reviewed');
  toast(labels[test]||test+' results reviewed — clinical state updated','ok');
  saveEnc(); renderClinical(); renderScreen(S.screen);
  updateCommandCenter();
}


/* ---------- COMMAND PALETTE (Ctrl+K) ---------- */
let palIdx=0;
function openPalette(){
  $('paletteOv').classList.add('show');
  const inp=$('paletteInput'); inp.value=''; palIdx=0;
  paletteFilter();
  setTimeout(()=>inp.focus(),10);
}
function closePalette(){ $('paletteOv').classList.remove('show'); }
function paletteEntries(q){
  const t=q.trim().toLowerCase();
  const acts=[
    {label:'Open Command Center', sub:'Overview', go:'dashboard'},
    {label:'Start new encounter', sub:'Clinical', go:'encounter', act:()=>{}},
    {label:'Register a new patient', sub:'People', go:'register'},
    {label:'View patients directory', sub:'People', go:'patients'},
    {label:'Laboratory & Imaging worklist', sub:'Operations', go:'diagnostics'},
    {label:'Pharmacy / dispensing', sub:'Operations', go:'pharmacy'},
    {label:'ICD-11 coding search', sub:'Clinical', go:'coding'},
    {label:'Generate clinical document', sub:'Clinical', go:'documents'},
    {label:'Reports / HMIS', sub:'System', go:'reports'},
    {label:'Governance & audit trail', sub:'System', go:'governance'},
    {label:'Billing & claims', sub:'Operations', go:'billing'},
    {label:'Executive overview', sub:'Command', go:'exec'},
    {label:'Workforce command', sub:'Command', go:'workforce'},
    {label:'Provision staff & roles', sub:'Configure', go:'provision'},
    {label:'National data readiness', sub:'Enterprise', go:'national'},
    {label:'HMIS connection', sub:'Enterprise', go:'hmis'},
    {label:'Facility ecosystem', sub:'Enterprise', go:'ecosystem'},
    {label:'Clinical operations monitor', sub:'Command Center', go:'clinicalops'},
    {label:'Financial', sub:'Command', go:'financial'},
    {label:'Ward 4A — census', sub:'Today', go:'ward'},
    {label:'Daily ward round', sub:'Today', go:'round'},
    {label:'Handover board', sub:'Today', go:'handover'},
    {label:'Clinic — General OPD', sub:'Work', go:'clinic'},
    {label:'Results inbox', sub:'Work', go:'results'},
    {label:'Discharge — readiness', sub:'Today', go:'discharge'}
  ];
  const hits=[];
  if(!t){
    return [
      {label:'Open Command Center', sub:'Quick action', go:'dashboard', kind:'action'},
      ...acts.slice(1,4).map(a=>({label:a.label,sub:a.sub,go:a.go,kind:'action'}))
    ];
  }
  acts.filter(a=>(a.label+' '+a.sub).toLowerCase().includes(t)).forEach(a=>hits.push({label:a.label,sub:a.sub,go:a.go,kind:'action'}));
  PATIENTS.filter(p=>(p.name+' '+p.mrn+' '+p.conditions.join(' ')).toLowerCase().includes(t)).forEach(p=>hits.push({label:p.name,sub:`Patient • ${p.mrn} • ${p.sex} ${p.ageLabel||p.age+'y'}`,go:'patient',kind:'patient',run:()=>selectPatient(p.mrn)}));
  ENCOUNTERS.filter(e=>(e.id+' '+e.cc+' '+e.mrn).toLowerCase().includes(t)).forEach(e=>hits.push({label:e.id,sub:`Encounter • ${e.cc}`,go:'encounter',kind:'encounter',run:()=>selectPatient(e.mrn)}));
  return hits.slice(0,9);
}
function paletteFilter(){
  const q=$('paletteInput').value;
  const items=paletteEntries(q);
  palIdx=Math.min(palIdx,items.length-1);
  $('paletteList').innerHTML = items.length?items.map((it,i)=>`
    <div class="palette-item ${i===palIdx?'sel':''}" data-pidx="${i}" onclick="paletteGo(${i})" onmousemove="palIdx=${i};palettePaint()">
      ${it.kind==='action'?'<svg class="ic" width="16" height="16" viewBox="0 0 24 24"><path d="M4 13h6V4H4Zm10 7h6v-9h-6Zm-10 0h6v-5H4Zm10-13v4h6V4Z"/></svg>':it.kind==='patient'?'<svg class="ic" width="16" height="16" viewBox="0 0 24 24"><path d="M12 12a4 4 0 1 0-4-4 4 4 0 0 0 4 4Zm0 2c-4 0-8 2-8 5v1h16v-1c0-3-4-5-8-5Z"/></svg>':'<svg class="ic" width="16" height="16" viewBox="0 0 24 24"><path d="M12 8v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"/></svg>'}
      <div><b>${it.label}</b><div><small>${it.sub}</small></div></div>
    </div>`).join('')
    :`<div class="empty-row"><div>No results for “${q}”. Try a patient name, MRN, encounter or action.</div></div>`;
}
function palettePaint(){ document.querySelectorAll('.palette-item').forEach((el,i)=>el.classList.toggle('sel',i===palIdx)); }
function paletteGo(i){
  const items=paletteEntries($('paletteInput').value);
  const it=items[i]; if(!it) return;
  if(it.run) it.run();
  closePalette();
  if(it.go) go(it.go);
  if(it.label==='Start new encounter') toast('New encounter opened (demo)','ok');
}
$('paletteInput').addEventListener('keydown',e=>{
  const n=paletteEntries($('paletteInput').value).length;
  if(e.key==='ArrowDown'){ e.preventDefault(); palIdx=(palIdx+1)%Math.max(n,1); palettePaint(); }
  else if(e.key==='ArrowUp'){ e.preventDefault(); palIdx=(palIdx-1+Math.max(n,1))%Math.max(n,1); palettePaint(); }
  else if(e.key==='Enter'){ e.preventDefault(); paletteGo(palIdx); }
  else if(e.key==='Escape'){ closePalette(); }
});

/* ---------- FACILITY SWITCH ---------- */
function showFacilitySwitch(){
  const role=ROLES.find(r=>r.id===S.role);
  const day = id=>dayFor(id);
  const facCard = f=>`
    <button class="row gap3 card-hover" style="width:100%;text-align:left;padding:var(--sp3) var(--sp4);border:1px solid ${S.facility===f.id?'var(--primary)':'var(--border)'};border-radius:var(--r-lg);background:${S.facility===f.id?'var(--primary-light)':'#fff'};cursor:pointer" onclick="switchFacility('${f.id}')">
      <span style="width:40px;height:40px;border-radius:12px;background:${f.color}15;color:${f.color};display:flex;align-items:center;justify-content:center;font-weight:700;flex-shrink:0">${f.code}</span>
      <span class="grow">
        <b style="font-size:var(--sm)">${f.name}</b>
        <div class="small muted">${f.level} • ${day(f.id).patients} patients • ${day(f.id).encounters} encounters today</div>
        <div class="row gap1" style="margin-top:4px"><span class="chip">${f.workspace}</span>${f.status==='Operational'?'<span class="chip green"><span class="dot dot-green"></span>Operational</span>':'<span class="chip red">Attention</span>'}</div>
      </span>
      ${S.facility===f.id?'<span class="badge badge-sky">Active</span>':''}
    </button>`;
  const campuses = ['Main campus','Outpatient complex','Maternity unit','Community outreach sites','Satellite clinics'];
  $('modalBox').innerHTML=`
    <div class="modal-h">
      <h3 style="font-size:var(--lg)">Where are you working today?</h3>
      <button class="btn btn-icon" onclick="closeModal()"><svg class="ic" viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg></button>
    </div>
    <div class="modal-b">
      <div class="small muted" style="margin-bottom:var(--sp3)">Signed in as <b>${role?role.def:'—'}</b> (${role?role.label:'—'}). Every facility carries its own departments, services, workforce and reporting.</div>
      <div class="switch-group"><div class="switch-gtitle">MY FACILITIES</div>
        ${FACILITIES.map(facCard).join('')}
      </div>
      <div class="switch-group"><div class="switch-gtitle">FACILITY NETWORK — Kisii Teaching &amp; Referral Hospital</div>
        <div class="row gap1 wrap" style="padding:var(--sp3) var(--sp4);background:#f8fafc;border:1px dashed var(--border);border-radius:var(--r-lg)">
          ${campuses.map(c=>`<span class="chip">${c}</span>`).join('')}
        </div>
      </div>
      <div class="switch-group"><div class="switch-gtitle">PARTNER NETWORK</div>
        <div class="row gap1 wrap" style="padding:var(--sp3) var(--sp4);background:#f8fafc;border:1px dashed var(--border);border-radius:var(--r-lg)">
          ${(PARTNERS||[]).map(p=>`<span class="chip" style="border-color:${p.color}55;color:${p.color}">${p.type}</span>`).join('')}
        </div>
      </div>
      <div class="row gap1" style="margin-top:var(--sp4);padding-top:var(--sp4);border-top:1px solid var(--border)">
        <span class="small muted grow">Switch role?</span>
        <button class="btn btn-outline btn-sm" onclick="closeModal();go('auth')">Change role</button>
      </div>
    </div>`;
  $('modalOv').classList.add('show');
}
function switchFacility(id){
  S.facility=id;
  closeModal();
  auditLog(`Switched workspace to ${FACILITIES.find(f=>f.id===id).code}`);
  toast(`Now working at ${FACILITIES.find(f=>f.id===id).code}`,'ok');
  go('dashboard');
}

/* ---------- QUICK ACTIONS (+ New) ---------- */
function showQuickActions(){
  const hasCtx = !!S.patient;
  $('modalBox').innerHTML=`
    <div class="modal-h"><h3 style="font-size:var(--lg)">Quick actions</h3>
      <button class="btn btn-icon" onclick="closeModal()"><svg class="ic" viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg></button>
    </div>
    <div class="modal-b">
      ${hasCtx?`<div class="small muted" style="margin-bottom:var(--sp3)">Context: <b>${S.patient.name}</b> ${S.encounter?`• ${S.encounter.id}`:''}</div>`:''}
      <div class="grid cols-2" style="gap:var(--sp2)">
        ${[
          {l:'New encounter', s:'Open the encounter workspace', go:'encounter', ic:'M12 5v14M5 12h14'},
          {l:'Register patient', s:'Add a new person to this facility', go:'register', ic:'M12 5v14M5 12h14'},
          {l:'Order investigation', s:'Lab / imaging from current context', go:'diagnostics', ic:'M6 3v12M18 3v6M6 9h12'},
          {l:'Write prescription', s:'Medication for current context', go:'pharmacy', ic:'M12 3 5 6v6c0 4 3 7 7 9'},
          {l:'Generate document', s:'Full note / SOAP / discharge', go:'documents', ic:'M6 2h9l4 4v16H6Z'},
          {l:'ICD-11 coding', s:'Assign diagnosis codes', go:'coding', ic:'M8 5h8M8 12h8M8 19h8'}
        ].map(a=>`
          <button class="card-hover" style="text-align:left;padding:var(--sp3);border:1px solid var(--border);border-radius:var(--r-lg);background:#fff;cursor:pointer" onclick="closeModal();go('${a.go}')">
            <svg class="ic" style="color:var(--primary)" viewBox="0 0 24 24"><path d="${a.ic}"/></svg>
            <b style="font-size:var(--sm);display:block;margin-top:6px">${a.l}</b>
            <span class="small muted">${a.s}</span>
          </button>`).join('')}
      </div>
    </div>`;
  $('modalOv').classList.add('show');
}

/* ---------- KEYBOARD SHORTCUTS ---------- */
document.addEventListener('keydown',e=>{
  if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='k'){ e.preventDefault(); if(!$('shell').classList.contains('hide')) openPalette(); }
  if(e.key==='Escape'){ closePalette(); closeModal(); }
});

/* ---------- SESSION PERSISTENCE ---------- */
const SKEY='amexan.session.v1';
function persistSession(){
  try{ sessionStorage.setItem(SKEY, JSON.stringify({role:S.role, facility:S.facility, patient:S.patient?S.patient.mrn:null, encounter:S.encounter?S.encounter.id:null, savedAt:S.savedAt})); }catch(e){}
}
function restoreSession(){
  try{
    const raw=sessionStorage.getItem(SKEY); if(!raw) return false;
    const s=JSON.parse(raw);
    if(s.role && s.facility){
      S.role=s.role; S.facility=s.facility;
      if(s.patient){ const p=PATIENTS.find(x=>x.mrn===s.patient); if(p) selectPatient(p.mrn); }
      if(s.encounter){ const en=ENCOUNTERS.find(x=>x.id===s.encounter); if(en && en.mrn===S.patient.mrn) S.encounter=en; }
      loadEnc(S.encounter);
      return true;
    }
  }catch(e){}
  return false;
}

/* ---------- TOAST ---------- */
function toast(msg,type){
  const t=document.createElement('div'); t.className='toast '+(type||'');
  t.innerHTML=`<span class="dot ${type==='err'?'dot-red':type==='warn'?'dot-amber':'dot-sky'}"></span>${msg}`;
  $('toastWrap').appendChild(t);
  setTimeout(()=>{ t.style.opacity=0; t.style.transition='opacity .3s'; setTimeout(()=>t.remove(),300); },2600);
}

/* ---------- SIDEBAR / LOGOUT ---------- */
function toggleSidebar(open){ $('sidebar').classList.toggle('open',open); $('sidebarOverlay').classList.toggle('show',open); }
function logout(){ S.session=null; try{sessionStorage.removeItem(SKEY);}catch(e){} go('auth'); toast('Signed out (demo session cleared)','ok'); }

/* ---------- AUTH RENDER ---------- */
function renderRoles(){
  $('roleGrid').innerHTML=ROLES.map(r=>`<div class="role-card" onclick="pickRole('${r.id}')">
    <div class="rc" style="background:${r.color}"><span style="font-size:18px">${r.icon}</span></div>
    <b>${r.label}</b><small>${r.desc}</small>
  </div>`).join('');
}
function pickRole(id){ S.role=id; const r=ROLES.find(x=>x.id===id); $('facilityRoleBadge').textContent=r.label; renderFacilities(); go('facility'); }
function renderFacilities(){
  $('facilityList').innerHTML=FACILITIES.map(f=>`<div class="facility-card" onclick="pickFacility('${f.id}')">
    <div class="fl" style="background:${f.color}">${f.code[0]}</div>
    <div class="grow"><b>${f.name}</b><div class="tiny muted">${f.level} · ${f.count}</div></div>
    <span class="badge badge-green"><span class="dot dot-green"></span>Operational</span>
  </div>`).join('');
}
function pickFacility(id){ S.facility=id; S.session={role:S.role,facility:id}; auditLog(`${ROLES.find(r=>r.id===S.role).def} signed in at ${FACILITIES.find(f=>f.id===id).name}`); persistSession(); toast(`Welcome to ${FACILITIES.find(f=>f.id===id).name} (demo)`,'ok'); go('dashboard'); }