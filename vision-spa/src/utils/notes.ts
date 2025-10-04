import { NoteSummary } from '../types';

export const sortNotesByUpdatedAt = (notes: NoteSummary[]): NoteSummary[] =>
  [...notes].sort((a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime());

export const mergeNotes = (existing: NoteSummary[], incoming: NoteSummary): NoteSummary[] => {
  const filtered = existing.filter(note => note.id !== incoming.id);
  const next = [...filtered, incoming];
  return sortNotesByUpdatedAt(next.filter(note => note.projectId === incoming.projectId));
};

export const mergeNotePages = (existing: NoteSummary[], incoming: NoteSummary[]): NoteSummary[] => {
  if (incoming.length === 0) return existing;
  const map = new Map<string, NoteSummary>();
  for (const note of existing) {
    map.set(note.id, note);
  }
  for (const note of incoming) {
    map.set(note.id, note);
  }
  return sortNotesByUpdatedAt(Array.from(map.values()));
};
