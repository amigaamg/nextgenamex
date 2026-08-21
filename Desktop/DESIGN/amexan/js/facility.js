/* =================================================================
   AMEXAN FACILITY ADMINISTRATOR WORKSPACE — constitutional screens.
   The Facility Administrator is the operational governor of the
   facility: configures, authorizes, monitors, coordinates and governs
   every role/subsystem — never trapped inside an EMR.
   ================================================================= */

const FProv = {dept:'surgery', role:'nurse', count:8, seed:'', done:null};
window.FProv = FProv;
function setProv(k,v){ FProv[k]=v; FProv.done=null; renderScreen('provision'); }
function doProvision(from){
  const count = Math.max(1, Math.min(40, parseInt(FProv.count,10)||8));
  const created = provisionStaff(FProv.dept, FProv.role, count, FProv.seed);
  FProv.done = created;
  auditLog(`Provisioned ${created.length} ${created[0].role} identities (${created[0].dept})`);
  toast(`${created.length} constitutional workspaces provisioned`,'ok');
  renderScreen('provision');
}
function resetProvision(){ FProv.done=null; renderScreen('provision'); }
function provSelect(opts, sel){
  return `<select class="input" onchange="setProv('${opts.k}','${opts.v}',this.value)"><option value="">—</option></select>`;
}

const facBar = (title, sub) => `<div class="row-b mb4" style="flex-wrap:wrap;gap:var(--sp3)">
  <div><h2 style="font-size:var(--xl)">${title}</h2><p class="small muted">${sub}</p></div>
  <div class="row gap2"><span class="chip">${(FACILITIES.find(f=>f.id===S.facility)||FACILITIES[0]).code}</span><button class="btn btn-outline btn-sm" onclick="go('dashboard')">← Command center</button></div>
</div>`;
const fhead = (title, badge) => `<div class="card-h"><h3>${title}</h3>${badge||''}</div>`;

function facilityScreen(name){
  switch(name){
    case 'exec': return execScreen();
    case 'workforce': return workforceScreen();
    case 'workforceanalytics': return workforceAnalyticsScreen();
    case 'provision': return provisionScreen();
    case 'researchintel': return researchIntelScreen();
    case 'organizations': return organizationsScreen();
    case 'services': return servicesScreen();
    case 'infrastructure': return infrastructureScreen();
    case 'assets': return assetsScreen();
    case 'clinicalops': return clinicalOpsScreen();
    case 'quality': return qualityScreen();
    case 'financial': return financialScreen();
    case 'hmis': return hmisScreen();
    case 'national': return nationalScreen();
    case 'ecosystem': return ecosystemScreen();
    case 'integrations': return integrationScreen();
    case 'execintel': return execIntelScreen();
    case 'security': return securityScreen();
    case 'education': return educationScreen();
    case 'communications': return communicationsScreen();
    case 'protocols': return protocolsScreen();
    case 'intel': return intelScreen();
    case 'migration': return migrationScreen();
    case 'builder': return builderScreen();
    case 'identity': return identityScreen();
    case 'invitations': return invitationsScreen();
    case 'stafflogins': return staffLoginsScreen();
    case 'marketplace': return marketplaceScreen();
  }
  return '';
}

/* ---------- EXECUTIVE OVERVIEW (performance, not operations) ---------- */
function execScreen(){
  const f = FACILITIES.find(x=>x.id===S.facility) || FACILITIES[0];
  const day = dayFor(S.facility);
  const today = new Date().toLocaleDateString('en-GB',{weekday:'short',day:'numeric',month:'short',year:'numeric'});

  /* ---- FACILITY PERFORMANCE ---- */
  const perf=[
    {l:'Patients in facility', v:day.patients, t:'Census', c:'#0284c7', go:'dashboard', ic:'M3 20c0-3 3-5 6-5s6 2 6 5M16 4a3 3 0 0 1 0 6M19 15c2 0 3 1.5 3 3'},
    {l:'Encounters today', v:day.encounters, t:'Activity', c:'#059669', go:'ops', ic:'M12 8v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z'},
    {l:'Admissions today', v:day.admissions, t:day.discharges+' discharges', c:'#7c3aed', go:'ops', ic:'M5 21V7l7-4 7 4v14M3 21h18M10 11h4'},
    {l:'Bed occupancy', v:day.occupancy+'%', t:day.occupancy>=85?'Pressure':'Stable', c:day.occupancy>=85?'#dc2626':'#059669', go:'clinicalops', ic:'M12 8v5l3 2'},
    {l:'Active operational risks', v:'3', t:'Organizational', c:'#d97706', go:'quality', ic:'M12 9v5M12 17h.01'}
  ];

  /* ---- FACILITY TODAY ---- */
  const todayRows=[
    ['Patient census', day.patients, '↑'],
    ['Encounters', day.encounters, '↑'],
    ['Admissions', day.admissions, '→'],
    ['Discharges', day.discharges, '↑'],
    ['Occupancy', day.occupancy+'%', '→'],
    ['Emergency attendance', 'High', '↑'],
    ['Theatre utilization', '76%', '→'],
    ['Laboratory TAT', '+22%', '↓']
  ];

  /* ---- PERFORMANCE AT A GLANCE ---- */
  const glance=[
    {l:'Patient volume', badge:'7 days', delta:'↑ 18%', note:'Above 30-day baseline', dc:'#059669', ser:day.trend.patients, c:'#0284c7'},
    {l:'Admissions', badge:'7 days', delta:'→ Stable', note:'Within expected range', dc:'#64748b', ser:[12,15,13,17,16,18,18], c:'#7c3aed'},
    {l:'Outpatient attendance', badge:'7 days', delta:'↑ 6%', note:'vs previous week', dc:'#059669', ser:[118,126,141,132,121,118,128], c:'#0284c7'},
    {l:'Emergency attendance', badge:'7 days', delta:'↑ High', note:'Above configured demand threshold', dc:'#dc2626', ser:[22,28,24,31,28,25,26], c:'#dc2626'},
    {l:'Theatre utilization', badge:'7 days', delta:'76%', note:'Normal operating range', dc:'#64748b', ser:[60,66,64,72,69,66,71], c:'#0891b2'},
    {l:'Laboratory turnaround', badge:'Today', delta:'↓ 22%', note:'Slower since 14:00 · Operational concern', dc:'#dc2626', ser:[92,90,95,88,86,84,82], c:'#059669'},
    {l:'Revenue', badge:'Month to date', delta:'KES 48.0M', note:'↑ 8.4% vs previous month', dc:'#059669', ser:day.trend.rev, c:'#059669'},
    {l:'Claims', badge:'Submission', delta:'94%', note:'Readiness · 12 pending exceptions', dc:'#059669', ser:[90,91,93,92,93,94,94], c:'#d97706'},
    {l:'Workforce coverage', badge:'Today', delta:'92%', note:'2 services below target', dc:'#d97706', ser:[91,93,90,92,89,91,90], c:'#0284c7'}
  ];

  /* ---- FACILITY HEALTH ---- */
  const health=[
    {d:'Clinical Operations', s:'Stable', c:'green', tr:'↑'},
    {d:'Capacity', s:'Pressure', c:'amber', tr:'↑'},
    {d:'Workforce', s:'Attention', c:'amber', tr:'→'},
    {d:'Financial', s:'Stable', c:'green', tr:'↑'},
    {d:'Quality & Safety', s:'Stable', c:'green', tr:'→'},
    {d:'Infrastructure', s:'Attention', c:'amber', tr:'↓'},
    {d:'Supplies', s:'Stable', c:'green', tr:'→'},
    {d:'National Reporting', s:'96% ready', c:'green', tr:'↑'},
    {d:'Ecosystem', s:'Connected', c:'green', tr:'→'}
  ];
  const trCol = t => t==='↑'?'#059669' : t==='↓'?'#dc2626' : '#94a3b8';

  /* ---- WHAT NEEDS YOUR ATTENTION (organizational, no patient data) ---- */
  const risks=[
    {tag:'Workforce capacity', title:'Emergency night shift below required coverage', rows:[['Current projected coverage','4 / 6 required'],['Impact','Emergency service capacity']], go:'workforce', label:'Review workforce'},
    {tag:'Capacity', title:'Medical wards approaching configured capacity', rows:[['Current occupancy','88%'],['Available beds','11'],['Trend','↑']], go:'clinicalops', label:'Review capacity'},
    {tag:'Infrastructure', title:'CT service degradation risk', rows:[['Scheduled studies affected','17'],['Risk','Moderate'],['Alternative imaging','Available']], go:'assets', label:'Review asset'}
  ];

  /* ---- EXECUTIVE TRENDS (selectable range) ---- */
  const ranges=[['7d','7 DAYS'],['30d','30 DAYS'],['90d','90 DAYS'],['12m','12 MONTHS']];
  const range=S.execRange||'7d';
  const n = range==='7d'?7 : range==='30d'?30 : range==='90d'?90 : 12;
  const gen = (base, drift, noise)=>{ const out=[]; let v=base; for(let i=0;i<n;i++){ out.push(Math.max(0,Math.round(v))); v+=drift+(Math.sin(i*1.7)+Math.cos(i*0.9))*noise; } return out; };
  const is7 = range==='7d';
  const trendMetrics=[
    {l:'Patient demand', note:'+18% vs baseline', c:'#0284c7', ser: is7?day.trend.patients : gen(118,0.4,6)},
    {l:'Admissions', note:'Stable', c:'#7c3aed', ser: is7?[12,15,13,17,16,18,18] : gen(15,0.05,2)},
    {l:'Emergency', note:'Above threshold', c:'#dc2626', ser: is7?[22,28,24,31,28,25,26] : gen(26,0.15,3)},
    {l:'Bed occupancy', note:'84%', c:'#d97706', ser: is7?[78,80,79,82,81,83,84] : gen(80,0.2,2)},
    {l:'Theatre utilization', note:'76%', c:'#0891b2', ser: is7?[60,66,64,72,69,66,71] : gen(66,0.1,4)},
    {l:'Laboratory turnaround', note:'+22% delay', c:'#059669', ser: is7?[92,90,95,88,86,84,82] : gen(88,-0.3,4)},
    {l:'Revenue', note:'+8.4%', c:'#059669', ser: is7?day.trend.rev : gen(42,0.35,3)},
    {l:'Workforce coverage', note:'92%', c:'#0284c7', ser: is7?[91,93,90,92,89,91,90] : gen(90,0.05,2)}
  ];

  /* ---- AMEXAN INTELLIGENCE: WHY THIS MATTERS ---- */
  const insights=[
    {tag:'Demand pressure', claim:'Patient volume has remained 18% above the facility\u2019s 30-day baseline for four consecutive days.', rows:[['Potential operational effect','Emergency and inpatient capacity are under increasing pressure.'],['Recommended review','Workforce coverage + bed capacity']], go:'workforce', label:'Investigate'},
    {tag:'Laboratory performance', claim:'Laboratory turnaround time has increased 22% since 14:00.', rows:[['Affected services','Emergency · Inpatient Medicine · Surgery'],['Current operational risk','Moderate'],['Possible contributing factor','Evening staffing coverage below configured target']], go:'diagnostics', label:'Investigate'}
  ];

  /* ---- EXPLORE ---- */
  const explore=[
    ['Workforce','workforce','M3 20c0-3 3-5 6-5s6 2 6 5M16 4a3 3 0 0 1 0 6M19 15c2 0 3 1.5 3 3'],
    ['Capacity','clinicalops','M3 7h18M3 7v10a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V7M7 3l-4 4M17 3l4 4'],
    ['Clinical Operations','clinicalops','M12 8v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z'],
    ['Financial','financial','M5 3h14v18l-2-1-2 1-2-1-2 1-2-1-2 1Z'],
    ['Quality & Safety','quality','M12 2l8 4v6c0 5-3.5 8.5-8 10-4.5-1.5-8-5-8-10V6Z'],
    ['Infrastructure','infrastructure','M3 21h18M5 21V5l6-3 8 5v14M9 9h.01M9 13h.01M9 17h.01'],
    ['National Reporting','national','M12 2a10 10 0 1 0 10 10A10 10 0 0 0 12 2Z M12 8v6M12 17h.01'],
    ['Ecosystem','ecosystem','M12 3a9 9 0 1 0 9 9M12 3v8l6 4M12 21a9 9 0 0 0 7-12']
  ];

  const defRow=(k,v)=>`<div class="row-b" style="padding:6px 0;border-bottom:1px solid var(--neutral-100)"><span class="small muted">${k}</span><b style="font-size:var(--sm)">${v}</b></div>`;

  return `
    ${facBar('Executive Overview', `${f.name} · Facility Administrator · ${f.level} · ${today}`)}
    <div class="grid cols-5 mb4">
      ${perf.map(p=>`<div class="kpi hoverable" onclick="go('${p.go}')"><div class="kpi-icon" style="background:${p.c}"><svg class="ic" viewBox="0 0 24 24"><path d="${p.ic}"/></svg></div><div><div class="kpi-value">${p.v}</div><div class="kpi-label">${p.l}</div><div class="kpi-trend">${p.t}</div></div></div>`).join('')}
    </div>
    <div class="card mb4">
      <div class="card-h"><h3>Facility today</h3><span class="badge badge-sky">Executive summary</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        <div class="table-wrap"><table>
          <tr><th>Indicator</th><th>Today</th><th>Trend</th></tr>
          ${todayRows.map(([k,v,tr])=>`<tr><td><b style="font-size:var(--sm)">${k}</b></td><td class="mono">${v}</td><td style="color:${trCol(tr)};font-weight:700">${tr==='↑'?'↑ improving':tr==='↓'?'↓ declining':'→ steady'}</td></tr>`).join('')}
        </table></div>
      </div>
    </div>
    <div class="grid cols-3 mb4">
      ${glance.map(g=>`
        <div class="card"><div class="card-h"><h3>${g.l}</h3><span class="badge badge-sky">${g.badge}</span></div>
          <div class="card-body" style="padding-top:var(--sp3)">
            <div class="kpi-value" style="font-size:26px;color:${g.dc}">${g.delta}</div>
            <div class="small muted mb2">${g.note}</div>
            ${spark(g.ser, 240, 44, g.c)}
          </div></div>`).join('')}
    </div>
    <div class="card mb4">
      <div class="card-h"><h3>Facility health</h3><span class="badge badge-green">Scorecard</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        <div class="status-grid">
          ${health.map(h=>`<div class="status-row"><b>${h.d}</b><span class="row gap2"><span class="chip ${h.c}"><span class="dot dot-${h.c}"></span>${h.s}</span><span class="mono" style="color:${trCol(h.tr)};font-weight:700">${h.tr}</span></span></div>`).join('')}
        </div>
      </div></div>
    <div class="grid cols-3 mb4">
      ${risks.map(r=>`
        <div class="card"><div class="card-h"><h3><span class="dot dot-amber"></span> ${r.tag}</h3><span class="badge badge-amber">Risk</span></div>
          <div class="card-body" style="padding-top:var(--sp3)">
            <b style="font-size:var(--md)">${r.title}</b>
            <div class="mt2">${r.rows.map(([k,v])=>defRow(k,v)).join('')}</div>
            <button class="btn btn-outline btn-block mt3" onclick="go('${r.go}')">${r.label} →</button>
          </div></div>`).join('')}
    </div>
    <div class="card mb4">
      <div class="card-h"><h3>Executive trends</h3>
        <div class="row gap1">
          ${ranges.map(([id,lab])=>`<button class="chip ${range===id?'active':''}" onclick="setExecRange('${id}')">${lab}</button>`).join('')}
        </div>
      </div>
      <div class="card-body" style="padding-top:var(--sp3)">
        <div class="grid cols-4" style="gap:var(--sp2)">
          ${trendMetrics.map(m=>`
            <div class="qa-btn" style="cursor:default"><b>${m.l}</b><small>${m.note}</small>${spark(m.ser, 150, 34, m.c)}</div>`).join('')}
        </div>
      </div></div>
    <div class="grid cols-2 mb4">
      ${insights.map(in2=>`
        <div class="card"><div class="card-h"><h3>${in2.tag}</h3><span class="badge badge-sky">Why this matters</span></div>
          <div class="card-body" style="padding-top:var(--sp3)">
            <p style="font-size:var(--md);line-height:1.5"><b>${in2.claim}</b></p>
            <div class="mt2">${in2.rows.map(([k,v])=>defRow(k,v)).join('')}</div>
            <button class="btn btn-primary btn-block mt3" onclick="go('${in2.go}')">${in2.label} →</button>
          </div></div>`).join('')}
    </div>
    <div class="card">
      <div class="card-h"><h3>Explore</h3><span class="badge badge-sky">Domain command</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        <div class="grid cols-4" style="gap:var(--sp2)">
          ${explore.map(([l,g,ic])=>`
            <button class="qa-btn" onclick="go('${g}')"><svg class="ic" viewBox="0 0 24 24"><path d="${ic}"/></svg><b>${l}</b><small>Open command</small></button>`).join('')}
        </div>
      </div></div>`;
}
function setExecRange(r){ S.execRange=r; renderScreen('exec'); }
window.setExecRange = setExecRange;

/* ---------- WORKFORCE COMMAND ---------- */
function workforceScreen(){
  const byGrp = g => WORKFORCE.filter(w=>w.roleId===g).length;
  const grpCounts=[['Executive',['admin','hospital_admin'],'#0ea5e9'],['Clinical',['consultant','registrar','medical_officer','clinical_officer','surgeon','anaesthetist','dept_head','ward_incharge'],'#0284c7'],['Nursing',['nurse','midwife'],'#7c3aed'],['Laboratory',['lab_tech','lab_scientist'],'#059669'],['Pharmacy',['pharmacist'],'#d97706'],['Support',['hr_officer','ict_officer','finance_officer','telemedicine_officer','cho','researcher','med_student'],'#64748b']].map(([l,ids,c])=>({l,v:WORKFORCE.filter(w=>ids.includes(w.roleId)).length,c}));
  const maxGrp = Math.max(...grpCounts.map(g=>g.v));
  const onDuty=WORKFORCE.filter(w=>w.status==='On duty').length;
  const offDuty=WORKFORCE.filter(w=>w.status==='Off duty').length;
  const leave=WORKFORCE.filter(w=>w.status==='Leave').length;
  const pending=WORKFORCE.filter(w=>w.status==='Pending activation').length;
  return `
    ${facBar('Workforce Command', `${WORKFORCE_SUMMARY.total} staff records · every identity carries department, role, workspace and permissions`)}
    <div class="grid cols-4 mb4">
      <div class="kpi"><div class="kpi-icon" style="background:var(--primary)">W</div><div><div class="kpi-value">${WORKFORCE_SUMMARY.total}</div><div class="kpi-label">Staff records</div><div class="kpi-trend">${WORKFORCE.length} identities loaded</div></div></div>
      <div class="kpi"><div class="kpi-icon" style="background:var(--success)">✓</div><div><div class="kpi-value">${WORKFORCE_SUMMARY.onDuty}</div><div class="kpi-label">On duty</div></div></div>
      <div class="kpi"><div class="kpi-icon" style="background:var(--warning)">◷</div><div><div class="kpi-value">${WORKFORCE_SUMMARY.offDuty+WORKFORCE_SUMMARY.leave}</div><div class="kpi-label">Off duty / leave</div></div></div>
      <div class="kpi"><div class="kpi-icon" style="background:var(--danger)">!</div><div><div class="kpi-value">${WORKFORCE_SUMMARY.unassigned}</div><div class="kpi-label">Unassigned</div></div></div>
    </div>
    <div class="grid split2 mb4">
      <div class="card"><div class="card-h"><h3>Workforce composition</h3><span class="badge badge-sky">${WORKFORCE.length}</span></div>
        <div class="card-body">
          ${grpCounts.map(g=>`<div class="row-b mb3"><b style="font-size:var(--sm);width:90px">${g.l}</b>${hbar(g.v, maxGrp, g.c, 220)}<span class="small mono">${g.v}</span></div>`).join('')}
        </div></div>
      <div class="card"><div class="card-h"><h3>Coverage alerts</h3><span class="badge badge-red">${COVERAGE_ALERTS.filter(a=>a.sev==='red').length} critical</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          ${COVERAGE_ALERTS.map(a=>`<div class="fact ${a.sev==='red'?'flag':''}"><div class="fc" style="background:${a.sev==='red'?'#fee2e2':'#fef3c7'};color:${a.sev==='red'?'#dc2626':'#d97706'}">${a.sev==='red'?'!':'▲'}</div><div><b>${a.scope}</b><p>${a.msg}</p></div></div>`).join('')}
          <button class="btn btn-outline btn-block mt3" onclick="go('provision')">Provision staff to close gaps →</button>
        </div></div>
    </div>
    <div class="card"><div class="card-h"><h3>Staff roster</h3><button class="btn btn-ghost btn-sm" onclick="go('provision')">+ Provision →</button></div>
      <div class="table-wrap"><table>
        <tr><th>ID</th><th>Identity</th><th>Department</th><th>Role</th><th>Constitutional workspace</th><th>Status</th><th>Roster</th></tr>
        ${WORKFORCE.map(w=>`<tr><td class="mono">${w.id}</td><td><b>${w.name}</b>${w.provisioned?' <span class="badge badge-sky">NEW</span>':''}</td><td>${w.dept}</td><td>${w.role}</td><td><span class="chip">${w.workspace}</span></td><td><span class="state-pill ${w.status==='On duty'?'state-active':w.status==='Pending activation'?'state-pending':'state-idle'}">${w.status}</span></td><td class="muted">${w.roster}</td></tr>`).join('')}
      </table></div></div>`;
}

/* ---------- WORKFORCE ANALYTICS — intelligence layer, not an HR roster ----------
   Workforce Analytics does not count people. It measures whether the facility has
   sufficient authorized workforce capacity to safely and efficiently meet current
   and projected service demand. Analysis stays organizational — no individual
   performance, absence reasons, or HR cases are exposed unless a role has that
   authorization. Analytics tells the administrator there is a problem; Workforce
   Command lets them act on it. */
const WF_RANGES=[['now','Now'],['today','Today'],['next24','Next 24h'],['7d','7 days'],['30d','30 days']];
const WF_SHIFTS={
  now:   {label:'18:00–22:00', cVal:89, next:'22:00–06:00', nVal:78, nFlag:'🔴 High pressure', tom:'06:00–14:00', tVal:96},
  today: {label:'06:00–14:00', cVal:96, next:'14:00–22:00', nVal:89, nFlag:'🟠 Pressure', tom:'22:00–06:00', tVal:78},
  next24:{label:'18:00–22:00', cVal:89, next:'22:00–06:00', nVal:78, nFlag:'🔴 High pressure', tom:'06:00–14:00', tVal:96},
  '7d':   {label:'This week', cVal:90, next:'Next 24h', nVal:82, nFlag:'🟠 Pressure', tom:'48h out', tVal:93},
  '30d': {label:'This month', cVal:91, next:'Next 7 days', nVal:84, nFlag:'🟠 Pressure', tom:'Next 30 days', tVal:88}
};
const WF_MATRIX=[['Emergency',92,84,79,91],['OPD',98,'—','—',96],['Theatre',103,71,82,100],['ICU',94,88,74,92],['Laboratory',76,68,72,84],['Pharmacy',94,91,89,95]];
const WF_PRESSURE=[['Laboratory','🔴','High'],['Emergency','🔴','High'],['Radiology','🟠','Moderate'],['Nursing','🟠','Moderate'],['Theatre','🟢','Stable']];
const WF_UPCOMING=[['Monday','Nursing','-8%','🟠'],['Tuesday','Covered','0%','🟢'],['Wednesday','Laboratory','-19%','🔴'],['Thursday','Emergency','-11%','🟠'],['Friday','Pharmacy','-5%','🟡'],['Saturday','Covered','0%','🟢'],['Sunday','Nursing','-6%','🟡']];
function setWfRange(r){ S.wfRange=r; renderScreen('workforceanalytics'); }
function setWfDrill(){ S.wfDrill=true; renderScreen('workforceanalytics'); }
function clearWfDrill(){ S.wfDrill=null; renderScreen('workforceanalytics'); }
window.setWfRange=setWfRange; window.setWfDrill=setWfDrill; window.clearWfDrill=clearWfDrill;

function wfDual(a,b,w=320,h=96,c1='#0284c7',c2='#d97706'){
  const all=[...a,...b], min=Math.min(...all), max=Math.max(...all), range=(max-min)||1;
  const pts=s=>s.map((v,i)=>`${(i/(s.length-1))*w},${(h-12)-((v-min)/range)*(h-24)}`).join(' ');
  return `<svg class="spark" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">
    <polyline fill="none" stroke="${c1}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" points="${pts(a)}"/>
    <polyline fill="none" stroke="${c2}" stroke-width="2.4" stroke-dasharray="4 3" stroke-linecap="round" stroke-linejoin="round" points="${pts(b)}"/>
  </svg>`;
}
function wfCoverageTable(){
  const rows=[['Nursing',92,'🟠','Pressure'],['Doctors',88,'🟠','Pressure'],['Laboratory',76,'🔴','Critical'],['Theatre',103,'🟢','Covered'],['Radiology',81,'🟠','Pressure'],['Pharmacy',94,'🟠','Attention']];
  const colorOf=p=>p>=100?'#7c3aed':p>=90?'#059669':p>=80?'#d97706':'#dc2626';
  return `<div class="table-wrap"><table>
    <tr><th>Service</th><th>Coverage</th><th>Status</th><th style="width:46%"></th></tr>
    ${rows.map(([k,p,ic,st])=>`
      <tr><td><b>${k}</b></td><td><b>${p}%</b></td><td><span>${ic} ${st}</span></td><td>${hbar(p,110,colorOf(p),260)}</td></tr>`).join('')}
  </table></div>`;
}
function workforceAnalyticsScreen(){
  if(S.wfDrill){
    return `
      ${facBar('Emergency Workforce Pressure', `Workforce Analytics → Emergency · staffing pressure drill-down`)}
      <div class="card mb4"><div class="card-h"><h3>Emergency — current coverage</h3><span class="badge badge-red">84%</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="int-health">
            ${[['Current coverage','84%'],['Required','12 nursing capacity units'],['Available','10'],['Demand vs baseline','+28%'],['Next 6 hours · projected coverage','78%']].map(([l,v])=>`<div class="int-stat"><b style="font-size:var(--lg)">${v}</b><span>${l}</span></div>`).join('')}
          </div>
          <div class="small muted mt3">Coverage = available qualified capacity ÷ required capacity for the service + shift + demand. 84% means 12 required nursing positions have 10 qualified staff available for the relevant window.</div>
        </div></div>
      <div class="card mb4"><div class="card-h"><h3>Why is Emergency under pressure?</h3><span class="badge badge-amber">Explainable</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          ${[['Emergency attendance','+28%','↑ demand'],['Nursing availability','−12%','↓ coverage'],['Expected demand (next window)','+19%','↑ forecast'],['Projected pressure','High','next 6 hours']].map(([k,v,n])=>`
            <div class="row-b mb3" style="padding:9px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm);width:230px">${k}</b><span class="small muted">${n}</span><b style="color:${v.startsWith('−')||v==='High'?'#dc2626':'#d97706'}">${v}</b></div>`).join('')}
          <div class="small muted mt3">Source signals: emergency demand · roster · attendance · current shift. This is an automatic operational insight with high confidence, not a clinical judgment.</div>
        </div></div>
      <div class="card"><div class="card-h"><h3>Recommended operational actions</h3><span class="badge badge-sky">Administrator decides</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="row gap2 wrap">
            <button class="btn btn-primary btn-sm" onclick="toast('Standby coverage review opened (demo)','ok')">Review standby coverage</button>
            <button class="btn btn-outline btn-sm" onclick="toast('Cross-service staffing review opened (demo)','ok')">Review cross-service staffing</button>
            <button class="btn btn-outline btn-sm" onclick="toast('Next shift roster review opened (demo)','ok')">Review next shift</button>
            <button class="btn btn-outline btn-sm" onclick="go('workforce')">Escalate to Workforce Command →</button>
          </div>
          <div class="small muted mt3" style="margin-top:var(--sp3)">These actions route the problem — they never expose individual staff performance. Staff-level analytics require HR authorization and purpose.</div>
        </div></div>`;
  }
  const r=S.wfRange||'now';
  const shifts=WF_SHIFTS[r];
  const demand=[86,90,92,95,97,100,104], capacity=[88,88,89,89,88,87,86];
  const colorOf=p=>p>=100?'#7c3aed':p>=90?'#059669':p>=80?'#d97706':'#dc2626';
  return `
    ${facBar('Workforce Analytics', `Staffing pressure, coverage & service demand — not an HR roster. Does the facility have enough of the right workforce, in the right services, at the right times, for the demand it is experiencing?`)}
    <div class="row-b mb4" style="flex-wrap:wrap"><span class="chip">Thu, 20 Aug 2026</span><span class="badge badge-green"><span class="dot dot-green"></span>Workforce data live</span></div>

    <div class="grid cols-4 mb4">
      <div class="kpi"><div class="kpi-icon" style="background:#059669">✓</div><div><div class="kpi-value">89%</div><div class="kpi-label">Overall coverage</div><div class="kpi-trend" style="color:#dc2626">↓ 4% vs target</div></div></div>
      <div class="kpi"><div class="kpi-icon" style="background:#d97706">◷</div><div><div class="kpi-value">15 hrs</div><div class="kpi-label">Overtime</div><div class="kpi-trend" style="color:var(--text-muted)">7-day average</div></div></div>
      <div class="kpi"><div class="kpi-icon" style="background:#dc2626">!</div><div><div class="kpi-value">5%</div><div class="kpi-label">Absenteeism</div><div class="kpi-trend" style="color:var(--text-muted)">7-day average</div></div></div>
      <div class="kpi"><div class="kpi-icon" style="background:#7c3aed">Δ</div><div><div class="kpi-value">11%</div><div class="kpi-label">Current staffing gap</div><div class="kpi-trend">Required 100% · Available 89%</div></div></div>
    </div>

    <div class="card mb4"><div class="card-h"><h3>What "coverage" means</h3><span class="badge badge-sky">Measured against configured requirement</span></div>
      <div class="card-body">
        <div class="fact"><div class="fc">E</div><div><b>Emergency: 12 nursing positions required · 10 available · 83% coverage</b><p>Coverage = available qualified capacity ÷ required capacity for the service + shift + demand. It is never a simple "percentage of employees who showed up." Departments carry minimum-safe, standard, surge and on-call requirements — coverage is calculated against the configured requirement for the relevant window.</p></div></div>
      </div></div>

    <div class="card mb4" style="border-color:var(--warning);border-width:1px">
      <div class="card-h"><h3>AMEXAN Workforce Intelligence</h3><span class="badge badge-amber"><span class="dot dot-amber"></span>Automatic operational insight</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        <div class="fact flag"><div class="fc">!</div><div><b>Emergency demand increased 28% while nursing coverage decreased 12%.</b><p><b>Confidence:</b> High · <b>Source signals:</b> Emergency demand · roster · attendance · current shift · <b>Reason:</b> Demand ↑ + coverage ↓</p><div class="row gap2 mt2">
          <span class="chip red">Current pressure: High</span><span class="chip">Affected: Emergency · Nursing · Laboratory</span><span class="chip amber">Next critical window: 22:00 theatre anaesthesia handover · projected coverage 71%</span></div>
          <button class="btn btn-primary btn-sm mt3" onclick="setWfDrill()">Review staffing pressure →</button></div></div>
      </div></div>

    <div class="grid split2 mb4">
      <div class="card"><div class="card-h"><h3>Current staffing coverage</h3><span class="badge badge-sky">Target: 100% of configured requirement</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">${wfCoverageTable()}</div></div>
      <div class="card"><div class="card-h"><h3>Shift coverage</h3><span class="badge badge-sky">${r.toUpperCase()}</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="row gap2 wrap mb3">
            ${WF_RANGES.map(([id,l])=>`<button class="chip ${r===id?'active':''}" onclick="setWfRange('${id}')">${l}</button>`).join('')}
          </div>
          ${[['Current',shifts.label,shifts.cVal],['Next',shifts.next,shifts.nVal],['Tomorrow',shifts.tom,shifts.tVal]].map(([l,win,v],i)=>`
            <div class="row-b mb3" style="padding:10px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm);width:74px">${l}</b><span class="muted" style="flex:1">${win}</span><b style="color:${colorOf(v)}">${v}%</b>${i===1?`<span class="badge badge-red" style="margin-left:8px">${shifts.nFlag}</span>`:''}</div>`).join('')}
          <div class="small muted mt3">The administrator can identify tomorrow night's problem before it happens — not after the shift is already short.</div>
        </div></div>
    </div>

    <div class="card mb4"><div class="card-h"><h3>Coverage forecast — service × shift</h3><span class="badge badge-sky">Projected</span></div>
      <div class="table-wrap"><table>
        <tr><th>Service</th><th>Now</th><th>22:00</th><th>02:00</th><th>06:00</th></tr>
        ${WF_MATRIX.map(row=>{
          const [svc,...cells]=row;
          return `<tr><td><b>${svc}</b></td>${cells.map((v,i)=>`<td>${v==='—'?'<span class="muted">—</span>':`<b style="${typeof v==='number'&&v<78?'color:#dc2626':''}">${v}%</b>`}</td>`).join('')}</tr>`;
        }).join('')}
      </table></div>
      <div class="card-body"><div class="small muted">Values below 78% are flagged — Theatre (22:00 · 71%), ICU (02:00 · 74%), Laboratory (22:00 · 68%) are the projected pressure points.</div></div></div>

    <div class="grid split2 mb4">
      <div class="card"><div class="card-h"><h3>Workforce pressure</h3><span class="badge badge-red">High</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          ${WF_PRESSURE.map(([k,ic,st])=>`<div class="row-b mb3" style="padding:9px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm);width:120px">${k}</b><span>${ic} ${st}</span>${hbar(st==='High'?92:st==='Moderate'?78:55,100,st==='High'?'#dc2626':st==='Moderate'?'#d97706':'#059669',120)}</div>`).join('')}
        </div></div>
      <div class="card"><div class="card-h"><h3>Current service load</h3><span class="badge badge-sky">Contextual ratios</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          ${[['Emergency','14 waiting','1 nurse : 7 waiting patients'],['OPD','62 active','1 clinician : 21 active encounters'],['ICU','9 occupied','1 nurse : 2.25 patients']].map(([k,v,ratio])=>`
            <div class="fact"><div class="fc">●</div><div><b>${k} — ${v}</b><p>${ratio}</p></div></div>`).join('')}
          <div class="small muted mt3">Ratios are not automatically unsafe — they are read against configured clinical/operational thresholds.</div>
        </div></div>
    </div>

    <div class="grid split2 mb4">
      <div class="card"><div class="card-h"><h3>Demand vs coverage</h3><span class="badge badge-sky">7 days</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          ${wfDual(demand,capacity,320,110,'#0284c7','#d97706')}
          <div class="row gap3 mt2"><span class="small muted"><span class="dot" style="background:#0284c7"></span>Patient demand</span><span class="small muted"><span class="dot" style="background:#d97706"></span>Staffing capacity</span></div>
          <div class="fact mt3"><div class="fc">▲</div><div><b>Demand has risen faster than workforce capacity over the past 4 days.</b><p>Demand is 104 (index) today vs 86 four days ago; capacity has drifted from 88 to 86.</p></div></div>
        </div></div>
      <div class="card"><div class="card-h"><h3>Overtime</h3><span class="badge badge-amber"><span class="dot dot-amber"></span>↑ Increasing</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="hmis-big" style="font-size:28px">15 hrs <span>7-day average · +18% vs previous period</span></div>
          ${[['Nursing','highest'],['Emergency','second'],['Laboratory','third']].map(([k,n])=>`<div class="row-b mb2 mt2" style="padding:7px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm)">${k}</b><span class="small muted">${n} affected service</span></div>`).join('')}
          <div class="small muted mt3">Persistent overtime may indicate a recurring coverage gap. Analysis stays organizational — it never names individual staff.</div>
        </div></div>
    </div>

    <div class="grid split2 mb4">
      <div class="card"><div class="card-h"><h3>Absenteeism</h3><span class="badge badge-red"><span class="dot dot-red"></span>↑ 0.8%</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="hmis-big" style="font-size:28px">5.0% <span>7-day average</span></div>
          ${[['Nursing','7.2%'],['Laboratory','6.4%'],['Doctors','3.1%']].map(([k,v])=>`<div class="row-b mb3 mt3" style="padding:9px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm)">${k}</b>${hbar(parseFloat(v),10,'#d97706',160)}<span class="small mono">${v}</span></div>`).join('')}
          <div class="small muted mt3">Aggregate only — individual absence records, protected reasons and employee health information are never shown without HR authorization and purpose.</div>
        </div></div>
      <div class="card"><div class="card-h"><h3>Upcoming workforce pressure</h3><span class="badge badge-sky">Next 7 days</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          ${WF_UPCOMING.map(([d,svc,p,ic])=>`<div class="row-b mb2" style="padding:9px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm);width:86px">${d}</b><span class="muted" style="flex:1">${svc}</span><b style="color:${p.startsWith('-')?'#dc2626':'#059669'}">${p}</b><span>${ic}</span></div>`).join('')}
          <div class="small muted mt3">Wednesday (Laboratory −19%) and Thursday (Emergency −11%) are the actionable problems — before they happen.</div>
        </div></div>
    </div>

    <div class="card mb4"><div class="card-h"><h3>AMEXAN Intelligence — what changed, why, what's next, where to act</h3><span class="badge badge-sky">Operational read</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        ${[['What changed?','Emergency attendance is 28% above baseline; nursing coverage is 12% below target; overtime is up 18%.'],['Why?','Rising demand plus a recurring coverage gap — the same services (Emergency, Laboratory, Nursing) appear in demand, overtime and absenteeism signals.'],['What is likely next?','22:00 theatre anaesthesia handover projected at 71% coverage; Laboratory and ICU dip below 78% during the night.'],['Where should the administrator act?','Emergency and Laboratory coverage first, then the night windows — via Workforce Command, not the analytics page.']].map(([k,v])=>`
          <div class="row-b mb3" style="padding:10px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm);width:180px">${k}</b><span class="small muted" style="flex:1">${v}</span></div>`).join('')}
      </div></div>

    <div class="card mb4"><div class="card-h"><h3>Workforce actions</h3><span class="badge badge-sky">Analytics → action</span></div>
      <div class="card-body">
        <div class="row gap2 wrap">
          <button class="btn btn-outline btn-sm" onclick="setWfDrill()">Review coverage</button>
          <button class="btn btn-primary btn-sm" onclick="go('workforce')">Open workforce command</button>
          <button class="btn btn-outline btn-sm" onclick="toast('Next 7 days roster review opened (demo)','ok')">Review next 7 days</button>
          <button class="btn btn-outline btn-sm" onclick="toast('Overtime review opened (demo)','ok')">Review overtime</button>
          <button class="btn btn-outline btn-sm" onclick="toast('Service gaps review opened (demo)','ok')">Review service gaps</button>
          <button class="btn btn-outline btn-sm" onclick="toast('Roster planning opened (demo)','ok')">Open roster planning</button>
        </div>
        <div class="small muted mt3">Analytics tells the administrator <b>there is a problem</b>. Workforce Command lets her <b>do something about it</b>. This page is not a scheduling editor.</div>
      </div></div>

    <div class="card"><div class="card-h"><h3>Who sees what</h3><span class="badge badge-sky">Role → purpose → minimum necessary</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        <div class="gov-grid">
          ${[['Facility Administrator','Service coverage, staffing requirements, aggregate availability, shift coverage, overtime/absenteeism aggregates, service demand, pressure, forecasts, recommendations. Can initiate review, escalation, roster review, workforce request.']].map(([k,v])=>`<div class="gov-item" style="grid-column:1/-1"><b>${k}</b><p>${v}</p></div>`).join('')}
        </div>
        <div class="vis-grid mt3">
          <div class="vis-col"><b class="vis-can">Can see</b>
            ${['Service coverage','Staffing requirements','Aggregate workforce availability','Shift coverage','Overtime aggregates','Absenteeism aggregates','Service demand','Staffing pressure','Workforce forecasts','Operational recommendations'].map(x=>`<div class="vis-row"><span class="vis-ok">✓</span>${x}</div>`).join('')}
          </div>
          <div class="vis-col"><b class="vis-cant">Restricted</b>
            ${['Individual medical / HR information','Protected absence reasons','Employee health information','Confidential HR cases'].map(x=>`<div class="vis-row"><span class="vis-no">🔒</span>${x}</div>`).join('')}
          </div>
        </div>
        <div class="gov-grid mt3">
          ${[['HR Officer','Employee records, leave, contracts, attendance, HR workflows — but not clinical patient information.'],['Department Head','Their department: staffing, shift coverage, workload, department forecast, authorized staff information — not the entire hospital workforce.'],['Individual clinician','My shifts, my workload, my schedule, my tasks — not hospital-wide analytics.']].map(([k,v])=>`<div class="gov-item"><b>${k}</b><p>${v}</p></div>`).join('')}
        </div>
      </div></div>`;
}

/* ---------- RESEARCH INTELLIGENCE ---------- */
function researchIntelScreen(){
  const seg=RESEARCH.active.map((s,i)=>[['#0284c7','#7c3aed','#059669','#d97706'][i],s]);
  const maxEnr=Math.max(...RESEARCH.active.map(s=>s.enrolled));
  return `
    ${facBar('Research Intelligence', `Clinical data is not a playground — access, datasets, approvals and de-identification are governed here`)}
    <div class="grid cols-4 mb4">
      ${[['Active studies',RESEARCH.studies,'#0284c7'],['Patients enrolled',RESEARCH.enrolled.toLocaleString(),'#059669'],['Studies requiring review',RESEARCH.review,'#d97706'],['Data requests',RESEARCH.requests,'#dc2626']].map(([l,v,c])=>`
        <div class="kpi"><div class="kpi-icon" style="background:${c}"><svg class="ic" viewBox="0 0 24 24"><path d="M9 3v18M15 3v18M3 7h18M3 17h18"/></svg></div><div><div class="kpi-value">${v}</div><div class="kpi-label">${l}</div></div></div>`).join('')}
    </div>
    <div class="grid split2 mb4">
      <div class="card"><div class="card-h"><h3>Active studies</h3><span class="badge badge-sky">${RESEARCH.active.length}</span></div>
        <div class="table-wrap"><table>
          <tr><th>Study</th><th>PI</th><th>Enrolled</th><th>Status</th><th>Needs</th></tr>
          ${RESEARCH.active.map((s,i)=>`<tr><td><b>${s.title}</b></td><td>${s.pi}</td><td><div class="row gap1">${hbar(s.enrolled,maxEnr,['#0284c7','#7c3aed','#059669','#d97706'][i],80)}<span class="small mono">${s.enrolled}</span></div></td><td><span class="badge ${s.status==='Active'?'badge-green':'badge-amber'}">${s.status}</span></td><td>${s.needs}</td></tr>`).join('')}
        </table></div></div>
      <div class="card"><div class="card-h"><h3>Enrollment mix</h3><span class="badge badge-sky">${RESEARCH.enrolled.toLocaleString()}</span></div>
        <div class="card-body" style="display:flex;gap:var(--sp5);align-items:center;flex-wrap:wrap">
          <div style="text-align:center">${multiDonut(seg.map(([c,s])=>({v:s.enrolled,color:c})),150)}</div>
          <div style="flex:1;min-width:180px">${legend(seg.map(([c,s])=>({v:s.enrolled,color:c,label:s.title.slice(0,26)})))}</div>
        </div></div>
    </div>
    <div class="card"><div class="card-h"><h3>Data requests awaiting governance</h3><span class="badge badge-amber">${RESEARCH_REQUESTS.filter(r=>r.status!=='Approved').length} pending</span></div>
      <div class="table-wrap"><table>
        <tr><th>Request</th><th>Requester</th><th>Scope</th><th>Status</th><th></th></tr>
        ${RESEARCH_REQUESTS.map(r=>`<tr><td><b>${r.title}</b></td><td>${r.requester}</td><td class="muted">${r.scope}</td><td><span class="badge ${r.status==='Approved'?'badge-green':'badge-amber'}">${r.status}</span></td><td>${r.status!=='Approved'?`<button class="btn btn-primary btn-sm" onclick="toast('Dataset approval logged to governance (demo)','ok')">Approve</button>`:''}</td></tr>`).join('')}
      </table></div></div>`;
}

/* ---------- PROVISION STAFF & ROLES ---------- */
function provisionScreen(){
  const deptOpts=DEPARTMENTS.map(d=>`<option value="${d.id}" ${d.id===FProv.dept?'selected':''}>${d.name}</option>`).join('');
  const roleOpts=WORKFORCE_ROLES.map(r=>`<option value="${r.id}" ${r.id===FProv.role?'selected':''}>${r.name} — ${r.workspace}</option>`).join('');
  const role = WORKFORCE_ROLES.find(r=>r.id===FProv.role) || WORKFORCE_ROLES[0];
  const deptRow = dept(FProv.dept);
  const preview = Array.from({length:Math.min(12,FProv.count)},(_,i)=>i+1).map(i=>{
    const sid=String(i).padStart(3,'0');
    return `<tr><td class="mono">${(FProv.seed||deptRow.code)}-${sid}</td><td>${role.name} ${sid}</td><td>${deptRow.name}</td><td>${role.name}</td><td>${role.workspace}</td><td><span class="state-pill state-pending">Pending activation</span></td></tr>`;
  }).join('');
  return `
    ${facBar('Provision Staff & Roles', `One department + one role + a count → that many real identities, each routed to its own constitutional workspace`)}
    <div class="grid split2 mb4">
      <div class="card"><div class="card-h"><h3>Provision</h3><span class="badge badge-sky">Constitutional identity engine</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="field"><label>Department</label>
            <select class="input" onchange="setProv('dept',this.value)">${deptOpts}</select></div>
          <div class="field"><label>Role</label>
            <select class="input" onchange="setProv('role',this.value)">${roleOpts}</select></div>
          <div class="grid cols-2"><div class="field"><label>How many?</label>
            <input class="input" type="number" min="1" max="40" value="${FProv.count}" onchange="setProv('count',this.value)"></div>
            <div class="field"><label>Name seed (optional)</label>
            <input class="input" type="text" placeholder="${deptRow.code}" value="${FProv.seed}" onchange="setProv('seed',this.value)"></div></div>
          <div class="row gap2 mt3"><button class="btn btn-primary" onclick="doProvision()">PROVISION ${FProv.count} identities →</button><button class="btn btn-outline" onclick="resetProvision()">Reset</button></div>
          <div class="small muted mt3">AMEXAN creates real identity records — department, role, constitutional workspace, permissions, dashboard, roster and status for each.</div>
        </div></div>
      <div class="card"><div class="card-h"><h3>Provisioning preview</h3><span class="badge badge-sky">${Math.min(12,FProv.count)} shown of ${FProv.count}</span></div>
        <div class="table-wrap"><table>
          <tr><th>Identity</th><th>Name</th><th>Department</th><th>Role</th><th>Workspace</th><th>Status</th></tr>
          ${preview}
        </table></div>
        <div class="card-body"><div class="row gap1 wrap">${['One department + one role + a count','real Auth logins','routed to constitutional workspaces','ready for activation'].map(x=>`<span class="chip">${x}</span>`).join('')}</div></div>
      </div>
    </div>
    ${FProv.done?`
      <div class="card mb4" style="border-color:var(--success)">
        <div class="card-h"><h3>PROVISIONING COMPLETE</h3><span class="badge badge-green">Ready for activation</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="grid cols-5 mb3">
            ${[['Department',deptRow.name],['Role',role.name],['Created',FProv.done.length+' identities'],['Workspaces',FProv.done.length],['Authentication',FProv.done.length+' accounts']].map(([k,v])=>`
              <div class="row-b" style="flex-direction:column;align-items:flex-start;gap:2px;padding:10px;border:1px solid var(--border);border-radius:12px"><span class="small muted">${k}</span><b>${v}</b></div>`).join('')}
          </div>
          <button class="btn btn-primary" onclick="go('workforce')">VIEW PROVISIONED STAFF →</button>
        </div></div>`:''}
    <div class="card"><div class="card-h"><h3>Role → Workspace routing (constitutional resolver)</h3><span class="badge badge-sky">${WORKFORCE_ROLES.length} roles</span></div>
      <div class="table-wrap"><table>
        <tr><th>Role</th><th>Group</th><th>Constitutional workspace</th></tr>
        ${WORKFORCE_ROLES.map(r=>`<tr><td><b>${r.name}</b></td><td>${r.grp}</td><td><span class="chip">${r.workspace}</span></td></tr>`).join('')}
      </table></div></div>`;
}

/* ---------- ORGANIZATIONS ---------- */
function organizationsScreen(){
  const f = FACILITIES.find(x=>x.id===S.facility) || FACILITIES[0];
  return `
    ${facBar('Organizations', `Organization → Facility Network → Facility → Campus → Department → Ward/Unit`)}
    <div class="grid split2">
      <div class="card mb4"><div class="card-h"><h3>Organization</h3><span class="badge badge-sky">AMEXAN instance</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="org-block"><div class="org-title" style="background:${f.color}">${f.code}</div><div><b>${f.name}</b><p class="small muted">${f.level}</p></div></div>
          <div class="org-links">
            ${FACILITIES.map(x=>`<div class="org-node"><span class="dot" style="background:${x.color}"></span><b>${x.name}</b><span class="small muted">${x.level} · ${dayFor(x.id).patients} patients</span><span class="badge badge-green">${x.status}</span></div>`).join('')}
          </div>
        </div></div>
      <div class="card mb4"><div class="card-h"><h3>Facility network</h3><span class="badge badge-sky">5 campuses</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="org-block"><div class="org-title" style="background:${f.color}">${f.code}</div><div><b>Kisii Regional Health Network</b><p class="small muted">Organization → Facility Network</p></div></div>
          ${['Main campus','Outpatient complex','Maternity unit','Community outreach sites','Satellite clinics'].map(c=>`<div class="org-node"><span class="dot" style="background:var(--primary)"></span><b>${c}</b><span class="small muted">campus</span></div>`).join('')}
        </div></div>
    </div>
    <div class="card"><div class="card-h"><h3>Partner network</h3><span class="badge badge-sky">${PARTNERS.length} active relationships</span></div>
      <div class="table-wrap"><table>
        <tr><th>Partner</th><th>Type</th><th>Relationship</th><th>Status</th><th>Agreement</th></tr>
        ${PARTNERS.map(p=>`<tr><td><b>${p.name}</b></td><td>${p.type}</td><td><span class="chip" style="border-color:${p.color}55;color:${p.color}">${p.rel}</span></td><td><span class="badge ${p.state==='ACTIVE'?'badge-green':'badge-amber'}">${p.state}</span></td><td><span class="badge badge-gray">${p.agreement.kind}</span></td></tr>`).join('')}
      </table></div></div>`;
}

/* ---------- SERVICE CATALOGUES ---------- */
function servicesScreen(){
  const grps=['Clinical','Diagnostics','Support'];
  return `
    ${facBar('Service Catalogues', `Every service carries department, location, staffing, workflow, pricing and reporting codes`)}
    ${grps.map(g=>`
      <div class="card mb4"><div class="card-h"><h3>${g}</h3><span class="badge badge-sky">${SERVICES.filter(s=>s.grp===g).length} services</span></div>
        <div class="grid cols-3" style="gap:var(--sp3);padding:var(--sp3)">
          ${SERVICES.filter(s=>s.grp===g).map(s=>`
            <div class="svc-card">
              <div class="row-b"><b style="font-size:var(--md)">${s.name}</b><span class="chip">${dept(s.dept).code}</span></div>
              <div class="small muted mt1">${s.loc} · ${s.staff} staff</div>
              <div class="tiny muted mt2"><b class="uppercase">Workflow</b> — ${s.workflow}</div>
              <div class="row gap1 mt2"><span class="chip">${s.pricing}</span><span class="chip mono">${s.codes}</span></div>
            </div>`).join('')}
        </div></div>`).join('')}`;
}

/* ---------- INFRASTRUCTURE ---------- */
function infraTree(node, depth=0){
  const c = COUNT_INFRA(node);
  const kids = (node.children||[]).map(k=>infraTree(k, depth+1)).join('');
  const bedTxt = node.beds ? `<span class="badge badge-sky">${node.beds} beds</span>` : (c.beds?`<span class="badge badge-gray">${c.beds} beds below</span>`:'');
  return `<div class="tree-node" style="--td:${depth}">
    <div class="tree-row"><span class="tree-caret">${kids?'▾':''}</span><b>${node.name}</b><span class="chip">${node.kind||'Unit'}</span>${bedTxt}</div>
    ${kids?`<div class="tree-kids">${kids}</div>`:''}
  </div>`;
}
function infrastructureScreen(){
  const total = COUNT_INFRA(INFRA);
  return `
    ${facBar('Infrastructure', `${total.beds} beds across ${total.nodes} nodes — every ward, room and bed accounted for`)}
    <div class="grid cols-3 mb4">
      ${[['Buildings & campuses',3,'#0284c7'],['Departments',13,'#059669'],['Beds',total.beds,'#7c3aed']].map(([l,v,c])=>`
        <div class="kpi"><div class="kpi-icon" style="background:${c}"><svg class="ic" viewBox="0 0 24 24"><path d="M3 21h18M5 21V5l6-3 8 5v14"/></svg></div><div><div class="kpi-value">${v}</div><div class="kpi-label">${l}</div></div></div>`).join('')}
    </div>
    <div class="card mb4"><div class="card-h"><h3>Hospital structure</h3><button class="btn btn-ghost btn-sm" onclick="go('builder')">Open Hospital Builder →</button></div>
      <div class="card-body" style="padding-top:var(--sp3)">${infraTree(INFRA)}</div></div>
    <div class="card"><div class="card-h"><h3>Asset map</h3><span class="badge badge-sky">${ASSETS.length} tracked</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        <div class="grid cols-3" style="gap:var(--sp3)">
          ${ASSETS.map(a=>`<div class="svc-card"><div class="row-b"><b>${a.name}</b><span class="badge ${a.status==='Operational'?'badge-green':'badge-amber'}">${a.status}</span></div><div class="small muted mt1">${a.id} · ${a.loc}</div></div>`).join('')}
        </div></div></div>`;
}

/* ---------- ASSET INTELLIGENCE ---------- */
function assetsScreen(){
  return `
    ${facBar('Asset Intelligence', `Not asset CRUD — what happens to care if this asset fails`)}
    <div class="grid split2">
      <div class="card"><div class="card-h"><h3>Asset register</h3><span class="badge badge-sky">${ASSETS.length}</span></div>
        <div class="table-wrap"><table>
          <tr><th>Asset</th><th>Status</th><th>Location</th><th>Last / next service</th><th>Utilization</th><th>Risk</th></tr>
          ${ASSETS.map(a=>`
            <tr><td><b>${a.name}</b><div class="tiny muted mono">${a.id}</div></td>
            <td><span class="badge ${a.status==='Operational'?'badge-green':'badge-amber'}">${a.status}</span></td>
            <td>${a.loc}</td>
            <td class="muted">${a.lastService} → ${a.nextService}</td>
            <td>${hbar(a.util,100,a.util>=85?'#dc2626':a.util>=70?'#d97706':'#059669',90)} <span class="small mono">${a.util}%</span></td>
            <td><span class="badge ${a.risk==='High'?'badge-red':a.risk==='Moderate'?'badge-amber':'badge-gray'}">${a.risk}</span></td></tr>`).join('')}
        </table></div></div>
      <div>
        <div class="card mb4"><div class="card-h"><h3>Impact — if this asset fails</h3><span class="badge badge-red">CT Scanner</span></div>
          <div class="card-body" style="padding-top:var(--sp3)">
            ${[['Scheduled investigations affected',17],['Departments affected',3],['Partner facilities available',2]].map(([k,v])=>`
              <div class="row-b" style="padding:9px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm)">${k}</b><span class="mono">${v}</span></div>`).join('')}
            <button class="btn btn-outline btn-block mt3" onclick="toast('Maintenance scheduled (demo)','ok')">Schedule preventive maintenance</button>
          </div></div>
        <div class="card"><div class="card-h"><h3>Utilization — haematology analyser</h3><span class="badge badge-red">88% · High</span></div>
          <div class="card-body" style="padding-top:var(--sp3)">${spark([71,74,80,77,84,88,88], 260, 70, '#dc2626')}
            <div class="row-b small muted mt2"><span>140 investigations/day depend on this unit</span></div></div></div>
      </div>
    </div>`;
}

/* ---------- CLINICAL OPERATIONS MONITOR ---------- */
/* ---------- CLINICAL OPERATIONS MONITOR ----------
   Operational telemetry layer, NOT the clinical chart.
   Facility Admin sees where patients are in the flow, who is working,
   bottlenecks, referrals and staffing — never HPI/diagnosis/results/
   notes. Those stay in the authorized clinical workspace.
   Operational visibility does not imply clinical access. */
const COPS_LIVE = [
  {t:'20:01:42', unit:'OPD', msg:'Patient moved — Triage → Consultation'},
  {t:'20:01:26', unit:'OPD', msg:'Dr. Brian Kamau accepted encounter'},
  {t:'20:01:38', unit:'Laboratory', msg:'Laboratory request created'},
  {t:'20:01:12', unit:'OPD', msg:'Patient moved — Registration → Triage'},
  {t:'20:00:58', unit:'Referral', msg:'Update — Orthopaedics → Kenyatta County Hospital'},
  {t:'20:00:31', unit:'Inpatient', msg:'Discharge documented — Ward 3'}
];
const COPS_PATIENTS = [
  {name:'Kevin Kamau',   unit:'OPD',        loc:'Consultation',       state:'In consultation',        team:'Dr. Jane Wambui',   wait:'18m',  started:'19:42', cur:2},
  {name:'John Otieno',   unit:'OPD',        loc:'Triage',             state:'Awaiting vitals',        team:'Nurse station',     wait:'12m',  started:'19:50', cur:1},
  {name:'Mary Achieng',  unit:'OPD',        loc:'Registration',       state:'Registration',           team:'Front desk',        wait:'8m',   started:'19:54', cur:0},
  {name:'David Omondi',  unit:'OPD',        loc:'Waiting',            state:'Awaiting consultation',  team:'OPD nursing',       wait:'31m',  started:'19:31', cur:2},
  {name:'Esther Nyambura',unit:'OPD',       loc:'Investigation',      state:'Awaiting results',       team:'Laboratory',        wait:'26m',  started:'19:36', cur:3},
  {name:'Baby A.',       unit:'Emergency',  loc:'Resuscitation',      state:'In consultation',        team:'Emergency team',    wait:'4m',   started:'19:58', cur:2},
  {name:'James Mwangi',  unit:'Referral',   loc:'Orthopaedics → KCH', state:'Awaiting acceptance',    team:'Orthopaedics',      wait:'2h 12m', started:'17:50', cur:99}
];
const COPS_STAGES = ['Registration','Triage','Consultation','Investigation','Treatment','Disposition'];

function setCopsUnit(id){ S.copsUnit=id; S.copsPatient=null; renderScreen('clinicalops'); }
function setCopsPatient(name){ S.copsPatient=name; renderScreen('clinicalops'); }
function closeCopsPatient(){ S.copsPatient=null; renderScreen('clinicalops'); }
function clearCops(){ S.copsUnit=null; S.copsPatient=null; renderScreen('clinicalops'); }
window.setCopsUnit=setCopsUnit; window.setCopsPatient=setCopsPatient; window.closeCopsPatient=closeCopsPatient; window.clearCops=clearCops;

function copsTimeline(p){
  if(p.cur===99) return [['Registration','done'],['Triage','done'],['Consultation','done'],['Referral — Orthopaedics → KCH','now']];
  return COPS_STAGES.map((s,i)=>i<p.cur?[s,'done']:i===p.cur?[s,'now']:[s,'next']);
}

function clinicalOpsScreen(){
  const day = dayFor(S.facility);
  const st = day.strip;
  const now = new Date().toLocaleTimeString('en-GB',{hour12:false});

  const units = [
    {id:'emergency',   name:'Emergency',   v:st.emergency+' waiting', s:'3 critical',        tag:'Pressure',    tagC:'#dc2626', c:'#dc2626', dept:'emergency',  wait:'12 min avg'},
    {id:'opd',         name:'OPD',         v:'62 active',             s:'3 clinicians',      tag:'Moderate',    tagC:'#d97706', c:'#0284c7', dept:'opd',        wait:'24 min avg'},
    {id:'maternity',   name:'Maternity',   v:st.maternity+' active',  s:'Labour suite ready',tag:'Stable',      tagC:'#059669', c:'#7c3aed', dept:'obgyn',      wait:'10 min avg'},
    {id:'theatre',     name:'Theatre',     v:st.theatre+' procedures',s:'Theatre 1 · 2',     tag:'Stable',      tagC:'#059669', c:'#0891b2', dept:'theatre',    wait:'next 20:30'},
    {id:'inpatient',   name:'Inpatient',   v:day.occupancy+'% occupancy', s:day.admissions+' admissions today', tag:'Pressure', tagC:'#d97706', c:'#059669', dept:'medicine', wait:'—'},
    {id:'icu',         name:'ICU',         v:'91% occupancy',         s:'2 ventilated',      tag:'Near capacity',tagC:'#dc2626', c:'#dc2626', dept:'icu',        wait:'—'},
    {id:'laboratory',  name:'Laboratory',  v:st.lab+' pending',       s:'TAT 42 min',        tag:'Delayed',     tagC:'#d97706', c:'#7c3aed', dept:'lab',        wait:'42 min TAT'},
    {id:'radiology',   name:'Radiology',   v:st.radiology+' pending', s:'CT next 14:20',     tag:'Stable',      tagC:'#059669', c:'#0ea5e9', dept:'radiology',  wait:'14:20 CT'},
    {id:'pharmacy',    name:'Pharmacy',    v:st.pharmacy+' pending',  s:'2 priority',        tag:'Stable',      tagC:'#059669', c:'#059669', dept:'pharmacy',   wait:'—'}
  ];

  if(S.copsUnit) return copsUnitCommand(units, st, now);

  const amb = QUEUE_FLOW.filter(q=>['Registration','Waiting','Triage','Consultation','Investigation','Treatment','Discharge'].includes(q.stage));
  const admitted = (QUEUE_FLOW.find(q=>q.stage==='Admitted')||{count:0}).count;
  const referred = (QUEUE_FLOW.find(q=>q.stage==='Referred')||{count:0}).count;
  const flowCount = amb.reduce((a,q)=>a+q.count,0) + admitted + referred;
  const patPanel = S.copsPatient ? copsPatientPanel(COPS_PATIENTS.find(p=>p.name===S.copsPatient)) : '';

  return `
    ${facBar('Clinical Operations Monitor', `The living facility — every unit reporting right now`)}
    <div class="live-strip">
      <span class="live-dot"></span>
      <b>Live facility telemetry</b>
      <span class="chip">Last updated ${now}</span>
      <span class="small muted">Operational layer only — clinical records stay with the authorized care team.</span>
    </div>

    <h3 class="cops-title">CURRENT FACILITY</h3>
    <div class="grid cols-3 mb4">
      ${units.map(u=>`
        <button class="mon-cell" onclick="setCopsUnit('${u.id}')">
          <span class="mon-ic" style="background:${u.c}"></span>
          <div><b>${u.name}</b><div class="mon-v">${u.v}</div><div class="small muted">${u.s}</div></div>
          <span class="mon-tag" style="background:${u.tagC}15;color:${u.tagC};border:1px solid ${u.tagC}33">${u.tag}</span>
        </button>`).join('')}
    </div>

    ${patPanel}

    <div class="card mb4">
      <div class="card-h"><h3>FACILITY FLOW — active encounters</h3><span class="badge badge-sky">${flowCount} active</span></div>
      <div class="card-body">
        <div class="flow-stages" style="grid-template-columns:repeat(7,1fr)">
          ${amb.map(q=>`<div class="stage"><span class="stage-bar" style="height:${Math.round(q.count/Math.max(...amb.map(x=>x.count))*100)}%"></span><b>${q.count}</b><span>${q.stage}</span><small>${q.note}</small></div>`).join('')}
        </div>
        <div class="row gap2 mt3 wrap">
          <span class="badge badge-amber">${admitted} admitted → wards</span>
          <span class="badge badge-sky">${referred} referred → outbound</span>
          <span class="small muted">Terminal states — counted once, not in the ambulatory pipeline.</span>
        </div>
      </div>
    </div>

    <div class="grid split2 mb4">
      <div class="card">
        <div class="card-h"><h3>LIVE OPERATIONS</h3><span class="badge badge-green"><span class="dot dot-green"></span>Reporting</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          ${[['OPD','3 clinicians active','18 waiting · 24 min average wait'],['Emergency','14 waiting · 3 critical','4 clinicians active · 12 min average'],['Laboratory','38 pending','42 min TAT · +22% today']].map(i=>`
            <div class="fact"><div class="fc">●</div><div><b>${i[0]}</b><p>${i[1]} — ${i[2]}</p></div></div>`).join('')}
        </div>
      </div>
      <div class="card">
        <div class="card-h"><h3>Live facility feed</h3><span class="badge badge-sky">Operational events</span></div>
        <div class="card-body" style="padding-top:var(--sp2)">
          ${COPS_LIVE.map(e=>`
            <div class="feed-item"><span class="mono small muted">${e.t}</span><b>${e.unit}</b><p>${e.msg}</p></div>`).join('')}
        </div>
      </div>
    </div>

    <div class="card mb4">
      <div class="card-h"><h3>OPERATIONAL PATIENT FLOW</h3><span class="badge badge-sky">${COPS_PATIENTS.length} in flow</span></div>
      <div class="table-wrap"><table>
        <tr><th>Patient</th><th>Location</th><th>State</th><th>Responsible team</th><th>Wait</th><th></th></tr>
        ${COPS_PATIENTS.map(p=>`
          <tr class="click-row" onclick="setCopsPatient('${p.name}')">
            <td><b>${p.name}</b></td>
            <td>${p.unit} · ${p.loc}</td>
            <td><span class="state-pill state-active">${p.state}</span></td>
            <td>${p.team}</td>
            <td class="mono">${p.wait}</td>
            <td class="muted">›</td>
          </tr>`).join('')}
      </table></div>
      <div class="card-body small muted" style="border-top:1px solid var(--neutral-100)">Operational rows only — location, queue state, responsible team. Clinical history, HPI, diagnosis, results and notes are not exposed at facility level.</div>
    </div>

    <div class="grid split2 mb4">
      <div class="card">
        <div class="card-h"><h3>Referral status</h3><span class="badge badge-sky">${referred} outbound</span></div>
        <div class="card-body">
          <div class="fact flag"><div class="fc">↗</div><div><b>Orthopaedics → Kenyatta County Hospital</b><p>Awaiting acceptance · created 19:41 · state pending</p></div></div>
          <button class="btn btn-primary btn-sm mt3" onclick="toast('Referral coordination opened (demo)','ok')">Coordinate referral →</button>
        </div>
      </div>
      <div class="card">
        <div class="card-h"><h3>Who is working — staff presence</h3><span class="badge badge-sky">${WORKFORCE.filter(w=>w.status==='On duty').length} on duty</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          ${['opd','emergency','theatre','laboratory','icu','pharmacy'].map(d=>{
            const wf = WORKFORCE.filter(w=>w.deptId===d && w.status==='On duty');
            const u = units.find(x=>x.dept===d);
            return `<div class="row-b mb3" style="padding:8px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm);width:130px">${u?u.name:d}</b><span class="small muted">${wf.length} on duty · roster ${wf[0]?wf[0].roster:'—'}</span></div>`;
          }).join('')}
        </div>
      </div>
    </div>

    <div class="card">
      <div class="card-h"><h3>Operational visibility ≠ clinical access</h3><span class="badge badge-sky">Constitutional boundary</span></div>
      <div class="card-body">
        <div class="vis-grid">
          <div class="vis-col vis-can">
            <h3>FACILITY ADMIN CAN SEE</h3>
            ${['Patient operational location','Queue state','Responsible clinical team','Assigned clinician','Operational timeline','Referral status','Staff presence'].map(x=>`<div class="vis-row"><span class="vis-ok">✓</span>${x}</div>`).join('')}
          </div>
          <div class="vis-col vis-cant">
            <h3>CANNOT ROUTINELY SEE</h3>
            ${['Clinical history','HPI','Clinical notes','Diagnosis','Lab results','Medication orders','Clinical reasoning'].map(x=>`<div class="vis-row"><span class="vis-no">🔒</span>${x}</div>`).join('')}
            <div class="small muted mt3">Authorized clinical workspace required.</div>
          </div>
        </div>
      </div>
    </div>`;
}

function copsPatientPanel(p){
  if(!p) return '';
  const tl = copsTimeline(p);
  return `
    <div class="card mb4" style="border-color:var(--primary-border)">
      <div class="card-h"><h3>Operational patient view</h3><button class="btn btn-outline btn-sm" onclick="closeCopsPatient()">Close ✕</button></div>
      <div class="card-body">
        <div class="row-b wrap" style="padding-bottom:var(--sp3)">
          <div><h2 style="font-size:var(--xl)">${p.name}</h2>
            <div class="small muted">${p.unit} · ${p.loc} — Encounter <b>active</b></div></div>
          <span class="badge badge-green"><span class="dot dot-green"></span>In facility flow</span>
        </div>
        <div class="grid split2">
          <div>
            ${[['Assigned clinician', p.team], ['Encounter status', 'Active'], ['Started', p.started], ['Elapsed', p.wait], ['Queue state', p.state]].map(([k,v])=>`
              <div class="row-b mb3" style="padding:8px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm)">${k}</b><span>${v}</span></div>`).join('')}
            <div class="small muted mt3">Operational timeline</div>
            <div class="tl mt2">
              ${tl.map(([s,st])=>`<span class="tl-step ${st==='done'?'tl-done':st==='now'?'tl-now':'tl-next'}">${st==='done'?'✓':st==='now'?'●':'—'} ${s}</span>`).join('')}
            </div>
          </div>
          <div class="lock">
            <div class="lock-ic">🔒</div>
            <div>
              <b style="font-size:var(--sm)">Clinical record restricted</b>
              <p class="small mt1">Clinical history, HPI, notes, results and medications are available only to authorized clinical users. Operational visibility does not imply clinical access.</p>
              <button class="btn btn-outline btn-sm mt3" onclick="toast('Switch demo account to a clinical role (e.g. Dr. Brian Kamau) to open the clinical workspace','ok')">Switch to authorized clinical workspace</button>
            </div>
          </div>
        </div>
      </div>
    </div>`;
}

function copsUnitCommand(units, st, now){
  const u = units.find(x=>x.id===S.copsUnit);
  const staff = WORKFORCE.filter(w=>w.deptId===u.dept && w.status==='On duty');
  const pats = COPS_PATIENTS.filter(p=>p.unit===u.name);
  const evs = COPS_LIVE.filter(e=>e.unit===u.name);
  return `
    ${facBar(`${u.name} — operational command`, `${u.v} · ${u.wait}`)}
    <button class="btn btn-outline btn-sm mb4" onclick="clearCops()">← All units</button>
    <div class="grid cols-4 mb4">
      ${[[u.v,'Now'],[u.wait,'Wait'],[staff.length+' on duty','Staff'],[pats.length+' in flow','Active']].map(([v,l])=>`
        <div class="kpi"><div class="kpi-icon" style="background:${u.c}"><span style="font-weight:800;font-size:16px">${u.name[0]}</span></div><div><div class="kpi-value">${v}</div><div class="kpi-label">${l}</div></div></div>`).join('')}
    </div>
    <div class="grid split2 mb4">
      <div class="card"><div class="card-h"><h3>Current staff</h3><span class="badge badge-sky">${staff.length} on duty</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          ${staff.length?staff.map(s=>`
            <div class="row-b mb3" style="padding:8px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm)">${s.name}</b><span class="badge badge-green"><span class="dot dot-green"></span>${s.role}</span></div>`).join(''):'<div class="small muted">No staff currently on duty.</div>'}
        </div></div>
      <div class="card"><div class="card-h"><h3>Patient flow</h3><span class="badge badge-sky">${pats.length} active</span></div>
        <div class="table-wrap"><table>
          <tr><th>Patient</th><th>State</th><th>Team</th><th>Wait</th></tr>
          ${pats.map(p=>`<tr class="click-row" onclick="setCopsPatient('${p.name}')"><td><b>${p.name}</b></td><td><span class="state-pill state-active">${p.state}</span></td><td>${p.team}</td><td class="mono">${p.wait}</td></tr>`).join('')}
        </table></div></div>
    </div>
    <div class="card"><div class="card-h"><h3>Operational events</h3><span class="badge badge-sky">Live</span></div>
      <div class="card-body" style="padding-top:var(--sp2)">
        ${evs.length?evs.map(e=>`<div class="feed-item"><span class="mono small muted">${e.t}</span><b>${e.unit}</b><p>${e.msg}</p></div>`).join(''):'<div class="small muted">No live events for this unit right now.</div>'}
      </div></div>`;
}

/* ---------- QUALITY · SAFETY & GOVERNANCE ---------- */
function qualityScreen(){
  return `
    ${facBar('Quality · Safety & Governance', `${INCIDENTS.filter(i=>i.sev==='red').length} open critical incidents · every action traceable (WHO · WHAT · WHEN · WHERE · WHY · SOURCE · OUTCOME)`)}
    <div class="grid split2 mb4">
      <div class="card"><div class="card-h"><h3>Safety Center — open incidents</h3><span class="badge badge-red">${INCIDENTS.filter(i=>i.status!=='Resolved').length} open</span></div>
        <div class="table-wrap"><table>
          <tr><th>ID</th><th>Type</th><th>Severity</th><th>Dept</th><th>Status</th></tr>
          ${INCIDENTS.map(i=>`<tr><td class="mono">${i.id}</td><td><b>${i.type}</b></td><td><span class="badge ${i.sev==='red'?'badge-red':i.sev==='amber'?'badge-amber':'badge-gray'}">${i.sev}</span></td><td>${i.dept}</td><td><span class="state-pill ${i.status==='Resolved'?'state-active':i.status==='Under review'?'state-pending':'state-idle'}">${i.status}</span></td></tr>`).join('')}
        </table></div></div>
      <div class="card"><div class="card-h"><h3>Governance</h3><span class="badge badge-sky">${GOVERNANCE.length} items</span></div>
        <div class="table-wrap"><table>
          <tr><th>Item</th><th>Status</th><th>Owner</th><th>Due</th></tr>
          ${GOVERNANCE.map(g=>`<tr><td><b>${g.item}</b></td><td><span class="badge ${g.status==='Completed'?'badge-green':g.status==='In progress'?'badge-amber':'badge-gray'}">${g.status}</span></td><td>${g.owner}</td><td class="mono">${g.due}</td></tr>`).join('')}
        </table></div></div>
    </div>
    <div class="card"><div class="card-h"><h3>Traceability contract</h3><span class="badge badge-sky">WHO · WHAT · WHEN · WHERE · WHY · SOURCE · OUTCOME</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        ${INCIDENTS.slice(0,3).map(i=>`<div class="fact"><div class="fc">!</div><div><b>${i.type} — ${i.id}</b><p>${i.dept} · reported ${i.time} · <span class="tiny muted">source: ${i.id} · outcome: ${i.status}</span></p></div></div>`).join('')}
      </div></div>
    <div class="grid cols-2">
      <div class="card"><div class="card-h"><h3>Incident severity mix</h3><span class="badge badge-sky">${INCIDENTS.length} total</span></div>
        <div class="card-body" style="display:flex;gap:var(--sp5);align-items:center;flex-wrap:wrap">
          <div style="text-align:center">${multiDonut([{v:INCIDENTS.filter(i=>i.sev==='red').length,color:'#dc2626'},{v:INCIDENTS.filter(i=>i.sev==='amber').length,color:'#d97706'},{v:INCIDENTS.filter(i=>i.sev==='green').length,color:'#059669'}],140)}</div>
          <div style="flex:1;min-width:160px">${legend([{v:INCIDENTS.filter(i=>i.sev==='red').length,color:'#dc2626',label:'Critical'},{v:INCIDENTS.filter(i=>i.sev==='amber').length,color:'#d97706',label:'Moderate'},{v:INCIDENTS.filter(i=>i.sev==='green').length,color:'#059669',label:'Resolved'}] )}</div>
        </div></div>
      <div class="card"><div class="card-h"><h3>Governance workload</h3><span class="badge badge-sky">${GOVERNANCE.length} actions</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          ${[['In approval',GOVERNANCE.filter(g=>g.status==='In approval'||g.status==='Pending').length,'#d97706'],['Scheduled audits',GOVERNANCE.filter(g=>g.status==='Scheduled').length,'#0284c7'],['In progress',GOVERNANCE.filter(g=>g.status==='In progress').length,'#7c3aed'],['Completed',GOVERNANCE.filter(g=>g.status==='Completed').length,'#059669']].map(([k,v,c])=>`
            <div class="row-b" style="padding:9px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm)">${k}</b><span class="badge" style="background:${c}15;color:${c}">${v}</span></div>`).join('')}
        </div></div>
    </div>`;
}

/* ---------- FINANCIAL ---------- */
function financialScreen(){
  const maxSvc = Math.max(...FINANCE.services.map(s=>s[1]));
  const shaSeg=[{v:74,color:'#059669',label:'Accepted'},{v:9,color:'#d97706',label:'Pending'},{v:3,color:'#dc2626',label:'Rejected'}];
  return `
    ${facBar('Financial', `The operating picture — clinical activity meeting money`)}
    <div class="grid cols-4 mb4">
      ${[['Revenue today',FINANCE.todayRevenue,'#0284c7'],['SHA claims',FINANCE.claims,'#059669'],['Pending claims',FINANCE.pendingClaims,'#d97706'],['Outstanding balances',FINANCE.outstanding,'#dc2626']].map(([l,v,c])=>`
        <div class="kpi"><div class="kpi-icon" style="background:${c}"><svg class="ic" viewBox="0 0 24 24"><path d="M5 3h14v18l-2-1-2 1-2-1-2 1-2-1-2 1Z"/></svg></div><div><div class="kpi-value">${v}</div><div class="kpi-label">${l}</div></div></div>`).join('')}
    </div>
    <div class="grid split2">
      <div class="card mb4"><div class="card-h"><h3>Service revenue — today</h3><span class="badge badge-sky">7 services</span></div>
        <div class="card-body">
          ${FINANCE.services.map(([k,v])=>`<div class="row-b mb3"><b style="font-size:var(--sm);width:110px">${k}</b>${hbar(v,maxSvc,k==='Pharmacy'?'#059669':'#0284c7',180)}<span class="small mono">${v}</span></div>`).join('')}
        </div></div>
      <div class="card mb4"><div class="card-h"><h3>SHA / payer — claim cycle</h3><span class="badge badge-sky">86 submitted</span></div>
        <div class="card-body" style="display:flex;gap:var(--sp5);align-items:center;flex-wrap:wrap">
          <div style="text-align:center">${multiDonut(shaSeg,140)}</div>
          <div style="flex:1;min-width:180px">${legend(shaSeg)}
            <div class="row-b small muted mt3"><span>86 claims this cycle</span><span>74 accepted</span></div></div>
        </div></div>
    </div>
    <div class="card mb4"><div class="card-h"><h3>Revenue mix — today</h3><span class="badge badge-sky">KES 4.8M</span></div>
      <div class="card-body" style="display:flex;gap:var(--sp5);align-items:center;flex-wrap:wrap">
        <div style="text-align:center">${multiDonut(FINANCE.services.map((s,i)=>[['#0284c7','#059669','#0891b2','#7c3aed','#d97706','#0ea5e9','#dc2626'][i],{v:s[1]}] ).map(([c,o])=>({v:o.v,color:c})),150)}</div>
        <div style="flex:1;min-width:200px">${legend(FINANCE.services.map((s,i)=>[['#0284c7','#059669','#0891b2','#7c3aed','#d97706','#0ea5e9','#dc2626'][i],s]).map(([c,s])=>({v:s[1],color:c,label:s[0]})))}</div>
      </div></div>`;
}

/* ---------- HMIS CONNECTION ---------- */
/* ---------- HMIS CONNECTION — NATIONAL REPORTING & INTEROPERABILITY ----------
   AMEXAN maintains the facility's operational record and produces validated,
   interoperable representations for authorized national reporting. It is not
   a second isolated reporting database. The admin routes corrections to the
   responsible clinical service — never edits clinical facts to make reporting
   pass. Facility data readiness ≠ clinical data editing. */
const HMIS_STATE = {period:'today', submit:null};
window.HMIS_STATE = HMIS_STATE;
function hmisPeriod(p){ HMIS_STATE.period=p; renderScreen('hmis'); }
function hmisSubmit(){
  HMIS_STATE.submit='submitted';
  toast('DEMO dataset submitted — awaiting acknowledgement','ok');
  renderScreen('hmis');
}
function hmisAckNext(){
  const seq=['submitted','received','validating','accepted'];
  const cur=seq.indexOf(HMIS_STATE.submit);
  HMIS_STATE.submit = cur>=0 && cur<seq.length-1 ? seq[cur+1] : 'accepted';
  renderScreen('hmis');
}
window.hmisPeriod=hmisPeriod; window.hmisSubmit=hmisSubmit; window.hmisAckNext=hmisAckNext;

function hmisScreen(){
  const period = HMIS_STATE.period;
  const submit = HMIS_STATE.submit;
  const periodLabel = period==='today'?'20 Aug 2026 — Today':period==='yesterday'?'19 Aug 2026 — Yesterday':period==='month'?'August 2026 — Current month':'Custom period';
  const completeness = period==='month' ? 94.7 : 96.4;
  const pipelineSteps = [
    ['Clinical event','1,842 events'],
    ['Structured AMEXAN record','1,842 structured'],
    ['Validation','1,824 validated'],
    ['Interoperability mapping','1,802 mapped'],
    ['National reporting dataset','1,802 submission-ready'],
    ['Submission','DEMO SUBMISSION'],
    ['Acknowledgement','Acknowledgement pending']
  ];
  const exceptions = [
    {sev:'attention', icon:'🟠', scope:'2 maternity records', issue:'Missing outcome', owner:'Maternity', btn:'Assign to department →'},
    {sev:'attention', icon:'🟠', scope:'1 discharge record', issue:'Incomplete disposition', owner:'Inpatient Services', btn:'Review →'},
    {sev:'attention', icon:'🟠', scope:'4 laboratory records', issue:'Missing service classification', owner:'Laboratory', btn:'Review →'},
    {sev:'attention', icon:'🟠', scope:'7 encounters', issue:'Inconsistent demographic field', owner:'Front desk', btn:'Assign to department →'}
  ];
  const ackSteps = ['SUBMITTED','RECEIVED','VALIDATING','ACCEPTED'];
  const ackIdx = submit? ackSteps.indexOf(submit.toUpperCase()) : -1;
  return `
    ${facBar('HMIS Connection', `National Reporting & Interoperability — AMEXAN maintains the facility's operational record and produces validated, interoperable representations for authorized national reporting and exchange. It is not a second isolated reporting database.`)}
    <div class="demo-env">
      <b>DEMO ENVIRONMENT</b>
      <span>Reporting shown here is simulated. No production national-system dataset is being transmitted from this demo.</span>
    </div>

    <div class="grid split2 mb4">
      <div class="card">
        <div class="card-h"><h3>National reporting status</h3><span class="badge badge-green"><span class="dot dot-green"></span>Operational</span></div>
        <div class="card-body">
          <div class="hmis-ready">
            <div style="text-align:center">${miniDonut(98,'#0284c7',132,'ready')}</div>
            <div class="grow" style="min-width:200px">
              <div class="hmis-big">97.8% <span>READY</span></div>
              <div class="small muted mb3">${periodLabel}</div>
              ${[['Records processed','1,842'],['Ready','1,802'],['Require attention','40'],['Submission state','DEMO READY']].map(([k,v])=>`
                <div class="row-b mb2"><b style="font-size:var(--sm)">${k}</b><span>${v}</span></div>`).join('')}
            </div>
          </div>
          <div class="row gap2 mt3 wrap" style="border-top:1px dashed var(--neutral-200);padding-top:var(--sp3)">
            ${[['Data completeness', completeness+'%'],['Validation pass rate','98.1%'],['Submission readiness','97.8%']].map(([k,v])=>`
              <div class="kpi-mini"><b>${v}</b><span>${k}</span></div>`).join('')}
          </div>
        </div>
      </div>
      <div class="card">
        <div class="card-h"><h3>Reporting period</h3><span class="badge badge-sky">${periodLabel}</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="row gap2 wrap mb3">
            ${[['today','Today'],['yesterday','Yesterday'],['month','Current month'],['custom','Custom period']].map(([id,l])=>`
              <button class="chip ${period===id?'active':''}" onclick="hmisPeriod('${id}')">${l}</button>`).join('')}
          </div>
          ${period==='month'
            ? `<div class="fact mt3"><div class="fc">M</div><div><b>August 2026</b><p>Reporting completeness 94.7% · ${completeness}% across month-to-date records</p></div></div>`
            : `<div class="fact mt3"><div class="fc">✓</div><div><b>Today's reporting period is open</b><p>20 Aug 2026 · daily facility dataset · closes 23:59</p></div></div>`}
          <div class="small muted mt3">One facility reporting period — this is the window the readiness percentages refer to.</div>
        </div>
      </div>
    </div>

    <div class="card mb4">
      <div class="card-h"><h3>Interoperability pipeline</h3><span class="badge badge-sky">Live processing</span></div>
      <div class="card-body">
        <div class="pipe mb3">
          ${HMIS_PIPELINE.map((s,i)=>`
            <div class="pipe-step"><span class="pipe-n">${i+1}</span><b>${s}</b></div>
            ${i<HMIS_PIPELINE.length-1?'<div class="pipe-arrow">→</div>':''}`).join('')}
        </div>
        <div class="hmis-pipe">
          ${pipelineSteps.map(([s,count],i)=>`
            <div class="pipe-step" style="${i===5?'border-color:#059669;background:#ecfdf5':''}"><b>${s}</b><span class="small mono muted">${count}</span></div>
            ${i<pipelineSteps.length-1?'<div class="pipe-arrow">↓</div>':''}`).join('')}
        </div>
        <div class="row-b small muted mt3" style="border-top:1px dashed var(--neutral-200);padding-top:var(--sp2)">
          <span>Every relevant operational event is captured in the AMEXAN canonical model. Applicable reporting data is validated, mapped and transformed into the required national representation.</span>
        </div>
      </div></div>

    <div class="grid split2 mb4">
      <div class="card">
        <div class="card-h"><h3>Facility Reporting Readiness</h3><span class="badge badge-green">97.8% ready</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="small muted mb3">1,842 reporting-relevant records evaluated</div>
          ${[['Ready', 1802, '97.8%', '#059669'],['Needs attention', 40, '2.2%', '#d97706'],['Blocking', 0, '0%', '#dc2626']].map(([k,v,p,c])=>`
            <div class="row-b mb3" style="padding:9px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm)">${k}</b>${hbar(v,1842,c,180)}<span class="small mono" style="color:${c}">${p}</span></div>`).join('')}
          <div class="small muted mt3">${HMIS_STATE.submit==='accepted'?'A prior demo dataset was accepted today.':'Readiness is evaluate-now: warnings do not block, blocking errors do.'}</div>
        </div></div>
      <div class="card">
        <div class="card-h"><h3>Reporting exceptions</h3><span class="badge badge-amber">40 records</span></div>
        <div class="card-body" style="padding-top:var(--sp2)">
          ${exceptions.map(e=>`
            <div class="fact ${e.sev==='blocking'?'flag':''}"><div class="fc">${e.icon}</div><div><b>${e.scope}</b><p>${e.issue} · owner: ${e.owner}</p><button class="btn btn-outline btn-sm mt2" onclick="toast('${e.btn.replace(' →','')} — routed to ${e.owner} (demo)','ok')">${e.btn}</button></div></div>`).join('')}
        </div></div>
    </div>

    <div class="card mb4">
      <div class="card-h"><h3>Who corrects the data</h3><span class="badge badge-sky">Clinical accountability</span></div>
      <div class="card-body">
        <div class="fact flag"><div class="fc">i</div><div><b>Clinical correction required</b><p>Missing outcome — maternity record. Required owner: Maternity clinical team. The Facility Administrator routes the problem to the responsible service and requests correction — AMEXAN does not let reporting edits overwrite clinical facts.</p><div class="row gap2 mt2"><button class="btn btn-primary btn-sm" onclick="toast('Request correction sent to Maternity clinical team (demo)','ok')">Request correction</button><button class="btn btn-outline btn-sm" onclick="toast('Authorized workflow opened for Maternity clinical team (demo)','ok')">Open authorized workflow →</button></div></div></div>
      </div></div>

    <div class="grid split2 mb4">
      <div class="card">
        <div class="card-h"><h3>Data quality</h3><span class="badge badge-green"><span class="dot dot-green"></span>↑ Improving · +2.1% vs yesterday</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          ${[['Completeness', 96.4, 'Missing required fields'],['Consistency', 98.1, 'Internal data agrees across AMEXAN domains'],['Validity', 97.9, 'Values conform to configured validation rules'],['Mapping coverage', 98.7, 'AMEXAN concepts mapped to reporting representation']].map(([k,v,n])=>`
            <div class="row-b mb3" style="padding:8px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm);width:150px">${k}</b>${hbar(v,100,v>=98?'#059669':v>=96?'#d97706':'#dc2626',150)}<div><span class="small mono">${v}%</span><div class="tiny muted">${n}</div></div></div>`).join('')}
        </div></div>
      <div class="card">
        <div class="card-h"><h3>Validation exceptions</h3><span class="badge badge-amber">17 records</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          ${[['Incomplete diagnosis coding',7],['Missing outcome',3],['Inconsistent demographic field',4],['Missing service classification',3]].map(([k,v])=>`
            <div class="row-b mb3"><b style="font-size:var(--sm);width:240px">${k}</b>${hbar(v,20,'#d97706',160)}<span class="small mono">${v}</span></div>`).join('')}
        </div></div>
    </div>

    <div class="grid split2 mb4">
      <div class="card">
        <div class="card-h"><h3>Interoperability mapping</h3><span class="badge badge-sky">98.7% mapped</span></div>
        <div class="card-body">
          <div class="row gap3 wrap" style="align-items:center">
            <div style="text-align:center">${miniDonut(99,'#7c3aed',116,'mapped')}</div>
            <div class="grow">
              <div class="hmis-big" style="font-size:20px">1,802 <span>/ 1,826 mapped</span></div>
              <div class="small muted">24 concepts require review</div>
            </div>
          </div>
          <div class="small muted mt3">Unmapped concepts</div>
          ${['local service classification','facility-specific service code','local terminology','unsupported legacy field'].map(x=>`
            <div class="row-b mb2" style="padding:7px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm)">${x}</b><button class="btn btn-outline btn-sm" onclick="toast('Mapping review opened (demo)','ok')">Review →</button></div>`).join('')}
        </div></div>
      <div class="card">
        <div class="card-h"><h3>Show the transformation — Encounter</h3><span class="badge badge-sky">AMEXAN → Reporting</span></div>
        <div class="card-body">
          <div class="hmis-xform">
            <div><b class="hmis-xh">AMEXAN operational record</b>${['Encounter','Facility','Department','Service','Date/time','Encounter type','Diagnosis','Procedure','Outcome'].map(x=>`<div class="chip">${x}</div>`).join('')}</div>
            <div class="pipe-arrow" style="align-self:center">↓</div>
            <div><b class="hmis-xh">Reporting representation</b>${['Reporting period','Facility identifier','Service category','Encounter category','Diagnosis classification','Outcome','Required aggregate fields'].map(x=>`<div class="chip">${x}</div>`).join('')}</div>
            <div class="pipe-arrow" style="align-self:center">↓</div>
            <div><b class="hmis-xh">National dataset</b><div class="chip" style="background:#ecfdf5;color:#059669">Validated reporting representation</div></div>
          </div>
        </div></div>
    </div>

    <div class="grid split2 mb4">
      <div class="card">
        <div class="card-h"><h3>Data lineage</h3><span class="badge badge-sky">Every reported value traceable</span></div>
        <div class="card-body">
          <div class="pipe mb3">${['Source','AMEXAN record','Validation','Mapping','Reporting dataset','Submission','Acknowledgement'].map((s,i)=>`<div class="pipe-step"><span class="pipe-n">${i+1}</span><b>${s}</b></div>${i<6?'<div class="pipe-arrow">→</div>':''}`).join('')}</div>
          <div class="fact"><div class="fc">M</div><div><b>Maternity deliveries: 18</b><p><a href="#" onclick="event.preventDefault();this.closest('.fact').querySelector('.lin').style.display='block'">View lineage →</a></p><div class="lin" style="display:none;margin-top:8px">${[['18 clinical/service events','0'],['18 structured AMEXAN records','0'],['18 validated','0'],['18 mapped','0'],['18 included in reporting dataset','0']].map(([s],i)=>`<div class="row-b mb2" style="padding:6px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm)">${s}</b>${i<4?'<span class="pipe-arrow">↓</span>':'<span class="badge badge-green">included</span>'}</div>`).join('')}</div></div></div>
        </div></div>
      <div class="card">
        <div class="card-h"><h3>Current submission</h3><span class="badge ${submit==='accepted'?'badge-green':submit?'badge-sky':'badge-gray'}">${submit?submit.toUpperCase():'DEMO READY'}</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="hmis-big" style="font-size:18px">August 20 daily dataset</div>
          ${[['Prepared','20:12'],['Validated','20:13'],['Mapped','20:13'],['Submitted', submit?'20:14 — YES':'Not yet'],['Acknowledgement', submit?submit.toUpperCase():'—']].map(([k,v])=>`
            <div class="row-b mb3" style="padding:8px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm)">${k}</b><span>${v}</span></div>`).join('')}
          <div class="row gap2 mt3 wrap">
            <button class="btn btn-outline btn-sm" onclick="toast('Re-validated — 1,824/1,842 passed (demo)','ok')">Validate again</button>
            <button class="btn btn-outline btn-sm" onclick="toast('Dataset preview opened — 1,802 records (demo)','ok')">Preview dataset</button>
            <button class="btn btn-primary btn-sm" ${submit?'disabled':''} onclick="hmisSubmit()">SUBMIT DEMO DATASET</button>
            <button class="btn btn-outline btn-sm" onclick="toast('Submission history shown below','ok')">View submission history</button>
          </div>
          <div class="small muted mt3">Demo submission only — never 'Submit to DHA' without a real production connection.</div>
        </div></div>
    </div>

    <div class="card mb4">
      <div class="card-h"><h3>Acknowledgement lifecycle</h3><span class="badge badge-sky">${submit? ackSteps[ackIdx] : 'Awaiting submission'}</span></div>
      <div class="card-body">
        <div class="pipe mb3">
          ${ackSteps.map((s,i)=>`
            <div class="pipe-step ${submit && i<=ackIdx ? 'style="border-color:#059669;background:#ecfdf5"':''}"><b>${s}</b></div>
            ${i<ackSteps.length-1?'<div class="pipe-arrow">↓</div>':''}`).join('')}
        </div>
        ${submit===null
          ? `<div class="small muted">Submit the demo dataset to advance the acknowledgement lifecycle.</div>`
          : submit==='accepted'
          ? `<div class="fact"><div class="fc">✓</div><div><b>ACCEPTED</b><p>Submission AMX-2026-0820 · timestamp 20:14 · dataset August 20 daily · 1,802 records · errors 0</p></div></div>`
          : `<div class="row gap2"><button class="btn btn-primary btn-sm" onclick="hmisAckNext()">Advance acknowledgement →</button><span class="small muted" style="align-self:center">Current: ${submit.toUpperCase()}</span></div>`}
      </div></div>

    <div class="grid split2 mb4">
      <div class="card">
        <div class="card-h"><h3>Submission history</h3><span class="badge badge-sky">Consistent reporting</span></div>
        <div class="table-wrap"><table>
          <tr><th>Period</th><th>Records</th><th>Status</th><th>Exceptions</th></tr>
          ${[['20 Aug',1802,'Demo ready',40],['19 Aug',1764,'Accepted',12],['18 Aug',1701,'Accepted',9],['17 Aug',1688,'Accepted',15]].map(r=>`
            <tr><td><b>${r[0]}</b></td><td class="mono">${r[1].toLocaleString()}</td><td><span class="badge ${r[2]==='Accepted'?'badge-green':'badge-sky'}">${r[2]}</span></td><td class="mono">${r[3]}</td></tr>`).join('')}
        </table></div>
      </div>
      <div class="card">
        <div class="card-h"><h3>Reporting governance</h3><span class="badge badge-sky">Every submission</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          ${[['Purpose','Authorized national reporting & exchange'],['Authorization','Facility-level reporting mandate'],['Minimum necessary data','Aggregate and de-identified where possible'],['Validation','Schema, coding and consent validation'],['Audit','Every submission recorded and traceable']].map(([k,v])=>`
            <div class="row-b mb3" style="padding:8px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm);width:180px">${k}</b><span class="small muted">${v}</span></div>`).join('')}
        </div></div>
    </div>

    <div class="card">
      <div class="card-h"><h3>Who can access</h3><span class="badge badge-sky">Role → purpose → minimum necessary</span></div>
      <div class="card-body">
        <div class="gov-grid">
          ${[['Facility Administrator','Readiness, exceptions, routing, approval, demo submission, mappings, audit'],['Hospital Admin','Readiness monitoring, coordination, operational exceptions'],['Department Head','Department reporting exceptions — resolve within clinical authority'],['Clinician','Encounter documentation completion — the actual clinical correction'],['ICT Officer','Mappings, endpoints, schemas, technical logs']].map(([k,v])=>`
            <div class="gov-item"><b>${k}</b><p>${v}</p></div>`).join('')}
        </div>
      </div></div>`;
}

/* ---------- NATIONAL DATA READINESS ---------- */
function nationalScreen(){
  const avg = Math.round(REPORT_DOMAINS.reduce((a,d)=>a+d.pct,0)/REPORT_DOMAINS.length);
  return `
    ${facBar('National Data Readiness', `DHA reporting — what AMEXAN gives the national system`)}
    <div class="grid split2 mb4">
      <div class="card"><div class="card-h"><h3>Today's reporting</h3><span class="badge badge-sky">${avg}% ready</span></div>
        <div class="card-body" style="display:flex;gap:var(--sp5);align-items:center;flex-wrap:wrap">
          <div style="text-align:center">${miniDonut(avg,'#0284c7',130,'ready')}</div>
          <div style="flex:1;min-width:220px">
            ${REPORT_DOMAINS.map(d=>`
              <div class="row-b mb2"><b style="font-size:12px;width:150px">${d.name}</b>${hbar(d.pct,100,d.pct>=99?'#059669':d.pct>=95?'#d97706':'#dc2626',140)}<span class="small mono">${d.pct}%</span></div>`).join('')}
          </div>
        </div></div>
      <div class="card"><div class="card-h"><h3>Data quality issues</h3><span class="badge badge-amber">17 records need correction</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          ${REPORTING_ISSUES.map(i=>`<div class="fact flag"><div class="fc">!</div><div><b>${i.record}</b><p>${i.issue}</p></div></div>`).join('')}
        </div></div>
    </div>
    <div class="card"><div class="card-h"><h3>Reporting workflow</h3><span class="badge badge-green">Generate → Validate → Submit → Acknowledge</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        <div class="row gap2 wrap">
          <button class="btn btn-primary" onclick="toast('National dataset generated (demo)','ok')">Generate national dataset</button>
          <button class="btn btn-outline" onclick="toast('Validation passed (demo)','ok')">Validate</button>
          <button class="btn btn-outline" onclick="toast('Submitted to DHA — acknowledgement received (demo)','ok')">Submit</button>
          <button class="btn btn-outline" onclick="toast('Acknowledgement: AMEXAN-DHA-0001 (demo)','ok')">View acknowledgement</button>
        </div>
        <div class="row-b small muted mt3"><span>AMEXAN maintains the richer operational model and produces interoperable DHA representations from it.</span></div>
      </div></div>`;
}

/* ---------- FACILITY ECOSYSTEM — CONTROL PLANE ---------- */
function setEcoFilter(f){ S.ecoFilter=f; S.ecoOrg=null; renderScreen('ecosystem'); }
function setEcoOrg(id){ S.ecoOrg=id; renderScreen('ecosystem'); }
function clearEcoOrg(){ S.ecoOrg=null; renderScreen('ecosystem'); }
window.setEcoFilter=setEcoFilter; window.setEcoOrg=setEcoOrg; window.clearEcoOrg=clearEcoOrg;

const ECO_FILTERS=[['all','All'],['referrals','Referrals'],['shared','Shared services'],['laboratory','Laboratory'],['pharmacy','Pharmacy'],['suppliers','Suppliers'],['education','Education'],['research','Research'],['community','Community']];
const ECO_STATES=[['ACTIVE','Agreement valid + relationship currently usable'],['LIMITED','Relationship exists but one service is unavailable'],['EXPIRING','Agreement approaching expiry'],['SUSPENDED','Relationship temporarily unavailable'],['PENDING','Agreement/configuration not complete'],['EXPIRED','Agreement expired'],['TERMINATED','Relationship ended'],['DEMO','Simulated relationship only']];

function ecoDirLabel(dir){
  return dir==='out'?`<span class="chip green">KTRH → partner</span>`:dir==='in'?`<span class="chip">→ KTRH</span>`:`<span class="chip" style="background:#f5f3ff;border-color:#ddd6fe;color:#6d28d9">⇄ both directions</span>`;
}
function ecoDetailPanel(p){
  const d=p.detail;
  const facts=(d.facts||[]).map(([k,v])=>`<div class="row-b mb3" style="padding:8px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm)">${k}</b><span class="mono">${v}</span></div>`).join('');
  const metrics=(d.metrics||[]).map(([k,v])=>`<div class="row-b mb3" style="padding:8px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm)">${k}</b><span class="mono">${v}</span></div>`).join('');
  const services=(d.services||[]).map(s=>`<span class="chip">${s}</span>`).join(' ');
  let panel='';
  if(d.kind==='referral'){
    panel=`
      <div class="card mb4"><div class="card-h"><h3>Referral activity</h3><span class="badge badge-sky">This month</span></div><div class="card-body" style="padding-top:var(--sp3)">${facts}${metrics}</div></div>
      <div class="card"><div class="card-h"><h3>Services</h3></div><div class="card-body" style="padding-top:var(--sp3)">${services}</div></div>
      <div class="card mt4"><div class="card-h"><h3>Referral exchange</h3><span class="badge badge-sky">12 referrals</span></div><div class="card-body" style="padding-top:var(--sp3)">
        <div class="small muted mb3">${d.note}</div>
        <button class="btn btn-primary btn-sm" onclick="toast('Authorized referral records opened (demo)','ok')">View authorized referral records →</button>
        <button class="btn btn-outline btn-sm" onclick="go('clinicalops')">Open referral command →</button>
        <div class="small muted mt3">Referral command handles: sending facility → patient encounter → referral reason → clinical handover → receiving facility → acceptance → transport → arrival → continuity.</div>
      </div></div>`;
  }
  if(d.kind==='affiliate'){
    panel=`
      <div class="card mb4"><div class="card-h"><h3>Shared services activity</h3><span class="badge badge-sky">Operational</span></div><div class="card-body" style="padding-top:var(--sp3)">${facts}${metrics}</div></div>
      <div class="card"><div class="card-h"><h3>Shared services</h3></div><div class="card-body" style="padding-top:var(--sp3)">${services}</div></div>`;
  }
  if(d.kind==='primary'||d.kind==='community'){
    panel=`
      <div class="card mb4"><div class="card-h"><h3>Network activity</h3><span class="badge badge-sky">${d.level}</span></div><div class="card-body" style="padding-top:var(--sp3)">${facts}${metrics}</div></div>
      ${d.shared?`<div class="card"><div class="card-h"><h3>Shared services</h3></div><div class="card-body" style="padding-top:var(--sp3)">${d.shared.map(s=>`<span class="chip">${s}</span>`).join(' ')}<div class="small muted mt3">Community facilities are nodes in the AMEXAN facility ecosystem — not inferior copies of KTRH.</div></div></div>`:''}
      <div class="card mt4"><div class="card-h"><h3>Network-of-facilities model</h3></div><div class="card-body" style="padding-top:var(--sp3)"><div class="small muted">Each facility remains its own organization. AMEXAN understands relationships between them — interoperable organizational nodes connected through governed relationships, not one enormous hospital database.</div></div></div>`;
  }
  if(d.kind==='lab'){
    panel=`
      <div class="card mb4"><div class="card-h"><h3>Activity</h3><span class="badge badge-sky">Orders this month</span></div><div class="card-body" style="padding-top:var(--sp3)">${facts}</div></div>
      <div class="card mb4"><div class="card-h"><h3>Services</h3></div><div class="card-body" style="padding-top:var(--sp3)">${services}</div></div>
      <div class="card"><div class="card-h"><h3>Integration</h3><span class="badge badge-sky">${d.integrationState}</span></div><div class="card-body" style="padding-top:var(--sp3)">
        <div class="fact"><div class="fc">⇄</div><div><b>${d.integration}</b><p>External integration shown as a ${d.integrationState} — no production transaction transmitted.</p></div></div>
        <button class="btn btn-outline btn-sm mt2" onclick="go('integrations')">View integrations →</button>
      </div></div>`;
  }
  if(d.kind==='pharmacy'){
    panel=`
      <div class="card mb4"><div class="card-h"><h3>Current activity</h3><span class="badge badge-sky">Requisitions</span></div><div class="card-body" style="padding-top:var(--sp3)">${facts}${metrics}</div></div>
      <div class="card"><div class="card-h"><h3>Supply relationship</h3></div><div class="card-body" style="padding-top:var(--sp3)"><div class="small muted">${p.name} supplies ${p.type==='Partner Pharmacy'?'pharmacy stock to KTRH.':'KTRH.'}</div><button class="btn btn-outline btn-sm mt3" onclick="toast('Supply network opened (demo)','ok')">Open supply network →</button></div></div>`;
  }
  if(d.kind==='supplier'){
    panel=`
      <div class="card mb4"><div class="card-h"><h3>Supply dependencies</h3><span class="badge badge-sky">${d.dependencies.length} categories</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          ${d.dependencies.map(([lvl,item,count,c])=>`<div class="row-b mb3" style="padding:9px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm);width:70px;color:${c}">${lvl}</b><b style="font-size:var(--sm)">${item}</b>${hbar(count,4,c,120)}<span class="small mono">${count} supplier${count>1?'s':''}</span></div>`).join('')}
        </div></div>
      <div class="card"><div class="card-h"><h3>Supplier dependency risk</h3><span class="badge badge-amber">${d.risk}</span></div><div class="card-body" style="padding-top:var(--sp3)"><div class="small muted mb3">${d.riskNote}</div><div class="small muted">If a supplier fails, AMEXAN identifies which facility services are affected.</div><button class="btn btn-outline btn-sm mt3" onclick="toast('Supply resilience review opened (demo)','ok')">Review supply resilience →</button></div></div>`;
  }
  if(d.kind==='teaching'){
    panel=`
      <div class="card mb4"><div class="card-h"><h3>Current activity</h3><span class="badge badge-sky">Teaching relationship</span></div><div class="card-body" style="padding-top:var(--sp3)">${facts}<div class="row-b mb3"><b style="font-size:var(--sm)">Current capacity</b>${hbar(d.capacity,100,'#059669',180)}<span class="small mono">${d.capacity}%</span></div></div></div>
      <div class="card"><div class="card-h"><h3>Departments</h3></div><div class="card-body" style="padding-top:var(--sp3)">${d.departments.map(x=>`<span class="chip">${x}</span>`).join(' ')}<div class="small muted mt3">Student educational data is kept separate from patient clinical records.</div><button class="btn btn-outline btn-sm mt3" onclick="toast('Teaching relationship management opened (demo)','ok')">Manage teaching relationship →</button></div></div>`;
  }
  if(d.kind==='research'){
    panel=`
      <div class="card mb4"><div class="card-h"><h3>Research activity</h3><span class="badge badge-sky">3 active studies</span></div><div class="card-body" style="padding-top:var(--sp3)">${facts}</div></div>
      <div class="card"><div class="card-h"><h3>Data governance</h3></div><div class="card-body" style="padding-top:var(--sp3)"><div class="small muted">${d.note}</div><button class="btn btn-outline btn-sm mt3" onclick="toast('Research intelligence opened (demo)','ok')">Open research intelligence →</button></div></div>`;
  }
  return panel;
}
function ecosystemGraph(){
  const list=PARTNERS.filter(p=>!S.ecoFilter || S.ecoFilter==='all' || p.cat===S.ecoFilter);
  const cx=330, cy=200, R=140;
  const ring=list.map((n,i)=>{ const ang=i/list.length*2*Math.PI-Math.PI/2; return {n, x:cx+R*Math.cos(ang), y:cy+R*Math.sin(ang)}; });
  const arrows=`<defs><marker id="ecoArrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0 0L10 5L0 10z" fill="#94a3b8"/></marker></defs>`;
  const lines=ring.map(e=>{
    const dir=e.n.dir;
    const mk = dir==='out' ? ' marker-end="url(#ecoArrow)"'
      : dir==='in' ? ' marker-start="url(#ecoArrow)"'
      : ' marker-start="url(#ecoArrow)" marker-end="url(#ecoArrow)"';
    return `<line x1="${cx}" y1="${cy}" x2="${e.x}" y2="${e.y}" stroke="${e.n.color}" stroke-width="1.6" stroke-dasharray="4 3"${mk}/>`;
  }).join('');
  const boxes=ring.map(e=>`
    <g style="cursor:pointer" onclick="setEcoOrg('${e.n.id}')">
      <rect x="${e.x-62}" y="${e.y-21}" width="124" height="42" rx="10" fill="${e.n.state==='LIMITED'?'#fef2f2':'#fff'}" stroke="${e.n.state==='LIMITED'?'#fca5a5':e.n.color}" stroke-width="1.6"/>
      <text x="${e.x}" y="${e.y-4}" text-anchor="middle" font-size="9" font-weight="700" fill="#0f172a">${e.n.name.slice(0,26)}</text>
      <text x="${e.x}" y="${e.y+8}" text-anchor="middle" font-size="7" fill="${e.n.color}">${e.n.rel.toUpperCase()}</text>
      <text x="${e.x}" y="${e.y+17}" text-anchor="middle" font-size="6.5" fill="${e.n.state==='LIMITED'?'#dc2626':'#64748b'}">${e.n.state}</text>
    </g>`).join('');
  return `<svg class="eco-svg" viewBox="0 0 660 400" role="img" aria-label="Facility ecosystem network graph">
    ${arrows}
    ${lines}
    <circle cx="${cx}" cy="${cy}" r="40" fill="#0284c7"/>
    <text x="${cx}" y="${cy-2}" text-anchor="middle" fill="#fff" font-size="11" font-weight="800">KTRH</text>
    <text x="${cx}" y="${cy+12}" text-anchor="middle" fill="#e0f2fe" font-size="7.5">FACILITY</text>
    ${boxes}
  </svg>`;
}
function ecosystemScreen(){
  if(S.ecoOrg){
    const p=PARTNERS.find(x=>x.id===S.ecoOrg);
    if(p) return `
      ${facBar('Facility Ecosystem', `The AMEXAN network — facilities, laboratories, pharmacies, suppliers, universities and research · ${p.name}`)}
      <div class="demo-env"><b>DEMO ENVIRONMENT</b><span>External relationships shown here are simulated. No production national-system, payer, HIE, LIS or pharmacy transaction is being transmitted from this demo.</span></div>
      <div class="card mb4">
        <div class="card-h"><h3>${p.name}</h3><span class="badge ${p.state==='ACTIVE'?'badge-green':'badge-amber'}">${p.state}</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="row gap2 wrap mb3">${ecoDirLabel(p.dir)}<span class="chip">${p.type}</span><button class="btn btn-outline btn-sm" style="margin-left:auto" onclick="clearEcoOrg()">← Back to ecosystem</button></div>
          <div class="fact"><div class="fc">R</div><div><b>Relationship with KTRH</b><p>${p.rel}</p></div></div>
          ${p.stateNote?`<div class="fact flag mt2"><div class="fc">!</div><div><b>Reason for ${p.state}</b><p>${p.stateNote}</p></div></div>`:''}
        </div></div>
      <div class="grid split2 mb4">
        <div class="card"><div class="card-h"><h3>Agreement</h3><span class="badge ${p.agreement.status==='Active'?'badge-green':'badge-amber'}">${p.agreement.status}</span></div>
          <div class="card-body" style="padding-top:var(--sp3)">
            ${[['Kind',p.agreement.kind],['Effective',p.agreement.effective],['Expires',p.agreement.expires],['Owner',p.agreement.owner],['Renewal',p.agreement.renewal]].map(([k,v])=>`
              <div class="row-b mb3" style="padding:8px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm)">${k}</b><span>${v}</span></div>`).join('')}
          </div></div>
        <div class="card"><div class="card-h"><h3>Operational activity</h3><span class="badge badge-sky">${p.activity.when}</span></div>
          <div class="card-body" style="padding-top:var(--sp3)">
            <div class="fact"><div class="fc">●</div><div><b>${p.activity.what}</b><p>${p.name} · ${p.activity.when}</p></div></div>
            <div class="small muted mt3">${p.activity.when} — last relationship activity.</div>
          </div></div>
      </div>
      ${ecoDetailPanel(p)}`;
  }
  const active=PARTNERS.filter(p=>p.state==='ACTIVE').length;
  const attention=PARTNERS.length-active;
  const fList=S.ecoFilter&&S.ecoFilter!=='all'?PARTNERS.filter(p=>p.cat===S.ecoFilter):PARTNERS;
  return `
    ${facBar('Facility Ecosystem', `The AMEXAN network — facilities, laboratories, pharmacies, suppliers, universities and research`)}
    <div class="demo-env"><b>DEMO ENVIRONMENT</b><span>External relationships shown here are simulated. No production national-system, payer, HIE, LIS or pharmacy transaction is being transmitted from this demo.</span></div>

    <div class="card mb4"><div class="card-h"><h3>Ecosystem status</h3><span class="badge badge-green"><span class="dot dot-green"></span>Network health 94%</span></div>
      <div class="card-body">
        <div class="int-health">
          ${[['Active relationships',PARTNERS.length],['Operational',active],['Requires attention',attention],['Active agreements',8],['External service dependencies',3],['Critical relationship failures',0]].map(([l,v])=>`
            <div class="int-stat"><b>${v}</b><span>${l}</span></div>`).join('')}
        </div>
        <div class="row gap2 mt3 wrap" style="align-items:center">
          <div style="text-align:center">${miniDonut(94,'#059669',104,'network health')}</div>
          <div class="grow"><div class="hmis-big" style="font-size:24px">94% <span>Operational</span></div><div class="small muted mt2">9 of 10 relationships currently usable. 1 relationship (Sunshine Referral Hospital) is LIMITED.</div></div>
        </div>
      </div></div>

    <div class="card mb4"><div class="card-h"><h3>Quick network summary</h3><span class="badge badge-sky">Categories</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        <div class="gov-grid">
          ${[['Referral network','4 organizations · 12 referrals this month','Operational','#059669'],['Diagnostics','Laboratory · Imaging capabilities','1 partner','#0ea5e9'],['Supply network','Pharmacy · Medical supplies','2 suppliers','#d97706'],['Education','Egerton University Medical School','Teaching relationship active','#0284c7'],['Research','Kisii Research Institute','3 active studies','#7c3aed'],['Affiliated facilities','Maternity & Christamarie HC','Shared services enabled','#0891b2']].map(([k,v,s,c])=>`
            <div class="gov-item"><b style="color:${c}">${k}</b><p>${v}</p><span class="badge badge-gray" style="margin-top:6px">${s}</span></div>`).join('')}
        </div>
      </div></div>

    <div class="card mb4">
      <div class="card-h"><h3>Network</h3><span class="badge badge-sky">${fList.length} relationships · ${PARTNERS.length} organizations · ${new Set(PARTNERS.map(p=>p.rel)).size} relationship types · 3 active service dependencies</span></div>
      <div class="card-body">
        <div class="row gap2 wrap mb3">
          <span class="small muted" style="align-self:center">Filter:</span>
          ${ECO_FILTERS.map(([id,l])=>`<button class="chip ${S.ecoFilter===id?'active':''}" onclick="setEcoFilter('${id}')">${l}</button>`).join('')}
        </div>
        <div style="overflow-x:auto">${ecosystemGraph()}</div>
        <div class="small muted mt3">Directional relationships: <b>KTRH → partner</b> = KTRH sends; <b>→ KTRH</b> = partner sends to KTRH; <b>⇄</b> = both. Click a node to open the organization profile.</div>
      </div></div>

    <div class="card mb4"><div class="card-h"><h3>Connected organizations</h3><span class="badge badge-sky">${fList.length} relationships</span></div>
      <div class="table-wrap"><table>
        <tr><th>Organization</th><th>Type</th><th>Relationship</th><th>Status</th><th>Agreement</th><th>Last activity</th></tr>
        ${fList.map(p=>`
          <tr class="click-row" onclick="setEcoOrg('${p.id}')">
            <td><b>${p.name}</b></td>
            <td>${p.type}</td>
            <td><span class="chip" style="border-color:${p.color}55;color:${p.color}">${p.rel}</span></td>
            <td><span class="badge ${p.state==='ACTIVE'?'badge-green':'badge-amber'}">${p.state}</span>${p.state==='LIMITED'?'<div class="tiny muted">receiving service temporarily unavailable</div>':''}</td>
            <td><span class="badge badge-gray">${p.agreement.kind}</span></td>
            <td class="muted">${p.activity.when}</td>
          </tr>`).join('')}
      </table></div>
      <div class="card-body" style="padding-top:var(--sp2)">
        <div class="small muted">Relationship states: ${ECO_STATES.map(s=>`<b>${s[0]}</b> (${s[1]})`).join(' · ')}</div>
      </div></div>

    <div class="grid split2 mb4">
      <div class="card"><div class="card-h"><h3>Network activity</h3><span class="badge badge-green"><span class="dot dot-green"></span>Live relationship events</span></div>
        <div class="card-body" style="padding-top:var(--sp2)">
          ${ECO_ACTIVITY.map(e=>`<div class="feed-item"><span class="mono small muted">${e.t}</span><b>${e.what}</b><p>${e.who}</p></div>`).join('')}
        </div></div>
      <div class="card"><div class="card-h"><h3>Ecosystem attention</h3><span class="badge badge-amber">${ECO_RISKS.length} items</span></div>
        <div class="card-body" style="padding-top:var(--sp2)">
          ${ECO_RISKS.map(r=>`<div class="fact flag"><div class="fc">${r.sev}</div><div><b>${r.cat} — ${r.who}</b><p>${r.issue}</p><button class="btn btn-outline btn-sm mt2" onclick="toast('${r.act.replace(' →','')} — opened (demo)','ok')">${r.act}</button></div></div>`).join('')}
        </div></div>
    </div>

    <div class="card mb4"><div class="card-h"><h3>Facility Administrator actions</h3><span class="badge badge-sky">Governed workflows</span></div>
      <div class="card-body">
        <div class="row gap2 wrap">
          ${[['+ Add organization','Add organization workflow (demo)'],['Create relationship','Relationship workflow (demo)'],['Add agreement','Agreement workflow (demo)'],['Invite partner','Partner invitation (demo)'],['View referrals','Referral network opened (demo)'],['View supply network','Supply network opened (demo)'],['View integrations','go(\'integrations\')'],['Export ecosystem report','Ecosystem report exported (demo)']].map(([l,a])=>`
            <button class="btn btn-outline btn-sm" onclick="${a.includes('go(')?a:`toast('${a}','ok')`}">${l}</button>`).join('')}
        </div>
      </div></div>

    <div class="grid split2 mb4">
      <div class="card"><div class="card-h"><h3>Organization profile — one reusable model</h3><span class="badge badge-sky">ORGANIZATION</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="pipe">${['Identity','Type','Location','Ownership','Services','Relationships','Agreements','Integrations','Operational activity','Referrals','Supply relationships','Teaching','Research','Governance'].map((s,i)=>`<div class="pipe-step"><span class="pipe-n">${i+1}</span><b>${s}</b></div>${i<13?'<div class="pipe-arrow">→</div>':''}`).join('')}</div>
          <div class="small muted mt3">A laboratory isn't a special hard-coded object — it is an <b>organization with laboratory capabilities and a relationship to KTRH</b>. Same for pharmacy, supplier, university, research center, ambulance provider, referral hospital and community clinic.</div>
        </div></div>
      <div class="card"><div class="card-h"><h3>Role access</h3><span class="badge badge-sky">Can see vs Restricted</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="vis-grid">
            <div class="vis-col"><b class="vis-can">Can see</b>
              ${['Organizations','Relationships','Agreements','Operational activity','Referral volumes','Supply relationships','Teaching relationships','Research relationship status','Integration status'].map(x=>`<div class="vis-row"><span class="vis-ok">✓</span>${x}</div>`).join('')}
            </div>
            <div class="vis-col"><b class="vis-cant">Restricted</b>
              ${['Patient clinical records','Research participant records','Clinical notes','Patient-level referral content unless authorized','Supplier financial secrets','Technical credentials'].map(x=>`<div class="vis-row"><span class="vis-no">🔒</span>${x}</div>`).join('')}
            </div>
          </div>
        </div></div>
    </div>

    <div class="card"><div class="card-h"><h3>How the ecosystem works</h3><span class="badge badge-sky">Dependencies → consequences</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        <div class="small muted">The Facility Ecosystem does not merely tell the administrator who the hospital knows. It tells her <b>how the hospital depends on those organizations, what is flowing between them, whether those relationships are healthy, and what operational consequences arise when one fails</b> — part of the AMEXAN Operating System, not an address book with a graph.</div>
      </div></div>`;
}

/* ---------- EXECUTIVE INTELLIGENCE ---------- */
function execIntelScreen(){
  const insights=[
    {icon:'▲', color:'#dc2626', head:'Patient volume 18% above the 30-day baseline.', body:'128 patients today vs a 108 average. Peak arrivals between 09:00–11:00 in Emergency and OPD.'},
    {icon:'◍', color:'#d97706', head:'Medical wards approaching operational capacity.', body:'ICU at 91%, Medical at 85%. Two partner facilities — Kenyatta County Hospital and Maternity — have available beds.'},
    {icon:'⧗', color:'#d97706', head:'Laboratory turnaround has increased 22% since 14:00.', body:'Primarily affecting Emergency and Inpatient Medicine. Haematology analyser at 88% utilization is the constraint.'},
    {icon:'✓', color:'#059669', head:'Emergency demand up 28% while night nursing coverage is short 2.', body:'Coverage alert on the night shift. Provisioning additional surgical nurses closes the gap.'},
    {icon:'↻', color:'#0284c7', head:'Daily DHA submission 97.8% complete.', body:'4 laboratory records and 2 maternity records are blocking full readiness for today.'}
  ];
  return `
    ${facBar('Executive Intelligence', `Not "128 patients" — why the facility is what it is right now`)}
    <div class="card"><div class="card-h"><h3>What is actually happening</h3><span class="badge badge-sky">5 insights · live</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        ${insights.map(i=>`<div class="fact ${i.color==='#dc2626'?'flag':''}"><div class="fc" style="background:${i.color}15;color:${i.color}">${i.icon}</div><div><b>${i.head}</b><p>${i.body}</p></div></div>`).join('')}
        <div class="row gap2 mt3"><button class="btn btn-primary btn-sm" onclick="go('clinicalops')">Open monitor</button><button class="btn btn-outline btn-sm" onclick="go('workforce')">Resolve staffing →</button></div>
      </div></div>`;
}

/* ---------- SECURITY CENTER ---------- */
function securityScreen(){
  return `
    ${facBar('Security Center', `${SECURITY.sessions} active sessions · every important operation traceable`)}
    <div class="grid cols-5 mb4">
      ${[['Active sessions',SECURITY.sessions,'#0284c7'],['Failed logins',SECURITY.failedLogins,'#d97706'],['Suspicious activity',SECURITY.suspicious,'#dc2626'],['Privileged users',SECURITY.privileged,'#7c3aed'],['Pending access reviews',SECURITY.reviews,'#059669']].map(([l,v,c])=>`
        <div class="kpi"><div class="kpi-icon" style="background:${c}"><svg class="ic" viewBox="0 0 24 24"><path d="M12 2l8 4v6c0 5-3.5 8.5-8 10-4.5-1.5-8-5-8-10V6Z"/></svg></div><div><div class="kpi-value">${v}</div><div class="kpi-label">${l}</div></div></div>`).join('')}
    </div>
    <div class="grid split2 mb4">
      <div class="card"><div class="card-h"><h3>API & service connections</h3><span class="badge badge-sky">${SECURITY.api.length}</span></div>
        <div class="table-wrap"><table>
          <tr><th>Connection</th><th>Owner</th><th>Last activity</th><th>Scopes</th></tr>
          ${SECURITY.api.map(a=>`<tr><td><b>${a.name}</b></td><td>${a.owner}</td><td class="mono">${a.last}</td><td class="muted">${a.scopes.join(', ')}</td></tr>`).join('')}
        </table></div></div>
      <div class="card"><div class="card-h"><h3>Audit — recent operations</h3><span class="badge badge-green">Immutable trail</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          ${SECURITY.audit.map(a=>`<div class="tl-item"><div class="tl-time">${a.when}</div><div class="tl-title">${a.what}</div><div class="small muted">by ${a.who}</div></div>`).join('')}
        </div></div>
    </div>`;
}

/* ---------- CLINICAL EDUCATION ---------- */
function educationScreen(){
  return `
    ${facBar('Clinical Education', `A teaching layer operating over the clinical system`)}
    <div class="grid cols-5 mb4">
      ${[['Medical students',EDUCATION.students,'#0284c7'],['Interns',EDUCATION.interns,'#059669'],['Residents',EDUCATION.residents,'#7c3aed'],['Teaching cases',EDUCATION.teachingCases,'#d97706'],['Simulation sessions',EDUCATION.simSessions,'#0891b2']].map(([l,v,c])=>`
        <div class="kpi"><div class="kpi-icon" style="background:${c}"><svg class="ic" viewBox="0 0 24 24"><path d="M12 3 2 9l10 6 10-6ZM6 11v5c2 1.5 4 2.5 6 2.5s4-1 6-2.5v-5"/></svg></div><div><div class="kpi-value">${v}</div><div class="kpi-label">${l}</div></div></div>`).join('')}
    </div>
    <div class="card"><div class="card-h"><h3>Active rotations</h3><span class="badge badge-sky">${EDUCATION.rotations.length}</span></div>
      <div class="table-wrap"><table>
        <tr><th>Cohort</th><th>Department</th><th>Learners</th><th>Supervisor</th></tr>
        ${EDUCATION.rotations.map(r=>`<tr><td><b>${r.cohort}</b></td><td>${r.dept}</td><td>${r.count}</td><td>${r.supervisor}</td></tr>`).join('')}
      </table></div></div>`;
}

/* ---------- COMMUNICATIONS ---------- */
/* ---------- COMMUNICATIONS — controlled facility messaging & alerting ----------
   Announcements are not clinical orders. Clinical alerts are not ordinary
   announcements. Emergency broadcasts are not ordinary messages. AMEXAN routes
   each appropriately, records acknowledgement where required, and preserves an
   audit trail. Communications is the facility's messaging layer — it REFERENCES
   Protocol Center, Service Catalogue, Asset Intelligence, Clinical Operations —
   it is never the source of truth. */
const COMM_TYPES=[['announcement','Announcement'],['operational','Operational Alert'],['clinical','Clinical Notice'],['emergency','Emergency Broadcast'],['protocol','Protocol / Policy Notice'],['admin','Administrative']];
const COMM_PRI=[['normal','🟢 Normal','Standard notification.'],['important','🟡 Important','Notification + inbox.'],['urgent','🟠 Urgent','Notification + priority banner.'],['emergency','🔴 Emergency','Immediate alert + escalation rules + acknowledgement.']];
const COMM_RECIPS=[['facility','Facility-wide'],['dept','Department'],['service','Service'],['ward','Ward / Unit'],['role','Role'],['shift','Shift'],['onduty','On-duty staff'],['group','Specific authorized group']];
const COMM_TABS=[['inbox','Inbox'],['broadcasts','Broadcasts'],['alerts','Alerts'],['emergency','Emergency'],['clinical','Clinical'],['drafts','Drafts'],['archive','Archive']];
function setCommType(t){ S.commType=t; S.commConfirm=false; renderScreen('communications'); }
function setCommTab(t){ S.commTab=t; renderScreen('communications'); }
function setCommPri(p){ S.commPri=p; renderScreen('communications'); }
function setCommRecip(r){ S.commRecip=r; renderScreen('communications'); }
function commSend(){ toast('Broadcast sent — delivery recorded (demo)','ok'); renderScreen('communications'); }
function commEmergToggle(){ S.commConfirm=!S.commConfirm; renderScreen('communications'); }
function commEmergSend(){ S.commConfirm=false; toast('Emergency broadcast sent — 42 recipients · acknowledgement required · escalation armed','ok'); renderScreen('communications'); }
function commPII(){
  const t=document.getElementById('commMsg');
  const w=document.getElementById('commPII');
  if(!t||!w) return;
  const v=t.value||'';
  const flagged=/(AMX-\d{6}|ENC-\d{6}|MRN|Cough for|pneumonia|history of)/i.test(v);
  w.style.display=flagged?'block':'none';
}
function commComposer(){
  const type=S.commType||'announcement';
  const pri=S.commPri||'normal';
  const recip=S.commRecip||'facility';
  const priMeta=COMM_PRI.find(p=>p[0]===pri);
  const recipLabel=COMM_RECIPS.find(r=>r[0]===recip)[1];
  if(type==='emergency'){
    return `
      <div class="card mb4" style="border-color:var(--danger);border-width:1.5px">
        <div class="card-h"><h3>⚠ Emergency communication</h3><span class="badge badge-red">🔴 Emergency</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="field"><label>Message</label><textarea class="input" rows="2">Emergency Department has reached 92% operational capacity.</textarea></div>
          <div class="field"><label>Immediate instruction</label><textarea class="input" rows="2">Stable walk-in patients should be redirected to General OPD.</textarea></div>
          <div class="row gap2 wrap mb3"><span class="small muted" style="align-self:center">Affected areas</span>${['Emergency','General OPD','Triage','Security','Registration'].map(x=>`<span class="chip">${x}</span>`).join('')}</div>
          <div class="row-b mb3" style="padding:9px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm)">Priority</b><span class="badge badge-red">🔴 Emergency</span></div>
          <div class="row-b mb3" style="padding:9px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm)">Acknowledgement</b><span class="badge badge-amber">Required</span></div>
          <div class="row-b mb3" style="padding:9px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm)">Escalation</b><span>If not acknowledged within <b>5 minutes</b> → notify responsible operational leads.</span></div>
          ${S.commConfirm
            ? `<div class="fact flag"><div class="fc">!</div><div><b>Confirm emergency broadcast</b><p>This will alert 42 recipients facility-wide with acknowledgement required and escalation armed. Emergency broadcasts are not ordinary messages.</p><div class="row gap2 mt2"><button class="btn btn-primary btn-sm" onclick="commEmergSend()">CONFIRM — SEND EMERGENCY BROADCAST</button><button class="btn btn-outline btn-sm" onclick="commEmergToggle()">Cancel</button></div></div></div>`
            : `<button class="btn btn-primary" style="background:var(--danger);border-color:var(--danger)" onclick="commEmergToggle()">SEND EMERGENCY BROADCAST</button>`}
          <div class="small muted mt3">Confirmation step prevents accidental facility-wide emergency alerts.</div>
        </div></div>`;
  }
  if(type==='clinical'){
    return `
      <div class="card mb4">
        <div class="card-h"><h3>Clinical Notice — governed communication</h3><span class="badge badge-sky">🔵 Clinical</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="field"><label>Sender authority</label><select class="input"><option>Clinical Governance</option><option>Authorized clinical role</option></select></div>
          <div class="field"><label>Linked protocol</label><select class="input"><option>Neonatal sepsis thresholds (Protocol Center v2.5)</option><option>Antibiotic stewardship — amoxicillin dose</option><option>— no linked protocol —</option></select></div>
          <div class="grid split2">
            <div class="field"><label>Effective date</label><input class="input" value="20 Aug 2026"></div>
            <div class="field"><label>Expiry</label><input class="input" value="20 Sep 2026"></div>
          </div>
          <div class="row-b mb3"><b style="font-size:var(--sm)">Version</b><span class="chip">v2.5</span></div>
          <div class="field"><label>Message</label><textarea class="input" rows="2">Protocol Center contains the authoritative version.</textarea></div>
          <div class="fact mt2"><div class="fc">i</div><div><b>Protocol Center is the source of truth for clinical protocols.</b><p>This communication references it — it is not the protocol itself.</p><button class="btn btn-outline btn-sm mt2" onclick="go('protocols')">Open Protocol →</button></div></div>
          <button class="btn btn-primary btn-sm mt3" onclick="commSend()">Send clinical notice</button>
        </div></div>`;
  }
  return `
    <div class="card mb4">
      <div class="card-h"><h3>New communication</h3><span class="badge badge-sky">Composer</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        <div class="field"><label>Message type</label>
          <div class="row gap2 wrap">${COMM_TYPES.map(([id,l])=>`<button class="chip ${type===id?'active':''}" onclick="setCommType('${id}')">${l}</button>`).join('')}</div></div>
        <div class="field"><label>Send to</label>
          <div class="row gap2 wrap">${COMM_RECIPS.map(([id,l])=>`<button class="chip ${recip===id?'active':''}" onclick="setCommRecip('${id}')">${l}</button>`).join('')}</div>
          <div class="small muted mt2">Recipients: ${recipLabel} · e.g. <span class="chip">Surgery + Theatre</span><span class="chip">Anaesthesia</span><span class="chip">Theatre In-charge</span></div></div>
        <div class="field"><label>Priority</label>
          <div class="row gap2 wrap">${COMM_PRI.map(([id,l,d])=>`<button class="chip ${pri===id?'active':''}" onclick="setCommPri('${id}')">${l}</button>`).join('')}</div>
          <div class="small muted mt2">Delivery behavior — ${priMeta[1].replace(/^.. /,'')}: ${priMeta[2]}</div></div>
        <div class="field"><label>Message</label><textarea id="commMsg" class="input" rows="3" oninput="commPII()" placeholder="Do not include identifiable patient information in facility-wide communications."></textarea>
          <div id="commPII" style="display:none;margin-top:8px" class="fact flag"><div class="fc">⚠</div><div><b>Possible patient-identifiable information</b><p>This message targets a broad audience. Use the authorized clinical communication workflow for patient-specific information.</p></div></div></div>
        <div class="row gap2 wrap">
          <label class="chip" style="cursor:pointer"><input type="checkbox" checked> Require acknowledgement</label>
          <label class="chip" style="cursor:pointer"><input type="checkbox"> Schedule</label>
          <label class="chip" style="cursor:pointer"><input type="checkbox"> Expiry</label>
        </div>
        <div class="row gap2 mt3">
          <button class="btn btn-primary btn-sm" onclick="commSend()">Send broadcast</button>
          <button class="btn btn-outline btn-sm" onclick="setCommType('announcement')">Cancel</button>
        </div>
      </div></div>`;
}
function commCard(m){
  const col = m.kind==='alert'?'#dc2626':m.kind==='announcement'?'#059669':m.kind==='notice'?'#d97706':'#0284c7';
  const ic = m.kind==='alert'?'!':m.kind==='announcement'?'★':m.kind==='notice'?'◈':'✚';
  const delivery = m.ack
    ? `<div class="row-b" style="padding:6px 0"><span class="small muted">Recipients ${m.recipients} · Acknowledged ${m.acknowledged} · Pending ${m.pending}</span><span class="badge ${m.pending?'badge-amber':'badge-green'}">${m.pending?'Acknowledge pending':'Coverage '+(Math.round(m.acknowledged/m.recipients*100))+'%'}</span></div><button class="btn btn-outline btn-sm mt2" onclick="toast('Acknowledgement view opened (demo)','ok')">View acknowledgement →</button>`
    : '';
  const lifecycle = m.effective?`<div class="row-b" style="padding:6px 0"><span class="small muted">Effective ${m.effective} · Expires ${m.expires}</span><span class="badge badge-green">Active</span></div>`:'';
  const link = m.links
    ? m.links.protocol
      ? `<button class="btn btn-outline btn-sm mt2" onclick="go('protocols')">Open protocol →</button>`
      : `<div class="row gap1 mt2"><span class="chip">Service: ${m.links.service}</span><span class="chip">Asset: ${m.links.asset}</span><span class="chip">Incident: ${m.links.incident}</span></div>`
    : '';
  return `<div class="card mb4"><div class="card-h"><h3>${m.pri||''} ${m.title}</h3><span class="badge badge-gray">${m.priLabel||''}</span></div>
    <div class="card-body" style="padding-top:var(--sp3)">
      <div class="fact"><div class="fc" style="background:${col}15;color:${col}">${ic}</div><div><b>${m.author}</b><p>${m.body}</p><span class="tiny muted">${m.role||''} · ${m.scope} · ${m.time}</span></div></div>
      ${delivery}${lifecycle}${link}
      <button class="btn btn-ghost btn-sm mt2" onclick="toast('Message ${m.id} opened (demo)','ok')">View →</button>
    </div></div>`;
}
function communicationsScreen(){
  const tab=S.commTab||'broadcasts';
  let listHtml='';
  if(tab==='alerts') listHtml=COMM_ALERTS.map(a=>`<div class="fact flag"><div class="fc">${a.sev}</div><div><b>${a.name}</b><p>${a.detail} — ${a.source}</p><button class="btn btn-outline btn-sm mt2" onclick="toast('${a.act.replace(' →','')} (demo)','ok')">${a.act}</button></div></div>`).join('');
  else if(tab==='emergency') listHtml=COMMS.filter(m=>m.pri==='🔴'||m.kind==='alert').map(commCard).join('');
  else if(tab==='clinical') listHtml=COMMS.filter(m=>m.kind==='clinical').map(commCard).join('');
  else if(tab==='archive') listHtml=COMMS.filter(m=>m.archived).map(commCard).join('');
  else if(tab==='inbox') listHtml=COMMS.filter(m=>m.active).map(commCard).join('');
  else if(tab==='drafts') listHtml=COMM_DRAFT.map(d=>`<div class="fact flag"><div class="fc">✎</div><div><b>${d.title}</b><p>${d.body} · ${d.scope} · ${d.priLabel}</p><div class="row gap2 mt2"><button class="btn btn-primary btn-sm" onclick="setCommType('${d.kind}');toast('Draft loaded into composer (demo)','ok')">Edit draft</button><button class="btn btn-outline btn-sm" onclick="commSend()">Send now</button></div></div></div>`).join('');
  else listHtml=COMMS.filter(m=>!m.archived).map(commCard).join('');
  return `
    ${facBar('Communications', `Facility-wide communication and operational messaging — announcements, alerts, clinical notices, emergency broadcasts, acknowledgements and audit`)}
    <div class="demo-env"><b>DEMO ENVIRONMENT</b><span>Broadcasts shown here are simulated. No production message is being transmitted to staff or external parties from this demo.</span></div>

    <div class="card mb4"><div class="card-h"><h3>Communication status</h3><span class="badge badge-green"><span class="dot dot-green"></span>Delivery operational</span></div>
      <div class="card-body">
        <div class="int-health">
          ${[['Active broadcasts',4],['Require acknowledgement',2],['Unread priority messages',18],['Acknowledgement coverage','96%']].map(([l,v])=>`<div class="int-stat"><b>${v}</b><span>${l}</span></div>`).join('')}
        </div>
        <div class="fact mt3"><div class="fc" style="background:#ecfdf5;color:#059669">🟢</div><div><b>Facility communication — Operational</b><p>No communication delivery incidents.</p></div></div>
      </div></div>

    ${commComposer()}

    <div class="card mb4"><div class="card-h"><h3>Communication Center</h3><span class="badge badge-sky">${tab}</span></div>
      <div class="card-body" style="padding-top:var(--sp2)">
        <div class="row gap2 wrap mb3">
          ${COMM_TABS.map(([id,l])=>`<button class="chip ${tab===id?'active':''}" onclick="setCommTab('${id}')">${l}</button>`).join('')}
        </div>
        ${listHtml}
      </div></div>

    <div class="grid split2 mb4">
      <div class="card"><div class="card-h"><h3>Active alerts</h3><span class="badge badge-amber">${COMM_ALERTS.length}</span></div>
        <div class="card-body" style="padding-top:var(--sp2)">
          ${COMM_ALERTS.map(a=>`<div class="fact flag"><div class="fc">${a.sev}</div><div><b>${a.name}</b><p>${a.detail}</p><span class="tiny muted">${a.source}</span></div></div>`).join('')}
        </div></div>
      <div class="card"><div class="card-h"><h3>Suggested communications</h3><span class="badge badge-sky">Assistive — not autonomous</span></div>
        <div class="card-body" style="padding-top:var(--sp2)">
          ${COMM_SUGGEST.map(s=>`<div class="fact"><div class="fc">▶</div><div><b>${s.title}</b><p>${s.body}</p><div class="row gap1 mt2">${s.recipients.map(r=>`<span class="chip">${r}</span>`).join('')}</div><span class="tiny muted">${s.source} · proposed, not automatically broadcast unless event policy permits</span><div class="row gap2 mt2"><button class="btn btn-primary btn-sm" onclick="setCommType('operational');toast('Draft loaded — sender remains the approver (demo)','ok')">Use as draft</button><button class="btn btn-outline btn-sm" onclick="toast('Reviewed without sending (demo)','ok')">Review</button></div></div></div>`).join('')}
        </div></div>
    </div>

    <div class="grid split2 mb4">
      <div class="card"><div class="card-h"><h3>Message lifecycle</h3><span class="badge badge-sky">Auditable</span></div>
        <div class="card-body">
          <div class="pipe">${['DRAFT','VALIDATION','SENT','DELIVERED','ACKNOWLEDGED','EXPIRED / CLOSED'].map((s,i)=>`<div class="pipe-step"><span class="pipe-n">${i+1}</span><b>${s}</b></div>${i<5?'<div class="pipe-arrow">↓</div>':''}`).join('')}</div>
          <div class="small muted mt3">Emergency: EMERGENCY → SENT → DELIVERY → ACKNOWLEDGEMENT → ESCALATION → RESOLVED.</div>
        </div></div>
      <div class="card"><div class="card-h"><h3>Communication audit</h3><span class="badge badge-green">Immutable trail</span></div>
        <div class="table-wrap"><table>
          <tr><th>Message</th><th>Sender / role</th><th>Sent</th><th>Audience</th><th>Delivery</th><th>Ack</th><th>Escalation</th></tr>
          ${COMM_AUDIT.map(a=>`<tr><td class="mono">${a.id}</td><td>${a.sender}<div class="tiny muted">${a.role}</div></td><td class="mono">${a.sent}</td><td>${a.audience}</td><td class="mono">${a.delivery}</td><td class="mono">${a.ack}</td><td class="mono" style="color:${a.escalation!=='—'?'#d97706':'inherit'}">${a.escalation}</td></tr>`).join('')}
        </table></div>
        <div class="small muted" style="padding:var(--sp2) var(--sp4) 0">Every message records sender, role, audience, priority, delivery, acknowledgement and escalation — essential for emergency communications.</div>
      </div></div>
    </div>

    <div class="card mb4"><div class="card-h"><h3>Communications actions</h3><span class="badge badge-sky">Controlled</span></div>
      <div class="card-body">
        <div class="row gap2 wrap">
          <button class="btn btn-outline btn-sm" onclick="setCommTab('broadcasts');setCommType('announcement')">Compose</button>
          <button class="btn btn-primary btn-sm" style="background:var(--danger);border-color:var(--danger)" onclick="setCommType('emergency')">Emergency broadcast</button>
          <button class="btn btn-outline btn-sm" onclick="setCommTab('alerts')">View acknowledgements</button>
          <button class="btn btn-outline btn-sm" onclick="toast('Communication audit exported (demo)','ok')">Communication audit</button>
          <button class="btn btn-outline btn-sm" onclick="toast('Templates opened (demo)','ok')">Templates</button>
        </div>
      </div></div>

    <div class="card"><div class="card-h"><h3>Who can communicate</h3><span class="badge badge-sky">Role → scope → purpose</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        <div class="gov-grid">
          ${[['Facility Administrator','Facility-wide announcements, operational broadcasts, administrative notices, selected departmental broadcasts, review delivery/acknowledgement, close broadcasts, schedule messages. Emergency: send if authorized by facility policy.']].map(([k,v])=>`<div class="gov-item" style="grid-column:1/-1"><b>${k}</b><p>${v}</p></div>`).join('')}
        </div>
        <div class="gov-grid mt3">
          ${[['Clinical Governance','Clinical notices, protocol-linked communications, clinical emergency notices.'],['Department Head','Department communications and operational announcements — not facility-wide.'],['Ward In-charge','Ward / unit messages — facility-wide only when delegated.'],['Ordinary staff','Receive, acknowledge, respond where enabled — no facility-wide broadcast.']].map(([k,v])=>`<div class="gov-item"><b>${k}</b><p>${v}</p></div>`).join('')}
        </div>
        <div class="small muted mt3" style="padding-top:var(--sp2);border-top:1px dashed var(--neutral-200)">The AMEXAN rule: Communications is the facility's messaging layer, not the source of truth for clinical, operational, or patient information — it references those systems. Asset fails → Asset Intelligence knows why · service unavailable → Service Catalogue knows what changed · operations affected → Clinical Operations knows who · Communications proposes/routes · recipients acknowledge · event resolves · audit remains.</div>
      </div></div>`;
}

/* ---------- PROTOCOL CENTERS ---------- */
function protocolsScreen(){
  return `
    ${facBar('Protocol Centers', `DEFAULT → COUNTRY → FACILITY → DEPARTMENT → CLINICIAN → PATIENT CONTEXT`)}
    <div class="card"><div class="card-h"><h3>Protocol hierarchy</h3><span class="badge badge-sky">${PROTOCOLS.reduce((a,p)=>a+p.count,0)} protocols</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        ${PROTOCOLS.map(p=>`
          <div class="row-b" style="padding:12px 0;border-bottom:1px solid var(--neutral-100)">
            <div class="row gap2"><span class="badge ${p.layer==='FACILITY'?'badge-primary':p.layer==='COUNTRY'?'badge-green':'badge-gray'}">${p.layer}</span>
              <div><b>${p.name}</b><div class="small muted">${p.owner}</div></div></div>
            <div class="row gap1"><span class="badge badge-sky">${p.count} rules</span>${p.pending?`<span class="badge badge-amber">${p.pending} pending review</span>`:''}<span class="chip">${p.status}</span></div>
          </div>`).join('')}
      </div></div>
    <div class="card mt4"><div class="card-h"><h3>Facility layer approval</h3><span class="badge badge-amber">3 pending</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        ${['Neonatal jaundice thresholds — review','Antibiotic stewardship edit — amoxicillin dose','Emergency triage re-prioritisation'].map(p=>`
          <div class="row-b" style="padding:9px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm)">${p}</b><button class="btn btn-primary btn-sm" onclick="toast('Approved and versioned (demo)','ok')">Approve</button></div>`).join('')}
      </div></div>`;
}

/* ---------- CLINICAL INTELLIGENCE ---------- */
function intelScreen(){
  return `
    ${facBar('Clinical Intelligence', `The facility governor does not casually edit clinical reasoning — every change is proposed, reviewed, versioned, activated and audited`)}
    <div class="grid cols-3 mb4">
      ${[['Engine',CLINICAL_INTEL.engine,'#059669'],['Global baseline',CLINICAL_INTEL.baseline,'#0284c7'],['Kenya adaptation',CLINICAL_INTEL.kenya,'#059669']].map(([l,v,c])=>`
        <div class="kpi"><div class="kpi-icon" style="background:${c}"><svg class="ic" viewBox="0 0 24 24"><path d="M12 2l3 4h4v4l3 2-3 2v4h-4l-3 4-3-4H5v-4l-3-2 3-2V6h4Z"/></svg></div><div><div class="kpi-value">${v}</div><div class="kpi-label">${l}</div></div></div>`).join('')}
    </div>
    <div class="grid split2">
      <div class="card mb4"><div class="card-h"><h3>Knowledge layers</h3><span class="badge badge-sky">${CLINICAL_INTEL.facilityRules} facility rules</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          ${[['Global baseline','Active'],['Kenya adaptation','Active'],['Facility adaptation',CLINICAL_INTEL.facilityRules+' rules'],['Pending review',CLINICAL_INTEL.pendingReview]].map(([k,v])=>`
            <div class="row-b" style="padding:9px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm)">${k}</b><span class="badge ${v==='Active'?'badge-green':''}">${v}</span></div>`).join('')}
        </div></div>
      <div class="card mb4"><div class="card-h"><h3>Version history</h3><span class="badge badge-sky">4 versions</span></div>
        <div class="table-wrap"><table>
          <tr><th>Version</th><th>Change</th><th>Status</th><th>Date</th></tr>
          ${CLINICAL_INTEL.versions.map(v=>`<tr><td class="mono"><b>${v.v}</b></td><td>${v.change}</td><td><span class="badge ${v.status==='Active'?'badge-green':'badge-amber'}">${v.status}</span></td><td class="muted">${v.date}</td></tr>`).join('')}
        </table></div></div>
    </div>
    <div class="card"><div class="card-h"><h3>Change governance</h3><span class="badge badge-sky">Propose → Review → Approve → Version → Activate → Audit</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        <div class="pipe">${['Propose change','Review','Approve','Version','Activate','Audit'].map((s,i)=>`<div class="pipe-step"><span class="pipe-n">${i+1}</span><b>${s}</b></div>${i<5?'<div class="pipe-arrow">→</div>':''}`).join('')}</div>
        <button class="btn btn-primary mt3" onclick="toast('Proposal created — routed to clinical governance (demo)','ok')">Propose a facility adaptation</button>
      </div></div>`;
}

/* ---------- DATA MIGRATION ---------- */
function migrationScreen(){
  return `
    ${facBar('Data Migration', `Never silently destroy the old data — source → transformation → destination → timestamp → actor`)}
    <div class="grid split2 mb4">
      <div class="card"><div class="card-h"><h3>Import</h3><span class="badge badge-sky">${MIGRATION.sources.length} sources</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="row gap1 wrap">${MIGRATION.sources.map(s=>`<span class="chip">${s}</span>`).join('')}</div>
        </div></div>
      <div class="card"><div class="card-h"><h3>Pipeline</h3><span class="badge badge-green">Guarded</span></div>
        <div class="card-body">
          <div class="pipe">${MIGRATION_PIPELINE.map((s,i)=>`<div class="pipe-step"><span class="pipe-n">${i+1}</span><b>${s}</b></div>${i<MIGRATION_PIPELINE.length-1?'<div class="pipe-arrow">→</div>':''}`).join('')}</div>
        </div></div>
    </div>
    <div class="grid cols-4 mb4">
      ${[['Patients imported',MIGRATION.patients,'#0284c7'],['Matched',MIGRATION.matched,'#059669'],['Duplicates',MIGRATION.duplicates,'#d97706'],['Needs review',MIGRATION.review,'#dc2626']].map(([l,v,c])=>`
        <div class="kpi"><div class="kpi-icon" style="background:${c}"><svg class="ic" viewBox="0 0 24 24"><path d="M3 12h18M3 12l4-4M3 12l4 4M21 12l-4-4M21 12l-4 4"/></svg></div><div><div class="kpi-value">${v.toLocaleString()}</div><div class="kpi-label">${l}</div></div></div>`).join('')}
    </div>
    <div class="card"><div class="card-h"><h3>Traceability</h3><span class="badge badge-sky">source → transformation → destination → timestamp → actor</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        <div class="table-wrap"><table>
          <tr><th>Source</th><th>Transformation</th><th>Destination</th><th>Timestamp</th><th>Actor</th></tr>
          <tr><td class="mono">Legacy EMR</td><td>Map + normalize + dedupe</td><td class="mono">PATIENTS</td><td class="mono">18 Aug 04:12</td><td>HMIS Clerk</td></tr>
          <tr><td class="mono">Staff registry</td><td>Match to constitutional roles</td><td class="mono">WORKFORCE</td><td class="mono">19 Aug 09:40</td><td>ICT Officer</td></tr>
          <tr><td class="mono">Spreadsheets</td><td>Validate + reconcile</td><td class="mono">FINANCE</td><td class="mono">19 Aug 11:05</td><td>Finance Officer</td></tr>
        </table></div>
      </div></div>`;
}

/* ---------- HOSPITAL BUILDER ---------- */
function builderScreen(){
  return `
    ${facBar('Hospital Builder', `Visually create and edit the facility structure`)}
    <div class="card mb4"><div class="card-h"><h3>Structure</h3><button class="btn btn-ghost btn-sm" onclick="toast('Builder edit mode (demo)','ok')">✎ Edit structure</button></div>
      <div class="card-body" style="padding-top:var(--sp3)">${infraTree(INFRA)}</div></div>
    <div class="card"><div class="card-h"><h3>Add a unit</h3><span class="badge badge-sky">Constitutional</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        <div class="grid cols-3"><div class="field"><label>Parent</label><select class="input"><option>Main Hospital</option><option>Maternity Campus</option><option>Community Clinics</option></select></div>
        <div class="field"><label>Unit name</label><input class="input" placeholder="e.g. Day Surgery Unit"></div>
        <div class="field"><label>Kind</label><select class="input"><option>Department</option><option>Ward</option><option>Clinic</option><option>Room</option></select></div></div>
        <button class="btn btn-primary mt3" onclick="toast('Unit added to structure (demo)','ok')">Add unit</button>
      </div></div>`;
}

/* ---------- HOSPITAL IDENTITY ---------- */
function identityScreen(){
  const f = FACILITIES.find(x=>x.id===S.facility) || FACILITIES[0];
  const day = dayFor(S.facility);
  const rows=[['Facility name',f.name],['Facility level',f.level],['Ownership','Government of Kisii County'],['County','Kisii'],['Sub-county','Kisii Central'],['License','KTRH-LIC-2026-044'],['Bed capacity',f.beds+' beds'],['Operating hours','24 × 7 Emergency · 08:00–17:00 OPD'],['Emergency capability','Level 1 Trauma · Resuscitation'],['Teaching status','Teaching & Referral'],['Accreditation','NHIF/SHA accredited · COHSASA in progress'],['Reporting identifiers','HMIS: 36111 · MFL: 12345']];
  return `
    ${facBar('Hospital Identity', `The facility's machine-readable constitution`)}
    <div class="card mb4"><div class="card-h"><h3>Identity card</h3><span class="badge badge-green">${f.status}</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        <div class="row gap3 mb4"><div class="fac-monogram" style="background:${f.color};width:64px;height:64px;font-size:22px">${f.code}</div>
          <div><h2 style="font-size:var(--xl)">${f.name}</h2><p class="small muted">${f.level} · ${day.patients} patients today</p></div></div>
        <div class="grid cols-2">
          ${rows.map(([k,v])=>`<div class="field"><label>${k}</label><div>${v}</div></div>`).join('')}
        </div>
        <div class="row gap2 mt4"><button class="btn btn-primary" onclick="toast('Identity updated (demo)','ok')">Save identity</button><button class="btn btn-outline" onclick="toast('Identity exported as constitution (demo)','ok')">Export constitution</button></div>
      </div></div>`;
}

/* ---------- INVITATION LINKS & ROSTER ---------- */
function invitationsScreen(){
  const pending = WORKFORCE.filter(w=>w.status==='Pending activation'||w.status==='Unassigned');
  return `
    ${facBar('Invitation Links & Roster', `Real people join through invitations — identity → organization → facility → department → role → workspace → dashboard`)}
    <div class="grid split2 mb4">
      <div class="card"><div class="card-h"><h3>Generate invitation</h3><span class="badge badge-sky">Role-routed</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="field"><label>Department</label>
            <select class="input" onchange="FInv.dept=this.value">${DEPARTMENTS.map(d=>`<option value="${d.id}" ${d.id===(window.FInv||{dept:'medicine'}).dept?'selected':''}>${d.name}</option>`).join('')}</select></div>
          <div class="field"><label>Role</label>
            <select class="input" onchange="FInv.role=this.value">${WORKFORCE_ROLES.filter(r=>r.id!=='admin').map(r=>`<option value="${r.id}">${r.name}</option>`).join('')}</select></div>
          <button class="btn btn-primary mt3" onclick="window.FInv=window.FInv||{dept:'medicine'};window.FInv.link='https://amexan.health/invite/'+Math.random().toString(36).slice(2,10);renderScreen('invitations')">Generate invitation link</button>
          ${(window.FInv&&FInv.link)?`
            <div class="field mt3"><label>Invitation link</label>
              <div class="mono" style="padding:10px;background:#f8fafc;border:1px dashed var(--border);border-radius:10px">${FInv.link}</div></div>
            <div class="small muted mt2">The person joins → AMEXAN resolves identity, organization membership, facility, department, role, workspace and dashboard.</div>`:''}
        </div></div>
      <div class="card"><div class="card-h"><h3>Roster — pending activation</h3><span class="badge badge-amber">${pending.length}</span></div>
        <div class="table-wrap"><table>
          <tr><th>Identity</th><th>Department</th><th>Role</th><th>Workspace</th><th>Status</th></tr>
          ${pending.length?pending.map(w=>`<tr><td><b>${w.name}</b><div class="tiny muted mono">${w.id}</div></td><td>${w.dept}</td><td>${w.role}</td><td><span class="chip">${w.workspace}</span></td><td><span class="state-pill state-pending">${w.status}</span></td></tr>`).join(''):'<tr><td colspan="5" class="muted">No pending identities.</td></tr>'}
        </table></div></div>
    </div>`;
}
const FInv = {dept:'medicine', role:'medical_officer', link:null};
window.FInv = FInv;

/* ---------- AUTO-CREATE STAFF LOGINS ---------- */
function staffLoginsScreen(){
  const deptOpts=DEPARTMENTS.map(d=>`<option value="${d.id}" ${d.id===FProv.dept?'selected':''}>${d.name}</option>`).join('');
  const roleOpts=WORKFORCE_ROLES.map(r=>`<option value="${r.id}" ${r.id===FProv.role?'selected':''}>${r.name}</option>`).join('');
  const role = WORKFORCE_ROLES.find(r=>r.id===FProv.role) || WORKFORCE_ROLES[0];
  return `
    ${facBar('Auto-create Staff Logins', `One department + one role + a count → that many real Auth logins, each routed to its own constitutional workspace`)}
    <div class="grid split2">
      <div class="card mb4"><div class="card-h"><h3>Auto-create</h3><span class="badge badge-sky">Identity engine</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="field"><label>Department</label><select class="input" onchange="setProv('dept',this.value)">${deptOpts}</select></div>
          <div class="field"><label>Role</label><select class="input" onchange="setProv('role',this.value)">${roleOpts}</select></div>
          <div class="field"><label>Count</label><input class="input" type="number" min="1" max="40" value="${FProv.count}" onchange="setProv('count',this.value)"></div>
          <button class="btn btn-primary mt3" onclick="doProvision('stafflogins')">CREATE ${FProv.count} LOGINS →</button>
          <div class="small muted mt3">Each login: real identity record + authentication account + constitutional workspace routing + dashboard.</div>
        </div></div>
      <div class="card mb4"><div class="card-h"><h3>Provisioning proof</h3><span class="badge badge-sky">${PROVISION_LOG.length} batches</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          ${PROVISION_LOG.length?PROVISION_LOG.map(l=>`
            <div class="fact"><div class="fc">✓</div><div><b>${l.count} × ${l.role} → ${l.dept}</b><p>${l.count} identities · ${l.count} workspaces · ${l.count} Auth accounts · ${l.t}</p><span class="badge badge-sky">Routing: ${role.workspace}</span></div></div>`).join(''):'<div class="empty" style="padding:var(--sp4)"><p>No provisioning yet. Run one to see identities appear in Workforce Command.</p></div>'}
          <button class="btn btn-outline btn-block mt3" onclick="go('workforce')">VIEW PROVISIONED STAFF →</button>
        </div></div>
    </div>`;
}

/* ---------- INTEGRATIONS — EXTERNAL CONNECTIVITY CONTROL PLANE ----------
   The Facility Admin's view of everything AMEXAN connects outward.
   Never implies production access: every card says DEMO CONNECTED /
   DEMO CONNECTION / PENDING CONFIGURATION. Operational health,
   direction, data domains, owner, activity and failures — no raw secrets.
   Operational visibility does not imply production connectivity. */
const INT_GROUPS = [
  ['NATIONAL & EXTERNAL SYSTEMS', ['national','dha','hie','pharmacy','sha']],
  ['CLINICAL SYSTEMS', ['lis','ris','ambulance']]
];
const INT_RECENT = {
  lis:[['20:11','Lab result received'],['20:08','CBC order transmitted'],['20:04','Chemistry order transmitted'],['20:02','Validation failure — order blocked']],
  national:[['20:05','Simulated transmission acknowledged'],['20:01','DHIS2 report staged'],['19:57','Facility indicator aggregated']],
  dha:[['19:48','Simulated patient-summary exchange'],['19:40','Identity record matched'],['19:31','Summary prepared']],
  hie:[['19:42','Simulated referral context exchange'],['19:36','Acknowledgement received (KCH)'],['19:28','Encounter summary prepared']],
  pharmacy:[['20:02','Stock level sync'],['19:55','Requisition transmitted'],['19:47','Amoxicillin syrup below reorder level']],
  sha:[['19:55','Claim staged for review'],['19:51','Validation failure — auth reference'],['19:44','Claim line mapped']],
  ris:[['—','Awaiting endpoint configuration'],['—','17 imaging requests staged in preview']],
  ambulance:[['20:07','Simulated ETA handover'],['19:58','Transport status received'],['19:50','Triage handover prepared']]
};
function setIntConn(id){ S.intConn=id; renderScreen('integrations'); }
function clearIntConn(){ S.intConn=null; renderScreen('integrations'); }
window.setIntConn=setIntConn; window.clearIntConn=clearIntConn;

function integrationScreen(){
  if(S.intConn) return intConnDetail(S.intConn);
  const sum = INTEGRATION_SUMMARY;
  const tx = sum.tx;
  const reg = INTEGRATIONS.map(i=>[i.name, i.kind, i.direction, i.badge, i.last]);
  const groups = INT_GROUPS.map(([title, ids])=>`
    <div class="mb4"><h3 class="cops-title">${title}</h3>
      <div class="grid cols-2">
        ${ids.map(id=>intCard(INTEGRATIONS.find(x=>x.id===id))).join('')}
      </div>
    </div>`).join('');
  return `
    ${facBar('Integrations', `Where AMEXAN connects outward — external connectivity control plane`)}
    <div class="demo-env">
      <b>DEMO ENVIRONMENT</b>
      <span>External integrations shown here are simulated unless explicitly marked otherwise. No production national-system, payer, HIE, LIS, RIS/PACS or ambulance transaction is being transmitted from this demo.</span>
    </div>

    <div class="grid split2 mb4">
      <div class="card">
        <div class="card-h"><h3>Interoperability health</h3><span class="badge badge-green">Demo environment</span></div>
        <div class="card-body">
          <div class="int-health">
            <div>${intStat(sum.configured,'Configured connections')}</div>
            <div>${intStat(sum.demoActive,'Demo-active')}</div>
            <div>${intStat(sum.internal,'Connected internally')}</div>
            <div>${intStat(sum.pending,'Pending configuration','#d97706')}</div>
            <div>${intStat(sum.critical,'Critical failures','#dc2626')}</div>
          </div>
          <div class="row gap3 mt3 wrap" style="align-items:center">
            <div style="text-align:center">${miniDonut(sum.health,'#0284c7',120,'health')}</div>
            <div class="small muted" style="flex:1;min-width:160px">Last evaluated: <b>${sum.evaluated}</b><br>${sum.health}% interoperability health across configured connections.</div>
          </div>
        </div>
      </div>
      <div class="card">
        <div class="card-h"><h3>Connectivity status</h3><span class="badge badge-sky">${sum.configured} connections</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          ${[['Demo-active','#059669','DEMO CONNECTION / DEMO CONNECTED'],['Internal facility','#0284c7','LIS + Pharmacy supply'],['Pending configuration','#d97706','RIS/PACS'],['Critical failures','#dc2626','None right now']].map(([k,c,note])=>`
            <div class="row-b mb3" style="padding:9px 0;border-bottom:1px solid var(--neutral-100)"><div class="row gap2"><span class="dot" style="background:${c}"></span><b style="font-size:var(--sm)">${k}</b></div><span class="tiny muted">${note}</span></div>`).join('')}
        </div>
      </div>
    </div>

    ${groups}

    <div class="card mb4">
      <div class="card-h"><h3>Connection Registry</h3><span class="badge badge-sky">${sum.configured} registered</span></div>
      <div class="table-wrap"><table>
        <tr><th>Connection</th><th>Type</th><th>Direction</th><th>Status</th><th>Last activity</th></tr>
        ${reg.map(r=>`<tr><td><b style="font-size:var(--sm)">${r[0]}</b></td><td>${r[1]}</td><td><span class="chip">${r[2]}</span></td><td><span class="badge ${r[3].includes('PENDING')?'badge-amber':'badge-green'}">${r[3]}</span></td><td class="mono">${r[4]}</td></tr>`).join('')}
      </table></div>
    </div>

    <div class="grid split2 mb4">
      <div class="card">
        <div class="card-h"><h3>Exchange Monitor</h3><span class="badge badge-sky">Today</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="int-health">
            <div>${intStat(tx.today.toLocaleString(),'Transactions today')}</div>
            <div>${intStat(tx.ok.toLocaleString(),'Successful','#059669')}</div>
            <div>${intStat(tx.pendingTx,'Pending','#d97706')}</div>
            <div>${intStat(tx.failed,'Failed','#dc2626')}</div>
          </div>
        </div></div>
      <div class="card">
        <div class="card-h"><h3>Failed exchanges</h3><span class="badge badge-red">${INTEGRATION_FAILURES.length} surfaced</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          ${INTEGRATION_FAILURES.map(f=>`
            <div class="fact flag"><div class="fc">!</div><div><b>${f.id} — ${f.type}</b><p>${f.time} · ${f.reason}</p><span class="badge badge-gray">${f.action}</span></div></div>`).join('')}
          <div class="small muted mt3">Failures surface here — they never silently disappear.</div>
        </div></div>
    </div>

    <div class="card mb4">
      <div class="card-h"><h3>Interoperability architecture</h3><span class="badge badge-sky">AMEXAN → Layer → External</span></div>
      <div class="card-body">
        <div class="pipe mb3">
          <div class="pipe-step"><span class="pipe-n">1</span><b>AMEXAN</b></div><div class="pipe-arrow">→</div>
          <div class="pipe-step"><span class="pipe-n">2</span><b>${INTEGRATION_ARCH.layer}</b></div><div class="pipe-arrow">→</div>
          <div class="pipe-step"><span class="pipe-n">3</span><b>External systems</b></div>
        </div>
        <div class="arch-rows">
          ${INTEGRATION_ARCH.core.map(([k,sub],i)=>`
            <div class="arch-row">
              <b>${k}</b>
              <div class="pipe-arrow">↓</div>
              <span class="small muted">${sub}</span>
            </div>`).join('')}
          <div class="small muted mt3">Every module talks to the Interoperability Layer — never directly to every external system.</div>
        </div>
      </div></div>

    <div class="card mb4">
      <div class="card-h"><h3>Interoperability mapping</h3><span class="badge badge-sky">AMEXAN → Interop → External</span></div>
      <div class="card-body">
        ${INTEGRATION_MAPPINGS.map(m=>`
          <div class="pipe mb3">
            <div class="pipe-step"><b>${m.from}</b></div><div class="pipe-arrow">↓</div>
            <div class="pipe-step">${m.mid}</div><div class="pipe-arrow">↓</div>
            <div class="pipe-step">${m.to}</div>
          </div>`).join('')}
      </div></div>

    <div class="card mb4">
      <div class="card-h"><h3>Data Governance</h3><span class="badge badge-sky">Every external exchange</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        <div class="gov-grid">
          ${INTEGRATION_GOVERNANCE.map(([k,v])=>`<div class="gov-item"><b>${k}</b><p>${v}</p></div>`).join('')}
        </div>
      </div></div>

    <div class="card mb4">
      <div class="card-h"><h3>Connection states</h3><span class="badge badge-sky">State model</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        <div class="gov-grid">
          ${[['CONNECTED','Production credentials verified and successful exchange observed'],['DEMO CONNECTED','Simulated exchange only'],['CONFIGURED','Settings exist, connection not verified'],['PENDING','Required configuration incomplete'],['DEGRADED','Connection exists but errors/latency exceed thresholds'],['FAILED','Connection unavailable'],['DISABLED','Intentionally inactive']].map(([k,v])=>`
            <div class="gov-item"><b style="color:${k==='PENDING'?'#d97706':k.includes('DEMO')?'#059669':'#0f172a'}">${k}</b><p>${v}</p></div>`).join('')}
        </div>
      </div></div>

    <div class="card">
      <div class="card-h"><h3>Integration actions</h3><span class="badge badge-sky">Facility Administrator</span></div>
      <div class="card-body">
        <div class="grid cols-4" style="gap:var(--sp2)">
          ${[['Add connection','Governed workflow — not instant activation','#0284c7'],['Run connection test','Authorized test connection only','#059669'],['View exchange monitor','Today’s transaction picture','#7c3aed'],['View data mappings','Interoperability layer mapping','#0891b2'],['Review failures','Surfaced, never hidden','#dc2626'],['View audit','Every transmission traceable','#d97706'],['Integration policies','Data governance & authorization','#0ea5e9'],['Configure endpoints','ICT Officer technical workspace','#7c3aed']].map(([k,v,c])=>`
            <button class="qa-btn" onclick="toast('${k} — governed workflow (demo)','ok')"><svg class="ic" viewBox="0 0 24 24" style="color:${c}"><path d="M5 3h14v18l-2-1-2 1-2-1-2 1-2-1-2 1Z"/></svg><b>${k}</b><small>${v}</small></button>`).join('')}
        </div>
      </div></div>`;
}

function intCard(i){
  const badgeCls = i.badge.includes('PENDING') ? 'badge-amber' : 'badge-green';
  const dirTag = i.dir==='outbound' ? '→ Outbound' : i.dir==='in' ? '← Inbound' : '↔ Bidirectional';
  return `
    <button class="int-card" onclick="setIntConn('${i.id}')">
      <div class="row-b mb2" style="gap:10px;align-items:flex-start">
        <div><b>${i.name}</b><div class="tiny muted">${i.kind}</div></div>
        <span class="badge ${badgeCls}">${i.badge}</span>
      </div>
      <div class="int-purpose">${i.purpose}</div>
      <div class="int-data">${i.data.map(d=>`<span class="chip">${d}</span>`).join('')}</div>
      <div class="row-b mt3" style="border-top:1px dashed var(--neutral-200);padding-top:10px">
        <div class="small"><span class="tiny muted">Direction</span><br><b style="font-size:var(--sm)">${i.direction}</b> <span class="chip">${dirTag}</span></div>
      </div>
      <div class="row-b mt2" style="padding-top:2px">
        <span class="tiny muted">Last activity: <b>${i.last}</b> · Owner: <b>${i.owner}</b></span>
        <span style="color:var(--primary);font-size:var(--sm);font-weight:600">${i.action} ›</span>
      </div>
    </button>`;
}
function intStat(v,label,c){
  return `<div class="int-stat"><b style="${c?`color:${c}`:''}">${v}</b><span>${label}</span></div>`;
}

function intConnDetail(id){
  const i = INTEGRATIONS.find(x=>x.id===id);
  const recent = INT_RECENT[id] || [];
  const badgeCls = i.badge.includes('PENDING') ? 'badge-amber' : 'badge-green';
  return `
    ${facBar(`${i.name}`, `${i.kind} · ${i.purpose}`)}
    <button class="btn btn-outline btn-sm mb4" onclick="clearIntConn()">← All connections</button>
    <div class="demo-env">
      <b>${i.badge}</b>
      <span>${i.note}. No production transaction is being transmitted from this demo.</span>
    </div>
    <div class="grid split2 mb4">
      <div class="card">
        <div class="card-h"><h3>Connection health</h3><span class="badge ${badgeCls}">${i.badge}</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          ${[['Status', i.badge],['Last activity', i.last],['Direction', i.direction],['Owner', i.owner],['Authentication','Configured'],['Certificate','Valid'],['Endpoint','Verified']].map(([k,v])=>`
            <div class="row-b mb3" style="padding:8px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm)">${k}</b><span>${v}</span></div>`).join('')}
          ${i.extra?`<div class="fact mt3"><div class="fc">i</div><div><b>${i.extra}</b></div></div>`:''}
        </div></div>
      <div class="card">
        <div class="card-h"><h3>Data flow</h3><span class="badge badge-sky">${i.direction}</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="pipe mb3">
            ${i.dir==='bidir'
              ? `<div class="pipe-step"><b>AMEXAN</b></div><div class="pipe-arrow">↔</div><div class="pipe-step"><b>${i.kind}</b></div>`
              : i.dir==='outbound'
              ? `<div class="pipe-step"><b>AMEXAN</b></div><div class="pipe-arrow">→</div><div class="pipe-step"><b>${i.kind}</b></div>`
              : `<div class="pipe-step"><b>External</b></div><div class="pipe-arrow">→</div><div class="pipe-step"><b>AMEXAN</b></div>`}
          </div>
          <div class="small muted mb3">Data domains authorized for this connection</div>
          <div class="int-data">${i.data.map(d=>`<span class="chip">${d}</span>`).join('')}</div>
        </div></div>
    </div>
    <div class="card">
      <div class="card-h"><h3>Recent activity</h3><span class="badge badge-sky">Simulated</span></div>
      <div class="card-body" style="padding-top:var(--sp2)">
        ${recent.map(r=>`<div class="feed-item"><span class="mono small muted">${r[0]}</span><p>${r[1]}</p></div>`).join('')}
        <div class="small muted mt3">Operational activity only — no patient-level clinical values on this administrative screen.</div>
        <div class="row gap2 mt3"><button class="btn btn-primary" onclick="toast('${i.action.replace(' →','')} — governed workflow (demo)','ok')">${i.action}</button><button class="btn btn-outline" onclick="clearIntConn()">Back to all connections</button></div>
      </div></div>`;
}
/* ---------- MARKETPLACE ---------- */
function marketplaceScreen(){
  return `
    ${facBar('Marketplace', `Request → Approval → Procurement → Supplier → Delivery → Asset/Inventory`)}
    <div class="card mb4"><div class="card-h"><h3>Procurement pipeline</h3><span class="badge badge-green">Guarded</span></div>
      <div class="card-body">
        <div class="pipe">${['Request','Approval','Procurement','Supplier','Delivery','Asset / Inventory'].map((s,i)=>`<div class="pipe-step"><span class="pipe-n">${i+1}</span><b>${s}</b></div>${i<5?'<div class="pipe-arrow">→</div>':''}`).join('')}</div>
      </div></div>
    <div class="card"><div class="card-h"><h3>Approved suppliers</h3><span class="badge badge-sky">${MARKETPLACE.length}</span></div>
      <div class="table-wrap"><table>
        <tr><th>Supplier</th><th>Category</th><th>Relationship</th><th>Orders</th><th></th></tr>
        ${MARKETPLACE.map(m=>`<tr><td><b>${m.name}</b></td><td>${m.cat}</td><td><span class="chip">${m.rel}</span></td><td class="mono">${m.orders}</td><td><button class="btn btn-primary btn-sm" onclick="toast('Purchase request created (demo)','ok')">Order</button></td></tr>`).join('')}
      </table></div></div>`;
}
window.facilityScreen = facilityScreen;