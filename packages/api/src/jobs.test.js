import assert from 'node:assert/strict';
import test from 'node:test';

import { createJobRequest, getJobRequest, refineImageRequest } from './jobs.js';

function mockJsonFetch(handler) {
  const originalFetch = globalThis.fetch;
  const calls = [];
  globalThis.fetch = async (url, options = {}) => {
    calls.push({ url, options });
    const payload = await handler(url, options, calls.length - 1);
    return {
      ok: payload.ok ?? true,
      status: payload.status || 200,
      text: async () => JSON.stringify(payload.body ?? payload),
    };
  };
  return {
    calls,
    restore() {
      globalThis.fetch = originalFetch;
    },
  };
}

test('createJobRequest sends retrieval and task fields to gateway/Laf', async () => {
  const fetchMock = mockJsonFetch(() => ({ body: { code: 0, jobId: 'job-1', status: 'queued' } }));
  try {
    const result = await createJobRequest('https://gateway.example', { backendMode: 'gateway' }, {
      configurationMode: 'advanced',
      provider: 'bailian',
      apiKeys: { bailian: 'key' },
      taskName: 'diagram',
      methodContent: 'A sufficiently long method section for testing.',
      caption: 'Figure 1',
      infographicCategory: '方法框架图',
      outputFormat: 'png',
      mainModelName: 'qwen-plus',
      imageGenModelName: 'wanx2.1-t2i-plus',
      referenceVisionModelName: 'qwen-vl-plus',
      referenceImageMode: 'auto',
      referenceImages: [],
      pipelineMode: 'demo_full',
      retrievalSetting: 'manual',
      manualReferenceIds: ['diagram-001', 'diagram-002'],
      aspectRatio: '16:9',
      numCandidates: 2,
      maxCriticRounds: 1,
    });

    assert.deepEqual(result, { id: 'job-1', status: 'queued' });
    const body = JSON.parse(fetchMock.calls[0].options.body);
    assert.equal(body.action, 'createJob');
    assert.equal(body.taskName, 'diagram');
    assert.equal(body.pipelineMode, 'full');
    assert.equal(body.retrievalSetting, 'manual');
    assert.deepEqual(body.manualReferenceIds, ['diagram-001', 'diagram-002']);
  } finally {
    fetchMock.restore();
  }
});

test('getJobRequest normalizes PaperBanana parity fields', async () => {
  const fetchMock = mockJsonFetch(() => ({
    body: {
      code: 0,
      job: {
        _id: 'job-2',
        status: 'succeeded',
        taskName: 'diagram',
        retrievalSetting: 'auto',
        retrievedReferenceIds: ['ref-a'],
        retrievedReferences: [{ id: 'ref-a', title: 'Reference A', imageUrl: 'https://example.com/ref.png' }],
        criticMode: 'image',
        stages: [
          { id: 'stage-1', candidateId: 0, type: 'planner', title: 'Planner', text: 'plan' },
          { id: 'stage-2', candidateId: 0, type: 'critic', round: 1, text: 'revise spacing' },
        ],
        resultImages: [{ filename: 'candidate.png', url: 'data:image/png;base64,AAAA', candidateId: 0 }],
      },
    },
  }));
  try {
    const job = await getJobRequest('https://laf.example/paperbanana-api', { backendMode: 'laf' }, 'job-2');
    assert.equal(job.task_name, 'diagram');
    assert.equal(job.retrieval_setting, 'auto');
    assert.deepEqual(job.retrieved_reference_ids, ['ref-a']);
    assert.equal(job.retrieved_references[0].id, 'ref-a');
    assert.equal(job.critic_mode, 'image');
    assert.equal(job.stages.length, 2);
    assert.equal(job.stages[1].type, 'critic');
  } finally {
    fetchMock.restore();
  }
});

test('refineImageRequest sends image edit payload to gateway/Laf', async () => {
  const fetchMock = mockJsonFetch(() => ({ body: { code: 0, jobId: 'refine-1', status: 'queued' } }));
  try {
    const result = await refineImageRequest('https://gateway.example', { backendMode: 'gateway' }, {
      provider: 'openai',
      apiKeys: { openai: 'key' },
      imageModelName: 'gpt-image-1',
      sourceImageUrl: 'https://example.com/source.png',
      editInstruction: 'Make the labels larger.',
      aspectRatio: '16:9',
      imageSize: '2K',
    });

    assert.deepEqual(result, { id: 'refine-1', status: 'queued' });
    const body = JSON.parse(fetchMock.calls[0].options.body);
    assert.equal(body.action, 'refineImage');
    assert.equal(body.sourceImageUrl, 'https://example.com/source.png');
    assert.equal(body.editInstruction, 'Make the labels larger.');
  } finally {
    fetchMock.restore();
  }
});
