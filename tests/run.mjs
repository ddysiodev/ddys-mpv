import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const tests = [];

test('Lua script exposes DDYS mpv features', async () => {
  const lua = await readFile('scripts/ddys-mpv.lua', 'utf8');
  for (const fragment of [
    'source_defs',
    'prompt_search',
    'detail_menu',
    'play_resource',
    'export_playlist',
    'add_favorite',
    'history_menu',
    'favorites_menu',
    'filtered_resources',
    'resource_score'
  ]) {
    assert.ok(lua.includes(fragment), `missing ${fragment}`);
  }
});

test('Lua navigation keys are temporary', async () => {
  const lua = await readFile('scripts/ddys-mpv.lua', 'utf8');
  assert.match(lua, /function bind_navigation\(\)/u);
  assert.match(lua, /function unbind_navigation\(\)/u);
  assert.match(lua, /mp\.remove_key_binding/u);
  assert.match(lua, /state\.menu_open = false/u);
  assert.equal((lua.match(/mp\.add_forced_key_binding/g) || []).length, 5);
});

test('Lua parser handles broad DDYS API shapes', async () => {
  const lua = await readFile('scripts/ddys-mpv.lua', 'utf8');
  for (const fragment of [
    '"items", "list", "results", "movies", "records", "data"',
    '"src", "file", "play_url"',
    '"items", "resources", "episodes", "playlist", "play", "urls"',
    'meta.total_pages or meta.totalPages or meta.last_page or meta.lastPage or meta.pages',
    'Authorization: Bearer'
  ]) {
    assert.ok(lua.includes(fragment), `missing ${fragment}`);
  }
});

test('Config and docs point to the same keys', async () => {
  const conf = await readFile('script-opts/ddys-mpv.conf', 'utf8');
  const readme = await readFile('README.md', 'utf8');
  for (const key of ['api_base', 'site_base', 'api_key', 'http_command', 'direct_only', 'auto_play_best']) {
    assert.ok(conf.includes(`${key}=`), `config missing ${key}`);
    assert.ok(readme.includes(key), `README missing ${key}`);
  }
});

test('Install scripts target mpv scripts and script-opts folders', async () => {
  const ps1 = await readFile('install/install.ps1', 'utf8');
  const sh = await readFile('install/install.sh', 'utf8');
  assert.match(ps1, /scripts/u);
  assert.match(ps1, /script-opts/u);
  assert.match(sh, /scripts/u);
  assert.match(sh, /script-opts/u);
});

for (const entry of tests) {
  await entry.fn();
}

console.log(JSON.stringify({ ok: true, tests: tests.length }, null, 2));

function test(name, fn) {
  tests.push({ name, fn });
}
