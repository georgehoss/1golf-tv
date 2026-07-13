import 'package:bitmovin_player/bitmovin_player.dart';

/// Shared Bitmovin configuration for golf live/VOD playback. Extracted from
/// `bitmovin_player.dart` so [BitmovinPlayer] (widget-owned player) and
/// `LivePlaybackController` (shared, long-lived player for the home inline
/// preview) build byte-identical configs — the seamless inline→fullscreen
/// handoff relies on both sides driving the exact same `Player`/`Source`.

/// Bitmovin license key. The same key is licensed for the three apps (baseball
/// TV, golf mobile, golf TV) and for both SDKs: the native one used on Android
/// and the Web SDK the Tizen player loads in a WebView (`assets/index.html`).
const bitmovinLicenseKey = '3a21fd77-dd98-4146-8751-8d1858bfa033';

/// Bundle id the Bitmovin license is tied to. Also sent as `x-app-bundle` to
/// 1Golf's DRM backend and passed to the Web SDK's `optimizeForPlatform`.
const bitmovinAppId = 'tv.onegolf.tv';

/// Widevine/Fairplay license headers carrying the golf app bundle id, required
/// by 1Golf's DRM backend.
const DrmConfig golfDrmConfig = DrmConfig(
  fairplay: FairplayConfig(
    licenseRequestHeaders: {'x-app-bundle': bitmovinAppId},
  ),
  widevine: WidevineConfig(httpHeaders: {'x-app-bundle': bitmovinAppId}),
);

/// Player config used everywhere: golf license key, analytics key, UI disabled
/// (we render our own D-pad controls), cast/AirPlay off.
PlayerConfig buildGolfPlayerConfig() => const PlayerConfig(
  key: bitmovinLicenseKey,
  analyticsConfig: AnalyticsConfig(
    licenseKey: 'f2ae6442-705f-4531-ada7-b68e129a4eed',
  ),
  styleConfig: StyleConfig(isUiEnabled: false),
  remoteControlConfig: RemoteControlConfig(
    isCastEnabled: false,
    isAirPlayEnabled: false,
    sendManifestRequestsWithCredentials: true,
  ),
);

/// Builds a source config for [url]. Live streams are always HLS; VOD sniffs
/// `m3u8` to pick HLS vs. progressive (mirrors the original inline logic).
SourceConfig buildGolfSourceConfig({
  required String url,
  required String title,
  required bool isHLS,
}) {
  if (isHLS) {
    return SourceConfig(
      url: url,
      type: SourceType.hls,
      title: title,
      drmConfig: golfDrmConfig,
    );
  }
  return SourceConfig(
    url: url,
    drmConfig: golfDrmConfig,
    type: url.contains('m3u8') ? SourceType.hls : SourceType.progressive,
    title: '',
  );
}
