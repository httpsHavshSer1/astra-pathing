import { FIELD } from '../field/biobuzz';
export function FieldLayer({ grid, landmarks }: { grid: boolean; landmarks: boolean }) {
  return <g className="field-layer" pointerEvents="none">
    <rect x="-72" y="-72" width="144" height="144" fill="#202c32" />
    {Array.from({ length: 36 }, (_, i) => <rect key={i} x={-72 + i % 6 * 24} y={-72 + Math.floor(i / 6) * 24} width="24" height="24" fill={(i + Math.floor(i / 6)) % 2 ? '#243036' : '#263238'} />)}
    {grid && <g stroke="#809199" strokeOpacity=".17" strokeWidth=".15">
      {Array.from({ length: 25 }, (_, i) => i * 6 - 72).map(n => <g key={n}><line x1={n} y1="-72" x2={n} y2="72"/><line x1="-72" y1={n} x2="72" y2={n}/></g>)}
    </g>}
    <g stroke="#82949c" strokeOpacity=".3" strokeWidth=".25">{[-48, -24, 0, 24, 48].map(n => <g key={n}><line x1={n} y1="-72" x2={n} y2="72"/><line x1="-72" y1={n} x2="72" y2={n}/></g>)}</g>
    <rect x="-72" y="-72" width="144" height="144" fill="none" stroke="#94a6ae" strokeWidth=".7"/>
    <rect x="-74" y="-74" width="148" height="148" rx=".6" fill="none" stroke="#53636c" strokeWidth=".7"/>
    <line x1="-74" y1="-48" x2="-74" y2="48" stroke="#b87574" strokeWidth="1.3"/>
    <line x1="74" y1="-48" x2="74" y2="48" stroke="#789fc7" strokeWidth="1.3"/>
    {landmarks && <>
      <path d="M-71.5 48 H-61 V25 H-71.5" fill="#b65c6520" stroke="#b87574" strokeWidth=".7"/>
      <path d="M71.5 -48 H61 V-25 H71.5" fill="#688fbd20" stroke="#789fc7" strokeWidth=".7"/>
      <path d="M-72 -70 H-49" stroke="#b87574" strokeWidth="2"/><path d="M72 70 H49" stroke="#789fc7" strokeWidth="2"/>
      <g className="hive">
        <rect x={-FIELD.frame.width / 2} y={-FIELD.frame.depth / 2} width={FIELD.frame.width} height={FIELD.frame.depth} fill="#101c21" fillOpacity=".6" stroke="#78878d" strokeWidth=".4" strokeDasharray="1.3 1"/>
        {[-23.3, 23.3].map(x => <g key={x}><rect x={x - .8} y="-19.475" width="1.6" height="38.95" fill="#56656b"/><path d={`M${x} -19 L${x} 19`} stroke="#9aa5a5" strokeWidth=".3"/></g>)}
        <path d="M-24.73 0 H24.73" stroke="#88969a" strokeWidth="1"/>
        {[-12, 12].map(x => [-11, 11].map(y => <g key={`${x},${y}`} stroke={x < 0 ? '#a66f74' : '#718fac'} strokeWidth=".5" fill={x < 0 ? '#453239' : '#2f414f'}><path d={`M${x-9} ${y-6} L${x-9} ${y+5} L${x} ${y+7} L${x+9} ${y+5} L${x+9} ${y-6} Z`}/><path d={`M${x-8} ${y-4} L${x+8} ${y-4} M${x} ${y-4} V${y+6}`} fill="none" opacity=".5"/></g>))}
        <rect x="-12" y="-3" width="24" height="6" fill="#1b282e"/>
        <text transform="scale(1,-1)" x="0" y="1" textAnchor="middle" fill="#899c9f" fontSize="2.3" letterSpacing=".6">HIVE FRAME</text>
      </g>
      {FIELD.flowers.map((p, i) => <g key={i} transform={`translate(${p.x} ${p.y})`}><circle r="2.65" fill="#18252a" stroke="#a79f78" strokeWidth=".5"/><circle r="1.45" fill="#a39868" fillOpacity=".6"/><circle r=".45" fill="#d9c88b"/></g>)}
      <g fontSize="1.9" fill="#81949a" letterSpacing=".12" textAnchor="middle">
        <text transform="translate(-56 34) rotate(90) scale(1,-1)">LOADING</text>
        <text transform="translate(56 -36) rotate(90) scale(1,-1)">LOADING</text>
        <text transform="translate(-60 -65) scale(1,-1)">GARDEN</text>
        <text transform="translate(60 65) scale(1,-1)">GARDEN</text>
      </g>
    </>}
    <g stroke="#99b2b4" strokeWidth=".2" opacity=".5"><path d="M-2 0 H2 M0 -2 V2"/></g>
  </g>;
}
