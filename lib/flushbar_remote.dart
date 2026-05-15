import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'flushbar.dart';

/// A notification payload parsed from a FlushKit SSE message.
class FlushbarRemoteEvent {
  /// The optional title shown in the [Flushbar].
  final String? title;

  /// The main notification message.
  final String message;

  /// The background colour of the [Flushbar].
  final Color backgroundColor;

  /// How long the [Flushbar] stays visible.
  final Duration duration;

  /// Whether the [Flushbar] appears at the [FlushbarPosition.TOP] or
  /// [FlushbarPosition.BOTTOM] of the screen.
  final FlushbarPosition position;

  /// Optional label for an action button, e.g. "View" or "Retry".
  final String? actionLabel;

  /// Deep link or URL opened when the action button is tapped.
  final String? actionUrl;

  /// A Material icon name (e.g. "warning") or an https:// image URL.
  final String? iconName;

  /// When true the notification stays until the user dismisses it manually.
  final bool persistent;

  const FlushbarRemoteEvent({
    this.title,
    required this.message,
    required this.backgroundColor,
    required this.duration,
    required this.position,
    this.actionLabel,
    this.actionUrl,
    this.iconName,
    this.persistent = false,
  });
}

/// Provides optional remote notification support for [Flushbar] via the
/// [FlushKit](https://api.flushkit.dev) service.
///
/// ## Quick start
///
/// ```dart
/// // In your root widget's initState, after MaterialApp is built:
/// WidgetsBinding.instance.addPostFrameCallback((_) {
///   FlushbarRemote.init(apiKey: 'YOUR_KEY', context: context);
/// });
///
/// // In your root widget's dispose():
/// FlushbarRemote.dispose();
/// ```
///
/// The class connects to the FlushKit SSE endpoint and renders each incoming
/// notification as a [Flushbar].  If the connection drops it reconnects
/// automatically with exponential back-off (2 s → 4 s → … → 30 s cap).
///
/// The connection is automatically paused when the app is backgrounded and
/// resumed when it returns to the foreground, preventing unnecessary battery
/// drain.
///
/// For advanced use cases you can subscribe to [events] to receive raw
/// [FlushbarRemoteEvent] objects alongside (or instead of) the default
/// [Flushbar] display.
class FlushbarRemote with WidgetsBindingObserver {
  FlushbarRemote._();

  // Singleton instance used as the WidgetsBindingObserver.
  static final FlushbarRemote _instance = FlushbarRemote._();

  static final StreamController<FlushbarRemoteEvent> _eventController =
      StreamController<FlushbarRemoteEvent>.broadcast();

  /// A broadcast [Stream] of every [FlushbarRemoteEvent] received from
  /// the FlushKit server.
  ///
  /// Subscribe here when you need to react to events beyond the default
  /// [Flushbar] display — for example, to persist a notification history or
  /// update application state.
  ///
  /// ```dart
  /// FlushbarRemote.events.listen((event) {
  ///   print('Received: ${event.message}');
  /// });
  /// ```
  static Stream<FlushbarRemoteEvent> get events => _eventController.stream;

  static BuildContext? _context;
  static String? _apiKey;
  static bool _disposed = true;
  static http.Client? _client;
  static Timer? _reconnectTimer;

  static SharedPreferences? _prefs;
  static int _lastSeen = 0;
  static List<String> _seenIds = [];

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Connects to `https://api.flushkit.dev/v1/listen` and starts displaying
  /// remote [Flushbar] notifications.
  ///
  /// Call this **once**, after the root [MaterialApp] has been mounted and a
  /// valid [BuildContext] is available.  The safest place is inside a
  /// `WidgetsBinding.instance.addPostFrameCallback` in `initState`:
  ///
  /// ```dart
  /// @override
  /// void initState() {
  ///   super.initState();
  ///   WidgetsBinding.instance.addPostFrameCallback((_) {
  ///     FlushbarRemote.init(apiKey: 'YOUR_KEY', context: context);
  ///   });
  /// }
  /// ```
  ///
  /// * [apiKey] — Your FlushKit API key.
  /// * [context] — A [BuildContext] that remains valid for the lifetime of the
  ///   app (the root widget's context is ideal).
  static Future<void> init({
    required String apiKey,
    required BuildContext context,
  }) async {
    _apiKey = apiKey;
    _context = context;
    _disposed = false;

    _prefs = await SharedPreferences.getInstance();
    _lastSeen = _prefs!.getInt('fk_last_seen') ?? 0;
    _seenIds = _prefs!.getStringList('fk_seen_ids') ?? [];

    WidgetsBinding.instance.addObserver(_instance);
    _connect();
  }

  /// Pauses or resumes the SSE connection in response to app lifecycle events.
  ///
  /// The connection is closed when the app is backgrounded
  /// ([AppLifecycleState.paused]) and re-established when it returns to the
  /// foreground ([AppLifecycleState.resumed]), preventing unnecessary battery
  /// drain.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _connect();
        break;
      case AppLifecycleState.paused:
        _disconnect();
        break;
      default:
        break;
    }
  }

  /// Tears down the SSE connection and cancels any pending reconnect timer.
  ///
  /// Call this in the `dispose()` method of the widget that owns the
  /// [BuildContext] passed to [init].
  ///
  /// ```dart
  /// @override
  /// void dispose() {
  ///   FlushbarRemote.dispose();
  ///   super.dispose();
  /// }
  /// ```
  static void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(_instance);
    _disconnect();
    _context = null;
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static void _connect({int retryDelay = 2}) {
    if (_disposed || _apiKey == null) return;
    if (_client != null) return; // already connected — guard against duplicates

    _client = http.Client();

    final uri = Uri.parse(
      'https://api.flushkit.dev/v1/listen?apiKey=${Uri.encodeComponent(_apiKey!)}&since=$_lastSeen',
    );

    final request = http.Request('GET', uri)
      ..headers['Accept'] = 'text/event-stream'
      ..headers['Cache-Control'] = 'no-cache';

    _client!
        .send(request)
        .then((response) => _consumeStream(response.stream))
        .catchError((Object _) {
          _client = null; // allow the next retry to proceed past the guard
          if (!_disposed) _scheduleReconnect(retryDelay);
        });
  }

  /// Closes the active connection and cancels any pending reconnect timer.
  ///
  /// Called automatically when the app is backgrounded, and also by [dispose].
  static void _disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _client?.close();
    _client = null; // null out so the guard in _connect() passes on next call
  }

  static Future<void> _consumeStream(http.ByteStream byteStream) async {
    try {
      await for (final line in byteStream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (_disposed) return;
        if (line.startsWith('data: ')) {
          _handleData(line.substring(6).trim());
        }
      }
    } catch (_) {
      // connection error — fall through to reconnect
    }
    // If _disconnect() was already called (app backgrounded or disposed),
    // _client is null — skip reconnecting. It will be triggered by
    // AppLifecycleState.resumed or a fresh init() call.
    if (_client == null || _disposed) return;
    _client = null; // null out so _connect() guard passes on the next retry
    _scheduleReconnect(2);
  }

  static void _handleData(String rawJson) {
    try {
      final map = jsonDecode(rawJson) as Map<String, dynamic>;

      final notificationId = map['notificationId'] as String?;
      if (notificationId != null && _seenIds.contains(notificationId)) return;

      final title = map['title'] as String?;
      final message = (map['message'] as String?) ?? '';
      final bg = _parseColor(map['backgroundColor'] as String? ?? '#303030');
      final secs = (map['durationSeconds'] as num?)?.toInt() ?? 3;
      final posStr = (map['position'] as String?)?.toUpperCase();
      final position =
          posStr == 'TOP' ? FlushbarPosition.TOP : FlushbarPosition.BOTTOM;
      final actionLabel = map['actionLabel'] as String?;
      final actionUrl = map['actionUrl'] as String?;
      final iconName = map['iconName'] as String?;
      final persistent = (map['persistent'] as bool?) ?? false;

      final event = FlushbarRemoteEvent(
        title: title,
        message: message,
        backgroundColor: bg,
        duration: Duration(seconds: secs),
        position: position,
        actionLabel: actionLabel,
        actionUrl: actionUrl,
        iconName: iconName,
        persistent: persistent,
      );

      _eventController.add(event);
      _showFlushbar(event);

      if (notificationId != null) {
        _seenIds.add(notificationId);
        if (_seenIds.length > 100) {
          _seenIds = _seenIds.sublist(_seenIds.length - 100);
        }
        _lastSeen = DateTime.now().millisecondsSinceEpoch;
        _prefs?.setStringList('fk_seen_ids', _seenIds);
        _prefs?.setInt('fk_last_seen', _lastSeen);
      }
    } catch (_) {
      // Malformed payload — skip silently so a bad message can't crash the app.
    }
  }

  static const Map<String, IconData> _iconMap = {
    'info': Icons.info_outline,
    'warning': Icons.warning_amber_outlined,
    'error': Icons.error_outline,
    'success': Icons.check_circle_outline,
    'check_circle': Icons.check_circle_outline,
    'star': Icons.star_outline,
    'notifications': Icons.notifications_outlined,
  };

  static void _showFlushbar(FlushbarRemoteEvent event) {
    final ctx = _context;
    if (ctx == null || _disposed) return;

    // Holds a reference so buttons can call dismiss() on the same instance.
    Flushbar? flushbar;

    // --- ICON ---
    Widget? iconWidget;
    bool iconPulse = false;
    final iconName = event.iconName;
    if (iconName != null) {
      if (iconName.startsWith('http')) {
        iconWidget = SizedBox(
          width: 40,
          height: 40,
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: iconName,
              fit: BoxFit.cover,
            ),
          ),
        );
        iconPulse = false;
      } else {
        final iconData = _iconMap[iconName] ?? Icons.notifications;
        iconWidget = Icon(iconData, color: Colors.white, size: 28);
        iconPulse = true;
      }
    }

    // --- DURATION & DISMISSIBILITY ---
    Duration? duration = event.duration;
    bool isDismissible = true;

    if (event.persistent) {
      duration = null;
      isDismissible = event.actionLabel != null;
    }

    // --- MAIN BUTTON ---
    Widget? mainButton;
    if (event.actionLabel != null) {
      mainButton = TextButton(
        onPressed: () async {
          final url = event.actionUrl;
          if (url != null) {
            if (url.startsWith('http')) {
              await launchUrl(Uri.parse(url));
            } else {
              final context = _context;
              if (context != null) {
                Navigator.pushNamed(context, url);
              }
            }
          }
          flushbar?.dismiss();
        },
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        child: Text(event.actionLabel!),
      );
    } else if (event.persistent) {
      mainButton = IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () => flushbar?.dismiss(),
      );
    }

    flushbar = Flushbar(
      title: event.title,
      message: event.message,
      backgroundColor: event.backgroundColor,
      duration: duration,
      isDismissible: isDismissible,
      flushbarPosition: event.position,
      icon: iconWidget,
      shouldIconPulse: iconPulse,
      mainButton: mainButton,
    );

    flushbar.show(ctx);
  }

  /// Parses a CSS hex colour string (`"#FF5733"` or `"FF5733"`) into a
  /// Flutter [Color].  Falls back to `Color(0xFF303030)` on parse error.
  static Color _parseColor(String hex) {
    final cleaned = hex.replaceAll('#', '').trim();
    final padded = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    final value = int.tryParse(padded, radix: 16);
    return value != null ? Color(value) : const Color(0xFF303030);
  }

  /// Schedules a reconnect after [delaySeconds] seconds and doubles the next
  /// retry delay (capped at 30 s) for exponential back-off.
  static void _scheduleReconnect(int delaySeconds) {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    final nextDelay = (delaySeconds * 2).clamp(2, 30);
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_disposed) _connect(retryDelay: nextDelay);
    });
  }
}
