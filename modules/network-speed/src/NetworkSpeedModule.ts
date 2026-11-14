import { NativeModule, requireNativeModule } from 'expo';

import type { TrafficBytes } from './NetworkSpeed.types';

declare class NetworkSpeedModuleType extends NativeModule {
  getTrafficBytes(): TrafficBytes;
  isSupported(): boolean;
}

export default requireNativeModule<NetworkSpeedModuleType>('NetworkSpeed');
