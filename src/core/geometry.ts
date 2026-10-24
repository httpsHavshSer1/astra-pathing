/** World space: inches, +x right, +y up. Angles are radians, counterclockwise. */
export type Vec = { x: number; y: number };
export type Cubic = { p0: Vec; p1: Vec; p2: Vec; p3: Vec };
export type Viewport = { x: number; y: number; scale: number };
export const add = (a: Vec, b: Vec): Vec => ({ x: a.x + b.x, y: a.y + b.y });
export const sub = (a: Vec, b: Vec): Vec => ({ x: a.x - b.x, y: a.y - b.y });
export const mul = (a: Vec, n: number): Vec => ({ x: a.x * n, y: a.y * n });
export const length = (a: Vec) => Math.hypot(a.x, a.y);
export const distance = (a: Vec, b: Vec) => length(sub(a, b));
export const lerp = (a: Vec, b: Vec, t: number) => add(mul(a, 1 - t), mul(b, t));
export const clamp = (v: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, v));
export const radians = (degrees: number) => degrees * Math.PI / 180;
export const degrees = (angle: number) => angle * 180 / Math.PI;
export const angleDelta = (a: number, b: number) => Math.atan2(Math.sin(b - a), Math.cos(b - a));
export const angleLerp = (a: number, b: number, t: number) => a + angleDelta(a, b) * t;
export function evaluate(c: Cubic, t: number): Vec {
  const u = 1 - t;
  return add(add(mul(c.p0, u ** 3), mul(c.p1, 3 * u * u * t)), add(mul(c.p2, 3 * u * t * t), mul(c.p3, t ** 3)));
}
export function derivative(c: Cubic, t: number): Vec {
  return add(add(mul(sub(c.p1, c.p0), 3 * (1 - t) ** 2), mul(sub(c.p2, c.p1), 6 * (1 - t) * t)), mul(sub(c.p3, c.p2), 3 * t * t));
}
export function curvature(c: Cubic, t: number): number | null {
  const d = derivative(c, t);
  const d2 = add(mul(add(sub(c.p2, mul(c.p1, 2)), c.p0), 6 * (1 - t)), mul(add(sub(c.p3, mul(c.p2, 2)), c.p1), 6 * t));
  const speed = length(d);
  return speed < 1e-8 ? null : (d.x * d2.y - d.y * d2.x) / speed ** 3;
}
/** Exact de Casteljau subdivision; inserting an anchor does not change the curve. */
export function split(c: Cubic, t = 0.5): [Cubic, Cubic] {
  const a = lerp(c.p0, c.p1, t), b = lerp(c.p1, c.p2, t), d = lerp(c.p2, c.p3, t);
  const e = lerp(a, b, t), f = lerp(b, d, t), p = lerp(e, f, t);
  return [{ p0: c.p0, p1: a, p2: e, p3: p }, { p0: p, p1: f, p2: d, p3: c.p3 }];
}
export const fieldToScreen = (p: Vec, v: Viewport): Vec => ({ x: v.x + p.x * v.scale, y: v.y - p.y * v.scale });
export const screenToField = (p: Vec, v: Viewport): Vec => ({ x: (p.x - v.x) / v.scale, y: (v.y - p.y) / v.scale });
export function zoomAt(v: Viewport, screen: Vec, factor: number): Viewport {
  const p = screenToField(screen, v), scale = clamp(v.scale * factor, 1, 35);
  return { scale, x: screen.x - p.x * scale, y: screen.y + p.y * scale };
}
export function footprint(p: Vec, heading: number, width: number, robotLength: number): Vec[] {
  return [[-1, -1], [1, -1], [1, 1], [-1, 1]].map(([x, y]) => ({
    x: p.x + x * robotLength / 2 * Math.cos(heading) - y * width / 2 * Math.sin(heading),
    y: p.y + x * robotLength / 2 * Math.sin(heading) + y * width / 2 * Math.cos(heading),
  }));
}
