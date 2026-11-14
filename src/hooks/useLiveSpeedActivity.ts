import { useEffect, useRef, useState } from 'react';
import { AppState, Platform } from 'react-native';

import type { LiveActivity } from 'expo-widgets';

import NetworkSpeedActivity, {
  type NetworkSpeedActivityProps,
} from '../../widgets/NetworkSpeedActivity';
import { formatCompactSpeed } from '../utils/formatCompactSpeed';
import { formatBytesPerSec, type SpeedUnit } from '../utils/formatSpeed';

type Options = {
  enabled: boolean;
  downSpeed: number;
  upSpeed: number;
  networkLabel: string;
  unit: SpeedUnit;
  trafficSupported: boolean;
};

function buildProps(
  downSpeed: number,
  upSpeed: number,
  networkLabel: string,
  unit: SpeedUnit
): NetworkSpeedActivityProps {
  return {
    downLabel: formatBytesPerSec(downSpeed, unit),
    upLabel: formatBytesPerSec(upSpeed, unit),
    downShort: formatCompactSpeed(downSpeed),
    upShort: formatCompactSpeed(upSpeed),
    networkLabel: networkLabel || '网络',
  };
}

export function useLiveSpeedActivity({
  enabled,
  downSpeed,
  upSpeed,
  networkLabel,
  unit,
  trafficSupported,
}: Options) {
  const [active, setActive] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const instanceRef = useRef<LiveActivity<NetworkSpeedActivityProps> | null>(null);
  const propsRef = useRef({ downSpeed, upSpeed, networkLabel, unit });
  propsRef.current = { downSpeed, upSpeed, networkLabel, unit };

  // Start / stop Live Activity with monitoring session
  useEffect(() => {
    if (Platform.OS !== 'ios') return;

    const shouldRun = enabled && trafficSupported;

    if (!shouldRun) {
      const instance = instanceRef.current;
      instanceRef.current = null;
      setActive(false);
      if (instance) {
        const finalProps = buildProps(
          propsRef.current.downSpeed,
          propsRef.current.upSpeed,
          propsRef.current.networkLabel,
          propsRef.current.unit
        );
        void instance.end('immediate', finalProps).catch(() => undefined);
      }
      return;
    }

    try {
      const existing = NetworkSpeedActivity.getInstances();
      if (existing.length > 0) {
        instanceRef.current = existing[0] ?? null;
      } else if (!instanceRef.current) {
        const { downSpeed: d, upSpeed: u, networkLabel: n, unit: unitNow } = propsRef.current;
        instanceRef.current = NetworkSpeedActivity.start(
          buildProps(d, u, n, unitNow),
          'netspeed://',
          new Date(Date.now() + 45_000)
        );
      }
      setActive(!!instanceRef.current);
      setError(null);
    } catch (e) {
      instanceRef.current = null;
      setActive(false);
      setError(e instanceof Error ? e.message : '无法启动灵动岛');
    }
  }, [enabled, trafficSupported]);

  // Push speed into Dynamic Island / Lock Screen
  useEffect(() => {
    if (Platform.OS !== 'ios') return;
    if (!enabled || !trafficSupported) return;

    const instance = instanceRef.current ?? NetworkSpeedActivity.getInstances()[0] ?? null;
    if (!instance) return;
    instanceRef.current = instance;

    const staleDate = new Date(Date.now() + 45_000);
    void instance
      .update(buildProps(downSpeed, upSpeed, networkLabel, unit), staleDate)
      .then(() => {
        setActive(true);
        setError(null);
      })
      .catch((e: unknown) => {
        setError(e instanceof Error ? e.message : '灵动岛更新失败');
      });
  }, [enabled, trafficSupported, downSpeed, upSpeed, networkLabel, unit]);

  // When returning to foreground, force a refresh
  useEffect(() => {
    if (Platform.OS !== 'ios') return;

    const sub = AppState.addEventListener('change', (state) => {
      if (state !== 'active') return;
      const instance = instanceRef.current;
      if (!instance || !enabled || !trafficSupported) return;
      const { downSpeed: d, upSpeed: u, networkLabel: n, unit: unitNow } = propsRef.current;
      void instance
        .update(buildProps(d, u, n, unitNow), new Date(Date.now() + 45_000))
        .catch(() => undefined);
    });

    return () => sub.remove();
  }, [enabled, trafficSupported]);

  useEffect(() => {
    return () => {
      const instance = instanceRef.current;
      instanceRef.current = null;
      if (instance) {
        void instance.end('immediate').catch(() => undefined);
      }
    };
  }, []);

  return {
    active,
    error,
    available: Platform.OS === 'ios',
  };
}
