import { StyleSheet, Text, View } from 'react-native';

import { colors } from '../theme/colors';
import { PulseDot } from './PulseDot';

type Props = {
  available: boolean;
  active: boolean;
  error: string | null;
};

export function LiveIslandBanner({ available, active, error }: Props) {
  if (!available) {
    return (
      <View style={styles.wrap}>
        <Text style={styles.body}>灵动岛仅支持 iPhone（iOS 16.1+）</Text>
      </View>
    );
  }

  return (
    <View style={[styles.wrap, active ? styles.on : styles.off]}>
      <View style={styles.row}>
        <PulseDot color={active ? colors.teal : colors.amber} active={active} />
        <Text style={styles.title}>
          {active ? '灵动岛网速已开启' : '灵动岛未开启'}
        </Text>
      </View>
      <Text style={styles.body}>
        {active
          ? '切到别的 App 时，刘海 / 灵动岛会显示实时上下行。长按可展开详情。'
          : error
            ? error
            : '开始监控后，网速会同步到灵动岛与锁屏。需使用 Development Build。'}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    marginTop: 16,
    padding: 14,
    borderRadius: 14,
    borderWidth: 1,
  },
  on: {
    backgroundColor: colors.tealDim,
    borderColor: 'rgba(30, 202, 211, 0.35)',
  },
  off: {
    backgroundColor: 'rgba(245, 200, 76, 0.08)',
    borderColor: 'rgba(245, 200, 76, 0.28)',
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 6,
  },
  title: {
    fontFamily: 'DMSans_500Medium',
    fontSize: 14,
    color: colors.text,
  },
  body: {
    fontFamily: 'DMSans_400Regular',
    fontSize: 12,
    lineHeight: 18,
    color: colors.textMuted,
  },
});
