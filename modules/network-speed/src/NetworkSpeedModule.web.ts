import type { TrafficBytes } from './NetworkSpeed.types';

export default {
  getTrafficBytes(): TrafficBytes {
    return { rxBytes: 0, txBytes: 0, supported: false };
  },
  isSupported(): boolean {
    return false;
  },
};
