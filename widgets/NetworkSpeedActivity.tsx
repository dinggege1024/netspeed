import { HStack, Image, Text, VStack } from '@expo/ui/swift-ui';
import { font, foregroundStyle, padding } from '@expo/ui/swift-ui/modifiers';
import { createLiveActivity, type LiveActivityEnvironment } from 'expo-widgets';

export type NetworkSpeedActivityProps = {
  /** e.g. "1.2 MB/s" */
  downLabel: string;
  /** e.g. "320 KB/s" */
  upLabel: string;
  /** compact island short text, e.g. "1.2M" */
  downShort: string;
  /** compact island short text, e.g. "320K" */
  upShort: string;
  /** e.g. "Wi‑Fi" */
  networkLabel: string;
};

const NetworkSpeedActivityLayout = (
  props: NetworkSpeedActivityProps,
  environment: LiveActivityEnvironment
) => {
  'widget';

  const accent = environment.isLuminanceReduced ? '#FFFFFF' : '#1ECAD3';
  const mint = environment.isLuminanceReduced ? '#FFFFFF' : '#5EF2A8';
  const muted = environment.isLuminanceReduced ? '#DDDDDD' : '#A8D4D8';
  const stale = environment.isStale === true;

  const downText = stale ? '—' : props.downLabel;
  const upText = stale ? '—' : props.upLabel;
  const downShort = stale ? '—' : props.downShort;
  const upShort = stale ? '—' : props.upShort;

  return {
    banner: (
      <VStack modifiers={[padding({ all: 14 })]}>
        <Text modifiers={[font({ size: 13, weight: 'medium' }), foregroundStyle(muted)]}>
          网速 · {props.networkLabel}
        </Text>
        <HStack>
          <Text modifiers={[font({ size: 22, weight: 'bold' }), foregroundStyle(accent)]}>
            ↓ {downText}
          </Text>
          <Text modifiers={[font({ size: 22, weight: 'bold' }), foregroundStyle(mint)]}>
            ↑ {upText}
          </Text>
        </HStack>
      </VStack>
    ),

    compactLeading: (
      <Text modifiers={[font({ size: 14, weight: 'semibold' }), foregroundStyle(accent)]}>
        ↓{downShort}
      </Text>
    ),
    compactTrailing: (
      <Text modifiers={[font({ size: 14, weight: 'semibold' }), foregroundStyle(mint)]}>
        ↑{upShort}
      </Text>
    ),
    minimal: <Image systemName="arrow.up.arrow.down" color={accent} />,

    expandedLeading: (
      <VStack modifiers={[padding({ all: 8 })]}>
        <Image systemName="arrow.down" color={accent} />
        <Text modifiers={[font({ size: 11 }), foregroundStyle(muted)]}>下行</Text>
      </VStack>
    ),
    expandedTrailing: (
      <VStack modifiers={[padding({ all: 8 })]}>
        <Image systemName="arrow.up" color={mint} />
        <Text modifiers={[font({ size: 11 }), foregroundStyle(muted)]}>上行</Text>
      </VStack>
    ),
    expandedCenter: (
      <VStack>
        <Text modifiers={[font({ size: 16, weight: 'bold' }), foregroundStyle(accent)]}>
          {downText}
        </Text>
        <Text modifiers={[font({ size: 16, weight: 'bold' }), foregroundStyle(mint)]}>
          {upText}
        </Text>
      </VStack>
    ),
    expandedBottom: (
      <HStack modifiers={[padding({ all: 10 })]}>
        <Text modifiers={[font({ size: 13 }), foregroundStyle(muted)]}>
          网速监控中 · {props.networkLabel}
        </Text>
      </HStack>
    ),
  };
};

export default createLiveActivity('NetworkSpeedActivity', NetworkSpeedActivityLayout);
