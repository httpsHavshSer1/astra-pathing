import { add, angleLerp, clamp, curvature, derivative, distance, evaluate, length, mul, split, sub } from './geometry';
import type { Cubic, Vec } from './geometry';

export type HandleMode = 'free' | 'aligned' | 'mirrored';
export type HeadingMode = 'waypoints' | 'linear' | 'fixed' | 'tangent';
export type Waypoint = { id: string; position: Vec; incoming: Vec; outgoing: Vec; heading: number; handles: HandleMode };
export type PathDocument = {
  schemaVersion: 1; units: 'in'; angleUnits: 'rad'; coordinateFrame: 'center-x-right-y-up';
  field: 'biobuzz-2026-tu02'; name: string; pathName: string;
  robot: { width: number; length: number }; nodes: Waypoint[];
  headingMode: HeadingMode; fixedHeading: number;
};
export type Sample = { segment: number; t: number; s: number; point: Vec; curvature: number | null };
export type PathMetrics = { samples: Sample[]; length: number; maxCurvature: number; singular: boolean; segmentLengths: number[] };
export const newId = () => crypto.randomUUID();
export function initialDocument(): PathDocument {
  return {
    schemaVersion: 1, units: 'in', angleUnits: 'rad', coordinateFrame: 'center-x-right-y-up', field: 'biobuzz-2026-tu02',
    name: 'First light', pathName: 'Opening route', robot: { width: 16, length: 18 }, headingMode: 'waypoints', fixedHeading: 0,
    nodes: [
      { id: newId(), position: { x: -52, y: -43 }, incoming: { x: -65, y: -43 }, outgoing: { x: -47, y: 13 }, heading: Math.PI / 2, handles: 'free' },
      { id: newId(), position: { x: 38, y: 44 }, incoming: { x: -26, y: 60 }, outgoing: { x: 56, y: 44 }, heading: 0, handles: 'free' },
    ],
  };
}
export function segments(doc: PathDocument): Cubic[] {
  return doc.nodes.slice(0, -1).map((node, i) => ({ p0: node.position, p1: node.outgoing, p2: doc.nodes[i + 1].incoming, p3: doc.nodes[i + 1].position }));
}
/** 200 subdivisions/segment: numerical engineering estimates, not collision certification. */
export function measurePath(doc: PathDocument): PathMetrics {
  let s = 0, maxCurvature = 0, singular = false;
  const samples: Sample[] = [], segmentLengths: number[] = [];
  segments(doc).forEach((c, segment) => {
    const start = s;
    let prev = c.p0;
    for (let i = 0; i <= 200; i++) {
      const t = i / 200, point = evaluate(c, t), k = curvature(c, t);
      if (i) s += distance(prev, point);
      if (k === null) singular = true; else maxCurvature = Math.max(maxCurvature, Math.abs(k));
      samples.push({ segment, t, point, s, curvature: k }); prev = point;
    }
    segmentLengths.push(s - start);
  });
  return { samples, length: s, maxCurvature, singular, segmentLengths };
}
export function headingAt(doc: PathDocument, segment: number, t: number, fraction: number): number {
  if (doc.headingMode === 'fixed') return doc.fixedHeading;
  if (doc.headingMode === 'linear') return angleLerp(doc.nodes[0].heading, doc.nodes.at(-1)!.heading, fraction);
  if (doc.headingMode === 'tangent') {
    const c = segments(doc)[segment];
    let d = derivative(c, t);
    if (length(d) < 1e-8) d = sub(c.p3, c.p0);
    return length(d) < 1e-8 ? doc.nodes[segment].heading : Math.atan2(d.y, d.x);
  }
  return angleLerp(doc.nodes[segment].heading, doc.nodes[segment + 1].heading, t);
}
export function poseAt(doc: PathDocument, metrics: PathMetrics, fraction: number) {
  const target = clamp(fraction, 0, 1) * metrics.length, arr = metrics.samples;
  let low = 0, high = arr.length - 1;
  while (low < high) { const mid = (low + high) >>> 1; if (arr[mid].s < target) low = mid + 1; else high = mid; }
  const b = arr[low], a = arr[Math.max(0, low - 1)];
  const t = a.segment === b.segment && b.s > a.s ? a.t + (b.t - a.t) * (target - a.s) / (b.s - a.s) : b.t;
  const c = segments(doc)[b.segment], point = evaluate(c, t), d = derivative(c, t);
  return { ...point, heading: headingAt(doc, b.segment, t, fraction), tangent: Math.atan2(d.y, d.x), segment: b.segment, t };
}
export function updateNode(doc: PathDocument, id: string, update: Partial<Waypoint>): PathDocument {
  return { ...doc, nodes: doc.nodes.map(n => n.id === id ? { ...n, ...update } : n) };
}
export function moveNode(doc: PathDocument, id: string, position: Vec): PathDocument {
  const node = doc.nodes.find(n => n.id === id)!;
  const delta = sub(position, node.position);
  return updateNode(doc, id, { position, incoming: add(node.incoming, delta), outgoing: add(node.outgoing, delta) });
}
export function moveHandle(doc: PathDocument, id: string, side: 'incoming' | 'outgoing', point: Vec): PathDocument {
  const node = doc.nodes.find(n => n.id === id)!;
  const other = side === 'incoming' ? 'outgoing' : 'incoming';
  const update: Partial<Waypoint> = { [side]: point };
  if (node.handles !== 'free') {
    const vector = sub(point, node.position), len = length(vector);
    if (len > 1e-8) update[other] = add(node.position, mul(vector, -(node.handles === 'mirrored' ? len : distance(node[other], node.position)) / len));
  }
  return updateNode(doc, id, update);
}
export function insertNode(doc: PathDocument, segment: number, t = .5): PathDocument {
  t = clamp(t, .02, .98);
  const [a, b] = split(segments(doc)[segment], t);
  const nodes = doc.nodes.map(n => ({ ...n }));
  const heading = headingAt(doc, segment, t, (segment + t) / (nodes.length - 1));
  nodes[segment].outgoing = a.p1; nodes[segment + 1].incoming = b.p2;
  nodes.splice(segment + 1, 0, { id: newId(), position: a.p3, incoming: a.p2, outgoing: b.p1, heading, handles: 'aligned' });
  return { ...doc, nodes };
}
export function removeNode(doc: PathDocument, id: string): PathDocument {
  if (doc.nodes.length <= 2) return doc;
  return { ...doc, nodes: doc.nodes.filter(n => n.id !== id) };
}
export function reversePath(doc: PathDocument): PathDocument {
  return { ...doc, nodes: [...doc.nodes].reverse().map(n => ({ ...n, incoming: n.outgoing, outgoing: n.incoming })) };
}
export function reorderNode(doc: PathDocument, index: number, direction: -1 | 1): PathDocument {
  const next = index + direction;
  if (index <= 0 || index >= doc.nodes.length - 1 || next <= 0 || next >= doc.nodes.length - 1) return doc;
  const nodes = [...doc.nodes]; [nodes[index], nodes[next]] = [nodes[next], nodes[index]];
  return { ...doc, nodes };
}
export function nearestOnPath(doc: PathDocument, point: Vec): { segment: number; t: number; distance: number } {
  let best = { segment: 0, t: .5, distance: Infinity };
  segments(doc).forEach((c, segment) => { for (let i = 1; i < 100; i++) {
    const t = i / 100, d = distance(evaluate(c, t), point);
    if (d < best.distance) best = { segment, t, distance: d };
  } });
  return best;
}
