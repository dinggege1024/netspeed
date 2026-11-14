import NetworkSpeedModule from './src/NetworkSpeedModule';
import type { TrafficBytes } from './src/NetworkSpeed.types';

export type { TrafficBytes };

export function getTrafficBytes(): TrafficBytes {
  try {
    return NetworkSpeedModule.getTrafficBytes();
  } catch {
    return { rxBytes: 0, txBytes: 0, supported: false };
  }
}

export function isTrafficSupported(): boolean {
  try {
    return NetworkSpeedModule.isSupported();
  } catch {
    return false;
  }
}

export default NetworkSpeedModule;
