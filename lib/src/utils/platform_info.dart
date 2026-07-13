import 'dart:io';

/// Whether the app is running on Samsung Tizen.
///
/// Dart has no `Platform.isTizen`: flutter-tizen runs on a Linux-based OS and
/// reports itself as Linux. This app only ever ships Android TV and Tizen
/// targets, so Linux here means Tizen. (Host-run unit tests report macOS, so
/// they take the non-Tizen path.)
bool get isTizen => Platform.isLinux;
