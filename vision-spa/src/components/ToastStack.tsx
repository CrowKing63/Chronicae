import { FC } from 'react';

type Toast = { id: string; icon: string; message: string };

type Props = {
  toasts: Toast[];
};

export const ToastStack: FC<Props> = ({ toasts }) => (
  <div className="toast-stack">
    {toasts.map(toast => (
      <div key={toast.id} className="toast">
        <span className="toast__icon">{toast.icon}</span>
        <span>{toast.message}</span>
      </div>
    ))}
  </div>
);
