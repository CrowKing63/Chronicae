import { ChangeEventHandler, FC, useMemo, useRef, useState } from 'react';
import { renderMarkdown } from '../utils/diff';

type Mode = 'write' | 'preview' | 'split';

type Props = {
  value: string;
  onChange: (value: string) => void;
  disabled?: boolean;
};

const STORAGE_KEY = 'chronicae.markdownEditor.mode';

const loadInitialMode = (): Mode => {
  if (typeof window === 'undefined') return 'write';
  const stored = window.localStorage.getItem(STORAGE_KEY) as Mode | null;
  return stored === 'preview' || stored === 'split' ? stored : 'write';
};

export const MarkdownEditor: FC<Props> = ({ value, onChange, disabled }) => {
  const textareaRef = useRef<HTMLTextAreaElement | null>(null);
  const [mode, setMode] = useState<Mode>(loadInitialMode);

  const updateMode = (next: Mode) => {
    setMode(next);
    if (typeof window !== 'undefined') {
      window.localStorage.setItem(STORAGE_KEY, next);
    }
  };

  const applyInlineFormat = (prefix: string, suffix = prefix, placeholder = '') => {
    const target = textareaRef.current;
    if (!target || disabled) return;
    const { selectionStart, selectionEnd, value: currentValue } = target;
    const selected = currentValue.slice(selectionStart, selectionEnd) || placeholder;
    const nextValue = `${currentValue.slice(0, selectionStart)}${prefix}${selected}${suffix}${currentValue.slice(selectionEnd)}`;
    onChange(nextValue);
    requestAnimationFrame(() => {
      const start = selectionStart + prefix.length;
      const end = start + selected.length;
      target.focus();
      target.setSelectionRange(start, end);
    });
  };

  const applyBlockFormat = (prefix: string, suffix = '') => {
    const target = textareaRef.current;
    if (!target || disabled) return;
    const { selectionStart, selectionEnd, value: currentValue } = target;

    const blockStart = currentValue.lastIndexOf('\n', selectionStart - 1) + 1;
    const blockEndSearch = currentValue.indexOf('\n', selectionEnd);
    const blockEnd = blockEndSearch === -1 ? currentValue.length : blockEndSearch;

    const selectedBlock = currentValue.slice(blockStart, blockEnd);
    const lines = (selectionEnd > selectionStart ? selectedBlock : currentValue.slice(blockStart, selectionEnd)).split('\n');
    const formattedLines = lines.map(line => (line.startsWith(prefix) ? line : `${prefix}${line}`)).join('\n');

    const nextValue = `${currentValue.slice(0, blockStart)}${formattedLines}${suffix}${currentValue.slice(blockEnd)}`;
    onChange(nextValue);

    requestAnimationFrame(() => {
      const cursorStart = blockStart;
      const cursorEnd = blockStart + formattedLines.length;
      target.focus();
      target.setSelectionRange(cursorStart, cursorEnd);
    });
  };

  const handleInputChange: ChangeEventHandler<HTMLTextAreaElement> = event => {
    onChange(event.target.value);
  };

  const previewHtml = useMemo(() => renderMarkdown(value), [value]);

  return (
    <div className={`markdown-editor markdown-editor--${mode}`}>
      <div className="markdown-editor__toolbar">
        <div className="markdown-editor__controls">
          <button
            type="button"
            className="markdown-editor__button"
            onClick={() => applyInlineFormat('**', '**', '굵게')}
            disabled={disabled}
          >
            굵게
          </button>
          <button
            type="button"
            className="markdown-editor__button"
            onClick={() => applyInlineFormat('*', '*', '기울임')}
            disabled={disabled}
          >
            기울임
          </button>
          <button
            type="button"
            className="markdown-editor__button"
            onClick={() => applyInlineFormat('`', '`', 'code')}
            disabled={disabled}
          >
            코드
          </button>
          <button
            type="button"
            className="markdown-editor__button"
            onClick={() => applyInlineFormat('[', '](링크)', '텍스트')}
            disabled={disabled}
          >
            링크
          </button>
          <button
            type="button"
            className="markdown-editor__button"
            onClick={() => applyBlockFormat('# ')}
            disabled={disabled}
          >
            제목
          </button>
          <button
            type="button"
            className="markdown-editor__button"
            onClick={() => applyBlockFormat('- [ ] ')}
            disabled={disabled}
          >
            체크박스
          </button>
          <button
            type="button"
            className="markdown-editor__button"
            onClick={() => applyInlineFormat('```\n', '\n```', '코드를 입력하세요')}
            disabled={disabled}
          >
            코드 블록
          </button>
          <button
            type="button"
            className="markdown-editor__button"
            onClick={() => applyInlineFormat('#', '', '태그명')}
            disabled={disabled}
          >
            태그
          </button>
        </div>
        <div className="markdown-editor__modes">
          <button
            type="button"
            className={`markdown-editor__mode${mode === 'write' ? ' markdown-editor__mode--active' : ''}`}
            onClick={() => updateMode('write')}
          >
            Markdown
          </button>
          <button
            type="button"
            className={`markdown-editor__mode${mode === 'preview' ? ' markdown-editor__mode--active' : ''}`}
            onClick={() => updateMode('preview')}
          >
            미리보기
          </button>
          <button
            type="button"
            className={`markdown-editor__mode${mode === 'split' ? ' markdown-editor__mode--active' : ''}`}
            onClick={() => updateMode('split')}
          >
            분할
          </button>
        </div>
      </div>
      <div className="markdown-editor__body">
        {(mode === 'write' || mode === 'split') && (
          <textarea
            ref={textareaRef}
            className="textarea markdown-editor__textarea"
            value={value}
            onChange={handleInputChange}
            disabled={disabled}
            placeholder="마크다운을 입력하거나 도구를 사용하여 노트를 꾸며보세요."
            rows={12}
          />
        )}
        {(mode === 'preview' || mode === 'split') && (
          <div
            className="markdown-editor__preview note-preview"
            dangerouslySetInnerHTML={{ __html: previewHtml }}
          />
        )}
      </div>
    </div>
  );
};
