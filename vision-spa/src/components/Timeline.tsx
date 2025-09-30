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
        <strong>{version.title}</strong>
        <br />
        <small>{new Date(version.timestamp).toLocaleString()}</small>
      </li>
    ))}
  </ul>
);
