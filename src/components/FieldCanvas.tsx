import { useEffect, useRef, useState } from 'react';
import type { PointerEvent as ReactPointerEvent } from 'react';
import { Hand, LocateFixed, Minus, MousePointer2, Plus, Scan, Crosshair } from 'lucide-react';
import { add, clamp, degrees, fieldToScreen, footprint, radians, screenToField, sub, zoomAt } from '../core/geometry';
import type { Vec, Viewport } from '../core/geometry';
import { headingAt, insertNode, moveHandle, moveNode, nearestOnPath, poseAt, segments, updateNode } from '../core/path';
import type { PathDocument, PathMetrics } from '../core/path';
import type { EditorDocument } from '../editor/useDocument';
import { FieldLayer } from './FieldLayer';

export type Tool = 'select' | 'pan' | 'start' | 'goal' | 'insert';
type Props = { editor: EditorDocument; metrics: PathMetrics; selected: string | null; select: (id: string | null) => void; tool: Tool; setTool: (t: Tool) => void; grid: boolean; landmarks: boolean; snap: boolean; preview: number | null; onPointer: (p: Vec | null) => void; onZoom: (z: number) => void };
type Drag = { kind: 'node' | 'incoming' | 'outgoing' | 'heading' | 'pan'; id: string; screen: Vec; point: Vec; original: PathDocument; viewport: Viewport };

export function FieldCanvas({ editor, metrics, selected, select, tool, setTool, grid, landmarks, snap, preview, onPointer, onZoom }: Props) {
  const { doc } = editor;
  const host = useRef<HTMLDivElement>(null), svg = useRef<SVGSVGElement>(null), drag = useRef<Drag | null>(null);
  const space = useRef(false), size = useRef({ width: 800, height: 650 });
  const [view, setView] = useState<Viewport>({ x: 400, y: 325, scale: 3.5 });
  const viewRef = useRef(view); viewRef.current = view;
  const [panning, setPanning] = useState(false);
  const fit = () => {
    const { width, height } = size.current;
    setView({ x: width / 2, y: height / 2 + 3, scale: Math.max(.5, Math.min((width - 120) / 144, (height - 108) / 144)) });
  };
  useEffect(() => {
    const observer = new ResizeObserver(([entry]) => { size.current = { width: entry.contentRect.width, height: entry.contentRect.height }; fit(); });
    observer.observe(host.current!); return () => observer.disconnect();
  }, []);
  useEffect(() => { onZoom(Math.round(view.scale / (Math.min((size.current.width - 120) / 144, (size.current.height - 108) / 144)) * 100)); }, [view, onZoom]);
  useEffect(() => {
    const key = (e: KeyboardEvent) => {
      if ((e.target as HTMLElement).matches('input,textarea,select')) return;
      if (e.code === 'Space') { space.current = e.type === 'keydown'; setPanning(space.current); e.preventDefault(); }
      if (e.type === 'keydown' && e.key.toLowerCase() === 'f') fit();
      if (e.type === 'keydown' && e.key === 'Escape' && drag.current) { editor.cancel(); if (drag.current.kind === 'pan') setView(drag.current.viewport); drag.current = null; }
    };
    const blur = () => { space.current = false; setPanning(false); if (drag.current) { editor.cancel(); drag.current = null; } };
    window.addEventListener('keydown', key); window.addEventListener('keyup', key); window.addEventListener('blur', blur);
    return () => { window.removeEventListener('keydown', key); window.removeEventListener('keyup', key); window.removeEventListener('blur', blur); };
  });
  useEffect(() => {
    const el = svg.current!;
    const wheel = (e: WheelEvent) => { e.preventDefault(); const r = el.getBoundingClientRect(); setView(v => zoomAt(v, { x: e.clientX - r.left, y: e.clientY - r.top }, Math.exp(-e.deltaY * .0015))); };
    el.addEventListener('wheel', wheel, { passive: false }); return () => el.removeEventListener('wheel', wheel);
  }, []);
  const local = (e: ReactPointerEvent) => { const r = svg.current!.getBoundingClientRect(); return { x: e.clientX - r.left, y: e.clientY - r.top }; };
  const constrain = (p: Vec, snapping = snap): Vec => ({ x: clamp(snapping ? Math.round(p.x) : p.x, -72, 72), y: clamp(snapping ? Math.round(p.y) : p.y, -72, 72) });
  const start = (e: ReactPointerEvent, kind: Drag['kind'], id: string) => {
    if (e.button !== 0 && e.button !== 1) return;
    e.stopPropagation(); e.preventDefault();
    if (e.button === 1 || space.current || tool === 'pan') kind = 'pan';
    else { select(id); editor.begin(); }
    svg.current!.setPointerCapture(e.pointerId);
    const screen = local(e);
    drag.current = { kind, id, screen, point: screenToField(screen, view), original: doc, viewport: view };
  };
  const background = (e: ReactPointerEvent) => {
    if (e.button === 1 || space.current || tool === 'pan') return start(e, 'pan', '');
    if (e.button !== 0) return;
    const point = constrain(screenToField(local(e), view));
    if (tool === 'start' || tool === 'goal') {
      const node = tool === 'start' ? doc.nodes[0] : doc.nodes.at(-1)!;
      editor.apply(moveNode(doc, node.id, point)); select(node.id); setTool('select');
    } else if (tool === 'insert') {
      const nearest = nearestOnPath(doc, point), next = insertNode(doc, nearest.segment, nearest.t);
      if (next.nodes.length > 100) return;
      const node = next.nodes[nearest.segment + 1];
      editor.apply(nearest.distance * view.scale < 18 ? next : moveNode(next, node.id, point)); select(node.id); setTool('select');
    } else select(null);
  };
  const pointerMove = (e: ReactPointerEvent) => {
    const screen = local(e), point = screenToField(screen, viewRef.current); onPointer(point);
    const d = drag.current; if (!d) return;
    if (d.kind === 'pan') { setView({ ...d.viewport, x: d.viewport.x + screen.x - d.screen.x, y: d.viewport.y + screen.y - d.screen.y }); return; }
    const n = d.original.nodes.find(n => n.id === d.id)!;
    const delta = sub(point, d.point);
    if (d.kind === 'node') editor.preview(moveNode(d.original, d.id, constrain(add(n.position, delta), snap && !e.altKey)));
    else if (d.kind === 'heading') {
      let heading = Math.atan2(point.y - n.position.y, point.x - n.position.x);
      if (e.shiftKey || snap && !e.altKey) heading = Math.round(heading / radians(15)) * radians(15);
      const next = updateNode(d.original, d.id, { heading });
      editor.preview({ ...next, headingMode: d.original.headingMode === 'tangent' || d.original.headingMode === 'linear' ? 'waypoints' : d.original.headingMode, fixedHeading: d.original.headingMode === 'fixed' ? heading : next.fixedHeading });
    } else editor.preview(moveHandle(d.original, d.id, d.kind, constrain(add(n[d.kind], delta), snap && !e.altKey)));
  };
  const end = (e: ReactPointerEvent) => { if (drag.current) { editor.commit(); drag.current = null; } if (svg.current?.hasPointerCapture(e.pointerId)) svg.current.releasePointerCapture(e.pointerId); };
  const cs = segments(doc), pos = (p: Vec) => fieldToScreen(p, view);
  const pathD = cs.map((c, i) => { const a = pos(c.p0), b = pos(c.p1), d = pos(c.p2), e = pos(c.p3); return `${i === 0 ? `M${a.x},${a.y}` : ''} C${b.x},${b.y} ${d.x},${d.y} ${e.x},${e.y}`; }).join(' ');
  const selectedIndex = doc.nodes.findIndex(n => n.id === selected);
  const fractionForNode = (i: number) => metrics.length ? metrics.segmentLengths.slice(0, i).reduce((a, b) => a + b, 0) / metrics.length : 0;
  const headingForNode = (i: number) => headingAt(doc, Math.min(i, cs.length - 1), i === doc.nodes.length - 1 ? 1 : 0, fractionForNode(i));
  const robot = preview !== null ? poseAt(doc, metrics, preview) : selectedIndex >= 0 ? { ...doc.nodes[selectedIndex].position, heading: headingForNode(selectedIndex) } : null;
  const outside = robot && footprint(robot, robot.heading, doc.robot.width, doc.robot.length).some(p => Math.abs(p.x) > 72 || Math.abs(p.y) > 72);
  const robotGlyph = (p: Vec, heading: number, active: boolean, key: string) => {
    const s = pos(p), w = doc.robot.width * view.scale, l = doc.robot.length * view.scale;
    return <g key={key} transform={`translate(${s.x} ${s.y}) rotate(${-degrees(heading)})`} className={`robot-glyph ${active ? 'active' : 'ghost'}`} pointerEvents="none">
      <rect x={-l / 2} y={-w / 2} width={l} height={w} rx={2} fill={active ? '#dbbc7810' : '#d0ddd205'} stroke={active ? outside ? '#e88e87' : '#ddc17f' : '#7d9694'} strokeWidth={active ? 1.4 : .8} strokeDasharray={active ? undefined : '3 4'}/>
      {[-1, 1].map(a => [-1, 1].map(b => <rect key={`${a},${b}`} x={a * l * .29 - l * .13} y={b * w * .49 - w * .035} width={l * .26} height={w * .07} rx="1" fill={active ? '#c3c7b5' : '#6c827e'}/>))}
      <path d={`M${l * .12} ${-w * .16} L${l * .29} 0 L${l * .12} ${w * .16}`} fill="none" stroke={active ? '#ddc17f' : '#849a96'} strokeWidth="1.5"/>
      <line x1={l / 2} y1="0" x2={l / 2 + 20} y2="0" stroke={active ? '#ddc17f' : '#718786'} strokeWidth="1.4"/>
    </g>;
  };
  return <div className={`canvas-host tool-${tool} ${panning ? 'is-panning' : ''}`} ref={host}>
    <div className="canvas-heading"><span className="field-tag">Field view</span><span>BIOBUZZ <b>2026–27</b></span></div>
    <div className="canvas-scale">144 × 144 in <span>·</span> Top view</div>
    <svg ref={svg} className="field-canvas" data-testid="field-canvas" aria-label="Interactive FTC field. Drag waypoints and control handles. Use the inspector for keyboard editing." onPointerDown={background} onPointerMove={pointerMove} onPointerUp={end} onPointerCancel={() => { editor.cancel(); drag.current = null; }} onPointerLeave={() => { if (!drag.current) onPointer(null); }} onContextMenu={e => e.preventDefault()}>
      <g transform={`translate(${view.x} ${view.y}) scale(${view.scale} ${-view.scale})`}><FieldLayer grid={grid} landmarks={landmarks}/></g>
      {[-72, -48, -24, 0, 24, 48, 72].map(n => { const top = pos({ x: n, y: 72 }), left = pos({ x: -72, y: n }); return <g key={n} className="ruler" pointerEvents="none"><text x={top.x} y={top.y - 15} textAnchor="middle">{n}</text><text x={left.x - 13} y={left.y + 3} textAnchor="end">{n}</text></g>; })}
      <text className="alliance-label red" x={pos({ x: -79, y: 0 }).x} y={view.y} textAnchor="middle" transform={`rotate(-90 ${pos({ x: -79, y: 0 }).x} ${view.y})`}>RED ALLIANCE</text>
      <text className="alliance-label blue" x={pos({ x: 79, y: 0 }).x} y={view.y} textAnchor="middle" transform={`rotate(90 ${pos({ x: 79, y: 0 }).x} ${view.y})`}>BLUE ALLIANCE</text>
      <text className="ruler" x={view.x} y={pos({ x: 0, y: -72 }).y + 23} textAnchor="middle">AUDIENCE SIDE · +X RIGHT / +Y UP</text>
      <path d={pathD} fill="none" stroke="#0e2124" strokeWidth="7" pointerEvents="none"/>
      <path d={pathD} className="route-line" fill="none" stroke="#80d4bd" strokeWidth="2.6" pointerEvents="none"/>
      <path d={pathD} data-testid="path-hit-area" fill="none" stroke="transparent" strokeWidth="18" onPointerDown={e => { if (tool !== 'select' || e.button === 1 || space.current) background(e); else { e.stopPropagation(); select(doc.nodes[0].id); } }} onDoubleClick={e => { e.stopPropagation(); const r = svg.current!.getBoundingClientRect(); const n = nearestOnPath(doc, screenToField({ x: e.clientX - r.left, y: e.clientY - r.top }, view)); if (doc.nodes.length < 100) { const next = insertNode(doc, n.segment, n.t); editor.apply(next); select(next.nodes[n.segment + 1].id); } }} />
      {[.2, .43, .67, .87].map(f => { const p = poseAt(doc, metrics, f), s = pos(p); return <path key={f} d="M-4 -3.5 L1 0 L-4 3.5" fill="none" stroke="#a6ead8" strokeWidth="1.5" transform={`translate(${s.x} ${s.y}) rotate(${-degrees(p.tangent)})`} pointerEvents="none"/>; })}
      {doc.nodes.filter((_, i) => i === 0 || i === doc.nodes.length - 1).map(n => robotGlyph(n.position, headingForNode(doc.nodes.indexOf(n)), false, n.id))}
      {robot && robotGlyph(robot, robot.heading, true, 'selected-robot')}
      {doc.nodes.map((n, i) => {
        const active = n.id === selected, p = pos(n.position), heading = headingForNode(i);
        const linked = active || selectedIndex === i + 1 || selectedIndex === i - 1;
        return <g key={n.id}>
          {linked && (['incoming', 'outgoing'] as const).map(side => {
            if (side === 'incoming' && i === 0 || side === 'outgoing' && i === doc.nodes.length - 1) return null;
            const hp = pos(n[side]);
            return <g key={side} className="handle-group">
              <line x1={p.x} y1={p.y} x2={hp.x} y2={hp.y} stroke={active ? '#a5bdb8' : '#718881'} strokeWidth="1" strokeDasharray="4 4" pointerEvents="none"/>
              <circle cx={hp.x} cy={hp.y} r="15" fill="transparent" className="drag-target" data-testid={`handle-${i}-${side}`} aria-label={`Waypoint ${i + 1} ${side} control`} onPointerDown={e => start(e, side, n.id)}/>
              <rect x={hp.x - 3.5} y={hp.y - 3.5} width="7" height="7" fill="#202e32" stroke="#b1cec2" strokeWidth="1.3" pointerEvents="none"/>
              <text x={hp.x + 11} y={hp.y + 4} className="control-label" pointerEvents="none">{side === 'outgoing' ? 'C1' : 'C2'}</text>
            </g>;
          })}
          {active && preview === null && <g transform={`translate(${p.x} ${p.y}) rotate(${-degrees(heading)})`}>
            <path d={`M${doc.robot.length * view.scale / 2 + 15} -9 A12 12 0 0 1 ${doc.robot.length * view.scale / 2 + 15} 9`} fill="none" stroke="#d7bb79" strokeWidth="1" opacity=".5" pointerEvents="none"/>
            <circle data-testid="heading-handle" cx={doc.robot.length * view.scale / 2 + 20} cy="0" r="13" fill="transparent" className="rotate-target" onPointerDown={e => start(e, 'heading', n.id)}/>
            <circle cx={doc.robot.length * view.scale / 2 + 20} cy="0" r="4" fill="#dcc17e" stroke="#152026" strokeWidth="1" pointerEvents="none"/>
          </g>}
          <circle cx={p.x} cy={p.y} r={active ? 11 : 8} fill="#80d4bd" fillOpacity={active ? '.13' : '0'} stroke={active ? '#80d4bd80' : 'none'} pointerEvents="none"/>
          <circle cx={p.x} cy={p.y} r="5" fill={active ? '#b5f0dc' : '#213b39'} stroke="#9fdec7" strokeWidth="1.7" pointerEvents="none"/>
          <circle cx={p.x} cy={p.y} r="15" fill="transparent" className="drag-target" data-testid={`waypoint-${i}`} onPointerDown={e => start(e, 'node', n.id)}/>
          <g transform={`translate(${p.x + 15} ${p.y - 23})`} pointerEvents="none"><rect x="-5" y="-11" width={i === 0 || i === doc.nodes.length - 1 ? 53 : 28} height="19" rx="3" fill="#162326" stroke="#334e4b" strokeWidth=".7"/><text className="node-label" y="2">{i === 0 ? 'START' : i === doc.nodes.length - 1 ? 'GOAL' : String(i).padStart(2, '0')}</text></g>
        </g>;
      })}
    </svg>
    <div className="canvas-tools" aria-label="Canvas tools">
      <button className={tool === 'select' ? 'chosen' : ''} aria-label="Select tool (V)" title="Select · V" onClick={() => setTool('select')}><MousePointer2 size={17}/></button>
      <button className={tool === 'pan' ? 'chosen' : ''} aria-label="Pan tool (H)" title="Pan · H / Space + drag" onClick={() => setTool('pan')}><Hand size={17}/></button>
      <span/>
      <button aria-label="Zoom in" title="Zoom in" onClick={() => setView(v => zoomAt(v, { x: size.current.width / 2, y: size.current.height / 2 }, 1.2))}><Plus size={17}/></button>
      <button aria-label="Zoom out" title="Zoom out" onClick={() => setView(v => zoomAt(v, { x: size.current.width / 2, y: size.current.height / 2 }, 1 / 1.2))}><Minus size={17}/></button>
      <button aria-label="Fit field (F)" title="Fit field · F" onClick={fit}><Scan size={17}/></button>
    </div>
    <div className="axis-widget"><svg viewBox="0 0 52 52"><path d="M12 39 H43 M12 39 V8" stroke="currentColor" fill="none"/><path d="M39 36 L43 39 L39 42 M9 12 L12 8 L15 12" stroke="currentColor" fill="none"/><text x="43" y="31">x</text><text x="20" y="12">y</text></svg><span>in / deg</span></div>
    {tool !== 'select' && tool !== 'pan' && <div className="tool-prompt"><Crosshair size={15}/>{tool === 'insert' ? 'Click the path to insert a waypoint' : `Click the field to place the ${tool}`}<button onClick={() => setTool('select')}>Cancel</button></div>}
    {outside && <div className="boundary-warning"><LocateFixed size={14}/>Robot footprint extends beyond the field</div>}
  </div>;
}
