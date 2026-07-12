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

const forbiddenDirs = new Set(['.git', 'node_modules', 'coverage', 'dist', 'build', 'package']);

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
    if (forbiddenDirs.has(entry.name)) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) await listFiles(full, out);
    else out.push(full);
  }
  return out;
}

for (const file of required) {
  assert(await exists(file), `Missing required file: ${file}`);
}

const pkg = JSON.parse(await read('package.json'));
assert(pkg.name === 'ddys-mpv', 'package name mismatch.');
assert(pkg.version === '0.1.0', 'package version mismatch.');
assert(pkg.private === true, 'package must be private.');
assert(pkg.type === 'module', 'package must use ESM.');

const lua = await read('scripts/ddys-mpv.lua');
for (const fragment of [
  'mp.commandv("loadfile", resource.url, "replace")',
  'mp.osd_message',
  'mp.add_key_binding',
  'mp.add_forced_key_binding',
  'mp.remove_key_binding',
  'mp.command_native',
  'utils.parse_json',
  'options.read_options',
  'ddys-mpv-search',
  'flatten_sources',
  'export_playlist',
  'load_history',
  'load_favorites',
  'script-message-to console',
  'data_file("history.json")',
  'data_file("favorites.json")'
]) {
  assert(lua.includes(fragment), `Lua script missing ${fragment}`);
}
assert(!lua.includes('mkdir", "-p"'), 'Lua script must not rely on Unix mkdir.');
assert(lua.includes('state.menu_open = false'), 'Lua script must close menu on playback.');
assert((lua.match(/mp\.add_forced_key_binding/g) || []).length === 5, 'Navigation bindings should be temporary only.');

const conf = await read('script-opts/ddys-mpv.conf');
for (const fragment of ['api_base=', 'http_command=curl', 'key_menu=Ctrl+d', 'prefer_keywords=', 'direct_only=no']) {
  assert(conf.includes(fragment), `Config missing ${fragment}`);
}

const readme = await read('README.md');
for (const fragment of ['mpv', 'Lua', 'Ctrl+d', 'Ctrl+s', 'script-opts/ddys-mpv.conf', 'curl', 'M3U', 'PLS']) {
  assert(readme.includes(fragment), `README missing ${fragment}`);
}
assert(!readme.includes('## **开发打包**'), 'README contains unwanted developer packaging section.');

const files = await listFiles();
for (const file of files) {
  const relative = path.relative(root, file).replaceAll(path.sep, '/');
  assert(!relative.includes('/node_modules/'), `node_modules leaked: ${relative}`);
  assert(!relative.includes('/package/'), `package dir leaked: ${relative}`);
  assert(!/\.(log|tmp|cache|zip|tgz)$/i.test(relative), `generated file leaked: ${relative}`);
  assert(!/(^|\/)\.env($|\.)/i.test(relative), `env file leaked: ${relative}`);
}

const textFiles = files.filter((file) => /\.(lua|mjs|js|json|md|txt|conf|ps1|sh|yml|yaml|gitignore)$/i.test(file));
const allText = (await Promise.all(textFiles.map((file) => fs.readFile(file, 'utf8')))).join('\n');
for (const pattern of [/ghp_[A-Za-z0-9_]+/, /github_pat_[A-Za-z0-9_]+/, /npm_[A-Za-z0-9_]+/, /sk-[A-Za-z0-9]{20,}/]) {
  assert(!pattern.test(allText), `secret-like pattern found: ${pattern}`);
}
assert(!allText.includes('\uFFFD'), 'Replacement character found.');

console.log(JSON.stringify({ ok: true, package: 'ddys-mpv', files: files.length }, null, 2));
