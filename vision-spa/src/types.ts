export enum AppEventType {
  ProjectReset = 'project.reset',
  ProjectDeleted = 'project.deleted',
  ProjectSwitched = 'project.switched',
  NoteCreated = 'note.created',
  NoteUpdated = 'note.updated',
  NoteDeleted = 'note.deleted',
  NoteExportQueued = 'note.export.queued',
  NoteVersionRestored = 'note.version.restored',
  NoteVersionExportQueued = 'note.version.export.queued',
  BackupCompleted = 'backup.completed',
  IndexJobCompleted = 'index.job.completed',
  AISessionCompleted = 'ai.session.completed',
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

export type NoteListResponse = {
  items?: NoteSummary[];
  nextCursor?: string | null;
};

export type ProjectStats = {
  versionCount: number;
  latestNoteUpdatedAt?: string | null;
  uniqueTagCount: number;
  averageNoteLength: number;
};

export type ProjectSummary = {
  id: string;
  name: string;
  noteCount: number;
  lastIndexedAt?: string | null;
  stats?: ProjectStats;
};

export type VersionSnapshot = {
  id: string;
  title: string;
  timestamp: string;
  preview: string;
  projectId: string;
  noteId: string;
  version: number;
};

export type BackupRecordPayload = {
  id: string;
  startedAt: string;
  completedAt: string;
  status: string;
  artifactPath?: string;
};
