const path = require('node:path');
const fs = require('node:fs');
const { app, BrowserWindow, Menu, shell } = require('electron');

const DEFAULT_APP_URL = 'https://paperbanana.asia/';
const APP_URL = normalizeAppUrl(process.env.PAPERBANANA_DESKTOP_URL || DEFAULT_APP_URL);
const APP_ORIGIN = new URL(APP_URL).origin;
const WINDOW_ICON = path.join(__dirname, '../build/icon.png');
const WINDOW_STATE_FILE = 'window-state.json';
const APP_USER_MODEL_ID = 'asia.paperbanana.desktop';
const TRUSTED_HOSTS = new Set([
  'paperbanana.asia',
  'www.paperbanana.asia',
  new URL(APP_URL).hostname,
]);

let mainWindow = null;

app.setAppUserModelId(APP_USER_MODEL_ID);

function normalizeAppUrl(rawUrl) {
  try {
    const parsed = new URL(rawUrl);
    if (!['http:', 'https:'].includes(parsed.protocol)) return DEFAULT_APP_URL;
    return parsed.toString();
  } catch {
    return DEFAULT_APP_URL;
  }
}

function isTrustedNavigation(targetUrl) {
  try {
    const parsed = new URL(targetUrl);
    if (parsed.protocol === 'data:') return true;
    if (parsed.origin === APP_ORIGIN) return true;
    return ['http:', 'https:'].includes(parsed.protocol) && TRUSTED_HOSTS.has(parsed.hostname);
  } catch {
    return false;
  }
}

function openExternalUrl(targetUrl) {
  try {
    const parsed = new URL(targetUrl);
    if (['http:', 'https:', 'mailto:'].includes(parsed.protocol)) {
      void shell.openExternal(parsed.toString());
    }
  } catch {
    // Ignore malformed URLs from untrusted pages.
  }
}

function readWindowState() {
  const statePath = path.join(app.getPath('userData'), WINDOW_STATE_FILE);
  try {
    const state = JSON.parse(fs.readFileSync(statePath, 'utf8'));
    if (typeof state.width !== 'number' || typeof state.height !== 'number') return {};
    return state;
  } catch {
    return {};
  }
}

function saveWindowState(window) {
  if (!window || window.isDestroyed()) return;
  const statePath = path.join(app.getPath('userData'), WINDOW_STATE_FILE);
  const bounds = window.isMaximized() ? window.getNormalBounds() : window.getBounds();
  const state = {
    ...bounds,
    maximized: window.isMaximized(),
  };
  try {
    fs.mkdirSync(path.dirname(statePath), { recursive: true });
    fs.writeFileSync(statePath, JSON.stringify(state, null, 2));
  } catch {
    // Best effort only; window persistence should never block app shutdown.
  }
}

function errorPage(message, failedUrl = APP_URL) {
  const escaped = String(message || '网络连接失败').replace(/[&<>"']/g, (char) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  }[char]));
  const escapedUrl = String(failedUrl || APP_URL).replace(/[&<>"']/g, (char) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  }[char]));

  return `data:text/html;charset=utf-8,${encodeURIComponent(`
    <!doctype html>
    <html lang="zh-CN">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>PaperBanana</title>
        <style>
          body {
            min-height: 100vh;
            margin: 0;
            display: grid;
            place-items: center;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            color: #171513;
            background: #f3f2ee;
          }
          main {
            width: min(520px, calc(100vw - 40px));
            padding: 28px;
            border: 1px solid #e7dfd0;
            border-radius: 12px;
            background: #fffdf8;
            box-shadow: 0 18px 46px rgba(41, 31, 16, 0.08);
          }
          h1 {
            margin: 0 0 10px;
            font-size: 22px;
          }
          p {
            margin: 0 0 18px;
            color: #64748b;
            line-height: 1.6;
          }
          a {
            display: inline-flex;
            min-height: 40px;
            align-items: center;
            padding: 0 16px;
            border-radius: 8px;
            color: #fff;
            background: #f2a60d;
            text-decoration: none;
            font-weight: 700;
          }
          code {
            display: block;
            margin: 14px 0 0;
            padding: 10px;
            border-radius: 8px;
            background: #f8fafc;
            color: #475569;
            font-size: 12px;
            white-space: pre-wrap;
          }
          .hint {
            margin-top: 10px;
            font-size: 12px;
          }
        </style>
      </head>
      <body>
        <main>
          <h1>暂时无法打开 PaperBanana</h1>
          <p>请检查网络连接，或稍后重新打开应用。</p>
          <a href="${APP_URL}">重新连接</a>
          <p class="hint">目标地址：${escapedUrl}</p>
          <code>${escaped}</code>
        </main>
      </body>
    </html>
  `)}`;
}

function showContextMenu(window, params) {
  const template = [];
  if (params.isEditable) {
    template.push(
      { role: 'undo' },
      { role: 'redo' },
      { type: 'separator' },
      { role: 'cut' },
      { role: 'copy' },
      { role: 'paste' },
      { type: 'separator' },
      { role: 'selectAll' },
    );
  } else {
    if (params.selectionText) template.push({ role: 'copy' }, { type: 'separator' });
    template.push(
      { label: '重新加载', click: () => window.reload() },
      { role: 'selectAll' },
    );
  }
  Menu.buildFromTemplate(template).popup({ window });
}

function createMainWindow() {
  const savedState = readWindowState();
  mainWindow = new BrowserWindow({
    x: savedState.x,
    y: savedState.y,
    width: savedState.width || 1440,
    height: savedState.height || 960,
    minWidth: 1120,
    minHeight: 720,
    title: 'PaperBanana 工作台',
    icon: WINDOW_ICON,
    backgroundColor: '#f3f2ee',
    autoHideMenuBar: true,
    show: false,
    webPreferences: {
      contextIsolation: true,
      devTools: !app.isPackaged,
      nodeIntegration: false,
      sandbox: true,
      webSecurity: true,
    },
  });

  const showMainWindow = () => {
    if (!mainWindow || mainWindow.isDestroyed() || mainWindow.isVisible()) return;
    if (savedState.maximized) mainWindow.maximize();
    mainWindow.show();
  };
  mainWindow.once('ready-to-show', showMainWindow);
  setTimeout(showMainWindow, 3000);

  mainWindow.on('close', () => {
    saveWindowState(mainWindow);
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });

  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (isTrustedNavigation(url) && !url.startsWith('data:')) {
      void mainWindow.loadURL(url);
      return { action: 'deny' };
    }
    openExternalUrl(url);
    return { action: 'deny' };
  });

  mainWindow.webContents.on('will-navigate', (event, url) => {
    if (isTrustedNavigation(url)) return;
    event.preventDefault();
    openExternalUrl(url);
  });

  mainWindow.webContents.on('will-attach-webview', (event) => {
    event.preventDefault();
  });

  mainWindow.webContents.session.setPermissionRequestHandler((_webContents, _permission, callback) => {
    callback(false);
  });

  mainWindow.webContents.on('did-fail-load', (_event, errorCode, errorDescription, validatedURL, isMainFrame) => {
    if (!isMainFrame || errorCode === -3 || validatedURL.startsWith('data:')) return;
    void mainWindow.loadURL(errorPage(errorDescription, validatedURL));
  });

  mainWindow.webContents.on('render-process-gone', (_event, details) => {
    if (!mainWindow || mainWindow.isDestroyed()) return;
    void mainWindow.loadURL(errorPage(`页面进程意外退出：${details.reason}`));
  });

  mainWindow.webContents.on('before-input-event', (event, input) => {
    const key = input.key.toLowerCase();
    if (key === 'f5' || ((input.control || input.meta) && key === 'r')) {
      mainWindow.reload();
      event.preventDefault();
      return;
    }
    if (app.isPackaged && (key === 'f12' || ((input.control || input.meta) && input.shift && key === 'i'))) {
      event.preventDefault();
    }
  });

  mainWindow.webContents.on('context-menu', (_event, params) => {
    showContextMenu(mainWindow, params);
  });

  void mainWindow.loadURL(APP_URL);
}

const gotSingleInstanceLock = app.requestSingleInstanceLock();
if (!gotSingleInstanceLock) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (!mainWindow) return;
    if (mainWindow.isMinimized()) mainWindow.restore();
    mainWindow.show();
    mainWindow.focus();
  });

  app.whenReady().then(() => {
    Menu.setApplicationMenu(null);
    createMainWindow();

    app.on('activate', () => {
      if (BrowserWindow.getAllWindows().length === 0) createMainWindow();
    });
  });
}

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
