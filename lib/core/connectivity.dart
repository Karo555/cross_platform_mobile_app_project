import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device has a network connection: true when online, false when
/// offline. Emits the current state on listen, then again on every change.
///
/// This only knows whether Wi-Fi, mobile data or another network is switched
/// on, not whether Firebase can actually be reached (for example on hotel
/// Wi-Fi behind a login page). Writes therefore still have to wait for the
/// backend's confirmation (#33).
///
/// Tests override this provider, because the plugin needs a real device.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  yield isOnlineFrom(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(isOnlineFrom);
});

/// The plugin reports `[ConnectivityResult.none]` when there is no network,
/// and only then.
bool isOnlineFrom(List<ConnectivityResult> results) =>
    results.any((result) => result != ConnectivityResult.none);
