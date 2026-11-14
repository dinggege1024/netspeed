import { useEffect, useRef, useState } from 'react';
import { Animated, Platform, ScrollView, StyleSheet, Text, View } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { SafeAreaView } from 'react-native-safe-area-context';

import { ControlBar } from '../components/ControlBar';
import { LiveIslandBanner } from '../components/LiveIslandBanner';
import { NetworkMetaCard } from '../components/NetworkMeta';
import { SpeedChart } from '../components/SpeedChart';
import { SpeedHero } from '../components/SpeedHero';
import { SpeedTestPanel } from '../components/SpeedTestPanel';
import { useLiveSpeedActivity } from '../hooks/useLiveSpeedActivity';
import { useNetworkInfo } from '../hooks/useNetworkInfo';
import { useNetworkSpeed } from '../hooks/useNetworkSpeed';
import { colors } from '../theme/colors';
import type { SpeedUnit } from '../utils/formatSpeed';

export default function HomeScreen() {
  const [monitoring, setMonitoring] = useState(true);
  const [unit, setUnit] = useState<SpeedUnit>('auto-bytes');
  const speed = useNetworkSpeed(monitoring);
  const meta = useNetworkInfo();
  const live = useLiveSpeedActivity({
    enabled: monitoring,
    downSpeed: speed.downSpeed,
    upSpeed: speed.upSpeed,
    networkLabel: meta.typeLabel,
    unit,
    trafficSupported: speed.supported,
  });
  const enter = useRef(new Animated.Value(0)).current;
  const glow = useRef(new Animated.Value(0.7)).current;

  useEffect(() => {
    Animated.timing(enter, {
      toValue: 1,
      duration: 650,
      useNativeDriver: true,
    }).start();

    const breathe = Animated.loop(
      Animated.sequence([
        Animated.timing(glow, { toValue: 1, duration: 2200, useNativeDriver: true }),
        Animated.timing(glow, { toValue: 0.55, duration: 2200, useNativeDriver: true }),
      ])
    );
    breathe.start();
    return () => breathe.stop();
  }, [enter, glow]);

  return (
    <View style={styles.root}>
      <LinearGradient
        colors={[colors.bgMid, colors.bgDeep, '#021014']}
        locations={[0, 0.45, 1]}
        style={StyleSheet.absoluteFill}
      />
      <Animated.View style={[styles.glow, { opacity: glow }]}>
        <LinearGradient
          colors={['rgba(30, 202, 211, 0.22)', 'transparent']}
          start={{ x: 0.15, y: 0 }}
          end={{ x: 0.9, y: 0.55 }}
          style={StyleSheet.absoluteFill}
        />
      </Animated.View>

      <SafeAreaView style={styles.safe} edges={['top', 'bottom']}>
        <Animated.View
          style={{
            flex: 1,
            opacity: enter,
            transform: [
              {
                translateY: enter.interpolate({
                  inputRange: [0, 1],
                  outputRange: [18, 0],
                }),
              },
            ],
          }}
        >
        <ScrollView
          contentContainerStyle={styles.content}
          showsVerticalScrollIndicator={false}
        >
          <SpeedHero
            downSpeed={speed.downSpeed}
            upSpeed={speed.upSpeed}
            unit={unit}
            monitoring={monitoring}
          />

          <LiveIslandBanner
            available={live.available}
            active={live.active}
            error={live.error}
          />

          {!speed.supported && speed.ready ? (
            <View style={styles.notice}>
              <Text style={styles.noticeTitle}>需要 Development Build</Text>
              <Text style={styles.noticeBody}>
                {Platform.OS === 'ios'
                  ? '实时网速与灵动岛都依赖开发构建。请运行 npx expo run:ios；当前仍可使用下方一键测速。'
                  : '实时流量监控需要开发构建。请运行 npx expo run:android，或先使用一键测速。'}
              </Text>
            </View>
          ) : null}

          <SpeedChart history={speed.history} />

          <NetworkMetaCard
            meta={meta}
            totalDown={speed.totalDown}
            totalUp={speed.totalUp}
            supported={speed.supported}
          />

          <ControlBar
            monitoring={monitoring}
            unit={unit}
            onToggleMonitoring={() => setMonitoring((v) => !v)}
            onToggleUnit={() => setUnit((u) => (u === 'Mbps' ? 'auto-bytes' : 'Mbps'))}
          />

          <SpeedTestPanel />

          <Text style={styles.footer}>网速 · 灵动岛 + 本机仪表盘</Text>
        </ScrollView>
        </Animated.View>
      </SafeAreaView>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: colors.bgDeep,
  },
  glow: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: 320,
  },
  safe: {
    flex: 1,
  },
  content: {
    paddingHorizontal: 24,
    paddingBottom: 36,
  },
  notice: {
    marginTop: 16,
    padding: 14,
    borderRadius: 14,
    backgroundColor: 'rgba(245, 200, 76, 0.1)',
    borderWidth: 1,
    borderColor: 'rgba(245, 200, 76, 0.28)',
  },
  noticeTitle: {
    fontFamily: 'DMSans_500Medium',
    fontSize: 13,
    color: colors.amber,
    marginBottom: 4,
  },
  noticeBody: {
    fontFamily: 'DMSans_400Regular',
    fontSize: 12,
    lineHeight: 18,
    color: colors.textMuted,
  },
  footer: {
    marginTop: 28,
    textAlign: 'center',
    fontFamily: 'DMSans_400Regular',
    fontSize: 12,
    color: colors.textFaint,
  },
});
