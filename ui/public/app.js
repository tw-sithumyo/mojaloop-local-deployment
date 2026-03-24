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

const state = {
  services: [],
  selectedServiceId: null,
  searchTerm: '',
};

const groupOrder = ['infra', 'core', 'wallet'];
const groupTitles = {
  infra: 'Infrastructure',
  core: 'Core services',
  wallet: 'Wallet and MTPA',
};

const ansiPattern = /\u001b\[([0-9;]*)m/g;

const ansiNamedColors = {
  30: '#20252b',
  31: '#f26d78',
  32: '#69d48f',
  33: '#f1c56b',
  34: '#7db5ff',
  35: '#c792ea',
  36: '#68d7e5',
  37: '#e8eef2',
  90: '#7d8793',
  91: '#ff8c96',
  92: '#90efaa',
  93: '#ffd98d',
  94: '#9dc9ff',
  95: '#ddb1ff',
  96: '#8ae6f1',
  97: '#ffffff',
};

const escapeHtml = (value) => value
  .replaceAll('&', '&amp;')
  .replaceAll('<', '&lt;')
  .replaceAll('>', '&gt;');

const defaultAnsiState = () => ({
  bold: false,
  dim: false,
  italic: false,
  underline: false,
  inverse: false,
  fg: null,
  bg: null,
});

const clampColor = (value) => Math.max(0, Math.min(255, value));

const xtermColor = (index) => {
  if (index < 16) {
    const key = index < 8 ? 30 + index : 90 + (index - 8);
    return ansiNamedColors[key];
  }

  if (index >= 16 && index <= 231) {
    const offset = index - 16;
    const levels = [0, 95, 135, 175, 215, 255];
    const red = levels[Math.floor(offset / 36) % 6];
    const green = levels[Math.floor(offset / 6) % 6];
    const blue = levels[offset % 6];
    return `rgb(${red}, ${green}, ${blue})`;
  }

  const shade = clampColor(8 + ((index - 232) * 10));
  return `rgb(${shade}, ${shade}, ${shade})`;
};

const applyAnsiCodes = (state, rawCodes) => {
  const codes = rawCodes.length === 0 ? [0] : rawCodes;

  for (let index = 0; index < codes.length; index += 1) {
    const code = codes[index];

    if (Number.isNaN(code)) {
      continue;
    }

    if (code === 0) {
      state.bold = false;
      state.dim = false;
      state.italic = false;
      state.underline = false;
      state.inverse = false;
      state.fg = null;
      state.bg = null;
      continue;
    }

    if (code === 1) {
      state.bold = true;
      continue;
    }

    if (code === 2) {
      state.dim = true;
      continue;
    }

    if (code === 3) {
      state.italic = true;
      continue;
    }

    if (code === 4) {
      state.underline = true;
      continue;
    }

    if (code === 7) {
      state.inverse = true;
      continue;
    }

    if (code === 22) {
      state.bold = false;
      state.dim = false;
      continue;
    }

    if (code === 23) {
      state.italic = false;
      continue;
    }

    if (code === 24) {
      state.underline = false;
      continue;
    }

    if (code === 27) {
      state.inverse = false;
      continue;
    }

    if (code === 39) {
      state.fg = null;
      continue;
    }

    if (code === 49) {
      state.bg = null;
      continue;
    }

    if ((code >= 30 && code <= 37) || (code >= 90 && code <= 97)) {
      state.fg = ansiNamedColors[code] ?? null;
      continue;
    }

    if ((code >= 40 && code <= 47) || (code >= 100 && code <= 107)) {
      state.bg = ansiNamedColors[code - 10] ?? null;
      continue;
    }

    if (code === 38 || code === 48) {
      const isForeground = code === 38;
      const mode = codes[index + 1];

      if (mode === 5 && index + 2 < codes.length) {
        const colorIndex = codes[index + 2];
        if (!Number.isNaN(colorIndex)) {
          state[isForeground ? 'fg' : 'bg'] = xtermColor(colorIndex);
        }
        index += 2;
        continue;
      }

      if (mode === 2 && index + 4 < codes.length) {
        const red = clampColor(codes[index + 2]);
        const green = clampColor(codes[index + 3]);
        const blue = clampColor(codes[index + 4]);
        state[isForeground ? 'fg' : 'bg'] = `rgb(${red}, ${green}, ${blue})`;
        index += 4;
      }
    }
  }
};

const ansiStateToMarkup = (text, state) => {
  const escaped = escapeHtml(text);
  const classes = ['ansi-fragment'];
  const styles = [];

  if (state.bold) {
    classes.push('ansi-bold');
  }

  if (state.dim) {
    classes.push('ansi-dim');
  }

  if (state.italic) {
    classes.push('ansi-italic');
  }

  if (state.underline) {
    classes.push('ansi-underline');
  }

  const foreground = state.inverse ? (state.bg ?? 'var(--log-bg)') : state.fg;
  const background = state.inverse ? (state.fg ?? 'var(--log-fg)') : state.bg;

  if (foreground != null) {
    styles.push(`color: ${foreground};`);
  }

  if (background != null) {
    styles.push(`background-color: ${background};`);
  }

  if (classes.length === 1 && styles.length === 0) {
    return escaped;
  }

  const classAttribute = classes.join(' ');
  const styleAttribute = styles.length > 0 ? ` style="${styles.join(' ')}"` : '';
  return `<span class="${classAttribute}"${styleAttribute}>${escaped}</span>`;
};

const renderAnsi = (value) => {
  if (value.length === 0) {
    return '';
  }

  let html = '';
  let cursor = 0;
  const state = defaultAnsiState();

  for (const match of value.matchAll(ansiPattern)) {
    const [sequence, rawCodes] = match;
    const matchIndex = match.index ?? 0;

    if (matchIndex > cursor) {
      html += ansiStateToMarkup(value.slice(cursor, matchIndex), state);
    }

    const codes = rawCodes.length === 0
      ? []
      : rawCodes.split(';').map((code) => Number.parseInt(code, 10));

    applyAnsiCodes(state, codes);
    cursor = matchIndex + sequence.length;
  }

  if (cursor < value.length) {
    html += ansiStateToMarkup(value.slice(cursor), state);
  }

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

  for (const service of visibleServices) {
    grouped.get(service.group)?.push(service);
  }

  const visibleCount = visibleServices.length;
  serviceFilterMeta.textContent = state.searchTerm.trim().length === 0
    ? `Showing all ${state.services.length} services.`
    : `Showing ${visibleCount} of ${state.services.length} services for "${state.searchTerm.trim()}".`;

  const groupsHtml = groupOrder.map((group) => {
    const services = grouped.get(group) ?? [];
    if (services.length === 0) {
      return '';
    }

    return `
      <section class="service-group">
        <header class="group-header">
          <h3>${groupTitles[group] ?? group}</h3>
        </header>
        <div class="service-grid">
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
    ? renderAnsi(payload.text || '(log file is empty)')
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
