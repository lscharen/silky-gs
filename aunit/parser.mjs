/**
 * aunit/parser.mjs  -  AUNT result packet parser
 *
 * Parses the binary packet written to out.dat by aunit.s.
 * See aunit.s for the packet format specification.
 *
 * Returns:
 *   {
 *     ok: boolean,
 *     status: number,
 *     registers: { A, X, Y, P, DP, SP, DBR, K },
 *     memory: [{ bank, address, length, data: Buffer }],
 *     values: { [name]: number },
 *   }
 */

const MAGIC   = 0x54_4E_55_41; // 'AUNT' little-endian
const VERSION = 1;

export function parseResult(buf) {
  if (!Buffer.isBuffer(buf)) buf = Buffer.from(buf);

  if (buf.length < 8) throw new ParseError('result packet too short');

  const magic = buf.readUInt32LE(0);
  if (magic !== MAGIC) {
    throw new ParseError(
      `bad magic 0x${magic.toString(16).padStart(8,'0')} (expected 0x544e5541 'AUNT')`
    );
  }

  const version = buf.readUInt8(4);
  if (version !== VERSION) {
    throw new ParseError(`unsupported version ${version}`);
  }

  const status     = buf.readUInt8(5);
  const recCount   = buf.readUInt16LE(6);

  const result = {
    ok:        status === 0,
    status,
    registers: null,
    memory:    [],
    values:    {},
  };

  let offset = 8;
  for (let i = 0; i < recCount; i++) {
    if (offset + 3 > buf.length) break;

    const tag     = String.fromCharCode(buf.readUInt8(offset));
    const payLen  = buf.readUInt16LE(offset + 1);
    const payload = buf.slice(offset + 3, offset + 3 + payLen);
    offset += 3 + payLen;

    switch (tag) {
      case 'R':
        result.registers = parseRegs(payload);
        break;
      case 'M':
        result.memory.push(parseMem(payload));
        break;
      case 'V':
        parseValue(payload, result.values);
        break;
      default:
        // unknown tag — skip
    }
  }

  return result;
}

function parseRegs(payload) {
  if (payload.length < 16) throw new ParseError('register record too short');
  return {
    A:   payload.readUInt16LE(0),
    X:   payload.readUInt16LE(2),
    Y:   payload.readUInt16LE(4),
    P:   payload.readUInt16LE(6)  & 0xFF,
    DP:  payload.readUInt16LE(8),
    SP:  payload.readUInt16LE(10),
    DBR: payload.readUInt16LE(12) & 0xFF,
    K:   payload.readUInt16LE(14) & 0xFF,
  };
}

function parseMem(payload) {
  if (payload.length < 5) throw new ParseError('memory record too short');
  const bank    = payload.readUInt8(0);
  const address = payload.readUInt16LE(1);
  const length  = payload.readUInt16LE(3);
  const data    = payload.slice(5, 5 + length);
  return { bank, address, length, data };
}

function parseValue(payload, target) {
  if (payload.length < 3) throw new ParseError('value record too short');
  const nameLen = payload.readUInt8(0);
  const name    = payload.slice(1, 1 + nameLen).toString('ascii');
  const value   = payload.readUInt16LE(1 + nameLen);
  target[name]  = value;
}

export class ParseError extends Error {
  constructor(msg) { super(msg); this.name = 'ParseError'; }
}

// Pretty-print a result for debugging
export function formatResult(result) {
  const lines = [];
  lines.push(`status: ${result.status} (${result.ok ? 'ok' : 'FAIL'})`);

  if (result.registers) {
    const r = result.registers;
    const flags = [
      r.P & 0x80 ? 'N' : 'n',
      r.P & 0x40 ? 'V' : 'v',
      r.P & 0x20 ? 'M' : 'm',
      r.P & 0x10 ? 'X' : 'x',
      r.P & 0x08 ? 'D' : 'd',
      r.P & 0x04 ? 'I' : 'i',
      r.P & 0x02 ? 'Z' : 'z',
      r.P & 0x01 ? 'C' : 'c',
    ].join('');
    lines.push(
      `registers: A=$${r.A.toString(16).padStart(4,'0')}` +
      ` X=$${r.X.toString(16).padStart(4,'0')}` +
      ` Y=$${r.Y.toString(16).padStart(4,'0')}` +
      ` P=${flags}` +
      ` DP=$${r.DP.toString(16).padStart(4,'0')}` +
      ` SP=$${r.SP.toString(16).padStart(4,'0')}` +
      ` DBR=$${r.DBR.toString(16).padStart(2,'0')}` +
      ` K=$${r.K.toString(16).padStart(2,'0')}`
    );
  }

  for (const [i, m] of result.memory.entries()) {
    const addr = `$${m.bank.toString(16).padStart(2,'0')}:${m.address.toString(16).padStart(4,'0')}`;
    const hex  = [...m.data].map(b => b.toString(16).padStart(2,'0')).join(' ');
    lines.push(`memory[${i}] @ ${addr} len=${m.length}: ${hex}`);
  }

  for (const [name, value] of Object.entries(result.values)) {
    lines.push(`value '${name}' = $${value.toString(16).padStart(4,'0')} (${value})`);
  }

  return lines.join('\n');
}
