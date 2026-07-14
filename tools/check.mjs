import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const required = [
  'package.json',
  'README.md',
  'README.en.md',
  'LICENSE',
  '.gitignore',
  '.github/workflows/build.yml',
  'assets/icon.png',
  'scripts/ddys-mpv.lua',
  'script-opts/ddys-mpv.conf',
  'examples/ddys-mpv.local.conf',
  'install/install.ps1',
  'install/uninstall.ps1',
  'install/install.sh',
  'install/uninstall.sh',
  'docs/architecture.md',
  'tests/run.mjs',
  'tools/check.mjs',
  'tools/build-package.ps1'
];

const forbiddenDirs = new Set(['.git', 'node_modules', 'coverage', 'dist', 'build', 'package', 'releases']);

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function read(relative) {
  return fs.readFile(path.join(root, relative), 'utf8');
}

async function exists(relative) {
  try {
    await fs.access(path.join(root, relative));
    return true;
  } catch {
    return false;
  }
}

async function listFiles(dir = root, out = []) {
  for (const entry of await fs.readdir(dir, { withFileTypes: true })) {
    if (entry.name === '.git' || entry.name === 'node_modules') continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (forbiddenDirs.has(entry.name)) {
        out.push(full);
      } else {
        await listFiles(full, out);
      }
    } else {
      out.push(full);
    }
  }
  return out;
}

for (const file of required) {
  assert(await exists(file), `Missing required file: ${file}`);
}

const pkg = JSON.parse(await read('package.json'));
assert(pkg.name === 'ddys-mpv', 'package name mismatch.');
assert(pkg.version === '0.1.1', 'package version mismatch.');
assert(pkg.private === true, 'package must be private.');
assert(pkg.type === 'module', 'package must use ESM.');
assert(pkg.scripts?.check === 'node tools/check.mjs', 'check script mismatch.');
assert(pkg.scripts?.test === 'node tests/run.mjs', 'test script mismatch.');
assert(pkg.scripts?.package?.includes('tools/build-package.ps1'), 'package script mismatch.');

const lua = await read('scripts/ddys-mpv.lua');
for (const fragment of [
  'pcall(mp.commandv, "loadfile", resource.url, "replace")',
  'mp.osd_message',
  'mp.add_key_binding',
  'mp.add_forced_key_binding',
  'mp.remove_key_binding',
  'mp.command_native',
  'utils.parse_json',
  'options.read_options',
  'local VERSION = "0.1.1"',
  'opt.http_timeout = clamp_number(opt.http_timeout, 15, 3, 120)',
  'ddys-mpv-search',
  'table.concat({ ... }, " ")',
  'pcall(mp.command',
  'DDYS API returned empty or invalid JSON',
  'safe_file_stem',
  'single_line(resource.url)',
  'if state.menu_open and state.mode ~= "" then',
  'local grouped = false',
  'seen[resource.url]',
  'flatten_sources',
  'export_playlist',
  'load_history',
  'load_favorites',
  'script-message-to console',
  'data_file("history.json")',
  'data_file("favorites.json")',
  '最新更新',
  '蓝光'
]) {
  assert(lua.includes(fragment), `Lua script missing ${fragment}`);
}
assert(!lua.includes('mkdir", "-p"'), 'Lua script must not rely on Unix mkdir.');
assert(lua.includes('state.menu_open = false'), 'Lua script must close menu on playback.');
assert((lua.match(/mp\.add_forced_key_binding/g) || []).length === 5, 'Navigation bindings should be temporary only.');

const conf = await read('script-opts/ddys-mpv.conf');
for (const fragment of ['api_base=', 'http_command=curl', 'key_menu=Ctrl+d', 'prefer_keywords=', 'direct_only=no', '蓝光']) {
  assert(conf.includes(fragment), `Config missing ${fragment}`);
}

const readme = await read('README.md');
for (const fragment of ['mpv', 'Lua', 'Ctrl+d', 'Ctrl+s', 'script-opts/ddys-mpv.conf', 'curl', 'M3U', 'PLS', 'ddys-mpv-v0.1.1.zip.sha256']) {
  assert(readme.includes(fragment), `README missing ${fragment}`);
}
const readmeEn = await read('README.en.md');
for (const fragment of ['mpv Lua script', 'ddys-mpv-v0.1.1.zip', 'SHA-256']) {
  assert(readmeEn.includes(fragment), `README.en missing ${fragment}`);
}
const workflow = await read('.github/workflows/build.yml');
assert(/node-version:\s*['"]24['"]/u.test(workflow), 'workflow must use Node 24.');
assert(workflow.includes('luac5.4 -p scripts/ddys-mpv.lua'), 'workflow must run Lua syntax check.');
assert(workflow.includes('node tools/check.mjs'), 'workflow must run self-check.');
assert(workflow.includes('node tests/run.mjs'), 'workflow must run tests.');
assert(workflow.includes('tools/build-package.ps1'), 'workflow must build release package.');
assert(workflow.includes('ddys-mpv-v0.1.1.zip.sha256'), 'workflow artifact must include checksum.');

const buildScript = await read('tools/build-package.ps1');
assert(buildScript.includes('ddys-mpv-v{0}.zip'), 'build script must produce versioned ZIP.');
assert(buildScript.includes('Get-FileHash'), 'build script must produce SHA-256 checksum.');
assert(buildScript.includes('Set-Content'), 'build script must write checksum file.');
assert(buildScript.includes('Assert-InRoot'), 'build script must guard paths.');
assert(buildScript.includes('DdysZipCrc32'), 'build script must compute deterministic ZIP CRC values.');
assert(buildScript.includes('0x04034b50'), 'build script must write ZIP local file headers explicitly.');
assert(buildScript.includes('0x02014b50'), 'build script must write ZIP central directory headers explicitly.');
assert(buildScript.includes('StringComparer]::Ordinal.Compare'), 'build script must sort package entries by ordinal relative path.');

const icon = await pngSize('assets/icon.png');
assert(icon.width === 512 && icon.height === 512, 'icon.png must be 512x512.');

const files = await listFiles();
for (const file of files) {
  const relative = path.relative(root, file).replaceAll(path.sep, '/');
  const segments = relative.split('/');
  assert(!segments.includes('node_modules'), `node_modules leaked: ${relative}`);
  assert(!segments.includes('package'), `package dir leaked: ${relative}`);
  assert(!segments.includes('dist'), `dist dir leaked: ${relative}`);
  assert(!segments.includes('build'), `build dir leaked: ${relative}`);
  assert(!segments.includes('coverage'), `coverage dir leaked: ${relative}`);
  assert(!segments.includes('releases'), `releases dir leaked: ${relative}`);
  assert(!/\.(log|tmp|cache|zip|tgz|sha256)$/i.test(relative), `generated file leaked: ${relative}`);
  assert(!/(^|\/)\.env($|\.)/i.test(relative), `env file leaked: ${relative}`);
  assert(!['package-lock.json', 'pnpm-lock.yaml', 'yarn.lock'].includes(path.basename(relative)), `lockfile leaked: ${relative}`);
}

const textFiles = files.filter((file) => /\.(lua|mjs|js|json|md|txt|conf|ps1|sh|yml|yaml|gitignore)$/i.test(file));
const allText = (await Promise.all(textFiles.map((file) => fs.readFile(file, 'utf8')))).join('\n');
const tokenPatterns = [
  new RegExp('gh' + 'p_' + '[A-Za-z0-9_]+'),
  new RegExp('github_' + 'pat_' + '[A-Za-z0-9_]+'),
  new RegExp('np' + 'm_' + '[A-Za-z0-9_]+'),
  new RegExp('sk-' + '[A-Za-z0-9]{20,}')
];
for (const pattern of tokenPatterns) {
  assert(!pattern.test(allText), `secret-like pattern found: ${pattern}`);
}
assert(!allText.includes('\uFFFD'), 'Replacement character found.');
const mojibakeCodes = [0x93C8, 0x95AC, 0x9477, 0x5BEE, 0x9356, 0x59DD, 0x93BE, 0x7481, 0x9422];
for (const code of mojibakeCodes) {
  assert(!allText.includes(String.fromCodePoint(code)), `likely mojibake code point found: U+${code.toString(16).toUpperCase()}`);
}

console.log(JSON.stringify({ ok: true, package: 'ddys-mpv', files: files.length }, null, 2));

async function pngSize(relative) {
  const bytes = await fs.readFile(path.join(root, relative));
  assert(bytes.subarray(0, 8).toString('hex') === '89504e470d0a1a0a', `${relative} is not a PNG.`);
  return { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) };
}
