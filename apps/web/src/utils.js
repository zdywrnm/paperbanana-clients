export function resolveImageUrl(apiBase, url) {
  if (!url) return '';
  if (/^(https?:|data:|blob:)/i.test(url)) return url;
  return `${apiBase}${url}`;
}

export function formatErrorMessage(message) {
  if (!message) return '';
  if (message.includes('Missing API key')) return '缺少所选模型接口的 API 密钥。';
  if (message.includes('Failed to fetch')) return '任务状态刷新失败，页面会自动重试。';
  if (message.includes('Please log in') || message.includes('请先登录') || message.includes('Unauthorized')) return '请先登录后再使用生成服务。';
  if (message.includes('password')) return '密码至少需要 8 位。';
  if (message.includes('ADMIN_TOKEN is not configured')) return '管理接口未启用：还没有配置 ADMIN_TOKEN。';
  if (message.includes('Admin API disabled')) return '管理接口未启用。';
  if (message.includes('Backend is unavailable')) return '后端暂时不可用。';
  if (message.includes('HTTP 503')) return '服务暂时不可用，请稍后重试。';
  return message;
}

export function formatConfigurationMode(mode) {
  return mode === 'simple' ? '普通模式' : '专业模式';
}

export function formatOutputFormat(format) {
  if (format === 'svg') return 'SVG 矢量图';
  return 'PNG 图片';
}

export function formatReferenceImageMode(mode) {
  if (mode === 'main_model') return '主模型直读';
  if (mode === 'vision_model') return '独立识别';
  if (mode === 'auto') return '自动选择';
  if (mode === 'none') return '未使用参考图';
  return '未记录';
}

export function formatDate(value) {
  if (!value) return '';
  return new Intl.DateTimeFormat('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
}
