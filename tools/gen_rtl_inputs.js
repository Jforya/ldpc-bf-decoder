#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const MBLK = 40;
const NBLK = 50;
const ZP = 40;
const M = MBLK * ZP;
const N = NBLK * ZP;
const MAX_ITER = 50;
const MAX_RD = 6;
const MAX_CD = 4;
const MASK64 = (1n << 64n) - 1n;

function usage() {
  console.error(`usage: node ${path.relative(process.cwd(), __filename)} <base_matrix.txt> [nframes]`);
}

function readBase(file) {
  const rows = fs.readFileSync(file, "utf8")
    .split(/\r?\n/)
    .filter((line) => line.trim().length > 0)
    .map((line) => line.trim().split(/\s+/).map(Number));
  if (rows.length !== MBLK || rows.some((row) => row.length !== NBLK || row.some((v) => !Number.isInteger(v)))) {
    throw new Error(`base matrix must be ${MBLK}x${NBLK}`);
  }
  return rows;
}

function putBits(bits) {
  let out = "";
  for (let n = N - 1; n >= 0; n--) out += bits[n] ? "1" : "0";
  return out;
}

function makeRng() {
  let rs = 777n;
  return {
    rnd() {
      rs = (rs ^ ((rs << 13n) & MASK64)) & MASK64;
      rs = (rs ^ (rs >> 7n)) & MASK64;
      rs = (rs ^ ((rs << 17n) & MASK64)) & MASK64;
      return rs;
    },
    rnd01() {
      return Number(this.rnd() >> 11n) * (1.0 / 9007199254740992.0);
    },
  };
}

function buildGraph(base) {
  const rowDeg = Array(M).fill(0);
  const rowNbr = Array.from({ length: M }, () => []);
  const colDeg = Array(N).fill(0);
  const colNbr = Array.from({ length: N }, () => []);
  const thresh = Array(N).fill(0);

  for (let bi = 0; bi < MBLK; bi++) {
    for (let bj = 0; bj < NBLK; bj++) {
      const s = base[bi][bj];
      if (s < 0) continue;
      for (let r = 0; r < ZP; r++) {
        const m = bi * ZP + r;
        const n = bj * ZP + ((r + s) % ZP);
        rowNbr[m][rowDeg[m]++] = n;
        colNbr[n][colDeg[n]++] = m;
      }
    }
  }

  for (let n = 0; n < N; n++) thresh[n] = colDeg[n] - 1;
  return { rowDeg, rowNbr, colDeg, colNbr, thresh };
}

function bfDecode(x, graph, trace, fid) {
  const synd = Array(M).fill(0);
  const conflict = Array(N).fill(0);

  for (let it = 0; it < MAX_ITER; it++) {
    let weight = 0;
    for (let m = 0; m < M; m++) {
      let p = 0;
      for (let k = 0; k < graph.rowDeg[m]; k++) p ^= x[graph.rowNbr[m][k]];
      synd[m] = p;
      weight += p;
    }

    if (!weight) return { ok: 1, iters: it };

    for (let n = 0; n < N; n++) {
      let c = 0;
      for (let k = 0; k < graph.colDeg[n]; k++) c += synd[graph.colNbr[n][k]];
      conflict[n] = c;
    }

    let flips = 0;
    for (let n = 0; n < N; n++) {
      if (conflict[n] >= graph.thresh[n]) {
        x[n] ^= 1;
        flips++;
      }
    }

    if (trace && flips) trace.push(`F${fid} I${it + 1} ${putBits(x)}`);
    if (!flips) return { ok: 0, iters: it + 1 };
  }

  for (let m = 0; m < M; m++) {
    let p = 0;
    for (let k = 0; k < graph.rowDeg[m]; k++) p ^= x[graph.rowNbr[m][k]];
    if (p) return { ok: 0, iters: MAX_ITER };
  }
  return { ok: 1, iters: MAX_ITER };
}

function injectUnique(y, count, rng) {
  let injected = 0;
  while (injected < count) {
    const p = Number(rng.rnd() % BigInt(N));
    if (!y[p]) {
      y[p] = 1;
      injected++;
    }
  }
}

function writeVectors(base, nframes) {
  const graph = buildGraph(base);
  const rng = makeRng();
  const tvIn = [];
  const tvGoldBits = [];
  const tvGoldFlags = [];
  const traceGold = [];
  const summary = ["frame,injected_errors,success,iter_count,residual_errors"];
  let okCount = 0;
  let failCount = 0;

  for (let f = 0; f < nframes; f++) {
    const y = Array(N).fill(0);
    let injected = 0;

    if (f < 5) {
      injected = 0;
    } else if (f < 10) {
      injectUnique(y, 1, rng);
      injected = 1;
    } else if (f < 20) {
      injected = 2 + Number(rng.rnd() % 19n);
      injectUnique(y, injected, rng);
    } else {
      const rates = [0.01, 0.02, 0.03, 0.04, 0.05, 0.06];
      const rber = rates[f % 6];
      for (let n = 0; n < N; n++) {
        if (rng.rnd01() < rber) {
          y[n] = 1;
          injected++;
        }
      }
    }

    const x = y.slice();
    const res = bfDecode(x, graph, traceGold, f);
    const residual = x.reduce((acc, bit) => acc + bit, 0);

    tvIn.push(putBits(y));
    tvGoldBits.push(putBits(x));
    tvGoldFlags.push(String(res.ok) + res.iters.toString(2).padStart(7, "0"));
    summary.push(`${f},${injected},${res.ok},${res.iters},${residual}`);
    if (res.ok) okCount++;
    else failCount++;
  }

  fs.writeFileSync("tv_in.txt", tvIn.join("\n") + "\n");
  fs.writeFileSync("tv_gold_bits.txt", tvGoldBits.join("\n") + "\n");
  fs.writeFileSync("tv_gold_flags.txt", tvGoldFlags.join("\n") + "\n");
  fs.writeFileSync("trace_gold.txt", traceGold.join("\n") + (traceGold.length ? "\n" : ""));
  fs.writeFileSync("tv_summary.csv", summary.join("\n") + "\n");
  console.error(`vectors: ${nframes} frames (${okCount} success, ${failCount} fail)`);
}

function packEntry(valid, idx, shift) {
  if (!valid) return 0;
  if (idx < 0 || idx > 0x3f) throw new Error(`idx out of 6-bit range: ${idx}`);
  if (shift < 0 || shift > 0x3f) throw new Error(`shift out of 6-bit range: ${shift}`);
  return (1 << 15) | (idx << 8) | shift;
}

function emitVec(name, width, values) {
  const totalWidth = width * values.length;
  const hexWidth = Math.ceil(totalWidth / 4);
  let value = 0n;
  for (let i = 0; i < values.length; i++) value |= BigInt(values[i]) << BigInt(i * width);
  return `localparam [${totalWidth - 1}:0] ${name} = ${totalWidth}'h${value.toString(16).padStart(hexWidth, "0")};`;
}

function writeQcParams(base) {
  const rowEntries = [];
  const rowDegs = [];
  for (let bi = 0; bi < MBLK; bi++) {
    const conns = [];
    for (let bj = 0; bj < NBLK; bj++) {
      if (base[bi][bj] >= 0) conns.push([bj, base[bi][bj]]);
    }
    if (conns.length > MAX_RD) throw new Error(`row block ${bi} degree ${conns.length} > MAX_RD`);
    rowDegs.push(conns.length);
    for (let e = 0; e < MAX_RD; e++) {
      rowEntries.push(e < conns.length ? packEntry(true, conns[e][0], conns[e][1]) : packEntry(false, 0, 0));
    }
  }

  const colEntries = [];
  const colDegs = [];
  for (let bj = 0; bj < NBLK; bj++) {
    const conns = [];
    for (let bi = 0; bi < MBLK; bi++) {
      if (base[bi][bj] >= 0) conns.push([bi, base[bi][bj]]);
    }
    if (conns.length > MAX_CD) throw new Error(`column block ${bj} degree ${conns.length} > MAX_CD`);
    colDegs.push(conns.length);
    for (let e = 0; e < MAX_CD; e++) {
      colEntries.push(e < conns.length ? packEntry(true, conns[e][0], conns[e][1]) : packEntry(false, 0, 0));
    }
  }

  const nonzeroBlocks = rowDegs.reduce((acc, v) => acc + v, 0);
  const minCol = Math.min(...colDegs);
  const maxCol = Math.max(...colDegs);
  const minRow = Math.min(...rowDegs);
  const maxRow = Math.max(...rowDegs);
  if (nonzeroBlocks !== 197) throw new Error(`unexpected nonzero blocks: ${nonzeroBlocks}`);
  if (minCol !== 3 || maxCol !== 4) throw new Error(`unexpected column degree range: ${minCol}..${maxCol}`);
  if (minRow < 4 || maxRow > 6) throw new Error(`unexpected row degree range: ${minRow}..${maxRow}`);

  const out = [
    "// Auto-generated by tools/gen_qc_params.py. Do not edit by hand.",
    "// Entry format: {valid[15], idx[13:8], shift[5:0]}; bit[14] unused.",
    `localparam integer MBLK = ${MBLK};`,
    `localparam integer NBLK = ${NBLK};`,
    `localparam integer ZP = ${ZP};`,
    `localparam integer MAX_RD = ${MAX_RD};`,
    `localparam integer MAX_CD = ${MAX_CD};`,
    `localparam integer QC_MAX_ITER = ${MAX_ITER};`,
    emitVec("ROWCONN", 16, rowEntries),
    emitVec("COLCONN", 16, colEntries),
    emitVec("COLDEG", 4, colDegs),
    "",
  ].join("\n");

  const outPath = path.join("rtl", "qc_params.vh");
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, out);
  console.log(`generated ${outPath}`);
  console.log(`nonzero_blocks=${nonzeroBlocks}, col_degree=${minCol}..${maxCol}, row_degree=${minRow}..${maxRow}`);
}

function main() {
  const baseFile = process.argv[2];
  const nframes = process.argv[3] ? Number(process.argv[3]) : 120;
  if (!baseFile || !Number.isInteger(nframes) || nframes <= 0) {
    usage();
    process.exit(1);
  }
  const base = readBase(baseFile);
  writeQcParams(base);
  writeVectors(base, nframes);
}

main();
