import { useEffect, useRef } from 'react';
import { HubConnection, HubConnectionBuilder, HubConnectionState } from '@microsoft/signalr';

export type SignalRHandler = {
  onOpen?: () => void;
  onError?: (error: Error) => void;
  onEvent?: (message: { event: string; data: any; timestamp: string }) => void;
};

export const useSignalR = (url: string, handler: SignalRHandler) => {
  const handlerRef = useRef(handler);
  const connectionRef = useRef<HubConnection | null>(null);
  handlerRef.current = handler;

  useEffect(() => {
    let reconnectTimer: number | undefined;

    const connect = async () => {
      if (connectionRef.current) {
        await connectionRef.current.stop();
      }

      // Get auth token from localStorage if available
      const authToken = localStorage.getItem('authToken');
      
      const connection = new HubConnectionBuilder()
        .withUrl(url, {
          accessTokenFactory: () => authToken || ''
        })
        .withAutomaticReconnect({
          nextRetryDelayInMilliseconds: (retryContext) => {
            // Exponential backoff: 1s, 2s, 4s, 8s, then 30s
            if (retryContext.previousRetryCount < 4) {
              return Math.pow(2, retryContext.previousRetryCount) * 1000;
            }
            return 30000;
          }
        })
        .build();

      connectionRef.current = connection;

      // Handle connection events
      connection.onreconnecting(() => {
        handlerRef.current.onError?.(new Error('Connection lost, reconnecting...'));
      });

      connection.onreconnected(() => {
        handlerRef.current.onOpen?.();
      });

      connection.onclose((error) => {
        if (error) {
          handlerRef.current.onError?.(error);
          // Manual reconnect after 3 seconds if not using automatic reconnect
          if (reconnectTimer) window.clearTimeout(reconnectTimer);
          reconnectTimer = window.setTimeout(() => {
            connect().catch(console.error);
          }, 3000);
        }
      });

      // Listen for events
      connection.on('Event', (message: { event: string; data: any; timestamp: string }) => {
        handlerRef.current.onEvent?.(message);
      });

      try {
        await connection.start();
        handlerRef.current.onOpen?.();
      } catch (error) {
        handlerRef.current.onError?.(error as Error);
        // Retry connection after 3 seconds
        if (reconnectTimer) window.clearTimeout(reconnectTimer);
        reconnectTimer = window.setTimeout(() => {
          connect().catch(console.error);
        }, 3000);
      }
    };

    connect().catch(console.error);

    return () => {
      if (reconnectTimer) window.clearTimeout(reconnectTimer);
      if (connectionRef.current && connectionRef.current.state !== HubConnectionState.Disconnected) {
        connectionRef.current.stop().catch(console.error);
      }
    };
  }, [url]);
};