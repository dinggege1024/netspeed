import { StyleSheet, Text, View } from 'react-native';

import { colors } from '../theme/colors';
import { splitSpeed, type SpeedUnit } from '../utils/formatSpeed';

type Props = {
  downSpeed: number;
  upSpeed: number;
  unit: SpeedUnit;
  monitoring: boolean;
};

export function SpeedHero({ downSpeed, upSpeed, unit, monitoring }: Props) {
  const down = splitSpeed(downSpeed, unit);
  const up = splitSpeed(upSpeed, unit);

  return (
    <View style={styles.wrap}>
      <Text style={styles.brand}>网速</Text>
      <Text style={styles.tagline}>
        {monitoring ? '实时上下行 · 同步灵动岛' : '监控已暂停 · 灵动岛已结束'}
      </Text>

      <View style={styles.row}>
        <View style={styles.col}>
          <Text style={styles.dirLabel}>下行 ↓</Text>
          <Text style={[styles.value, { color: colors.teal }]}>{down.value}</Text>
          <Text style={styles.unit}>{down.unitLabel}</Text>
        </View>
        <View style={styles.divider} />
        <View style={styles.col}>
          <Text style={styles.dirLabel}>上行 ↑</Text>
          <Text style={[styles.value, { color: colors.mint }]}>{up.value}</Text>
          <Text style={styles.unit}>{up.unitLabel}</Text>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    paddingTop: 12,
    paddingBottom: 8,
  },
  brand: {
    fontFamily: 'SpaceGrotesk_700Bold',
    fontSize: 44,
    letterSpacing: -1.2,
    color: colors.text,
  },
  tagline: {
    marginTop: 4,
    fontFamily: 'DMSans_400Regular',
    fontSize: 14,
    color: colors.textMuted,
  },
  row: {
    marginTop: 28,
    flexDirection: 'row',
    alignItems: 'stretch',
  },
  col: {
    flex: 1,
  },
  divider: {
    width: 1,
    marginHorizontal: 16,
    backgroundColor: colors.line,
  },
  dirLabel: {
    fontFamily: 'DMSans_500Medium',
    fontSize: 13,
    color: colors.textMuted,
    marginBottom: 6,
  },
  value: {
    fontFamily: 'SpaceGrotesk_700Bold',
    fontSize: 48,
    letterSpacing: -1.5,
    lineHeight: 54,
  },
  unit: {
    marginTop: 2,
    fontFamily: 'DMSans_400Regular',
    fontSize: 15,
    color: colors.textFaint,
  },
});
