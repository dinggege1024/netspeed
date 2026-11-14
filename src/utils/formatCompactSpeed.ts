/** Short labels for Dynamic Island compact leading/trailing (tight width). */
export function formatCompactSpeed(bytesPerSec: number): string {
  const value = Math.max(0, bytesPerSec);

  if (value < 1024) {
    return `${Math.round(value)}B`;
  }

  const kb = value / 1024;
  if (kb < 1024) {
    return kb >= 100 ? `${Math.round(kb)}K` : `${kb.toFixed(kb >= 10 ? 0 : 1)}K`;
  }

  const mb = kb / 1024;
  if (mb < 1024) {
    return mb >= 100 ? `${Math.round(mb)}M` : `${mb.toFixed(mb >= 10 ? 1 : 2)}M`;
  }

  const gb = mb / 1024;
  return `${gb.toFixed(1)}G`;
}
