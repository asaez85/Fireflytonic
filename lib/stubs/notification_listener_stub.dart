enum NotificationState { post, remove }

class NotificationServicePlugin {
  static final NotificationServicePlugin instance = NotificationServicePlugin();
  Future<bool> isServicePermissionGranted() async => false;
  Future<bool> isServiceRunning() async => false;
  void executeNotificationListener(dynamic callback) {}
  Future<bool> requestServicePermission() async => false;
  Future<bool> requestPermissionsIfDenied() async => false;
  Future<bool> startService() async => false;
  Future<bool> initialize(dynamic callback) async => false;
}

class NotificationEvent {
  final String? packageName;
  final String? title;
  final String? message;
  final String? text;
  final String? postTime;
  final NotificationState state = NotificationState.post;
  NotificationEvent({
    this.packageName,
    this.title,
    this.message,
    this.text,
    this.postTime,
  });
}
