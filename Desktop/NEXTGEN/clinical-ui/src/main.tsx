import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import './tailwind.css';
import './styles.css';
import './components/Examination/exam.css';
import './admin/admin.css';

const rootElement = document.getElementById('root');

if (!rootElement) {
  throw new Error('AMEXAN Clinical UI: root element not found');
}

createRoot(rootElement).render(
  <StrictMode>
    <App />
  </StrictMode>,
);