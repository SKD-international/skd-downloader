const test = require('node:test');
const assert = require('node:assert/strict');

const {
  detectDefaultCookiesBrowser,
  normalizeCookiesConfig,
  getCookieArgs
} = require('../lib/yt-dlp-config');

const macEnvWithChrome = {
  homeDir: '/Users/tester',
  platform: 'darwin',
  existsSync: filePath => filePath.endsWith('/Google/Chrome/Default/Cookies')
};

test('detectDefaultCookiesBrowser returns chrome when Chrome cookies exist on macOS', () => {
  assert.equal(detectDefaultCookiesBrowser(macEnvWithChrome), 'chrome');
});

test('normalizeCookiesConfig upgrades legacy none config when browser choice was never configured', () => {
  const normalized = normalizeCookiesConfig({ cookiesBrowser: 'none' }, macEnvWithChrome);

  assert.equal(normalized.cookiesBrowser, 'chrome');
  assert.equal(normalized.cookiesBrowserConfigured, false);
});

test('normalizeCookiesConfig preserves explicit none choice once configured', () => {
  const normalized = normalizeCookiesConfig(
    { cookiesBrowser: 'none', cookiesBrowserConfigured: true },
    macEnvWithChrome
  );

  assert.equal(normalized.cookiesBrowser, 'none');
  assert.equal(normalized.cookiesBrowserConfigured, true);
});

test('getCookieArgs uses browser cookies when Chrome is available', () => {
  assert.deepEqual(
    getCookieArgs('https://youtube.com/watch?v=abc123', { cookiesBrowser: 'none' }, macEnvWithChrome),
    ['--cookies-from-browser', 'chrome']
  );
});

test('getCookieArgs keeps explicit no-cookie mode when user configured it', () => {
  assert.deepEqual(
    getCookieArgs(
      'https://youtube.com/watch?v=abc123',
      { cookiesBrowser: 'none', cookiesBrowserConfigured: true },
      macEnvWithChrome
    ),
    ['--no-cookies-from-browser']
  );
});
