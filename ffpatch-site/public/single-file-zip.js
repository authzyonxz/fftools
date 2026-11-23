'use strict';
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (root) root.FFSingleFileZip = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  const CRC_TABLE = new Uint32Array(256);
  for (let index = 0; index < CRC_TABLE.length; index++) {
    let value = index;
    for (let bit = 0; bit < 8; bit++) {
      value = (value & 1) ? (0xedb88320 ^ (value >>> 1)) : (value >>> 1);
    }
    CRC_TABLE[index] = value >>> 0;
  }

  function crc32(bytes) {
    let crc = 0xffffffff;
    for (let index = 0; index < bytes.length; index++) {
      crc = CRC_TABLE[(crc ^ bytes[index]) & 0xff] ^ (crc >>> 8);
    }
    return (crc ^ 0xffffffff) >>> 0;
  }

  function concat(parts) {
    const length = parts.reduce((total, part) => total + part.length, 0);
    const result = new Uint8Array(length);
    let offset = 0;
    for (const part of parts) {
      result.set(part, offset);
      offset += part.length;
    }
    return result;
  }

  function createSingleFileZip(filename, fileData) {
    const name = String(filename || '');
    if (!name || name === '.' || name === '..' || /[\\/\u0000-\u001f\u007f]/.test(name)) {
      throw new Error('Nome de arquivo inválido.');
    }
    const nameBytes = new TextEncoder().encode(name);
    const data = fileData instanceof Uint8Array ? fileData : new Uint8Array(fileData);
    if (nameBytes.length > 0xffff || data.length > 0xffffffff) {
      throw new Error('Arquivo grande demais para publicar.');
    }

    const checksum = crc32(data);
    const localHeader = new Uint8Array(30);
    const local = new DataView(localHeader.buffer);
    local.setUint32(0, 0x04034b50, true);
    local.setUint16(4, 20, true);
    local.setUint16(6, 0x0800, true);
    local.setUint16(8, 0, true);
    local.setUint32(14, checksum, true);
    local.setUint32(18, data.length, true);
    local.setUint32(22, data.length, true);
    local.setUint16(26, nameBytes.length, true);

    const centralHeader = new Uint8Array(46);
    const central = new DataView(centralHeader.buffer);
    central.setUint32(0, 0x02014b50, true);
    central.setUint16(4, 20, true);
    central.setUint16(6, 20, true);
    central.setUint16(8, 0x0800, true);
    central.setUint16(10, 0, true);
    central.setUint32(16, checksum, true);
    central.setUint32(20, data.length, true);
    central.setUint32(24, data.length, true);
    central.setUint16(28, nameBytes.length, true);

    const endRecord = new Uint8Array(22);
    const end = new DataView(endRecord.buffer);
    end.setUint32(0, 0x06054b50, true);
    end.setUint16(8, 1, true);
    end.setUint16(10, 1, true);
    end.setUint32(12, centralHeader.length + nameBytes.length, true);
    end.setUint32(16, localHeader.length + nameBytes.length + data.length, true);

    return concat([localHeader, nameBytes, data, centralHeader, nameBytes, endRecord]);
  }

  return { createSingleFileZip };
});
