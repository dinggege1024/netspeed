export type SpeedUnit = 'auto-bytes' | 'Mbps';

const BYTE_UNITS = ['B/s', 'KB/s', 'MB/s', 'GB/s'] as const;

export function formatBytesPerSec(bytesPerSec: number, unit: SpeedUnit): string {
  const value = Math.max(0, bytesPerSec);

  if (unit === 'Mbps') {
    const mbps = (value * 8) / 1_000_000;
    if (mbps >= 100) return `${mbps.toFixed(0)} Mbps`;
    if (mbps >= 10) return `${mbps.toFixed(1)} Mbps`;
    return `${mbps.toFixed(2)} Mbps`;
  }

  let size = value;
  let index = 0;
  while (size >= 1024 && index < BYTE_UNITS.length - 1) {
    size /= 1024;
    index += 1;
  }

  if (size >= 100) return `${size.toFixed(0)} ${BYTE_UNITS[index]}`;
  if (size >= 10) return `${size.toFixed(1)} ${BYTE_UNITS[index]}`;
  return `${size.toFixed(2)} ${BYTE_UNITS[index]}`;
}

export function splitSpeed(bytesPerSec: number, unit: SpeedUnit): { value: string; unitLabel: string } {
  const formatted = formatBytesPerSec(bytesPerSec, unit);
  const parts = formatted.split(' ');
  return {
    value: parts[0] ?? '0',
    unitLabel: parts.slice(1).join(' ') || (unit === 'Mbps' ? 'Mbps' : 'B/s'),
  };
}

export function formatDataSize(bytes: number): string {
  const value = Math.max(0, bytes);
  const units = ['B', 'KB', 'MB', 'GB', 'TB'] as const;
  let size = value;
  let index = 0;
  while (size >= 1024 && index < units.length - 1) {
    size /= 1024;
    index += 1;
  }
  return `${size.toFixed(size >= 100 ? 0 : 1)} ${units[index]}`;
}
