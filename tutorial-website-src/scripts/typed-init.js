document.addEventListener('DOMContentLoaded', () => {
  const titleEl = document.querySelector('#title-block-header h1.title');
  const workshopTitle = 'Beyond the Chatbox';
  const chatFinalTitle = 'Going beyond the chatbox';

  if (!titleEl || (!titleEl.textContent.trim().includes(workshopTitle) && !titleEl.textContent.trim().includes(chatFinalTitle))) {
    return;
  }

  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  const chatbox = document.createElement('div');
  chatbox.className = 'chatbox-container agent-demo';
  chatbox.innerHTML = `
    <div class="chatbox-header" id="chatbox-header">
      <div class="chatbox-dots" aria-hidden="true">
        <span class="dot red"></span>
        <span class="dot yellow"></span>
        <span class="dot green"></span>
      </div>
      <div class="chatbox-title" id="chatbox-header-title">
        <span class="status-indicator"></span>
        <span id="chatbox-header-label">workshop-agent chat</span>
      </div>
      <div class="chatbox-actions">
        <div class="demo-view-toggle">
          <div class="toggle-slider"></div>
          <button class="toggle-option chat active" type="button" data-view="chat">Chat</button>
          <button class="toggle-option agent" type="button" data-view="agent">Agent</button>
        </div>
        <button class="demo-replay-button" type="button" aria-label="Replay animation" title="Replay animation">
          <span class="demo-button-icon" aria-hidden="true">&#8635;</span>
          <span class="demo-button-text">Replay</span>
        </button>
      </div>
    </div>
    <div class="chatbox-viewport" style="position: relative;">
      <div class="chatbox-body" id="chatbox-body">
        <div class="chatbox-message user">
          <div class="avatar user-avatar" aria-hidden="true">
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 16 16">
              <path d="M3 14s-1 0-1-1 1-4 6-4 6 3 6 4-1 1-1 1H3zm5-6a3 3 0 1 0 0-6 3 3 0 0 0 0 6z"/>
            </svg>
          </div>
          <div class="message-content">
            <span class="message-sender">You</span>
            <p class="message-text">What are we doing in Bologna this June?</p>
          </div>
        </div>
        <div class="chatbox-message assistant">
          <div class="avatar assistant-avatar capybara-avatar" aria-hidden="true">
            ${capybaraSvg()}
          </div>
          <div class="message-content">
            <span class="message-sender">Agent</span>
            <h1 class="message-text title"><span id="typed-title"></span></h1>
          </div>
        </div>
      </div>
      <div class="ghost-scrollbar-track" id="ghost-scrollbar-track">
        <div class="ghost-scrollbar-thumb" id="ghost-scrollbar-thumb"></div>
      </div>
    </div>
  `;

  titleEl.parentNode.replaceChild(chatbox, titleEl);

  const bodyEl = document.getElementById('chatbox-body');
  if (bodyEl) {
    bodyEl.addEventListener('scroll', syncCustomScrollbar, { passive: true });
    // Initial sync
    window.requestAnimationFrame(syncCustomScrollbar);
  }

  const initialHeaderHtml = document.getElementById('chatbox-header-title').innerHTML;
  const initialBodyHtml = document.getElementById('chatbox-body').innerHTML;
  const replayButton = chatbox.querySelector('.demo-replay-button');
  const viewToggle = chatbox.querySelector('.demo-view-toggle');
  const demoTimers = new Set();
  let typedInstance = null;
  let currentView = 'animating';
  let terminalAutoScrollFrame = null;
  let terminalAutoScrollCleanups = [];

  const terminalSession = [
    {
      kind: 'agent',
      text: 'Ready. I can inspect files, run R, and make artifacts in userspace/projects/.',
    },
    {
      prompt: 'you',
      command: 'analyze this data',
      output: [
        '<span class="term-agent">agent</span> I will look for tabular data and use a small R workflow.',
      ],
      pauseAfter: 280,
    },
    {
      prompt: 'tool',
      command: 'ls data userspace/examples',
      output: [
        '<span class="term-dim">data/sample_data.csv</span>',
        '<span class="term-dim">userspace/examples/README.md</span>',
      ],
      pauseAfter: 260,
    },
    {
      prompt: 'tool',
      command: 'Rscript -e "install.packages(c(\'readr\', \'dplyr\', \'ggplot2\'))"',
      output: [
        '<span class="term-ok">ok</span> readr available',
        '<span class="term-ok">ok</span> dplyr available',
        '<span class="term-ok">ok</span> ggplot2 available',
      ],
      pauseAfter: 260,
    },
    {
      prompt: 'tool',
      command: 'Rscript userspace/projects/analyze_population.R',
      output: [
        '<span class="term-dim">read_csv("data/sample_data.csv")</span>',
        '<span class="term-dim">columns: year, region, population</span>',
        '<span class="term-dim">rows: 240 | years: 2000-2025 | regions: 8</span>',
        '<span class="term-ok">created</span> userspace/projects/population_trends.png',
      ],
      pauseAfter: 320,
      preview: true,
    },
    {
      kind: 'agent',
      text: 'Summary: population rises in most regions after 2012; the plot is ready for review.',
    },
  ];

  replayButton.addEventListener('click', restartDemo);
  viewToggle.addEventListener('click', (e) => {
    const btn = e.target.closest('.toggle-option');
    if (!btn) return;
    const view = btn.getAttribute('data-view');
    if (view === currentView) return;
    
    if (view === 'chat') {
      showCompletedChat();
    } else {
      showCompletedTerminal();
    }
  });

  function queueTimeout(callback, delay) {
    const timerId = window.setTimeout(() => {
      demoTimers.delete(timerId);
      callback();
    }, delay);
    demoTimers.add(timerId);
    return timerId;
  }

  function clearDemoTimers() {
    demoTimers.forEach((timerId) => window.clearTimeout(timerId));
    demoTimers.clear();
    stopTerminalAutoScroll();
  }

  function restartDemo() {
    clearDemoTimers();
    if (typedInstance && typeof typedInstance.destroy === 'function') {
      typedInstance.destroy();
      typedInstance = null;
    }

    const body = document.getElementById('chatbox-body');
    const headerTitle = document.getElementById('chatbox-header-title');
    if (!body || !headerTitle) {
      return;
    }

    chatbox.className = 'chatbox-container agent-demo';
    headerTitle.innerHTML = initialHeaderHtml;
    body.className = 'chatbox-body';
    body.innerHTML = initialBodyHtml;
    body.scrollTop = 0;
    currentView = 'animating';
    updateViewToggle();
    startTypedTitle();
  }

  function completeTerminal() {
    chatbox.classList.add('terminal-complete');
    currentView = 'terminal';
    updateViewToggle();
    scrollTerminal();
  }

  function toggleCompletedView() {
    if (currentView === 'terminal') {
      showCompletedChat();
      return;
    }

    showCompletedTerminal();
  }

  function showCompletedChat() {
    clearDemoTimers();
    if (typedInstance && typeof typedInstance.destroy === 'function') {
      typedInstance.destroy();
      typedInstance = null;
    }

    const body = document.getElementById('chatbox-body');
    const headerTitle = document.getElementById('chatbox-header-title');
    if (!body || !headerTitle) {
      return;
    }

    chatbox.className = 'chatbox-container agent-demo typed-complete chat-complete-view';
    headerTitle.innerHTML = initialHeaderHtml;
    body.className = 'chatbox-body';
    body.innerHTML = initialBodyHtml;
    const typedTarget = document.getElementById('typed-title');
    if (typedTarget) {
      typedTarget.outerHTML = `<span id="typed-title">${chatFinalTitle}</span><span class="typed-cursor typed-cursor--blink">|</span>`;
    }
    body.scrollTop = 0;
    currentView = 'chat';
    updateViewToggle();
  }

  function showCompletedTerminal() {
    clearDemoTimers();
    if (typedInstance && typeof typedInstance.destroy === 'function') {
      typedInstance.destroy();
      typedInstance = null;
    }

    const body = document.getElementById('chatbox-body');
    const headerTitle = document.getElementById('chatbox-header-title');
    if (!body || !headerTitle) {
      return;
    }

    chatbox.className = 'chatbox-container agent-demo terminal-mode terminal-complete';
    headerTitle.innerHTML = `
      <span class="terminal-title">${workshopTitle}</span>
      <span class="terminal-subtitle">agent workspace</span>
    `;
    body.className = 'chatbox-body';
    body.innerHTML = terminalShellHtml();
    renderTerminalInstantly();
    currentView = 'terminal';
    updateViewToggle();
    body.scrollTop = 0;
    queueTimeout(startTerminalAutoScroll, 260);
  }

  function updateViewToggle() {
    if (!viewToggle) {
      return;
    }

    const chatBtn = viewToggle.querySelector('[data-view="chat"]');
    const agentBtn = viewToggle.querySelector('[data-view="agent"]');

    if (currentView === 'terminal') {
      chatBtn.classList.remove('active');
      agentBtn.classList.add('active');
    } else if (currentView === 'chat') {
      chatBtn.classList.add('active');
      agentBtn.classList.remove('active');
    } else {
      chatBtn.classList.remove('active');
      agentBtn.classList.remove('active');
    }
  }

  function capybaraSvg() {
    return `
      <svg class="capybara-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" role="img" aria-label="Friendly agent">
        <path class="capybara-body" d="M12 36c0-10.2 8.5-18 20.3-18h6.9C47.6 18 54 24 54 32.2c0 8.6-6.9 15.8-17.2 15.8H24.5C17 48 12 43.3 12 36z"/>
        <path class="capybara-muzzle" d="M38 31.5c0-4.8 3.9-8.5 8.4-8.5 4.2 0 7.6 3.3 7.6 7.6 0 4.6-3.8 8.4-8.6 8.4H38v-7.5z"/>
        <path class="capybara-ear" d="M23.5 18.8c-.2-4 2.1-6.8 5.2-6.8 2.8 0 4.7 2.3 4.7 5.6"/>
        <path class="capybara-ear" d="M41.2 19c.5-3.5 2.7-5.6 5.3-5.1 2.5.4 3.9 2.8 3.2 5.8"/>
        <circle class="capybara-eye" cx="31" cy="29" r="2.1"/>
        <circle class="capybara-eye" cx="47" cy="31" r="1.8"/>
        <path class="capybara-nose" d="M51.4 34.5c0 1.3-1.3 2.3-2.9 2.3s-2.9-1-2.9-2.3 1.3-2.2 2.9-2.2 2.9.9 2.9 2.2z"/>
        <path class="capybara-smile" d="M43.8 38.2c1.8 1.3 4.6 1.5 6.7.1"/>
      </svg>
    `;
  }

  function startTypedTitle() {
    const typedTarget = document.getElementById('typed-title');
    if (!typedTarget) {
      return;
    }

    if (reduceMotion || typeof Typed === 'undefined') {
      typedTarget.textContent = chatFinalTitle;
      chatbox.classList.add('typed-complete');
      morphToTerminal({ instant: true });
      return;
    }

    typedInstance = new Typed('#typed-title', {
      strings: ['Beyond ordinary chat...', chatFinalTitle],
      typeSpeed: 42,
      backSpeed: 24,
      backDelay: 850,
      startDelay: 250,
      loop: false,
      showCursor: true,
      cursorChar: '|',
      autoInsertCss: false,
      onComplete: () => {
        chatbox.classList.add('typed-complete');
        queueTimeout(rotateWindowToTerminal, 2050);
      },
    });
  }

  function rotateWindowToTerminal() {
    const body = document.getElementById('chatbox-body');
    const headerTitle = document.getElementById('chatbox-header-title');
    if (!body || !headerTitle) {
      morphToTerminal({ instant: false });
      return;
    }

    chatbox.classList.add('cube-prep');

    queueTimeout(() => {
      const frontHtml = body.innerHTML;
      chatbox.classList.add('cube-rotating', 'cube-title-resolving', 'terminal-mode');
      headerTitle.innerHTML = `
        <span class="terminal-title">${workshopTitle}</span>
        <span class="terminal-subtitle">agent workspace</span>
      `;
      body.className = 'chatbox-body cube-body';
      body.innerHTML = `
        <div class="cube-stage">
          <div class="cube-face cube-face-front">${frontHtml}</div>
          <div class="cube-face cube-face-back">${terminalShellHtml()}</div>
        </div>
      `;

      window.requestAnimationFrame(() => {
        window.requestAnimationFrame(() => {
          const stage = body.querySelector('.cube-stage');
          if (stage) {
            stage.classList.add('is-turning');
          }
        });
      });

      queueTimeout(() => {
        body.className = 'chatbox-body body-enter terminal-live';
        body.innerHTML = terminalShellHtml();
        scrollTerminal({ instant: true });
        window.requestAnimationFrame(() => {
          body.classList.add('is-visible');
        });

        queueTimeout(() => {
          chatbox.classList.remove('cube-prep', 'cube-rotating', 'cube-title-resolving');
          body.classList.remove('body-enter', 'terminal-live', 'is-visible');
          runTerminalSession(0);
        }, 460);
      }, 1480);
    }, 240);
  }

  function morphToTerminal({ instant, cube = false }) {
    const body = document.getElementById('chatbox-body');
    const headerTitle = document.getElementById('chatbox-header-title');
    if (!body || !headerTitle) {
      return;
    }

    if (!instant && !cube) {
      chatbox.classList.add('morphing-to-terminal');
      body.classList.add('body-exit');
    }

    const swapToTerminal = () => {
      chatbox.classList.add('terminal-mode');
      headerTitle.innerHTML = `
        <span class="terminal-title">${workshopTitle}</span>
        <span class="terminal-subtitle">agent workspace</span>
      `;

      body.innerHTML = terminalShellHtml();
      body.classList.remove('body-exit', 'cube-face-out');
      body.classList.add(cube ? 'cube-face-in' : 'body-enter');
      scrollTerminal({ instant: true });
      syncCustomScrollbar();

      window.requestAnimationFrame(() => {
        body.classList.add('is-visible');
        syncCustomScrollbar();
      });

      if (instant) {
        renderTerminalInstantly();
        completeTerminal();
        return;
      }

      queueTimeout(() => {
        chatbox.classList.remove(
          'morphing-to-terminal',
          'morph-prep',
          'morph-terminal-ready',
          'cube-rotating',
          'cube-title-resolving'
        );
        body.classList.remove('cube-face-in', 'body-enter', 'is-visible');
        runTerminalSession(0);
      }, cube ? 560 : 420);
    };

    if (instant) {
      swapToTerminal();
      return;
    }

    queueTimeout(swapToTerminal, cube ? 80 : 210);
  }

  function terminalShellHtml() {
    return `
      <div class="terminal-content-wrapper" id="terminal-content-wrapper">
        <div class="terminal-output" id="terminal-output" aria-live="polite">
          <div class="terminal-agent-card">
            <span class="term-agent">agent</span>
            <span class="agent-name">Capy</span>
            <span class="agent-mode">R + CSV analysis</span>
          </div>
        </div>
      </div>
    `;
  }

  function syncCustomScrollbar() {
    const body = document.getElementById('chatbox-body');
    const track = document.getElementById('ghost-scrollbar-track');
    const thumb = document.getElementById('ghost-scrollbar-thumb');

    if (!body || !track || !thumb) return;

    const contentHeight = body.scrollHeight;
    const viewHeight = body.clientHeight;
    
    if (contentHeight <= viewHeight + 2) {
      track.style.opacity = '0';
      track.style.pointerEvents = 'none';
      return;
    }

    track.style.opacity = '1';
    track.style.pointerEvents = 'auto';

    const trackHeight = track.clientHeight;
    const scrollRatio = viewHeight / contentHeight;
    const thumbHeight = Math.max(30, trackHeight * scrollRatio);
    const maxScroll = contentHeight - viewHeight;
    const scrollProgress = maxScroll > 0 ? body.scrollTop / maxScroll : 0;
    const maxThumbMove = trackHeight - thumbHeight;

    thumb.style.height = `${thumbHeight}px`;
    thumb.style.transform = `translateY(${scrollProgress * maxThumbMove}px)`;

    if (!thumb.dataset.hasListener) {
      thumb.addEventListener('pointerdown', onThumbPointerDown);
      thumb.dataset.hasListener = 'true';
    }
    }

  // Handle dragging the custom scrollbar
  let isDraggingScrollbar = false;
  let startDragY = 0;
  let startScrollTop = 0;

  function onThumbPointerDown(e) {
    const body = document.getElementById('chatbox-body');
    const thumb = document.getElementById('ghost-scrollbar-thumb');
    if (!body || !thumb) return;
    
    isDraggingScrollbar = true;
    startDragY = e.clientY;
    startScrollTop = body.scrollTop;
    
    body.style.scrollBehavior = 'auto'; // Disable smooth scroll
    thumb.style.transition = 'none';
    document.body.style.userSelect = 'none';
    document.body.style.cursor = 'grabbing';
    
    window.addEventListener('pointermove', onThumbPointerMove);
    window.addEventListener('pointerup', onThumbPointerUp);
    e.stopPropagation();
    e.preventDefault();
  }

  function onThumbPointerMove(e) {
    if (!isDraggingScrollbar) return;
    
    const body = document.getElementById('chatbox-body');
    const track = document.getElementById('ghost-scrollbar-track');
    const thumb = document.getElementById('ghost-scrollbar-thumb');
    if (!body || !track || !thumb) return;
    
    const deltaY = e.clientY - startDragY;
    const maxThumbMove = track.clientHeight - thumb.clientHeight;
    if (maxThumbMove <= 0) return;

    const maxScroll = body.scrollHeight - body.clientHeight;
    const moveRatio = deltaY / maxThumbMove;
    
    body.scrollTop = startScrollTop + (moveRatio * maxScroll);
    syncCustomScrollbar();
  }

  function onThumbPointerUp() {
    isDraggingScrollbar = false;
    const body = document.getElementById('chatbox-body');
    const thumb = document.getElementById('ghost-scrollbar-thumb');
    
    if (body) body.style.scrollBehavior = '';
    if (thumb) thumb.style.transition = '';
    
    document.body.style.userSelect = '';
    document.body.style.cursor = '';
    window.removeEventListener('pointermove', onThumbPointerMove);
    window.removeEventListener('pointerup', onThumbPointerUp);
  }

  function runTerminalSession(index) {
    const outputEl = document.getElementById('terminal-output');
    
    syncCustomScrollbar();
    
    const step = terminalSession[index];
    if (!outputEl || !step) {
      completeTerminal();
      return;
    }

    if (step.kind === 'agent') {
      appendOutputLine(`<span class="term-agent">agent</span> ${escapeHtml(step.text)}`, outputEl);
      queueTimeout(() => runTerminalSession(index + 1), 430);
      return;
    }

    const line = document.createElement('div');
    line.className = 'term-line command-line';
    line.innerHTML = `<span class="term-prompt">${step.prompt}</span><span class="term-cmd"></span><span class="term-cursor">|</span>`;
    outputEl.appendChild(line);
    scrollTerminal();

    const cmdSpan = line.querySelector('.term-cmd');
    const cursor = line.querySelector('.term-cursor');
    let charIndex = 0;

    const typeChar = () => {
      if (charIndex < step.command.length) {
        cmdSpan.textContent += step.command[charIndex];
        charIndex += 1;
        scrollTerminal();
        queueTimeout(typeChar, 22 + Math.random() * 18);
        return;
      }

      cursor.style.display = 'none';
      queueTimeout(() => {
        printOutput(step, outputEl, () => {
          queueTimeout(() => runTerminalSession(index + 1), step.pauseAfter || 250);
        });
      }, 130);
    };

    typeChar();
  }

  function printOutput(step, outputEl, done) {
    const lines = step.output || [];
    let lineIndex = 0;

    const printLine = () => {
      if (lineIndex < lines.length) {
        appendOutputLine(lines[lineIndex], outputEl);
        lineIndex += 1;
        queueTimeout(printLine, 80);
        return;
      }

      if (step.preview) {
        appendPlotPreview(outputEl);
      }

      done();
    };

    printLine();
  }

  function renderTerminalInstantly() {
    const outputEl = document.getElementById('terminal-output');
    if (!outputEl) {
      return;
    }

    terminalSession.forEach((step) => {
      if (step.kind === 'agent') {
        appendOutputLine(`<span class="term-agent">agent</span> ${escapeHtml(step.text)}`, outputEl);
        return;
      }

      appendCommandLine(step, outputEl);
      (step.output || []).forEach((line) => appendOutputLine(line, outputEl));
      if (step.preview) {
        appendPlotPreview(outputEl);
      }
    });
    
    syncCustomScrollbar();
  }

  function appendCommandLine(step, outputEl) {
    const line = document.createElement('div');
    line.className = 'term-line command-line';
    line.innerHTML = `<span class="term-prompt">${step.prompt}</span><span class="term-cmd">${escapeHtml(step.command)}</span>`;
    outputEl.appendChild(line);
    scrollTerminal({ instant: true });
  }

  function appendOutputLine(html, outputEl) {
    const line = document.createElement('div');
    line.className = 'term-line term-output-line';
    line.innerHTML = html;
    outputEl.appendChild(line);
    scrollTerminal();
  }

  function appendPlotPreview(outputEl) {
    const preview = document.createElement('div');
    preview.className = 'terminal-plot-preview';
    preview.innerHTML = `
      <div class="plot-head">
        <span>population_trends.png</span>
        <span>preview</span>
      </div>
      <div class="plot-line-chart" aria-hidden="true">
        <svg viewBox="0 0 320 112" focusable="false">
          <g class="plot-grid">
            <path d="M28 18H300"/>
            <path d="M28 44H300"/>
            <path d="M28 70H300"/>
            <path d="M28 96H300"/>
            <path d="M28 18V96"/>
          </g>
          <path class="plot-area" d="M28 86 C64 76 82 63 112 67 C142 71 158 48 188 42 C220 35 238 48 268 31 C286 22 294 20 300 18 L300 96 L28 96 Z"/>
          <path class="plot-line" d="M28 86 C64 76 82 63 112 67 C142 71 158 48 188 42 C220 35 238 48 268 31 C286 22 294 20 300 18"/>
          <g class="plot-points">
            <circle cx="28" cy="86" r="3"/>
            <circle cx="112" cy="67" r="3"/>
            <circle cx="188" cy="42" r="3"/>
            <circle cx="268" cy="31" r="3"/>
            <circle cx="300" cy="18" r="3"/>
          </g>
        </svg>
      </div>
      <div class="plot-axis">2000 2005 2010 2015 2020 2025</div>
    `;
    outputEl.appendChild(preview);
    scrollTerminal();
  }

  function scrollTerminal({ instant = false } = {}) {
    const body = document.getElementById('chatbox-body');
    if (!body) {
      return;
    }

    const top = body.scrollHeight;
    if (typeof body.scrollTo === 'function') {
      body.scrollTo({
        top,
        behavior: instant || reduceMotion ? 'auto' : 'smooth',
      });
      // Small delay to allow smooth scroll to happen before syncing
      setTimeout(syncCustomScrollbar, 50);
      return;
    }

    body.scrollTop = top;
    syncCustomScrollbar();
  }

  function startTerminalAutoScroll() {
    stopTerminalAutoScroll();

    const body = document.getElementById('chatbox-body');
    if (!body || reduceMotion) {
      return;
    }

    const maxScroll = Math.max(0, body.scrollHeight - body.clientHeight);
    if (maxScroll < 4) {
      return;
    }

    body.scrollTop = 0;
    const duration = Math.min(8200, Math.max(3600, maxScroll * 34));
    const startedAt = window.performance.now();

    const stopOnUserIntent = () => stopTerminalAutoScroll();
    const addStopListener = (target, event, options) => {
      target.addEventListener(event, stopOnUserIntent, options);
      terminalAutoScrollCleanups.push(() => target.removeEventListener(event, stopOnUserIntent, options));
    };

    addStopListener(body, 'wheel', { passive: true });
    addStopListener(body, 'touchstart', { passive: true });
    addStopListener(body, 'pointerdown', { passive: true });

    const stopOnScrollKey = (event) => {
      if (['ArrowDown', 'ArrowUp', 'PageDown', 'PageUp', 'Home', 'End', ' '].includes(event.key)) {
        stopTerminalAutoScroll();
      }
    };
    window.addEventListener('keydown', stopOnScrollKey);
    terminalAutoScrollCleanups.push(() => window.removeEventListener('keydown', stopOnScrollKey));

    const step = (now) => {
      const progress = Math.min(1, (now - startedAt) / duration);
      const eased = 0.5 - Math.cos(progress * Math.PI) / 2;
      body.scrollTop = maxScroll * eased;
      syncCustomScrollbar();

      if (progress < 1) {
        terminalAutoScrollFrame = window.requestAnimationFrame(step);
        return;
      }

      stopTerminalAutoScroll();
    };

    terminalAutoScrollFrame = window.requestAnimationFrame(step);
  }

  function stopTerminalAutoScroll() {
    if (terminalAutoScrollFrame !== null) {
      window.cancelAnimationFrame(terminalAutoScrollFrame);
      terminalAutoScrollFrame = null;
    }

    terminalAutoScrollCleanups.forEach((cleanup) => cleanup());
    terminalAutoScrollCleanups = [];
  }

  function escapeHtml(text) {
    return String(text)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  startTypedTitle();
});
