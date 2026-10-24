import { describe, expect, it } from 'vitest';
import { angleLerp, evaluate, fieldToScreen, footprint, screenToField, split, zoomAt } from './geometry';
import { initialDocument, insertNode, measurePath, moveHandle, moveNode, poseAt, reversePath, segments } from './path';
import { DocumentHistory } from './history';
import { parseProject, serializeProject } from '../io/project';

describe('geometric path invariants', () => {
  it('evaluates cubic endpoints and an analytically known midpoint', () => {
    const c = { p0: { x: 0, y: 0 }, p1: { x: 0, y: 10 }, p2: { x: 10, y: 10 }, p3: { x: 10, y: 0 } };
    expect(evaluate(c, 0)).toEqual(c.p0); expect(evaluate(c, 1)).toEqual(c.p3); expect(evaluate(c, .5)).toEqual({ x: 5, y: 7.5 });
  });
  it('subdivision preserves the original curve at every corresponding parameter', () => {
    const c = segments(initialDocument())[0], cut = .37, [a, b] = split(c, cut);
    for (let i = 0; i <= 100; i++) { const t = i / 100, expected = evaluate(c, t), actual = t <= cut ? evaluate(a, t / cut) : evaluate(b, (t - cut) / (1 - cut)); expect(actual.x).toBeCloseTo(expected.x, 10); expect(actual.y).toBeCloseTo(expected.y, 10); }
  });
  it('measures a straight 100-inch path and maps distance to its pose', () => {
    const doc = initialDocument(); doc.nodes[0].position = { x: 0, y: 0 }; doc.nodes[0].outgoing = { x: 100 / 3, y: 0 }; doc.nodes[1].incoming = { x: 200 / 3, y: 0 }; doc.nodes[1].position = { x: 100, y: 0 };
    doc.headingMode = 'fixed'; doc.fixedHeading = Math.PI / 2;
    const m = measurePath(doc), p = poseAt(doc, m, .5); expect(m.length).toBeCloseTo(100, 8); expect(m.maxCurvature).toBe(0); expect(p.x).toBeCloseTo(50, 8); expect(p.heading).toBe(Math.PI / 2); expect(p.tangent).toBe(0);
  });
  it('inserting then reversing maintains path geometry and arc length', () => {
    const doc = initialDocument(), next = insertNode(doc, 0, .5), reversed = reversePath(next);
    expect(measurePath(next).length).toBeCloseTo(measurePath(doc).length, 2);
    for (let i = 0; i <= 20; i++) { const a = poseAt(next, measurePath(next), i / 20), b = poseAt(reversed, measurePath(reversed), 1 - i / 20); expect(a.x).toBeCloseTo(b.x, 6); expect(a.y).toBeCloseTo(b.y, 6); }
    expect(reversePath(reversed)).toEqual(next);
  });
  it('moves connected handles with an anchor and preserves mirrored tangents', () => {
    const doc = initialDocument(), n = doc.nodes[0]; n.handles = 'mirrored';
    const moved = moveNode(doc, n.id, { x: n.position.x + 7, y: n.position.y - 3 });
    expect(moved.nodes[0].outgoing.x).toBe(n.outgoing.x + 7);
    const edited = moveHandle(doc, n.id, 'outgoing', { x: n.position.x + 10, y: n.position.y + 4 });
    expect(edited.nodes[0].incoming).toEqual({ x: n.position.x - 10, y: n.position.y - 4 });
  });
  it('keeps heading interpolation continuous through the 360-degree seam', () => {
    expect(angleLerp(350 * Math.PI / 180, 10 * Math.PI / 180, .5)).toBeCloseTo(2 * Math.PI, 10);
  });
  it('handles a zero-length path without NaN', () => {
    const doc = initialDocument(); doc.nodes = doc.nodes.map(n => ({ ...n, position: { x: 0, y: 0 }, incoming: { x: 0, y: 0 }, outgoing: { x: 0, y: 0 } }));
    const m = measurePath(doc); expect(m.length).toBe(0); expect(m.singular).toBe(true); expect(Number.isFinite(poseAt(doc, m, .5).heading)).toBe(true);
  });
});
describe('coordinates and robot footprint', () => {
  it('round-trips coordinates and holds the cursor world point during zoom', () => {
    const v = { x: 500, y: 300, scale: 4 }, p = { x: -23.5, y: 51.2 };
    const s = fieldToScreen(p, v); expect(screenToField(s, v).x).toBeCloseTo(p.x, 10); expect(screenToField(s, v).y).toBeCloseTo(p.y, 10);
    expect(fieldToScreen(p, zoomAt(v, s, 1.7)).x).toBeCloseTo(s.x, 10); expect(fieldToScreen(p, zoomAt(v, s, 1.7)).y).toBeCloseTo(s.y, 10);
  });
  it('rotates a non-square robot with heading', () => {
    const points = footprint({ x: 0, y: 0 }, Math.PI / 2, 16, 18);
    expect(Math.max(...points.map(p => p.x))).toBeCloseTo(8, 10); expect(Math.max(...points.map(p => p.y))).toBeCloseTo(9, 10);
  });
});
describe('documents and undo transactions', () => {
  it('coalesces a drag and restores through undo/redo', () => {
    const h = new DocumentHistory({ x: 1 }); h.begin(); for (let x = 2; x < 200; x++) h.preview({ x }); h.commit();
    h.undo(); expect(h.current).toEqual({ x: 1 }); expect(h.canUndo).toBe(false); h.redo(); expect(h.current.x).toBe(199);
    h.begin(); h.preview({ x: 500 }); h.cancel(); expect(h.current.x).toBe(199);
  });
  it('invalidates redo when a new edit follows undo', () => {
    const h = new DocumentHistory(1); h.apply(2); h.undo(); h.apply(3); expect(h.canRedo).toBe(false);
  });
  it('round-trips all editing data and rejects malformed projects', () => {
    const d = insertNode(initialDocument(), 0); expect(parseProject(serializeProject(d))).toEqual(d);
    expect(() => parseProject(JSON.stringify({ ...d, units: 'm' }))).toThrow();
    expect(() => parseProject(JSON.stringify({ ...d, robot: { width: -1, length: 10 } }))).toThrow();
    expect(() => parseProject(JSON.stringify({ ...d, nodes: [d.nodes[0], d.nodes[0]] }))).toThrow();
    expect(() => parseProject(JSON.stringify({ ...d, nodes: [] }))).toThrow();
  });
});
