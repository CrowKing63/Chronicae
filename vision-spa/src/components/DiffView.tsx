import { FC } from 'react';
import { DiffSegment } from '../utils/diff';

type Props = {
  diff: DiffSegment[];
};

export const DiffView: FC<Props> = ({ diff }) => {
  if (!diff.length) {
    return <p className="placeholder">변경된 내용이 없습니다.</p>;
  }

  return (
    <div className="diff">
      {diff.map((segment, index) => (
        <div key={`${segment.prefix}-${index}`} className={`diff__line diff__line--${segment.type}`}>
          <span className="diff__marker">{segment.prefix}</span>
          <span className="diff__text">{segment.text}</span>
        </div>
      ))}
    </div>
  );
};
