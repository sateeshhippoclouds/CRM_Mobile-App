class NotificationService {
  static final NotificationService _singleton = NotificationService._internal();
  factory NotificationService() => _singleton;
  NotificationService._internal();

  Future<String> getDeviceToken() async => '';
}
