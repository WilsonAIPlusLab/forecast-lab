// Chapter 12: a small, dependency-free CART regression tree + random forest for the explorables.
// Splits minimise the sum of squared errors (SSE), exactly the rule rpart / randomForest use for regression.

export type Rng = () => number;

/** Seeded uniform [0,1) generator (mulberry32). Same seed, same forest, every time. */
export function mulberry(seed: number): Rng {
  let s = seed >>> 0;
  return () => {
    s = (s + 0x6d2b79f5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export interface Cut { thr: number; gain: number; nL: number; nR: number; meanL: number; meanR: number }

export function sse(y: number[], idx: number[]) {
  let s = 0, q = 0;
  for (const i of idx) { s += y[i]; q += y[i] * y[i]; }
  return idx.length ? q - (s * s) / idx.length : 0;
}
export function meanOf(y: number[], idx: number[]) {
  let s = 0; for (const i of idx) s += y[i];
  return idx.length ? s / idx.length : 0;
}

/** Every admissible cut on feature f (midpoints between distinct values), with its SSE reduction. */
export function scan(X: number[][], y: number[], idx: number[], f: number, minLeaf = 1): Cut[] {
  const o = idx.slice().sort((a, b) => X[a][f] - X[b][f]);
  const n = o.length;
  let tot = 0, totQ = 0;
  for (const i of o) { tot += y[i]; totQ += y[i] * y[i]; }
  const parent = totQ - (tot * tot) / n;
  const out: Cut[] = [];
  let sL = 0, qL = 0;
  for (let k = 0; k < n - 1; k++) {
    const i = o[k];
    sL += y[i]; qL += y[i] * y[i];
    const nL = k + 1, nR = n - nL;
    const a = X[i][f], b = X[o[k + 1]][f];
    if (a === b || nL < minLeaf || nR < minLeaf) continue;
    const sR = tot - sL, qR = totQ - qL;
    const child = (qL - (sL * sL) / nL) + (qR - (sR * sR) / nR);
    out.push({ thr: (a + b) / 2, gain: parent - child, nL, nR, meanL: sL / nL, meanR: sR / nR });
  }
  return out;
}

export function bestCut(X: number[][], y: number[], idx: number[], feats: number[], minLeaf = 1) {
  let best: (Cut & { f: number }) | null = null;
  for (const f of feats) for (const c of scan(X, y, idx, f, minLeaf)) if (!best || c.gain > best.gain + 1e-12) best = { ...c, f };
  return best;
}

export interface TNode { value: number; n: number; f?: number; thr?: number; l?: TNode; r?: TNode }

export interface TreeOpts { maxDepth?: number; minLeaf?: number; minSplit?: number; mtry?: number; rng?: Rng }

/** Grow one regression tree depth-first. mtry < #features samples features at every split (random forest). */
export function growTree(X: number[][], y: number[], idx: number[], o: TreeOpts = {}, depth = 0): TNode {
  const { maxDepth = 30, minLeaf = 1, minSplit = 2, mtry, rng = Math.random } = o;
  const node: TNode = { value: meanOf(y, idx), n: idx.length };
  if (depth >= maxDepth || idx.length < Math.max(minSplit, 2 * minLeaf)) return node;
  const p = X[0].length;
  let feats = Array.from({ length: p }, (_, j) => j);
  if (mtry && mtry < p) {
    for (let j = p - 1; j > 0; j--) { const k = Math.floor(rng() * (j + 1)); [feats[j], feats[k]] = [feats[k], feats[j]]; }
    feats = feats.slice(0, mtry);
  }
  const c = bestCut(X, y, idx, feats, minLeaf);
  if (!c || c.gain <= 1e-10) return node;
  node.f = c.f; node.thr = c.thr;
  node.l = growTree(X, y, idx.filter((i) => X[i][c.f] <= c.thr), o, depth + 1);
  node.r = growTree(X, y, idx.filter((i) => X[i][c.f] > c.thr), o, depth + 1);
  return node;
}

export function predictTree(t: TNode, x: number[]): number {
  let n = t;
  while (n.l && n.r) n = x[n.f!] <= n.thr! ? n.l : n.r;
  return n.value;
}

export interface Forest { trees: TNode[]; inbag: Uint8Array[] }

/** Bagging / random forest: bootstrap rows for every tree, optional feature sampling (mtry) at every split. */
export function growForest(X: number[][], y: number[], o: { nTrees: number; mtry?: number; minLeaf?: number; minSplit?: number; maxDepth?: number; seed?: number }): Forest {
  const rng = mulberry(o.seed ?? 1);
  const n = y.length, trees: TNode[] = [], inbag: Uint8Array[] = [];
  for (let b = 0; b < o.nTrees; b++) {
    const idx: number[] = [], bag = new Uint8Array(n);
    for (let k = 0; k < n; k++) { const i = Math.floor(rng() * n); idx.push(i); bag[i] = 1; }
    trees.push(growTree(X, y, idx, { mtry: o.mtry, minLeaf: o.minLeaf ?? 1, minSplit: o.minSplit ?? 5, maxDepth: o.maxDepth ?? 30, rng }));
    inbag.push(bag);
  }
  return { trees, inbag };
}

export function predictForest(f: Forest, x: number[], k = f.trees.length) {
  let s = 0; for (let b = 0; b < k; b++) s += predictTree(f.trees[b], x);
  return s / k;
}

/** Recursive multi-step forecast for a model of a vector with `p` lags as features (lag1 first). */
export function recursiveLags(predict: (x: number[]) => number, history: number[], p: number, h: number) {
  const hist = history.slice();
  for (let k = 0; k < h; k++) {
    const n = hist.length;
    hist.push(predict(Array.from({ length: p }, (_, j) => hist[n - 1 - j])));
  }
  return hist.slice(-h);
}

/** Supervised table from a vector: rows of [lag1..lagp] -> target. */
export function lagTable(v: number[], p: number) {
  const X: number[][] = [], y: number[] = [];
  for (let t = p; t < v.length; t++) { X.push(Array.from({ length: p }, (_, j) => v[t - 1 - j])); y.push(v[t]); }
  return { X, y };
}
