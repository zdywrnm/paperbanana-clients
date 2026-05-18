const path = require('node:path');
const { app, BrowserWindow, Menu, shell } = require('electron');

const APP_URL = process.env.PAPERBANANA_DESKTOP_URL || 'https://paperbanana.asia/';
const APP_ORIGIN = new URL(APP_URL).origin;
const WINDOW_ICON = path.join(__dirname, '../build/icon.png');
const TRUSTED_HOSTS = new Set([
  'paperbanana.asia',
  'www.paperbanana.asia',
  new URL(APP_URL).hostname,
]);

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

function errorPage(message) {
  const escaped = String(message || '网络连接失败').replace(/[&<>"']/g, (char) => ({
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
            color: #111827;
            background: #f3f5f9;
          }
          main {
            width: min(520px, calc(100vw - 40px));
            padding: 28px;
            border: 1px solid #e5e7eb;
            border-radius: 12px;
            background: #fff;
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
            background: #f59e0b;
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
        </style>
      </head>
      <body>
        <main>
          <h1>暂时无法打开 PaperBanana</h1>
          <p>请检查网络连接，或稍后重新打开应用。</p>
          <a href="${APP_URL}">重新连接</a>
          <code>${escaped}</code>
        </main>
      </body>
    </html>
  `)}`;
}

function createMainWindow() {
  const mainWindow = new BrowserWindow({
    width: 1440,
    height: 960,
    minWidth: 1120,
    minHeight: 720,
    title: 'PaperBanana 工作台',
    icon: WINDOW_ICON,
    backgroundColor: '#f3f5f9',
    autoHideMenuBar: true,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      webSecurity: true,
    },
  });

  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (isTrustedNavigation(url)) return { action: 'allow' };
    shell.openExternal(url);
    return { action: 'deny' };
  });

  mainWindow.webContents.on('will-navigate', (event, url) => {
    if (isTrustedNavigation(url)) return;
    event.preventDefault();
    shell.openExternal(url);
  });

  mainWindow.webContents.on('will-attach-webview', (event) => {
    event.preventDefault();
  });

  mainWindow.webContents.session.setPermissionRequestHandler((_webContents, _permission, callback) => {
    callback(false);
  });

  mainWindow.webContents.on('did-fail-load', (_event, errorCode, errorDescription, validatedURL, isMainFrame) => {
    if (!isMainFrame || errorCode === -3 || validatedURL.startsWith('data:')) return;
    mainWindow.loadURL(errorPage(errorDescription));
  });

  void mainWindow.loadURL(APP_URL);
}

app.whenReady().then(() => {
  Menu.setApplicationMenu(null);
  createMainWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createMainWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
