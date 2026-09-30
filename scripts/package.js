"use strict";

const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const root = path.resolve(__dirname, "..");
const toc = fs.readFileSync(path.join(root, "EasyFish_Forever.toc"), "utf8");
const version = /^## Version:\s*(\S+)\s*$/m.exec(toc)[1];
const output = path.join(root, "dist", `EasyFish_Forever-v${version}.zip`);
const files = [
  "EasyFish_Forever.toc",
  "Bindings.xml",
  "Core.lua",
  "Options.lua",
  "Media/icon.png",
  "README.md",
  "API_FINDINGS.md",
  "PLAN.md",
  "CHANGELOG.md",
  "CHANGELOG_RELEASE.md",
];

const crcTable = Array.from({ length: 256 }, (_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
  return c >>> 0;
});

function crc32(buffer) {
  let crc = 0xffffffff;
  for (const byte of buffer) crc = crcTable[(crc ^ byte) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

function u16(value) { const b = Buffer.alloc(2); b.writeUInt16LE(value); return b; }
function u32(value) { const b = Buffer.alloc(4); b.writeUInt32LE(value >>> 0); return b; }

function buildZip() {
  const localParts = [];
  const centralParts = [];
  let offset = 0;

  for (const relative of files) {
    const source = path.join(root, ...relative.split("/"));
    if (!fs.existsSync(source)) throw new Error(`missing package file: ${relative}`);
    const data = fs.readFileSync(source);
    const compressed = zlib.deflateRawSync(data, { level: 9 });
    const name = Buffer.from(`EasyFish_Forever/${relative}`, "utf8");
    const crc = crc32(data);
    // Fixed 2026-01-01 00:00:00 DOS timestamp for byte-for-byte reproducibility.
    const dosTime = 0;
    const dosDate = ((2026 - 1980) << 9) | (1 << 5) | 1;

    const local = Buffer.concat([
      u32(0x04034b50), u16(20), u16(0x0800), u16(8), u16(dosTime), u16(dosDate),
      u32(crc), u32(compressed.length), u32(data.length), u16(name.length), u16(0), name, compressed,
    ]);
    localParts.push(local);

    const central = Buffer.concat([
      u32(0x02014b50), u16(20), u16(20), u16(0x0800), u16(8), u16(dosTime), u16(dosDate),
      u32(crc), u32(compressed.length), u32(data.length), u16(name.length), u16(0), u16(0),
      u16(0), u16(0), u32(0), u32(offset), name,
    ]);
    centralParts.push(central);
    offset += local.length;
  }

  const central = Buffer.concat(centralParts);
  const end = Buffer.concat([
    u32(0x06054b50), u16(0), u16(0), u16(files.length), u16(files.length),
    u32(central.length), u32(offset), u16(0),
  ]);
  return Buffer.concat([...localParts, central, end]);
}

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, buildZip());
console.log(path.relative(root, output).replace(/\\/g, "/"));

module.exports = { buildZip, files, output };
