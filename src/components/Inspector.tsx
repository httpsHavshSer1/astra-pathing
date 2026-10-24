import { useEffect, useRef, useState } from 'react';
import { ChevronDown, ChevronRight, MoveUpRight, SlidersHorizontal, RotateCw, Bot, ArrowUp, ArrowDown, Trash2, X } from 'lucide-react';
import { degrees, radians } from '../core/geometry';
import { headingAt, moveHandle, moveNode, reorderNode, updateNode } from '../core/path';
import type { HandleMode, HeadingMode, PathMetrics } from '../core/path';
import type { EditorDocument } from '../editor/useDocument';

type NumberProps = { label: string; value: number; unit?: string; min?: number; max?: number; step?: number; begin: () => void; commit: () => void; change: (n: number) => void };
export function NumberField({ label, value, unit = 'in', min = -10000, max = 10000, step = .25, begin, commit, change }: NumberProps) {
  const [text, setText] = useState(String(Number(value.toFixed(2))));
  const focused = useRef(false);
  useEffect(() => { if (!focused.current) setText(String(Number(value.toFixed(2)))); }, [value]);
  const invalid = text.trim() === '' || !Number.isFinite(Number(text)) || Number(text) < min || Number(text) > max;
  return <label className={`number-field ${invalid ? 'invalid' : ''}`}><span>{label}</span><div><input type="number" aria-label={label} aria-invalid={invalid} value={text} min={min} max={max} step={step} onFocus={() => { focused.current = true; begin(); }} onChange={e => { setText(e.target.value); const n = e.target.valueAsNumber; if (Number.isFinite(n) && n >= min && n <= max) change(n); }} onBlur={() => { focused.current = false; setText(String(Number(value.toFixed(2)))); commit(); }} onKeyDown={e => { if (e.key === 'Enter') e.currentTarget.blur(); }}/><small>{unit}</small></div></label>;
}
export function Inspector({ editor, selected, metrics, onDelete, close }: { editor: EditorDocument; selected: string | null; metrics: PathMetrics; onDelete: () => void; close: () => void }) {
  const { doc } = editor, index = doc.nodes.findIndex(n => n.id === selected), node = doc.nodes[index];
  const [controlsOpen, setControlsOpen] = useState(true);
  const name = index === 0 ? 'Start pose' : index === doc.nodes.length - 1 ? 'Goal pose' : `Waypoint ${String(index).padStart(2, '0')}`;
  const props = { begin: editor.begin, commit: editor.commit };
  const fraction = metrics.length ? metrics.segmentLengths.slice(0, index).reduce((a, b) => a + b, 0) / metrics.length : 0;
  const actualHeading = node ? headingAt(doc, Math.min(index, doc.nodes.length - 2), index === doc.nodes.length - 1 ? 1 : 0, fraction) : 0;
  return <aside className="inspector">
    <div className="panel-top"><span><SlidersHorizontal size={14}/> Inspector</span><button className="icon-button panel-close" aria-label="Close inspector" onClick={close}><X size={15}/></button></div>
    <div className="inspector-scroll">
      {node ? <>
        <section className="selection-heading"><div className="selection-symbol"><MoveUpRight size={19}/></div><div><h2>{name}</h2><span>Pose · {index + 1} of {doc.nodes.length}</span></div><span className="selection-dot"/></section>
        <section className="inspector-section">
          <div className="section-heading"><h3>Position</h3><span>Field coordinates</span></div>
          <div className="fields-two"><NumberField {...props} label="X position" value={node.position.x} min={-72} max={72} change={x => editor.preview(moveNode(editor.current(), node.id, { ...editor.current().nodes.find(n => n.id === node.id)!.position, x }))}/><NumberField {...props} label="Y position" value={node.position.y} min={-72} max={72} change={y => editor.preview(moveNode(editor.current(), node.id, { ...editor.current().nodes.find(n => n.id === node.id)!.position, y }))}/></div>
          <NumberField {...props} label="Robot heading" unit="deg" step={1} value={degrees(actualHeading)} min={-360} max={360} change={v => {
            const d = editor.current(), next = updateNode(d, node.id, { heading: radians(v) });
            editor.preview({ ...next, headingMode: d.headingMode === 'tangent' || d.headingMode === 'linear' ? 'waypoints' : d.headingMode, fixedHeading: d.headingMode === 'fixed' ? radians(v) : d.fixedHeading });
          }}/>
          <p className="field-note"><span className="heading-swatch"/> Heading rotates the robot independently.</p>
        </section>
        <section className="inspector-section">
          <button className="section-toggle" onClick={() => setControlsOpen(v => !v)} aria-expanded={controlsOpen}>{controlsOpen ? <ChevronDown size={13}/> : <ChevronRight size={13}/>}<h3>Bézier controls</h3><span>{node.handles}</span></button>
          {controlsOpen && <>
            <div className="segment-control" aria-label="Control handle behavior">{(['free', 'aligned', 'mirrored'] as HandleMode[]).map(m => <button key={m} className={node.handles === m ? 'selected' : ''} aria-pressed={node.handles === m} onClick={() => { const d = updateNode(doc, node.id, { handles: m }); editor.apply(moveHandle(d, node.id, 'outgoing', node.outgoing)); }}>{m[0].toUpperCase() + m.slice(1)}</button>)}</div>
            {(['incoming', 'outgoing'] as const).map(side => (side === 'incoming' && index === 0 || side === 'outgoing' && index === doc.nodes.length - 1) ? null : <div className="control-fields" key={side}><div className="small-label"><span className="control-square"/>{side === 'outgoing' ? 'Outgoing · C1' : 'Incoming · C2'}</div><div className="fields-two">{(['x', 'y'] as const).map(axis => <NumberField key={axis} {...props} label={`${side === 'outgoing' ? 'C1' : 'C2'} ${axis.toUpperCase()}`} value={node[side][axis]} min={-72} max={72} change={v => editor.preview(moveHandle(editor.current(), node.id, side, { ...editor.current().nodes.find(n => n.id === node.id)![side], [axis]: v }))}/>)}</div></div>)}
          </>}
        </section>
      </> : <section className="selection-heading"><div className="selection-symbol"><SlidersHorizontal size={18}/></div><div><h2>Path settings</h2><span>Select a point to inspect its pose</span></div></section>}
      <section className="inspector-section"><div className="section-heading"><h3><RotateCw size={13}/> Heading behavior</h3></div><label className="select-label">Along this path<select aria-label="Heading behavior" value={doc.headingMode} onChange={e => editor.apply({ ...doc, headingMode: e.target.value as HeadingMode })}><option value="waypoints">Independent waypoints</option><option value="linear">Interpolate start → goal</option><option value="fixed">Fixed heading</option><option value="tangent">Follow path tangent</option></select></label><p className="muted-note">{doc.headingMode === 'waypoints' ? 'Blend between each waypoint’s heading.' : doc.headingMode === 'linear' ? 'Blend start to goal heading by distance.' : doc.headingMode === 'fixed' ? 'Keep one orientation along the entire path.' : 'Face the direction of travel along the curve.'}</p>{doc.headingMode === 'fixed' && <NumberField {...props} label="Fixed heading" unit="deg" step={1} value={degrees(doc.fixedHeading)} min={-360} max={360} change={v => editor.preview({ ...editor.current(), fixedHeading: radians(v) })}/>}</section>
      <section className="inspector-section"><div className="section-heading"><h3><Bot size={14}/> Robot footprint</h3><span>Mecanum</span></div><div className="fields-two"><NumberField {...props} label="Width" value={doc.robot.width} min={1} max={72} change={width => editor.preview({ ...editor.current(), robot: { ...editor.current().robot, width } })}/><NumberField {...props} label="Length" value={doc.robot.length} min={1} max={72} change={length => editor.preview({ ...editor.current(), robot: { ...editor.current().robot, length } })}/></div><p className="muted-note">Length follows the robot’s forward axis.</p></section>
      {node && index > 0 && index < doc.nodes.length - 1 && <section className="inspector-section point-actions"><button disabled={index === 1} onClick={() => editor.apply(reorderNode(doc, index, -1))}><ArrowUp size={13}/>Earlier</button><button disabled={index === doc.nodes.length - 2} onClick={() => editor.apply(reorderNode(doc, index, 1))}><ArrowDown size={13}/>Later</button><button className="danger" onClick={onDelete}><Trash2 size={13}/>Delete</button></section>}
    </div>
    <div className="inspector-foot"><span className="tiny-orbit"/> Designed for the field.</div>
  </aside>;
}
