const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const repoRoot = path.resolve(__dirname, '..');
const brainVaultRoot = process.env.BRAINVAULT_HOME || path.join(os.homedir(), 'BrainVault');
const skillPath = path.join(brainVaultRoot, 'skills/apple/homebrew-cask-release/SKILL.md');

function readRepo(relativePath) {
  return fs.readFileSync(path.join(repoRoot, relativePath), 'utf8');
}

test('native Homebrew cask is public-audit friendly by default', () => {
  const cask = readRepo('homebrew/skd-downloader.rb');

  assert.match(
    cask,
    /url "https:\/\/github\.com\/SKD-international\/skd-downloader\/releases\/download\/v#\{version\}\/SKD\.Downloader\.Native-#\{version\}-mac\.zip"/,
  );
  assert.doesNotMatch(cask, /HOMEBREW_GITHUB_API_TOKEN/);
  assert.doesNotMatch(cask, /api\.github\.com\/repos\/SKD-international\/skd-downloader\/releases\/assets/);
  assert.match(cask, /depends_on macos: ">= :sonoma"/);
  assert.match(cask, /depends_on formula: "yt-dlp"/);
  assert.match(cask, /depends_on formula: "ffmpeg"/);
  assert.doesNotMatch(cask, /xattr.*com\.apple\.quarantine/s);
});

test('native release script makes private GitHub asset casks explicit opt-in', () => {
  const script = readRepo('script/release_native.sh');

  assert.ok(script.includes('SKD_RELEASE_PRIVATE_ASSET'), 'missing SKD_RELEASE_PRIVATE_ASSET gate');
  assert.ok(
    script.includes('releases/download/v#{version}/SKD.Downloader.Native-#{version}-mac.zip'),
    'missing public GitHub release URL template',
  );
  assert.ok(
    script.includes('api.github.com/repos/SKD-international/skd-downloader/releases/assets'),
    'missing private GitHub asset URL template',
  );
});

test('Homebrew workflow skill exists and covers release pressure points', (t) => {
  if (!fs.existsSync(skillPath)) {
    if (process.env.SKD_REQUIRE_BRAINVAULT_SKILL === '1') {
      assert.fail(`missing Homebrew workflow skill at ${skillPath}`);
    }
    t.skip('BrainVault workflow skills are local operator docs outside the public repo');
    return;
  }

  const skill = fs.readFileSync(skillPath, 'utf8');

  assert.match(skill, /^---\nname: homebrew-cask-release\n/m);
  assert.match(skill, /description: Use when /);

  for (const needle of [
    'brew audit --cask --strict',
    'native:release',
    'native:release:upload',
    'SKD_NOTARY_PROFILE',
    'SKD_RELEASE_PRIVATE_ASSET',
    'HOMEBREW_GITHUB_API_TOKEN',
    'git -C /usr/local/Homebrew/Library/Taps',
    'open source',
    'legacy Electron',
  ]) {
    assert.ok(skill.includes(needle), `missing ${needle}`);
  }
});
