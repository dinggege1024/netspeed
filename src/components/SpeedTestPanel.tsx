import { useRef, useState } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Text, View } from 'react-native';

import {
  runSpeedTest,
  type SpeedTestPhase,
  type SpeedTestResult,
} from '../services/speedTest';
import { colors } from '../theme/colors';

const PHASE_LABEL: Record<SpeedTestPhase, string> = {
  idle: '测一下真实带宽',
  ping: '测量延迟…',
  download: '下载测速中…',
  upload: '上传测速中…',
  done: '测速完成',
  error: '测速失败',
};

export function SpeedTestPanel() {
  const [phase, setPhase] = useState<SpeedTestPhase>('idle');
  const [result, setResult] = useState<SpeedTestResult>({
    pingMs: null,
    downloadMbps: null,
    uploadMbps: null,
  });
  const abortRef = useRef<AbortController | null>(null);

  const busy = phase === 'ping' || phase === 'download' || phase === 'upload';

  const onStart = async () => {
    if (busy) {
      abortRef.current?.abort();
      abortRef.current = null;
      setPhase('idle');
      return;
    }

    const controller = new AbortController();
    abortRef.current = controller;
    setResult({ pingMs: null, downloadMbps: null, uploadMbps: null });

    await runSpeedTest((progress) => {
      setPhase(progress.phase);
      setResult(progress.result);
    }, controller.signal);

    abortRef.current = null;
  };

  return (
    <View style={styles.wrap}>
      <Text style={styles.title}>一键测速</Text>
      <Text style={styles.sub}>Cloudflare 公开节点 · 结果仅本机显示</Text>

      <View style={styles.metrics}>
        <Metric label="延迟" value={result.pingMs != null ? `${result.pingMs.toFixed(0)} ms` : '—'} />
        <Metric
          label="下载"
          value={result.downloadMbps != null ? `${result.downloadMbps.toFixed(1)} Mbps` : '—'}
        />
        <Metric
          label="上传"
          value={result.uploadMbps != null ? `${result.uploadMbps.toFixed(1)} Mbps` : '—'}
        />
      </View>

      {result.error ? <Text style={styles.error}>{result.error}</Text> : null}

      <Pressable
        onPress={onStart}
        style={({ pressed }) => [styles.btn, pressed && styles.btnPressed]}
        accessibilityRole="button"
      >
        {busy ? <ActivityIndicator color={colors.bgDeep} /> : null}
        <Text style={styles.btnText}>{busy ? '停止' : PHASE_LABEL[phase === 'done' ? 'idle' : phase]}</Text>
      </Pressable>
    </View>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.metric}>
      <Text style={styles.metricLabel}>{label}</Text>
      <Text style={styles.metricValue}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    marginTop: 18,
    padding: 16,
    borderRadius: 18,
    backgroundColor: colors.card,
    borderWidth: 1,
    borderColor: colors.line,
  },
  title: {
    fontFamily: 'DMSans_500Medium',
    fontSize: 15,
    color: colors.text,
  },
  sub: {
    marginTop: 4,
    fontFamily: 'DMSans_400Regular',
    fontSize: 12,
    color: colors.textFaint,
  },
  metrics: {
    marginTop: 16,
    flexDirection: 'row',
    gap: 12,
  },
  metric: {
    flex: 1,
  },
  metricLabel: {
    fontFamily: 'DMSans_400Regular',
    fontSize: 12,
    color: colors.textFaint,
    marginBottom: 4,
  },
  metricValue: {
    fontFamily: 'SpaceGrotesk_500Medium',
    fontSize: 16,
    color: colors.tealSoft,
  },
  error: {
    marginTop: 10,
    fontFamily: 'DMSans_400Regular',
    fontSize: 12,
    color: colors.coral,
  },
  btn: {
    marginTop: 16,
    height: 48,
    borderRadius: 14,
    backgroundColor: colors.teal,
    alignItems: 'center',
    justifyContent: 'center',
    flexDirection: 'row',
    gap: 8,
  },
  btnPressed: {
    opacity: 0.88,
  },
  btnText: {
    fontFamily: 'DMSans_500Medium',
    fontSize: 15,
    color: colors.bgDeep,
  },
});
