import { StyleSheet, Text, View } from 'react-native';

import type { NetworkMeta as Meta } from '../hooks/useNetworkInfo';
import { colors } from '../theme/colors';
import { formatDataSize } from '../utils/formatSpeed';
import { PulseDot } from './PulseDot';

type Props = {
  meta: Meta;
  totalDown: number;
  totalUp: number;
  supported: boolean;
};

export function NetworkMetaCard({ meta, totalDown, totalUp, supported }: Props) {
  return (
    <View style={styles.wrap}>
      <View style={styles.row}>
        <View style={[styles.pill, meta.connected ? styles.pillOn : styles.pillOff]}>
          <PulseDot color={meta.connected ? colors.mint : colors.coral} active={meta.connected} />
          <Text style={styles.pillText}>{meta.typeLabel}</Text>
        </View>
        <Text style={styles.detail} numberOfLines={1}>
          {meta.detail}
        </Text>
      </View>

      <View style={styles.stats}>
        <View style={styles.stat}>
          <Text style={styles.statLabel}>累计下行</Text>
          <Text style={styles.statValue}>{supported ? formatDataSize(totalDown) : '—'}</Text>
        </View>
        <View style={styles.stat}>
          <Text style={styles.statLabel}>累计上行</Text>
          <Text style={styles.statValue}>{supported ? formatDataSize(totalUp) : '—'}</Text>
        </View>
      </View>
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
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  pill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 999,
  },
  pillOn: {
    backgroundColor: 'rgba(94, 242, 168, 0.12)',
  },
  pillOff: {
    backgroundColor: 'rgba(255, 122, 89, 0.14)',
  },
  pillText: {
    fontFamily: 'DMSans_500Medium',
    fontSize: 13,
    color: colors.text,
  },
  detail: {
    flex: 1,
    fontFamily: 'DMSans_400Regular',
    fontSize: 13,
    color: colors.textMuted,
  },
  stats: {
    marginTop: 14,
    flexDirection: 'row',
    gap: 20,
  },
  stat: {
    flex: 1,
  },
  statLabel: {
    fontFamily: 'DMSans_400Regular',
    fontSize: 12,
    color: colors.textFaint,
    marginBottom: 4,
  },
  statValue: {
    fontFamily: 'SpaceGrotesk_500Medium',
    fontSize: 18,
    color: colors.text,
  },
});
