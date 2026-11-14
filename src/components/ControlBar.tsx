import { Pressable, StyleSheet, Text, View } from 'react-native';

import { colors } from '../theme/colors';
import type { SpeedUnit } from '../utils/formatSpeed';

type Props = {
  monitoring: boolean;
  unit: SpeedUnit;
  onToggleMonitoring: () => void;
  onToggleUnit: () => void;
};

export function ControlBar({ monitoring, unit, onToggleMonitoring, onToggleUnit }: Props) {
  return (
    <View style={styles.wrap}>
      <Pressable
        onPress={onToggleMonitoring}
        style={({ pressed }) => [styles.btn, monitoring ? styles.btnGhost : styles.btnSolid, pressed && styles.pressed]}
      >
        <Text style={[styles.btnText, monitoring ? styles.btnTextGhost : styles.btnTextSolid]}>
          {monitoring ? '暂停监控' : '开始监控'}
        </Text>
      </Pressable>
      <Pressable
        onPress={onToggleUnit}
        style={({ pressed }) => [styles.btn, styles.btnGhost, pressed && styles.pressed]}
      >
        <Text style={[styles.btnText, styles.btnTextGhost]}>
          {unit === 'Mbps' ? '改用 KB/s' : '改用 Mbps'}
        </Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    marginTop: 18,
    flexDirection: 'row',
    gap: 10,
  },
  btn: {
    flex: 1,
    height: 44,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  btnSolid: {
    backgroundColor: colors.teal,
  },
  btnGhost: {
    backgroundColor: 'transparent',
    borderWidth: 1,
    borderColor: colors.line,
  },
  pressed: {
    opacity: 0.85,
  },
  btnText: {
    fontFamily: 'DMSans_500Medium',
    fontSize: 14,
  },
  btnTextSolid: {
    color: colors.bgDeep,
  },
  btnTextGhost: {
    color: colors.text,
  },
});
