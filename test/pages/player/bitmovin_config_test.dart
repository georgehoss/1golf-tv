import 'package:bitmovin_player/bitmovin_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_golf_android_tv/src/pages/player/bitmovin_config.dart';

void main() {
  group('buildGolfSourceConfig', () {
    test('live streams are always HLS and carry the title + DRM', () {
      final source = buildGolfSourceConfig(
        url: 'https://example.com/live/index.m3u8',
        title: 'Canal 1',
        isHLS: true,
      );
      expect(source.type, SourceType.hls);
      expect(source.title, 'Canal 1');
      expect(source.drmConfig, golfDrmConfig);
    });

    test('VOD with an m3u8 url is treated as HLS', () {
      final source = buildGolfSourceConfig(
        url: 'https://example.com/vod/master.m3u8',
        title: 'Show',
        isHLS: false,
      );
      expect(source.type, SourceType.hls);
    });

    test('VOD without m3u8 is progressive', () {
      final source = buildGolfSourceConfig(
        url: 'https://example.com/vod/clip.mp4',
        title: 'Show',
        isHLS: false,
      );
      expect(source.type, SourceType.progressive);
    });
  });
}
