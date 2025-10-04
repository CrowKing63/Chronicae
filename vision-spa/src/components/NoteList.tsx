import { FC } from 'react';
import { NoteSummary } from '../types';

type Props = {
  notes: NoteSummary[];
  selectedId: string | null;
  onSelect: (noteId: string) => void;
  emptyMessage?: string;
  isLoading?: boolean;
  hasMore?: boolean;
  onLoadMore?: () => void;
  isLoadingMore?: boolean;
};

export const NoteList: FC<Props> = ({
  notes,
  selectedId,
  onSelect,
  emptyMessage,
  isLoading = false,
  hasMore = false,
  onLoadMore,
  isLoadingMore = false
}) => {
  if (isLoading && !notes.length) {
    return (
      <div className="list list--empty">
        <p className="placeholder">불러오는 중…</p>
      </div>
    );
  }

  if (!notes.length) {
    return (
      <div className="list list--empty">
        <p className="placeholder">{emptyMessage ?? '노트가 없습니다. macOS 앱에서 노트를 추가하면 실시간으로 반영됩니다.'}</p>
      </div>
    );
  }

  return (
    <>
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
      {(hasMore || isLoadingMore) && onLoadMore && (
        <div className="list__footer">
          <button
            type="button"
            className="button button--ghost"
            onClick={onLoadMore}
            disabled={isLoadingMore}
          >
            {isLoadingMore ? '추가 로딩 중…' : '노트 더 불러오기'}
          </button>
        </div>
      )}
    </>
  );
};
