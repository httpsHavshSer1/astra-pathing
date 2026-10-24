/** Transactional, immutable document history. One pointer gesture = one undo entry. */
export class DocumentHistory<T> {
  current: T;
  private past: T[] = [];
  private future: T[] = [];
  private start: T | null = null;
  constructor(initial: T) { this.current = initial; }
  get canUndo() { return this.past.length > 0; }
  get canRedo() { return this.future.length > 0; }
  begin() { if (this.start === null) this.start = this.current; }
  preview(next: T) { this.current = next; }
  commit() {
    if (this.start !== null && JSON.stringify(this.start) !== JSON.stringify(this.current)) {
      this.past = [...this.past.slice(-99), this.start]; this.future = [];
    }
    this.start = null;
  }
  apply(next: T) { this.begin(); this.preview(next); this.commit(); }
  cancel() { if (this.start !== null) this.current = this.start; this.start = null; }
  undo() { this.commit(); const prev = this.past.pop(); if (prev !== undefined) { this.future.push(this.current); this.current = prev; } }
  redo() { const next = this.future.pop(); if (next !== undefined) { this.past.push(this.current); this.current = next; } }
}
