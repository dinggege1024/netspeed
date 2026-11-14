export type SpeedTestPhase = 'idle' | 'ping' | 'download' | 'upload' | 'done' | 'error';

export type SpeedTestResult = {
  pingMs: number | null;
  downloadMbps: number | null;
  uploadMbps: number | null;
  error?: string;
};

export type SpeedTestProgress = {
  phase: SpeedTestPhase;
  result: SpeedTestResult;
  liveMbps?: number;
};

const DOWNLOAD_URL = 'https://speed.cloudflare.com/__down?bytes=12000000';
const UPLOAD_URL = 'https://speed.cloudflare.com/__up';
const PING_URL = 'https://speed.cloudflare.com/__down?bytes=10';

function nowMs(): number {
  return typeof performance !== 'undefined' && performance.now ? performance.now() : Date.now();
}

async function measurePing(signal: AbortSignal): Promise<number> {
  const samples: number[] = [];
  for (let i = 0; i < 3; i += 1) {
    const start = nowMs();
    const res = await fetch(`${PING_URL}&t=${Date.now()}`, { method: 'GET', signal, cache: 'no-store' });
    await res.arrayBuffer();
    samples.push(nowMs() - start);
  }
  samples.sort((a, b) => a - b);
  return samples[1] ?? samples[0] ?? 0;
}

async function measureDownload(signal: AbortSignal): Promise<number> {
  const start = nowMs();
  const res = await fetch(`${DOWNLOAD_URL}&t=${Date.now()}`, { method: 'GET', signal, cache: 'no-store' });
  const buf = await res.arrayBuffer();
  const elapsed = Math.max((nowMs() - start) / 1000, 0.001);
  return (buf.byteLength * 8) / elapsed / 1_000_000;
}

async function measureUpload(signal: AbortSignal): Promise<number> {
  const size = 4_000_000;
  const payload = new Uint8Array(size);
  const start = nowMs();
  const res = await fetch(UPLOAD_URL, {
    method: 'POST',
    body: payload,
    signal,
    headers: { 'Content-Type': 'application/octet-stream' },
  });
  await res.text();
  const elapsed = Math.max((nowMs() - start) / 1000, 0.001);
  return (size * 8) / elapsed / 1_000_000;
}

export async function runSpeedTest(
  onProgress: (progress: SpeedTestProgress) => void,
  signal: AbortSignal
): Promise<SpeedTestResult> {
  const result: SpeedTestResult = {
    pingMs: null,
    downloadMbps: null,
    uploadMbps: null,
  };

  try {
    onProgress({ phase: 'ping', result: { ...result } });
    result.pingMs = await measurePing(signal);
    onProgress({ phase: 'download', result: { ...result } });

    result.downloadMbps = await measureDownload(signal);
    onProgress({ phase: 'upload', result: { ...result }, liveMbps: result.downloadMbps });

    result.uploadMbps = await measureUpload(signal);
    onProgress({ phase: 'done', result: { ...result } });
    return result;
  } catch (error) {
    if (signal.aborted) {
      onProgress({ phase: 'idle', result });
      return result;
    }
    const message = error instanceof Error ? error.message : '测速失败';
    const failed = { ...result, error: message };
    onProgress({ phase: 'error', result: failed });
    return failed;
  }
}
