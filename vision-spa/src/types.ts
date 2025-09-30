export enum AppEventType {
  ProjectReset = 'project.reset',
  ProjectDeleted = 'project.deleted',
  NoteCreated = 'note.created',
  NoteUpdated = 'note.updated',
  NoteDeleted = 'note.deleted',
  NoteExportQueued = 'note.export.queued',
  NoteVersionRestored = 'note.version.restored',
  NoteVersionExportQueued = 'note.version.export.queued',
  BackupCompleted = 'backup.completed',
  Ping = 'ping'
}

export type NoteSummary = {
  id: string;
  projectId: string;
  title: string;
  content: string;
  excerpt: string;
  tags: string[];
  createdAt: string;
  updatedAt: string;
  version: number;
};

export type VersionSnapshot = {
  id: string;
  title: string;
  timestamp: string;
  preview: string;
  projectId: string;
  noteId: string;
};

export type BackupRecordPayload = {
  id: string;
  startedAt: string;
  completedAt: string;
  status: string;
  artifactPath?: string;
};
