const refreshButton = document.querySelector('#refreshButton');
const lastUpdated = document.querySelector('#lastUpdated');
const summary = document.querySelector('#summary');
const servicesRoot = document.querySelector('#services');
const serviceSearch = document.querySelector('#serviceSearch');
const serviceFilterMeta = document.querySelector('#serviceFilterMeta');
const logTitle = document.querySelector('#logTitle');
const logMeta = document.querySelector('#logMeta');
const logOutput = document.querySelector('#logOutput');
const lineCount = document.querySelector('#lineCount');
const themeToggle = document.querySelector('#themeToggle');
const themeStorageKey = 'local-monitor-theme';

const state = {
  services: [],
  selectedServiceId: null,
  searchTerm: '',
  collapsedGroups: new Set(['core', 'wallet', 'infra']),
};

const groupOrder = ['wallet', 'core', 'infra'];
const groupTitles = {
  infra: 'Infrastructure',
  core: 'Core services',
  wallet: 'Wallet and Pivotal',
};

const setTheme = (theme) => {
  const normalizedTheme = theme === 'light' ? 'light' : 'dark';
  document.documentElement.dataset.theme = normalizedTheme;
  localStorage.setItem(themeStorageKey, normalizedTheme);

  if (themeToggle != null) {
    themeToggle.textContent = normalizedTheme === 'dark' ? 'Light mode' : 'Dark mode';
    themeToggle.setAttribute('aria-pressed', String(normalizedTheme === 'dark'));
  }
};

setTheme(localStorage.getItem(themeStorageKey) || document.documentElement.dataset.theme || 'dark');

const escapeHtml = (value) => value
  .replaceAll('&', '&amp;')
  .replaceAll('<', '&lt;')
  .replaceAll('>', '&gt;');

const ansiFgClasses = new Map([
  [30, 'ansi-fg-black'],
  [31, 'ansi-fg-red'],
  [32, 'ansi-fg-green'],
  [33, 'ansi-fg-yellow'],
  [34, 'ansi-fg-blue'],
  [35, 'ansi-fg-magenta'],
  [36, 'ansi-fg-cyan'],
  [37, 'ansi-fg-white'],
  [90, 'ansi-fg-bright-black'],
  [91, 'ansi-fg-bright-red'],
  [92, 'ansi-fg-bright-green'],
  [93, 'ansi-fg-bright-yellow'],
  [94, 'ansi-fg-bright-blue'],
  [95, 'ansi-fg-bright-magenta'],
  [96, 'ansi-fg-bright-cyan'],
  [97, 'ansi-fg-bright-white'],
]);

const highlightLogLevels = (value) => value.replace(
  /\b(error|err|warn|warning|info|log|debug|audit|trace)\b/gi,
  (match) => {
    const normalized = match.toLowerCase();
    const level = normalized === 'warning' ? 'warn' : normalized === 'err' ? 'error' : normalized;
    return `<span class="log-level log-level-${level}">${match}</span>`;
  },
);

const ansiStateClasses = ({ fgClass, bold, dim }) => [
  fgClass,
  bold ? 'ansi-bold' : null,
  dim ? 'ansi-dim' : null,
].filter(Boolean);

const ansiToHtml = (value) => {
  const ansiPattern = /\x1b\[([0-9;]*)m/g;
  const state = {
    fgClass: null,
    bold: false,
    dim: false,
  };
  let cursor = 0;
  let html = '';
  let match;

  const renderSegment = (text) => {
    if (text.length === 0) {
      return '';
    }

    const escaped = highlightLogLevels(escapeHtml(text));
    const classes = ansiStateClasses(state);
    return classes.length === 0
      ? escaped
      : `<span class="${classes.join(' ')}">${escaped}</span>`;
  };

  const applyAnsiCodes = (codes) => {
    for (const code of codes) {
      if (code === 0) {
        state.fgClass = null;
        state.bold = false;
        state.dim = false;
      } else if (code === 1) {
        state.bold = true;
      } else if (code === 2) {
        state.dim = true;
      } else if (code === 22) {
        state.bold = false;
        state.dim = false;
      } else if (code === 39) {
        state.fgClass = null;
      } else if (ansiFgClasses.has(code)) {
        state.fgClass = ansiFgClasses.get(code);
      }
    }
  };

  while ((match = ansiPattern.exec(value)) !== null) {
    html += renderSegment(value.slice(cursor, match.index));
    applyAnsiCodes(match[1] === '' ? [0] : match[1].split(';').map(Number));
    cursor = ansiPattern.lastIndex;
  }

  html += renderSegment(value.slice(cursor));
  return html;
};

const serviceStateClass = (service) => {
  if (!service.running) {
    return 'error';
  }
  if (service.health?.state === 'error') {
    return 'warn';
  }
  return 'ok';
};

const healthLabel = (service) => {
  if (service.healthUrl == null) {
    return service.running ? 'No HTTP health' : 'Stopped';
  }

  if (service.health?.state === 'ok') {
    return `Health OK${service.health.detail ? `: ${service.health.detail}` : ''}`;
  }

  if (service.health?.state === 'error') {
    return `Health error${service.health.detail ? `: ${service.health.detail}` : ''}`;
  }

  return 'Health unknown';
};

const filteredServices = () => {
  const term = state.searchTerm.trim().toLowerCase();

  if (term.length === 0) {
    return state.services;
  }

  return state.services.filter((service) => {
    const haystack = [
      service.name,
      service.id,
      service.group,
      service.port != null ? String(service.port) : '',
      service.health?.detail ?? '',
      service.log?.path ?? '',
    ].join(' ').toLowerCase();

    return haystack.includes(term);
  });
};

const renderSummary = (totals) => {
  summary.innerHTML = `
    <article class="summary-card">
      <span class="summary-label">Total</span>
      <strong>${totals.total}</strong>
    </article>
    <article class="summary-card">
      <span class="summary-label">Running</span>
      <strong>${totals.running}</strong>
    </article>
    <article class="summary-card">
      <span class="summary-label">Stopped</span>
      <strong>${totals.stopped}</strong>
    </article>
    <article class="summary-card">
      <span class="summary-label">Health issues</span>
      <strong>${totals.unhealthy}</strong>
    </article>
  `;
};

const renderServices = () => {
  const grouped = new Map(groupOrder.map((group) => [group, []]));
  const visibleServices = filteredServices();
  const searchActive = state.searchTerm.trim().length > 0;

  for (const service of visibleServices) {
    grouped.get(service.group)?.push(service);
  }

  const visibleCount = visibleServices.length;
  serviceFilterMeta.textContent = !searchActive
    ? `Showing all ${state.services.length} services.`
    : `Showing ${visibleCount} of ${state.services.length} services for "${state.searchTerm.trim()}".`;

  const groupsHtml = groupOrder.map((group) => {
    const services = grouped.get(group) ?? [];
    if (services.length === 0) {
      return '';
    }

    const collapsed = !searchActive && state.collapsedGroups.has(group);
    const serviceCountLabel = `${services.length} service${services.length === 1 ? '' : 's'}`;

    return `
      <section class="service-group">
        <header class="group-header">
          <button class="group-toggle" type="button" data-group-id="${group}" aria-expanded="${!collapsed}">
            <span class="group-title">${groupTitles[group] ?? group}</span>
            <span class="group-meta">${searchActive ? 'Expanded by search' : serviceCountLabel}</span>
            <span class="group-caret" aria-hidden="true">${collapsed ? 'Show' : 'Hide'}</span>
          </button>
        </header>
        <div class="service-grid${collapsed ? ' collapsed' : ''}">
          ${services.map((service) => {
            const tone = serviceStateClass(service);
            const selected = service.id === state.selectedServiceId ? ' selected' : '';
            return `
              <button class="service-card ${tone}${selected}" data-service-id="${service.id}">
                <div class="service-card-top">
                  <span class="service-name">${service.name}</span>
                  <span class="badge ${tone}">${service.running ? 'UP' : 'DOWN'}</span>
                </div>
                <div class="service-card-meta">
                  <span>${healthLabel(service)}</span>
                  <span>${service.port != null ? `Port ${service.port}` : 'No port'}</span>
                  <span>${service.pid != null ? `PID ${service.pid}` : 'No PID file'}</span>
                </div>
              </button>
            `;
          }).join('')}
        </div>
      </section>
    `;
  }).join('');

  if (visibleCount === 0) {
    servicesRoot.innerHTML = `
      <section class="empty-state">
        <h3>No services match this filter.</h3>
        <p>Try a DFSP name, service id, group, or port number.</p>
      </section>
    `;
  } else {
    servicesRoot.innerHTML = groupsHtml;
  }

  for (const button of servicesRoot.querySelectorAll('[data-service-id]')) {
    button.addEventListener('click', () => {
      state.selectedServiceId = button.dataset.serviceId;
      renderServices();
      void refreshLogs();
    });
  }

  for (const button of servicesRoot.querySelectorAll('[data-group-id]')) {
    button.addEventListener('click', () => {
      const group = button.dataset.groupId;
      if (group == null || searchActive) {
        return;
      }

      if (state.collapsedGroups.has(group)) {
        state.collapsedGroups.delete(group);
      } else {
        state.collapsedGroups.add(group);
      }

      renderServices();
    });
  }
};

const refreshStatus = async () => {
  const response = await fetch('/api/status', { cache: 'no-store' });
  if (!response.ok) {
    throw new Error(`Status request failed with ${response.status}`);
  }

  const payload = await response.json();
  state.services = payload.services;
  if (state.selectedServiceId == null || !state.services.some((service) => service.id === state.selectedServiceId)) {
    const preferred = state.services.find((service) => !service.running || service.health?.state === 'error') ?? state.services[0];
    state.selectedServiceId = preferred?.id ?? null;
  }

  renderSummary(payload.totals);
  renderServices();
  lastUpdated.textContent = `Updated ${new Date(payload.generatedAt).toLocaleTimeString()}`;
};

const refreshLogs = async () => {
  const selected = state.services.find((service) => service.id === state.selectedServiceId);

  if (selected == null) {
    logTitle.textContent = 'Logs';
    logMeta.textContent = 'Select a service card to view its log.';
    logOutput.textContent = 'No service selected.';
    return;
  }

  const response = await fetch(`/api/logs?id=${encodeURIComponent(selected.id)}&lines=${encodeURIComponent(lineCount.value)}`, {
    cache: 'no-store',
  });

  if (!response.ok) {
    throw new Error(`Log request failed with ${response.status}`);
  }

  const payload = await response.json();
  logTitle.textContent = selected.name;
  logMeta.textContent = payload.exists
    ? `${payload.path} · ${payload.updatedAt ?? 'unknown update'}${payload.truncated ? ' · showing tail only' : ''}`
    : 'No log file found for this service yet.';
  logOutput.innerHTML = payload.exists
    ? ansiToHtml(payload.text || '(log file is empty)')
    : 'Log file not found.';
};

const refreshAll = async () => {
  try {
    await refreshStatus();
    await refreshLogs();
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    lastUpdated.textContent = `Refresh failed: ${message}`;
  }
};

refreshButton.addEventListener('click', () => {
  void refreshAll();
});

themeToggle?.addEventListener('click', () => {
  setTheme(document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark');
});

lineCount.addEventListener('change', () => {
  void refreshLogs();
});

serviceSearch.addEventListener('input', () => {
  state.searchTerm = serviceSearch.value;
  renderServices();
});

void refreshAll();
window.setInterval(() => {
  void refreshStatus();
}, 5000);
window.setInterval(() => {
  void refreshLogs();
}, 2500);
