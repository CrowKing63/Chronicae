import { FC } from 'react';
import { NoteSummary } from '../types';

type Props = {
  notes: NoteSummary[];
  selectedId: string | null;
  onSelect: (noteId: string) => void;
  emptyMessage?: string;
};

export const NoteList: FC<Props> = ({ notes, selectedId, onSelect, emptyMessage }) => {
  if (!notes.length) {
    return (
      <div className="list list--empty">
        <p className="placeholder">{emptyMessage ?? '노트가 없습니다. macOS 앱에서 노트를 추가하면 실시간으로 반영됩니다.'}</p>
      </div>
    );
  }

  return (
    <ul className="list">
      {notes.map(note => (
        <li
          key={note.id}
          className={`list__item${note.id === selectedId ? ' list__item--active' : ''}`}
          onClick={() => onSelect(note.id)}
        >
          <div className="list__title">{note.title || '제목 없음'}</div>
          <div className="list__meta">{new Date(note.updatedAt).toLocaleString()}</div>
          <p className="list__excerpt">{note.excerpt || (note.content ?? '').slice(0, 120) || '내용이 없습니다.'}</p>
          <div className="chip-group">
            {(note.tags ?? []).slice(0, 4).map(tag => (
              <span key={tag} className="chip chip--compact">{tag}</span>
            ))}
          </div>
        </li>
      ))}
    </ul>
  );
};
