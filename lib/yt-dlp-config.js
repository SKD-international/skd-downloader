const fs = require('fs');
const path = require('path');

function detectDefaultCookiesBrowser({ homeDir, platform = process.platform, existsSync = fs.existsSync } = {}) {
  if (platform !== 'darwin' || !homeDir) return 'none';

  const chromeCookiePaths = [
    path.join(homeDir, 'Library/Application Support/Google/Chrome/Default/Cookies'),
    path.join(homeDir, 'Library/Application Support/Google/Chrome/Default/Network/Cookies')
  ];

  return chromeCookiePaths.some(cookiePath => existsSync(cookiePath)) ? 'chrome' : 'none';
}

function normalizeCookiesConfig(config = {}, env = {}) {
  const normalized = { ...config };
  const detectedBrowser = detectDefaultCookiesBrowser(env);

  if (typeof normalized.cookiesBrowserConfigured !== 'boolean') {
    normalized.cookiesBrowserConfigured = false;
  }

  if (
    (!normalized.cookiesBrowser || normalized.cookiesBrowser === 'none') &&
    !normalized.cookiesBrowserConfigured &&
    detectedBrowser !== 'none'
  ) {
    normalized.cookiesBrowser = detectedBrowser;
  }

  if (!normalized.cookiesBrowser) {
    normalized.cookiesBrowser = detectedBrowser;
  }

  return normalized;
}

function getCookieArgs(url, config = {}, env = {}) {
  const normalized = normalizeCookiesConfig(config, env);

  if (normalized.cookiesBrowser && normalized.cookiesBrowser !== 'none') {
    return ['--cookies-from-browser', normalized.cookiesBrowser];
  }

  return ['--no-cookies-from-browser'];
}

module.exports = {
  detectDefaultCookiesBrowser,
  normalizeCookiesConfig,
  getCookieArgs
};
