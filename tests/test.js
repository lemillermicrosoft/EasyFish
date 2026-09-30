"use strict";

const assert = require("assert");
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const luaparse = require("luaparse");

const root = path.resolve(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const core = read("Core.lua");
const options = read("Options.lua");
const toc = read("EasyFish_Forever.toc");
const bindings = read("Bindings.xml");
const pkg = JSON.parse(read("package.json"));

for (const [name, source] of [["Core.lua", core], ["Options.lua", options]]) {
  assert.doesNotThrow(() => luaparse.parse(source, { luaVersion: "5.1" }), `${name} must parse as Lua 5.1`);
}

assert.match(toc, /^## Interface: 16001$/m);
assert.match(toc, /^## Title: EasyFish Forever$/m);
assert.match(toc, /^## SavedVariables: EasyFishForeverDB$/m);
assert(!/^Bindings\.xml\r?$/m.test(toc), "Bindings.xml is a WoW special file and must not be double-loaded from TOC");
assert.match(toc, /^Core\.lua\r?$/m);
assert.match(toc, /^Options\.lua\r?$/m);
assert.match(bindings, /EasyFishForeverActionButton/);
assert.match(core, /SLASH_EASYFISHFOREVER1 = "\/easyfishforever"/);
assert.match(core, /SLASH_EASYFISHFOREVER2 = "\/eff"/);
assert.doesNotMatch(core, /SLASH_EASYFISH1|EasyFishDB\s*=/, "must not own original globals");

for (const forbidden of [
  "GLOBAL_MOUSE_DOWN", "GetMouseFocus", "CastSpellByName",
  "UseItemByName", "EquipItemByName", "InteractUnit", "LootSlot",
]) {
  assert(!core.includes(forbidden), `runtime must not contain forbidden/risky API: ${forbidden}`);
}
assert(!/SetScript\s*\(\s*["']PreClick/.test(core), "runtime must not mutate secure state in PreClick");
assert(!/UnitExists\s*\(\s*["']mouseover/.test(core), "runtime must not inspect mouseover units");
assert.match(core, /issecretvalue/);
assert.match(core, /InCombatLockdown/);
assert.match(core, /SecureActionButtonTemplate/);

const tocVersion = /^## Version:\s*(\S+)$/m.exec(toc)[1];
assert.strictEqual(pkg.version, tocVersion, "package and TOC versions must match");
assert(core.includes(`EF.VERSION = "${tocVersion}"`), "Lua and TOC versions must match");

const packager = require("../scripts/package.js");
const first = packager.buildZip();
const second = packager.buildZip();
assert.strictEqual(crypto.createHash("sha256").update(first).digest("hex"), crypto.createHash("sha256").update(second).digest("hex"));
assert(first.includes(Buffer.from("EasyFish_Forever/EasyFish_Forever.toc")));
assert(!first.includes(Buffer.from("node_modules")));
assert(!first.includes(Buffer.from(".git")));

console.log("ok - Lua 5.1 parse, static security policy, metadata, and deterministic package");
