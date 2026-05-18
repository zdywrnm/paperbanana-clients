import { AUTH_ENABLED } from '../config';

export async function fetchJson(url, options = {}) {
  const fetchOptions = AUTH_ENABLED ? { credentials: 'include', ...options } : options;
  const res = await fetch(url, fetchOptions);
  const text = await res.text();
  let data = {};
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = { detail: text };
    }
  }
  if (!res.ok || (data.code && data.code !== 0)) {
    throw new Error(data.error || data.detail || `HTTP ${res.status}`);
  }
  return data;
}
