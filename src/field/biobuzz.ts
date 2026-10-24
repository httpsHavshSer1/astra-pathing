/** Nominal overhead geometry. Visual landmarks are not collision volumes. */
export const FIELD = {
  id: 'biobuzz-2026-tu02', name: 'BIOBUZZ', season: '2026–27', revision: 'TU02', size: 144, tile: 24,
  source: 'https://ftc-resources.firstinspires.org/ftc/game/cm-html/BIOBUZZ%20Competition%20Manual%20-%20TU02.htm',
  guide: 'https://ftc-resources.firstinspires.org/ftc/archive/2027/field/eventfieldguide',
  frame: { width: 49.46, depth: 38.95 },
  flowers: [{ x: -24, y: 69 }, { x: 69, y: 24 }, { x: 24, y: -69 }, { x: -69, y: -24 }],
} as const;
