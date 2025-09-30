export const renderMarkdown = (markdown: string): string => {
  if (!markdown || !markdown.trim()) {
    return '<p class="placeholder">내용이 비어 있습니다.</p>';
  }
  return markdown
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/\r\n|\r/g, '\n')
    .replace(/^### (.*$)/gim, '<h3>$1</h3>')
    .replace(/^## (.*$)/gim, '<h2>$1</h2>')
    .replace(/^# (.*$)/gim, '<h1>$1</h1>')
    .replace(/\*\*(.*)\*\*/gim, '<strong>$1</strong>')
    .replace(/\*(.*)\*/gim, '<em>$1</em>')
    .replace(/`{3}([\s\S]*?)`{3}/gim, '<pre><code>$1</code></pre>')
    .replace(/\n\n/g, '</p><p>')
    .replace(/\n/g, '<br />')
    .replace(/^<p>/, '<p>');
};

export type DiffSegment = {
  type: 'added' | 'removed' | 'context';
  prefix: string;
  text: string;
};

export const computeDiff = (oldContent: string, newContent: string): DiffSegment[] => {
  const oldLines = oldContent.split('\n');
  const newLines = newContent.split('\n');
  const max = Math.max(oldLines.length, newLines.length);
  const result: DiffSegment[] = [];
  for (let i = 0; i < max; i += 1) {
    const oldLine = oldLines[i] ?? '';
    const newLine = newLines[i] ?? '';
    if (oldLine === newLine) {
      result.push({ type: 'context', prefix: ' ', text: newLine });
    } else {
      if (oldLine) result.push({ type: 'removed', prefix: '-', text: oldLine });
      if (newLine) result.push({ type: 'added', prefix: '+', text: newLine });
    }
  }
  return result;
};
