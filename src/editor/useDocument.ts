import { useRef, useState } from 'react';
import { DocumentHistory } from '../core/history';
import type { PathDocument } from '../core/path';
export function useDocument(initial: () => PathDocument) {
  const ref = useRef<DocumentHistory<PathDocument> | null>(null);
  if (!ref.current) ref.current = new DocumentHistory(initial());
  const [, tick] = useState(0);
  const history = ref.current;
  const notify = () => tick(v => v + 1);
  return {
    doc: history.current, canUndo: history.canUndo, canRedo: history.canRedo,
    current: () => history.current,
    begin: () => history.begin(),
    preview: (d: PathDocument) => { history.preview(d); notify(); },
    commit: () => { history.commit(); notify(); },
    cancel: () => { history.cancel(); notify(); },
    apply: (d: PathDocument) => { history.apply(d); notify(); },
    undo: () => { history.undo(); notify(); }, redo: () => { history.redo(); notify(); },
  };
}
export type EditorDocument = ReturnType<typeof useDocument>;
