import { useEffect, useState } from 'react';
import NetInfo, { type NetInfoState } from '@react-native-community/netinfo';

export type NetworkMeta = {
  connected: boolean;
  typeLabel: string;
  detail: string;
};

function describe(state: NetInfoState): NetworkMeta {
  if (!state.isConnected) {
    return { connected: false, typeLabel: '离线', detail: '无可用网络' };
  }

  switch (state.type) {
    case 'wifi': {
      const wifi = state.details as { ssid?: string | null; strength?: number | null; linkSpeed?: number | null } | null;
      const ssid = wifi?.ssid?.trim();
      const speed = wifi?.linkSpeed != null ? `${wifi.linkSpeed} Mbps 链路` : null;
      return {
        connected: true,
        typeLabel: 'Wi‑Fi',
        detail: [ssid || '已连接', speed].filter(Boolean).join(' · '),
      };
    }
    case 'cellular': {
      const cellular = state.details as { cellularGeneration?: string | null; carrier?: string | null } | null;
      const gen = cellular?.cellularGeneration ? cellular.cellularGeneration.toUpperCase() : '蜂窝';
      const carrier = cellular?.carrier?.trim();
      return {
        connected: true,
        typeLabel: gen,
        detail: carrier || '移动数据',
      };
    }
    case 'ethernet':
      return { connected: true, typeLabel: '有线', detail: 'Ethernet' };
    case 'none':
      return { connected: false, typeLabel: '离线', detail: '无可用网络' };
    default:
      return { connected: !!state.isConnected, typeLabel: state.type, detail: '已连接' };
  }
}

export function useNetworkInfo() {
  const [meta, setMeta] = useState<NetworkMeta>({
    connected: true,
    typeLabel: '检测中',
    detail: '…',
  });

  useEffect(() => {
    const unsub = NetInfo.addEventListener((state) => {
      setMeta(describe(state));
    });
    void NetInfo.fetch().then((state) => setMeta(describe(state)));
    return unsub;
  }, []);

  return meta;
}
