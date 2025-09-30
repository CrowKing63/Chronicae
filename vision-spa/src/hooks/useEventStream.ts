import { useEffect, useRef } from 'react';

export type EventStreamHandler = {
  onOpen?: () => void;
  onError?: (error: Event) => void;
  onEvent?: (message: { type: string; data: string }) => void;
};

export const useEventStream = (url: string, handler: EventStreamHandler) => {
  const handlerRef = useRef(handler);
  handlerRef.current = handler;

  useEffect(() => {
    let source: EventSource | null = null;
    let reconnectTimer: number | undefined;

    const knownEvents = [
      'message',
      'note.created',
      'note.updated',
      'note.deleted',
      'note.version.restored',
      'note.export.queued',
      'note.version.export.queued',
      'project.reset',
      'project.deleted',
      'backup.completed',
      'ping'
    ];

    const listener = (event: MessageEvent) => {
      handlerRef.current.onEvent?.({ type: event.type, data: event.data });
    };

    const connect = () => {
      if (source) {
        knownEvents.forEach(type => source?.removeEventListener(type, listener));
        source.close();
      }

      source = new EventSource(url);
      source.onopen = () => handlerRef.current.onOpen?.();
      source.onerror = event => {
        handlerRef.current.onError?.(event);
        source?.close();
        if (reconnectTimer) window.clearTimeout(reconnectTimer);
        reconnectTimer = window.setTimeout(connect, 3000);
      };

      knownEvents.forEach(type => source?.addEventListener(type, listener));
    };

    connect();

    return () => {
      if (reconnectTimer) window.clearTimeout(reconnectTimer);
      if (source) {
        knownEvents.forEach(type => source?.removeEventListener(type, listener));
        source.close();
      }
    };
  }, [url]);
};
