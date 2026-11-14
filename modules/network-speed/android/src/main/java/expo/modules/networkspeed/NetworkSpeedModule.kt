package expo.modules.networkspeed

import android.net.TrafficStats
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

class NetworkSpeedModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("NetworkSpeed")

    Function("getTrafficBytes") {
      val rx = TrafficStats.getTotalRxBytes()
      val tx = TrafficStats.getTotalTxBytes()
      val supported = rx != TrafficStats.UNSUPPORTED.toLong() && tx != TrafficStats.UNSUPPORTED.toLong()
      mapOf(
        "rxBytes" to if (supported) rx else 0L,
        "txBytes" to if (supported) tx else 0L,
        "supported" to supported
      )
    }

    Function("isSupported") {
      TrafficStats.getTotalRxBytes() != TrafficStats.UNSUPPORTED.toLong()
    }
  }
}
