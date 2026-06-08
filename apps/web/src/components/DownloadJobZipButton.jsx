import { useState } from 'react';
import JSZip from 'jszip';
import { Archive } from 'lucide-react';
import { resolveImageUrl } from '../utils';

export default function DownloadJobZipButton({ job, apiBase }) {
  const [isPreparing, setIsPreparing] = useState(false);
  const images = collectImages(job);

  async function downloadZip() {
    if (!images.length || isPreparing) return;
    setIsPreparing(true);
    try {
      const zip = new JSZip();
      zip.file('metadata.json', JSON.stringify(job, null, 2));
      for (const item of images) {
        const url = resolveImageUrl(apiBase, item.url);
        if (!url) continue;
        const blob = await fetchBlob(url);
        zip.file(item.filename, blob);
      }
      const blob = await zip.generateAsync({ type: 'blob' });
      triggerDownload(URL.createObjectURL(blob), `paperbanana-${job.id || 'job'}.zip`);
    } finally {
      setIsPreparing(false);
    }
  }

  if (!images.length) return null;

  return (
    <button type="button" className="zip-download-button" onClick={downloadZip} disabled={isPreparing}>
      <Archive size={16} />
      {isPreparing ? '打包中' : '下载全部'}
    </button>
  );
}

function collectImages(job = {}) {
  const resultImages = (job.result_images || []).map((image, index) => ({
    url: image.url,
    filename: `results/result-${index + 1}.${extensionFor(image)}`,
  }));
  const referenceImages = (job.reference_images || []).map((image, index) => ({
    url: image.url,
    filename: `references/reference-${index + 1}.${extensionFor(image)}`,
  }));
  const stageImages = (job.stages || [])
    .filter((stage) => stage.image?.url)
    .map((stage, index) => ({
      url: stage.image.url,
      filename: `stages/stage-${String(index + 1).padStart(2, '0')}-${stage.type || 'stage'}.${extensionFor(stage.image)}`,
    }));
  return [...resultImages, ...referenceImages, ...stageImages].filter((item) => item.url);
}

function extensionFor(image = {}) {
  const mimeType = image.mime_type || image.mimeType || '';
  if (mimeType.includes('svg')) return 'svg';
  if (mimeType.includes('jpeg') || mimeType.includes('jpg')) return 'jpg';
  if (mimeType.includes('webp')) return 'webp';
  return 'png';
}

async function fetchBlob(url) {
  const response = await fetch(url, { credentials: 'omit' });
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  return await response.blob();
}

function triggerDownload(url, filename) {
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 1000);
}
