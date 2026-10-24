import type { PathDocument, Waypoint } from '../core/path';
const modes = ['waypoints', 'linear', 'fixed', 'tangent'];
const finite = (v: unknown, limit = 10000): v is number => typeof v === 'number' && Number.isFinite(v) && Math.abs(v) <= limit;
const vec = (v: unknown) => !!v && typeof v === 'object' && finite((v as Record<string, unknown>).x) && finite((v as Record<string, unknown>).y);
export function parseProject(text: string): PathDocument {
  const d = JSON.parse(text);
  if (!d || d.schemaVersion !== 1 || d.units !== 'in' || d.angleUnits !== 'rad' || d.coordinateFrame !== 'center-x-right-y-up' || d.field !== 'biobuzz-2026-tu02') throw new Error('This file uses an unsupported project version, field, or coordinate system.');
  if (typeof d.name !== 'string' || d.name.length > 100 || typeof d.pathName !== 'string' || d.pathName.length > 100) throw new Error('Project and path names must be text, up to 100 characters.');
  if (!d.robot || !finite(d.robot.width, 72) || !finite(d.robot.length, 72) || d.robot.width <= 0 || d.robot.length <= 0) throw new Error('Robot dimensions must be between 0 and 72 inches.');
  if (!modes.includes(d.headingMode) || !finite(d.fixedHeading)) throw new Error('Invalid heading configuration.');
  if (!Array.isArray(d.nodes) || d.nodes.length < 2 || d.nodes.length > 100) throw new Error('A path needs between 2 and 100 waypoints.');
  const ids = new Set<string>();
  for (const n of d.nodes) {
    if (!n || typeof n.id !== 'string' || ids.has(n.id) || !vec(n.position) || !vec(n.incoming) || !vec(n.outgoing) || !finite(n.heading) || !['free', 'aligned', 'mirrored'].includes(n.handles)) throw new Error('Invalid or duplicate waypoint data.');
    ids.add(n.id);
  }
  // Whitelist properties: imported files cannot inject arbitrary application state.
  return { schemaVersion: 1, units: 'in', angleUnits: 'rad', coordinateFrame: 'center-x-right-y-up', field: 'biobuzz-2026-tu02', name: d.name, pathName: d.pathName, robot: { width: d.robot.width, length: d.robot.length }, headingMode: d.headingMode, fixedHeading: d.fixedHeading, nodes: d.nodes.map((n: Waypoint) => ({ id: n.id, position: { ...n.position }, incoming: { ...n.incoming }, outgoing: { ...n.outgoing }, heading: n.heading, handles: n.handles })) };
}
export const serializeProject = (doc: PathDocument) => JSON.stringify(doc, null, 2);
export function downloadProject(doc: PathDocument) {
  const url = URL.createObjectURL(new Blob([serializeProject(doc)], { type: 'application/json' }));
  const a = document.createElement('a'); a.href = url; a.download = `${doc.name.replace(/[^a-z0-9_-]/gi, '-').toLowerCase() || 'moonlanders'}.moonpath.json`; a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
