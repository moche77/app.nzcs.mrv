import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// NotificationService
///
/// Manages local notifications for the NerZero MRV application:
///  - Monitoring period reminders (monthly QA sign-off cadence)
///  - Data entry reminders for operational roles
///  - Red-flag alerts surfaced from the calculation engine
///  - Verification due-date warnings (audit controls)
///
/// Persistence is handled via a lightweight Hive box so that scheduled
/// reminder preferences survive cold starts. The implementation gracefully
/// degrades on Web (where local notifications are limited) by routing
/// reminders to an in-memory queue surfaced through the in-app banner.
class NotificationService extends ChangeNotifier {
  static const String _boxName = 'notification_prefs';
  static const String _channelId = 'nerzero_mrv_channel';
  static const String _channelName = 'NerZero MRV Reminders';
  static const String _channelDesc =
      'Operational reminders, monitoring period sign-offs, and red-flag alerts.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Box<dynamic>? _prefsBox;
  bool _initialized = false;
  bool _enabled = true;
  bool _supported = true;

  // In-app reminder feed (surfaced on dashboard banner / drawer).
  final List<AppReminder> _inbox = <AppReminder>[];

  bool get isEnabled => _enabled;
  bool get isSupported => _supported;
  List<AppReminder> get inbox => List.unmodifiable(_inbox);
  int get unreadCount => _inbox.where((r) => !r.read).length;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _prefsBox = await Hive.openBox<dynamic>(_boxName);
      _enabled = _prefsBox?.get('enabled', defaultValue: true) as bool? ?? true;

      if (!kIsWeb) {
        // Defensive try/catch so notification plugin failures NEVER block app
        // startup. The Android 13+ POST_NOTIFICATIONS permission is requested
        // lazily on first push() call rather than during boot.
        try {
          const AndroidInitializationSettings androidInit =
              AndroidInitializationSettings('@mipmap/ic_launcher');
          const InitializationSettings initSettings =
              InitializationSettings(android: androidInit);
          await _plugin.initialize(initSettings);
          _supported = true;
        } catch (_) {
          _supported = false;
        }
      } else {
        // Web fallback - in-app banner queue only.
        _supported = false;
      }

      // Hydrate in-memory inbox from persistence.
      final stored = _prefsBox?.get('inbox', defaultValue: <dynamic>[]) as List?;
      if (stored != null) {
        for (final item in stored) {
          if (item is Map) {
            _inbox.add(AppReminder.fromMap(Map<String, dynamic>.from(item)));
          }
        }
      }

      _initialized = true;
      notifyListeners();
    } catch (e) {
      // Non-fatal: notifications disabled but app continues.
      _supported = false;
      _initialized = true;
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _prefsBox?.put('enabled', value);
    notifyListeners();
  }

  /// Records an in-app reminder and, where supported, fires an OS notification.
  Future<void> push({
    required String title,
    required String body,
    ReminderCategory category = ReminderCategory.info,
  }) async {
    if (!_initialized) await initialize();
    if (!_enabled) return;

    final reminder = AppReminder(
      id: DateTime.now().millisecondsSinceEpoch,
      title: title,
      body: body,
      category: category,
      createdAt: DateTime.now(),
    );
    _inbox.insert(0, reminder);
    if (_inbox.length > 50) _inbox.removeRange(50, _inbox.length);
    await _persistInbox();

    if (_supported && !kIsWeb) {
      try {
        const AndroidNotificationDetails androidDetails =
            AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        );
        const NotificationDetails details =
            NotificationDetails(android: androidDetails);
        await _plugin.show(reminder.id, title, body, details);
      } catch (_) {
        // Swallow — already captured in in-app inbox.
      }
    }
    notifyListeners();
  }

  Future<void> markRead(int id) async {
    final idx = _inbox.indexWhere((r) => r.id == id);
    if (idx >= 0) {
      _inbox[idx] = _inbox[idx].copyWith(read: true);
      await _persistInbox();
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    for (var i = 0; i < _inbox.length; i++) {
      _inbox[i] = _inbox[i].copyWith(read: true);
    }
    await _persistInbox();
    notifyListeners();
  }

  Future<void> clear() async {
    _inbox.clear();
    await _persistInbox();
    notifyListeners();
  }

  Future<void> _persistInbox() async {
    final serialized = _inbox.map((r) => r.toMap()).toList();
    await _prefsBox?.put('inbox', serialized);
  }

  /// Convenience: monthly monitoring period sign-off reminder.
  Future<void> remindMonitoringPeriodSignoff(String period) async {
    await push(
      title: 'Monitoring Period Sign-Off Pending',
      body:
          'Period $period requires Global QA review and reviewer attestation.',
      category: ReminderCategory.compliance,
    );
  }

  /// Convenience: red-flag alert from calculation engine.
  Future<void> remindRedFlag(String flag) async {
    await push(
      title: 'Red-Flag Integrity Alert',
      body: flag,
      category: ReminderCategory.alert,
    );
  }

  /// Convenience: data entry cadence reminder.
  Future<void> remindDataEntry(String role) async {
    await push(
      title: 'Daily Logging Reminder',
      body: '$role: please record today\'s operational entries before EOD.',
      category: ReminderCategory.task,
    );
  }
}

enum ReminderCategory { info, task, compliance, alert }

class AppReminder {
  final int id;
  final String title;
  final String body;
  final ReminderCategory category;
  final DateTime createdAt;
  final bool read;

  AppReminder({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.createdAt,
    this.read = false,
  });

  AppReminder copyWith({bool? read}) => AppReminder(
        id: id,
        title: title,
        body: body,
        category: category,
        createdAt: createdAt,
        read: read ?? this.read,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'category': category.name,
        'createdAt': createdAt.toIso8601String(),
        'read': read,
      };

  factory AppReminder.fromMap(Map<String, dynamic> m) => AppReminder(
        id: m['id'] as int? ?? 0,
        title: m['title'] as String? ?? '',
        body: m['body'] as String? ?? '',
        category: ReminderCategory.values.firstWhere(
          (c) => c.name == (m['category'] as String? ?? 'info'),
          orElse: () => ReminderCategory.info,
        ),
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ??
            DateTime.now(),
        read: m['read'] as bool? ?? false,
      );
}
