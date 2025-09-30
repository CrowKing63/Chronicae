import { NoteSummary } from '../types';

export const mergeNotes = (existing: NoteSummary[], incoming: NoteSummary): NoteSummary[] => {
  const filtered = existing.filter(note => note.id !== incoming.id);
  const next = [...filtered, incoming];
  return next
    .filter(note => note.projectId === incoming.projectId)
    .sort((a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime());
};
