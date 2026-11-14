import { useEffect, useRef, useState } from 'react';
import { Platform } from 'react-native';

import { getTrafficBytes, isTrafficSupported } from '../../modules/network-speed';

export type SpeedSample = {
  down: number;
  up: number;
  at: number;
};

const HISTORY_LEN = 60;
const INTERVAL_MS = 1000;
const SMOOTH = 0.35;

function smooth(prev: number, next: number): number {
  if (!Number.isFinite(next) || next < 0) return prev;
  return prev * (1 - SMOOTH) + next * SMOOTH;
}

export function useNetworkSpeed(enabled: boolean) {
  const [downSpeed, setDownSpeed] = useState(0);
  const [upSpeed, setUpSpeed] = useState(0);
  const [totalDown, setTotalDown] = useState(0);
  const [totalUp, setTotalUp] = useState(0);
  const [history, setHistory] = useState<SpeedSample[]>([]);
  const [supported, setSupported] = useState(false);
  const [ready, setReady] = useState(false);

  const lastRef = useRef<{ rx: number; tx: number; at: number } | null>(null);
  const smoothedRef = useRef({ down: 0, up: 0 });

  useEffect(() => {
    let alive = true;
    try {
      setSupported(isTrafficSupported());
    } catch {
      setSupported(false);
    }
    setReady(true);
    return () => {
      alive = false;
      void alive;
    };
  }, []);

  useEffect(() => {
    if (!enabled) return;

    const tick = () => {
      try {
        const traffic = getTrafficBytes();
        if (!traffic.supported) {
          setSupported(false);
          return;
        }
        setSupported(true);
        setTotalDown(traffic.rxBytes);
        setTotalUp(traffic.txBytes);

        const now = Date.now();
        const last = lastRef.current;
        if (!last) {
          lastRef.current = { rx: traffic.rxBytes, tx: traffic.txBytes, at: now };
          return;
        }

        const dt = Math.max((now - last.at) / 1000, 0.2);
        const rawDown = Math.max(0, (traffic.rxBytes - last.rx) / dt);
        const rawUp = Math.max(0, (traffic.txBytes - last.tx) / dt);
        lastRef.current = { rx: traffic.rxBytes, tx: traffic.txBytes, at: now };

        // Counter reset (reboot / overflow)
        if (traffic.rxBytes < last.rx || traffic.txBytes < last.tx) {
          return;
        }

        smoothedRef.current = {
          down: smooth(smoothedRef.current.down, rawDown),
          up: smooth(smoothedRef.current.up, rawUp),
        };

        const sample: SpeedSample = {
          down: smoothedRef.current.down,
          up: smoothedRef.current.up,
          at: now,
        };

        setDownSpeed(sample.down);
        setUpSpeed(sample.up);
        setHistory((prev) => {
          const next = [...prev, sample];
          return next.length > HISTORY_LEN ? next.slice(next.length - HISTORY_LEN) : next;
        });
      } catch {
        setSupported(false);
      }
    };

    tick();
    const id = setInterval(tick, INTERVAL_MS);
    return () => clearInterval(id);
  }, [enabled]);

  return {
    downSpeed,
    upSpeed,
    totalDown,
    totalUp,
    history,
    supported,
    ready,
    platform: Platform.OS,
  };
}
