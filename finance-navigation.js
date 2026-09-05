/* Finance navigation, progressive disclosure and authenticated read-only backup export. */
(() => {
  const root = document.getElementById('tab-fin');
  if (!root) return;
  const groups = [
    ['overview', 'Overzicht', ['finDashboard']],
    ['planning', 'Planning', ['finTimeline']],
    ['budgets', 'Budgetten', ['finKnab']],
    ['oneoff', 'Eenmalige uitgaven', ['finEenmaligeUItgaven']],
    ['fixed', 'Vaste lasten', ['finVaste']],
    ['subscriptions', 'Abonnementen', ['finVariabeleLasten']],
    ['debts', 'Schulden', ['finSchulden', 'finAnwbRegeling']],
    ['history', 'Historie', ['finHistorie']],
    ['settings', 'Beheer', []],
  ];
  const timeline = document.getElementById('finTimeline');
  const planning = document.createElement('section');
  planning.className = 'section';
  const heading = document.createElement('h2');
  heading.className = 'section-title';
  heading.textContent = 'Maandplanning';
  planning.append(heading, timeline);
  root.append(planning);
  const management = document.createElement('section');
  management.className = 'section';
  const managementTitle = document.createElement('h2');
  managementTitle.textContent = 'Beheer';
  management.append(managementTitle);
  const backupButton = document.createElement('button');
  backupButton.type = 'button';
  backupButton.className = 'btn-outline';
  backupButton.textContent = 'Financiële backup downloaden';
  const backupStatus = document.createElement('p');
  backupStatus.setAttribute('role', 'status');
  backupButton.addEventListener('click', async () => {
    if (!currentUser) { backupStatus.textContent = 'Log opnieuw in om een backup te maken.'; return; }
    backupButton.disabled = true;
    backupStatus.textContent = 'Gegevens ophalen…';
    try {
      const [finance, settings] = await Promise.all([
        sb.from('finance').select('*').eq('user_id', currentUser.id).order('month_key'),
        sb.from('settings').select('*').eq('user_id', currentUser.id),
      ]);
      if (finance.error || settings.error) throw new Error('backup unavailable');
      const payload = {format:'daily-coach-finance-backup',version:1,exportedAt:new Date().toISOString(),finance:finance.data,settings:settings.data};
      const url = URL.createObjectURL(new Blob([JSON.stringify(payload,null,2)], {type:'application/json'}));
      const link = document.createElement('a');
      link.href = url;
      link.download = `daily-coach-finance-backup-${new Date().toISOString().slice(0,10)}.json`;
      link.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
      backupStatus.textContent = 'Download aangevraagd. Controleer het bestand in Downloads en bewaar het privé; het bevat je financiële gegevens en instellingen.';
    } catch {
      backupStatus.textContent = 'Backup ophalen mislukt. Er is niets gewijzigd. Controleer je verbinding en probeer opnieuw.';
    } finally { backupButton.disabled = false; }
  });
  management.append(backupButton, backupStatus);
  root.querySelectorAll(':scope > button').forEach(button => management.append(button));
  root.append(management);
  const nav = document.createElement('nav');
  nav.className = 'finance-navigation';
  nav.setAttribute('aria-label', 'Financiële onderdelen');
  const sections = [...root.querySelectorAll(':scope > .section')];
  const buttons = [];
  function select(key) {
    const group = groups.find(item => item[0] === key);
    const visible = key === 'settings' ? [management] : group[2].map(id => document.getElementById(id).closest('.section'));
    sections.forEach(section => { section.hidden = !visible.includes(section); });
    buttons.forEach(button => {
      const active = button.dataset.view === key;
      button.setAttribute('aria-current', active ? 'page' : 'false');
    });
  }
  groups.forEach(([key, label]) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.dataset.view = key;
    button.textContent = label;
    button.addEventListener('click', () => select(key));
    buttons.push(button);
    nav.append(button);
  });
  root.prepend(nav);
  function compactBudgets() {
    root.querySelectorAll('.knab-tx-list').forEach(list => {
      if (list.dataset.compact) return;
      list.dataset.compact = 'true';
      const rows = [...list.children];
      if (rows.length <= 3) return;
      const details = document.createElement('details');
      const summary = document.createElement('summary');
      summary.textContent = `Nog ${rows.length - 3} transacties bekijken`;
      details.append(summary, ...rows.slice(3));
      list.append(details);
    });
    root.querySelectorAll('.knab-tx-form').forEach(form => {
      const amount = form.querySelector('input[type="number"]');
      const description = form.querySelector('input[type="text"]');
      const submit = form.querySelector('button');
      amount?.setAttribute('aria-label', 'Bedrag van uitgave');
      description?.setAttribute('aria-label', 'Omschrijving van uitgave');
      submit?.setAttribute('aria-label', 'Uitgave toevoegen');
    });
  }
  const budgetRoot = document.getElementById('finKnab');
  const observer = new MutationObserver(() => {
    observer.disconnect();
    compactBudgets();
    observer.observe(budgetRoot, {childList:true, subtree:true});
  });
  observer.observe(budgetRoot, {childList:true, subtree:true});
  compactBudgets();
  const fixedRoot = document.getElementById('finVaste');
  function compactFixed() {
    const paidRows = [...fixedRoot.querySelectorAll(':scope > .fin-list-item.betaald')];
    if (paidRows.length) {
      const paidDetails = document.createElement('details');
      paidDetails.className = 'finance-paid-group';
      const summary = document.createElement('summary');
      summary.textContent = `${paidRows.length} betaalde vaste lasten bekijken`;
      paidDetails.append(summary, ...paidRows);
      fixedRoot.append(paidDetails);
    }
    fixedRoot.querySelectorAll('.fin-item-actions').forEach(actions => {
      if (actions.parentElement.matches('details')) return;
      const row = actions.closest('.fin-list-item');
      const name = row.querySelector('.fin-item-naam')?.textContent || 'vaste last';
      const details = document.createElement('details');
      details.className = 'finance-row-options';
      const summary = document.createElement('summary');
      summary.textContent = 'Opties';
      summary.setAttribute('aria-label', `Opties voor ${name}`);
      actions.before(details);
      details.append(summary, actions);
      actions.querySelector('.fin-edit-btn')?.setAttribute('aria-label', `Bewerk ${name}`);
      actions.querySelector('.fin-delete-btn')?.setAttribute('aria-label', `Verwijder ${name}`);
    });
  }
  const fixedObserver = new MutationObserver(() => {
    fixedObserver.disconnect();
    compactFixed();
    fixedObserver.observe(fixedRoot, {childList:true, subtree:true});
  });
  compactFixed();
  fixedObserver.observe(fixedRoot, {childList:true, subtree:true});
  function compactPlanning() {
    const list = timeline.querySelector('.fin-timeline');
    if (!list) return;
    const completed = [...list.querySelectorAll(':scope > .fin-tl-item')].filter(row => row.querySelector('.done'));
    if (!completed.length) return;
    const details = document.createElement('details');
    const summary = document.createElement('summary');
    summary.textContent = `${completed.length} verwerkte posten bekijken`;
    details.append(summary, ...completed);
    list.append(details);
  }
  const planningObserver = new MutationObserver(() => {
    planningObserver.disconnect();
    compactPlanning();
    planningObserver.observe(timeline, {childList:true, subtree:true});
  });
  compactPlanning();
  planningObserver.observe(timeline, {childList:true, subtree:true});
  select('overview');
})();
