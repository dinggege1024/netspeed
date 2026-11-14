import { useMemo } from 'react';
import { StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import Svg, { Defs, LinearGradient, Path, Stop } from 'react-native-svg';

import type { SpeedSample } from '../hooks/useNetworkSpeed';
import { colors } from '../theme/colors';
import { formatBytesPerSec } from '../utils/formatSpeed';

type Props = {
  history: SpeedSample[];
};

const HEIGHT = 120;
const PAD = 4;

function buildPath(values: number[], width: number, max: number): string {
  if (values.length === 0) return '';
  const step = values.length > 1 ? width / (values.length - 1) : width;
  return values
    .map((v, i) => {
      const x = i * step;
      const y = HEIGHT - PAD - (Math.min(v, max) / max) * (HEIGHT - PAD * 2);
      return `${i === 0 ? 'M' : 'L'}${x.toFixed(1)},${y.toFixed(1)}`;
    })
    .join(' ');
}

export function SpeedChart({ history }: Props) {
  const { width: screenWidth } = useWindowDimensions();
  const width = Math.max(screenWidth - 48, 280);

  const { downPath, upPath, maxLabel } = useMemo(() => {
    const downs = history.map((h) => h.down);
    const ups = history.map((h) => h.up);
    const peak = Math.max(1, ...downs, ...ups);
    const max = peak * 1.15;
    return {
      downPath: buildPath(downs, width, max),
      upPath: buildPath(ups, width, max),
      maxLabel: peak,
    };
  }, [history, width]);

  return (
    <View style={styles.wrap}>
      <View style={styles.header}>
        <Text style={styles.title}>近 60 秒</Text>
        <Text style={styles.hint}>峰值 {formatBytesPerSec(maxLabel, 'auto-bytes')}</Text>
      </View>
      <View style={styles.chartBox}>
        <Svg width={width} height={HEIGHT}>
          <Defs>
            <LinearGradient id="downGrad" x1="0" y1="0" x2="0" y2="1">
              <Stop offset="0" stopColor={colors.teal} stopOpacity="0.9" />
              <Stop offset="1" stopColor={colors.teal} stopOpacity="0.2" />
            </LinearGradient>
          </Defs>
          {downPath ? (
            <Path d={downPath} stroke="url(#downGrad)" strokeWidth={2.5} fill="none" strokeLinecap="round" />
          ) : null}
          {upPath ? (
            <Path d={upPath} stroke={colors.mint} strokeWidth={2} fill="none" strokeLinecap="round" opacity={0.85} />
          ) : null}
        </Svg>
        {history.length < 2 ? (
          <Text style={styles.empty}>采样中…打开网页或刷视频即可看到曲线</Text>
        ) : null}
      </View>
      <View style={styles.legend}>
        <View style={styles.legendItem}>
          <View style={[styles.dot, { backgroundColor: colors.teal }]} />
          <Text style={styles.legendText}>下行</Text>
        </View>
        <View style={styles.legendItem}>
          <View style={[styles.dot, { backgroundColor: colors.mint }]} />
          <Text style={styles.legendText}>上行</Text>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    marginTop: 20,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'baseline',
    marginBottom: 10,
  },
  title: {
    fontFamily: 'DMSans_500Medium',
    fontSize: 14,
    color: colors.text,
  },
  hint: {
    fontFamily: 'DMSans_400Regular',
    fontSize: 12,
    color: colors.textFaint,
  },
  chartBox: {
    height: HEIGHT,
    borderRadius: 16,
    backgroundColor: colors.card,
    borderWidth: 1,
    borderColor: colors.line,
    overflow: 'hidden',
    justifyContent: 'center',
    alignItems: 'center',
  },
  empty: {
    position: 'absolute',
    fontFamily: 'DMSans_400Regular',
    fontSize: 12,
    color: colors.textFaint,
    paddingHorizontal: 16,
    textAlign: 'center',
  },
  legend: {
    marginTop: 10,
    flexDirection: 'row',
    gap: 16,
  },
  legendItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  legendText: {
    fontFamily: 'DMSans_400Regular',
    fontSize: 12,
    color: colors.textMuted,
  },
});
