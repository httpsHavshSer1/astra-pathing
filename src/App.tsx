import { useEffect, useMemo, useRef, useState } from 'react';
import { ArrowDownToLine, ArrowLeftRight, ArrowUpRight, Check, ChevronDown, CircleHelp, Crosshair, FileJson, FolderOpen, Grid2X2, Layers, Magnet, MapPin, Moon, PanelLeftClose, PanelLeftOpen, PanelRightClose, PanelRightOpen, Plus, Redo2, Route, Save, Undo2, X, Info, Copy, CheckCheck, ChevronRight } from 'lucide-react';
import { initialDocument, insertNode, measurePath, moveNode, removeNode, reversePath } from './core/path';
import { degrees } from './core/geometry';
import type { Vec } from './core/geometry';
import { downloadProject, parseProject, serializeProject } from './io/project';
import { useDocument } from './editor/useDocument';
import { FieldCanvas } from './components/FieldCanvas';
import type { Tool } from './components/FieldCanvas';
import { Inspector } from './components/Inspector';
import { FIELD } from './field/biobuzz';

const STORAGE = 'moonlanders.path-studio.v1';
function loadInitial() { try { const stored = localStorage.getItem(STORAGE); if (stored) return parseProject(stored); } catch { /* A damaged recovery file cannot prevent opening the editor. */ } return initialDocument(); }
export default function App() {
  const editor = useDocument(loadInitial), { doc } = editor;
  const [selected, setSelected] = useState<string | null>(doc.nodes[0].id);
  const [tool, setTool] = useState<Tool>('select');
  const [grid, setGrid] = useState(true), [landmarks, setLandmarks] = useState(true), [snap, setSnap] = useState(false);
  const [pointer, setPointer] = useState<Vec | null>(null), [zoom, setZoom] = useState(100);
  const [preview, setPreview] = useState<number | null>(null);
  const [modal, setModal] = useState<'export' | 'help' | 'field' | null>(null);
  const [leftOpen, setLeftOpen] = useState(() => window.innerWidth > 850), [rightOpen, setRightOpen] = useState(() => window.innerWidth > 620);
  const [notice, setNotice] = useState(''), [saveState, setSaveState] = useState('Saved locally'), [copied, setCopied] = useState(false);
  const fileInput = useRef<HTMLInputElement>(null), dialog = useRef<HTMLDialogElement>(null);
  const metrics = useMemo(() => measurePath(doc), [doc]);
  const select = (id: string | null) => { setSelected(id); setPreview(null); };
  useEffect(() => { if (selected && !doc.nodes.some(n => n.id === selected)) setSelected(doc.nodes[0].id); }, [doc.nodes, selected]);
  useEffect(() => { setSaveState('Saving…'); const t = setTimeout(() => { try { localStorage.setItem(STORAGE, serializeProject(doc)); setSaveState('Saved locally'); } catch { setSaveState('Local save unavailable'); } }, 400); return () => clearTimeout(t); }, [doc]);
  useEffect(() => { if (!notice) return; const t = setTimeout(() => setNotice(''), 4500); return () => clearTimeout(t); }, [notice]);
  useEffect(() => { if (modal) dialog.current?.showModal(); else dialog.current?.close(); }, [modal]);
  const save = () => { downloadProject(editor.current()); setNotice('Project downloaded as native JSON.'); };
  const remove = () => {
    const i = doc.nodes.findIndex(n => n.id === selected);
    if (i > 0 && i < doc.nodes.length - 1) { editor.apply(removeNode(doc, selected!)); select(doc.nodes[i - 1].id); }
  };
  const addPoint = () => {
    if (doc.nodes.length >= 100) { setNotice('This editor supports up to 100 waypoints per path.'); return; }
    const i = Math.max(0, Math.min(doc.nodes.findIndex(n => n.id === selected), doc.nodes.length - 2));
    const next = insertNode(doc, i); editor.apply(next); select(next.nodes[i + 1].id);
  };
  useEffect(() => {
    const key = (e: KeyboardEvent) => {
      if ((e.target as HTMLElement).matches('input,textarea,select') || modal) return;
      if (e.ctrlKey || e.metaKey) {
        if (e.key.toLowerCase() === 'z') { e.preventDefault(); e.shiftKey ? editor.redo() : editor.undo(); }
        else if (e.key.toLowerCase() === 'y') { e.preventDefault(); editor.redo(); }
        else if (e.key.toLowerCase() === 's') { e.preventDefault(); save(); }
        else if (e.key.toLowerCase() === 'o') { e.preventDefault(); fileInput.current?.click(); }
        return;
      }
      if (e.key.toLowerCase() === 'v') setTool('select');
      if (e.key.toLowerCase() === 'h') setTool('pan');
      if (e.key.toLowerCase() === 'w') setTool('insert');
      if (e.key.toLowerCase() === 'g') setGrid(v => !v);
      if (e.key === '?') setModal('help');
      if (e.key === 'Escape') { setTool('select'); setPreview(null); }
      if (e.key === 'Delete' || e.key === 'Backspace') { e.preventDefault(); remove(); }
      const n = doc.nodes.find(n => n.id === selected);
      if (n && ['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown'].includes(e.key)) {
        e.preventDefault(); const step = e.shiftKey ? 1 : .25;
        editor.apply(moveNode(doc, n.id, { x: Math.max(-72, Math.min(72, n.position.x + (e.key === 'ArrowRight' ? step : e.key === 'ArrowLeft' ? -step : 0))), y: Math.max(-72, Math.min(72, n.position.y + (e.key === 'ArrowUp' ? step : e.key === 'ArrowDown' ? -step : 0))) }));
      }
    };
    window.addEventListener('keydown', key); return () => window.removeEventListener('keydown', key);
  });
  const importFile = async (file: File | undefined) => {
    if (!file) return;
    try { if (file.size > 1_000_000) throw new Error('Project files must be smaller than 1 MB.'); const d = parseProject(await file.text()); editor.apply(d); select(d.nodes[0].id); setNotice(`Opened ${d.name}. Undo restores your previous project.`); } catch (e) { setNotice(e instanceof Error ? e.message : 'Unable to open this file.'); }
    if (fileInput.current) fileInput.current.value = '';
  };
  const graph = metrics.samples.filter((_, i) => i % 4 === 0).map((s, i, arr) => `${i / Math.max(1, arr.length - 1) * 160},${25 - Math.min(22, Math.abs(s.curvature ?? 0) / Math.max(.005, metrics.maxCurvature) * 22)}`).join(' ');
  return <div className={`studio ${!leftOpen ? 'left-collapsed' : ''} ${!rightOpen ? 'right-collapsed' : ''}`}>
    <header className="app-header">
      <a className="brand" href="#" onClick={e => { e.preventDefault(); setModal('help'); }} aria-label="Moonlanders Path Studio help"><span className="brand-mark"><Moon size={22}/><i/></span><span>Moonlanders<small>PATH STUDIO</small></span><span className="team-number">23477</span></a>
      <div className="project-breadcrumb"><span className="header-divider"/><FolderOpen size={15}/><input aria-label="Project name" value={doc.name} maxLength={100} onFocus={editor.begin} onChange={e => editor.preview({ ...editor.current(), name: e.target.value })} onBlur={editor.commit} onKeyDown={e => { if (e.key === 'Enter') e.currentTarget.blur(); }}/><span className="local-indicator" title={saveState}/></div>
      <div className="header-actions"><button onClick={() => fileInput.current?.click()} title="Open project · Ctrl+O"><FolderOpen size={15}/><span>Open</span></button><button onClick={save} title="Save project · Ctrl+S"><Save size={15}/><span>Save</span></button><span className="header-divider"/><button className="export-button" onClick={() => { setCopied(false); setModal('export'); }}><ArrowUpRight size={16}/>Export</button></div>
    </header>
    <nav className="workspace-toolbar" aria-label="Editor toolbar">
      <div className="workspace-title"><span className="live-dot"/><span>Path editor</span><ChevronRight size={13}/><span className="path-breadcrumb">{doc.pathName}</span></div>
      <div className="toolbar-group history-buttons"><button aria-label="Undo (Ctrl+Z)" title="Undo · Ctrl+Z" disabled={!editor.canUndo} onClick={editor.undo}><Undo2 size={16}/></button><button aria-label="Redo (Ctrl+Shift+Z)" title="Redo · Ctrl+Shift+Z" disabled={!editor.canRedo} onClick={editor.redo}><Redo2 size={16}/></button></div>
      <span className="toolbar-divider"/>
      <div className="toolbar-group"><button className={tool === 'start' ? 'active' : ''} onClick={() => setTool(tool === 'start' ? 'select' : 'start')} title="Place start pose"><Crosshair size={15}/><span>Start</span></button><button className={tool === 'goal' ? 'active' : ''} onClick={() => setTool(tool === 'goal' ? 'select' : 'goal')} title="Place goal pose"><MapPin size={15}/><span>Goal</span></button><button className={tool === 'insert' ? 'active' : ''} onClick={() => setTool(tool === 'insert' ? 'select' : 'insert')} title="Insert waypoint · W"><Plus size={15}/><span>Waypoint</span></button></div>
      <div className="toolbar-spacer"/>
      <div className="toolbar-group display-buttons"><button className={snap ? 'active' : ''} aria-pressed={snap} onClick={() => setSnap(v => !v)} title="Snap to 1 in / 15° · Hold Alt to bypass"><Magnet size={15}/><span>Snap</span></button><button className={grid ? 'active' : ''} aria-label="Toggle coordinate grid" aria-pressed={grid} title="Coordinate grid · G" onClick={() => setGrid(v => !v)}><Grid2X2 size={15}/></button><button className={landmarks ? 'active' : ''} aria-label="Toggle field landmarks" aria-pressed={landmarks} title="Field landmarks" onClick={() => setLandmarks(v => !v)}><Layers size={15}/></button></div>
      <span className="toolbar-divider"/>
      <div className="toolbar-group"><button aria-label="Toggle path outline" title="Toggle path outline" onClick={() => setLeftOpen(v => !v)}>{leftOpen ? <PanelLeftClose size={15}/> : <PanelLeftOpen size={15}/>}</button><button aria-label="Toggle inspector" title="Toggle inspector" onClick={() => setRightOpen(v => !v)}>{rightOpen ? <PanelRightClose size={15}/> : <PanelRightOpen size={15}/>}</button></div>
    </nav>
    <main className="work-area">
      {leftOpen && <aside className="outline"><div className="panel-top"><span>Project</span><span className="revision-badge">01</span></div><div className="project-path"><Route size={17}/><input aria-label="Path name" value={doc.pathName} maxLength={100} onFocus={editor.begin} onChange={e => editor.preview({ ...editor.current(), pathName: e.target.value })} onBlur={editor.commit}/><ChevronDown size={14}/></div><div className="outline-section-title"><span>Waypoints</span><span>{String(doc.nodes.length).padStart(2, '0')}</span></div>
        <div className="waypoint-list">{doc.nodes.map((n, i) => <button className={`waypoint-row ${n.id === selected ? 'selected' : ''}`} key={n.id} onClick={() => select(n.id)} aria-label={`Select ${i === 0 ? 'start' : i === doc.nodes.length - 1 ? 'goal' : `waypoint ${i}`}`} aria-pressed={n.id === selected}><span className={`waypoint-symbol ${i === 0 ? 'start' : i === doc.nodes.length - 1 ? 'goal' : ''}`}>{i !== 0 && i !== doc.nodes.length - 1 && i}</span><span className="waypoint-description"><strong>{i === 0 ? 'Start pose' : i === doc.nodes.length - 1 ? 'Goal pose' : `Waypoint ${String(i).padStart(2, '0')}`}</strong><small>{n.position.x.toFixed(1)}, {n.position.y.toFixed(1)} <span>in</span></small></span><span className="waypoint-heading">{Math.round(degrees(n.heading))}°</span></button>)}</div>
        <button className="add-waypoint" onClick={addPoint} disabled={doc.nodes.length >= 100}><Plus size={14}/>Add waypoint</button>
        <div className="outline-section-title path-actions-title"><span>Path actions</span></div><button className="outline-action" onClick={() => { editor.apply(reversePath(doc)); setPreview(null); }}><ArrowLeftRight size={15}/>Reverse path<span>↔</span></button>
        <div className="outline-space"/>
        <div className="field-card"><div className="field-card-icon"><Grid2X2 size={20}/></div><div><strong>{FIELD.name}</strong><span>{FIELD.season} FTC field</span></div><button aria-label="Field information" title="Field source and dimensions" onClick={() => setModal('field')}><Info size={15}/></button></div>
        <div className="outline-footer"><span>Team 23477</span><span className="moon-phase"><i/><i/><i/></span></div>
      </aside>}
      <section className="canvas-column"><FieldCanvas editor={editor} metrics={metrics} selected={selected} select={select} tool={tool} setTool={setTool} grid={grid} landmarks={landmarks} snap={snap} preview={preview} onPointer={setPointer} onZoom={setZoom}/>
        <div className="path-measurements"><div className="measurement"><span>Path length</span><strong data-testid="path-length">{metrics.length.toFixed(2)}<small>in</small></strong></div><div className="measurement"><span>Peak curvature <Info size={11} aria-label="Numerical estimate at 200 samples per segment"/></span><strong>{metrics.singular ? '—' : metrics.maxCurvature.toFixed(3)}<small>in⁻¹</small></strong></div><div className="measurement curve-measure"><span>Curvature profile</span><svg viewBox="0 0 160 28" aria-label="Absolute path curvature profile"><path d="M0 26 H160" stroke="#3c4e52" fill="none"/><polyline points={graph} stroke="#78b6a7" fill="none" strokeWidth="1.3"/></svg></div><div className="measurement"><span>Segments</span><strong>{String(doc.nodes.length - 1).padStart(2, '0')}<small>cubic</small></strong></div></div>
        <div className="path-scrubber"><span><Crosshair size={13}/>Inspect path</span><input type="range" min="0" max="1000" value={Math.round((preview ?? 0) * 1000)} aria-label="Inspect position along path" onChange={e => setPreview(Number(e.target.value) / 1000)}/><span className="scrub-value">{Math.round((preview ?? 0) * 100)}%</span>{preview !== null ? <button className="icon-button" aria-label="Exit path inspection" onClick={() => setPreview(null)}><X size={13}/></button> : <span className="scrub-geometric">Geometry</span>}</div>
      </section>
      {rightOpen && <Inspector editor={editor} selected={selected} metrics={metrics} onDelete={remove} close={() => setRightOpen(false)}/>}
    </main>
    <footer className="status-bar"><span className="save-status"><Check size={12}/>{saveState}</span><span className="status-hint">{metrics.singular ? 'Degenerate tangent · adjust the Bézier handles' : 'Drag to edit · Double-click path to insert · Space to pan'}</span><div className="status-readouts"><span>{pointer ? `X ${pointer.x.toFixed(1)}   Y ${pointer.y.toFixed(1)}` : 'X —   Y —'}<small>in</small></span><span>{zoom}%</span><button aria-label="Keyboard shortcuts and help" title="Keyboard shortcuts · ?" onClick={() => setModal('help')}><CircleHelp size={14}/></button></div></footer>
    {notice && <div role="status" className="notice">{notice}<button aria-label="Dismiss notification" onClick={() => setNotice('')}><X size={14}/></button></div>}
    <input className="file-input" ref={fileInput} type="file" accept=".json,.moonpath" aria-label="Open native project file" onChange={e => void importFile(e.target.files?.[0])}/>
    <dialog ref={dialog} aria-label={modal === 'export' ? 'Export project' : modal === 'field' ? 'Field information' : 'Editor help'} className="studio-dialog" onCancel={() => setModal(null)} onClick={e => { if (e.target === e.currentTarget) setModal(null); }}><div className="dialog-inner"><button className="dialog-close icon-button" aria-label="Close dialog" onClick={() => setModal(null)}><X size={18}/></button>
      {modal === 'export' && <><div className="dialog-icon"><FileJson size={24}/></div><h2>Take your path with you.</h2><p>Native JSON preserves every waypoint, Bézier handle, heading, and robot dimension.</p><div className="export-format"><FileJson size={18}/><div><strong>Moonlanders project</strong><span>.moonpath.json · Inches / radians</span></div><Check size={16}/></div><pre className="export-preview">{serializeProject(doc)}</pre><p className="dialog-note">Geometric path data. Time-based trajectories and FTC Java adapters are planned for a later milestone.</p><div className="dialog-actions"><button onClick={() => { void navigator.clipboard.writeText(serializeProject(doc)).then(() => setCopied(true)).catch(() => setNotice('Clipboard unavailable. Download the JSON file instead.')); }}>{copied ? <CheckCheck size={15}/> : <Copy size={15}/>} {copied ? 'Copied' : 'Copy JSON'}</button><button className="primary-button" onClick={save}><ArrowDownToLine size={15}/>Download JSON</button></div></>}
      {modal === 'help' && <><div className="dialog-icon"><Moon size={26}/></div><h2>A clear path to first light.</h2><p>Shape the route on the field. Inspect any pose with the distance slider. Your project is recovered locally when you return.</p><div className="legend-help"><span><i className="legend-route"/>Path direction</span><span><i className="legend-heading"/>Robot heading</span><span><i className="legend-handle"/>Bézier control</span></div><div className="shortcut-list">{[['V / H', 'Select / pan'], ['W', 'Place a waypoint'], ['F / G', 'Fit field / toggle grid'], ['Space + drag', 'Pan the field'], ['Mouse wheel', 'Zoom around the cursor'], ['Arrow keys', 'Move selected pose by 0.25 in'], ['Shift + arrows', 'Move selected pose by 1 in'], ['Ctrl + Z / Shift + Z', 'Undo / redo'], ['Ctrl + S / O', 'Save / open project'], ['Delete', 'Remove intermediate waypoint']].map(([key, text]) => <div key={key}><span>{text}</span><kbd>{key}</kbd></div>)}</div><p className="dialog-note">Square handles shape the curve. The gold rotation grip turns the robot. While snapping is on, hold Alt for free movement.</p></>}
      {modal === 'field' && <><div className="dialog-icon"><Grid2X2 size={25}/></div><h2>BIOBUZZ · 2026–27</h2><p>A dimensioned, simplified overhead field based on FIRST’s Competition Manual TU02 and Event Field Setup Guide v1.0.</p><dl className="field-facts"><div><dt>Nominal perimeter</dt><dd>144 × 144 in</dd></div><div><dt>Tile layout</dt><dd>6 × 6 · nominal 24 in</dd></div><div><dt>Hive frame</dt><dd>49.46 × 38.95 in</dd></div><div><dt>Coordinate frame</dt><dd>Center origin · +X right · +Y up</dd></div><div><dt>Heading</dt><dd>Counterclockwise from +X</dd></div></dl><p className="dialog-note">Landmarks show nominal placement; hive cell silhouettes and flowers are simplified. Field drawings carry physical tolerances. This milestone does not certify obstacle clearance or drivetrain feasibility.</p><div className="dialog-actions"><a href={FIELD.source} target="_blank" rel="noreferrer">Competition manual <ArrowUpRight size={14}/></a><a href={FIELD.guide} target="_blank" rel="noreferrer">Field setup guide <ArrowUpRight size={14}/></a></div></>}
    </div></dialog>
  </div>;
}
