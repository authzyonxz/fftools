'use strict';
// Minimal ZIP reader: local file headers + central directory, stored (0) and
// deflate (8), no encryption, no zip64. Enough for payload packs that the admin
// uploads from Compress-Archive / Finder / 7-Zip.

const zlib = require('node:zlib');

const SIG_EOCD = 0x06054b50;
const SIG_CENTRAL = 0x02014b50;
const SIG_LOCAL = 0x04034b50;

class ZipError extends Error {}

function findEndOfCentralDirectory(buffer) {
  const minimum = Math.max(0, buffer.length - 0xffff - 22);
  for (let offset = buffer.length - 22; offset >= minimum; offset--) {
    if (buffer.readUInt32LE(offset) === SIG_EOCD) return offset;
  }
  throw new ZipError('EOCD não encontrado (arquivo não é um ZIP válido)');
}

function readCentralDirectory(buffer) {
  const eocd = findEndOfCentralDirectory(buffer);
  const entryCount = buffer.readUInt16LE(eocd + 10);
  let offset = buffer.readUInt32LE(eocd + 16);
  const entries = [];
  for (let index = 0; index < entryCount; index++) {
    if (buffer.readUInt32LE(offset) !== SIG_CENTRAL) throw new ZipError('central directory corrompido');
    const flags = buffer.readUInt16LE(offset + 8);
    const method = buffer.readUInt16LE(offset + 10);
    const compressedSize = buffer.readUInt32LE(offset + 20);
    const uncompressedSize = buffer.readUInt32LE(offset + 24);
    const nameLength = buffer.readUInt16LE(offset + 28);
    const extraLength = buffer.readUInt16LE(offset + 30);
    const commentLength = buffer.readUInt16LE(offset + 32);
    const localOffset = buffer.readUInt32LE(offset + 42);
    const name = buffer.toString('utf8', offset + 46, offset + 46 + nameLength);
    entries.push({ name, flags, method, compressedSize, uncompressedSize, localOffset });
    offset += 46 + nameLength + extraLength + commentLength;
  }
  return entries;
}

function readEntryData(buffer, entry) {
  if (buffer.readUInt32LE(entry.localOffset) !== SIG_LOCAL) throw new ZipError('local header corrompido');
  const nameLength = buffer.readUInt16LE(entry.localOffset + 26);
  const extraLength = buffer.readUInt16LE(entry.localOffset + 28);
  const dataStart = entry.localOffset + 30 + nameLength + extraLength;
  const raw = buffer.subarray(dataStart, dataStart + entry.compressedSize);
  if (entry.flags & 0x1) throw new ZipError('ZIP com senha não é suportado');
  if (entry.method === 0) return Buffer.from(raw);
  if (entry.method === 8) return zlib.inflateRawSync(raw);
  throw new ZipError(`método de compressão não suportado: ${entry.method}`);
}

/*! Returns [{ path, data }] for every regular file, skipping directories,
    __MACOSX and dotfiles. Rejects absolute paths and "..". */
function extractZip(buffer) {
  const entries = readCentralDirectory(buffer);
  const files = [];
  for (const entry of entries) {
    if (entry.name.endsWith('/')) continue;
    const cleaned = entry.name.replace(/\\/g, '/');
    if (cleaned.startsWith('__MACOSX/')) continue;
    const parts = cleaned.split('/').filter(Boolean);
    if (parts.length === 0) continue;
    if (parts.some((part) => part === '..' || part === '.')) {
      throw new ZipError(`caminho inseguro no ZIP: ${entry.name}`);
    }
    if (parts[0].startsWith('.')) continue;
    const data = readEntryData(buffer, entry);
    if (data.length === 0) continue;
    files.push({ path: parts.join('/'), data });
  }
  if (files.length === 0) throw new ZipError('ZIP sem arquivos de payload');
  return files;
}

module.exports = { extractZip, ZipError };
