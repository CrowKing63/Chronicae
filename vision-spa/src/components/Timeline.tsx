import { FC } from 'react';
import { VersionSnapshot } from '../types';

type Props = {
  versions: VersionSnapshot[];
  selectedId: string | null;
  onSelect: (versionId: string) => void;
};

export const Timeline: FC<Props> = ({ versions, selectedId, onSelect }) => (
  <ul className="list">
    {versions.map(version => (
      <li
        key={version.id}
        className={`list__item${version.id === selectedId ? ' list__item--active' : ''}`}
        onClick={() => onSelect(version.id)}
      >
        <div className="timeline__header">
          <strong>{version.title || '제목 없음'}</strong>
          <small>{new Date(version.timestamp).toLocaleString()}</small>
        </div>
        <p className="timeline__preview">
          {(version.preview ?? '').replace(/\n+/g, ' ').trim().slice(0, 140) || '내용 미리보기를 불러올 수 없습니다.'}
        </p>
      </li>
    ))}
  </ul>
);
