import 'enum/notification_type.dart';

class NotificationMessage {
  final NotificationType type;
  final String? url;
  final String? id;

  NotificationMessage({
    required this.type,
    required this.url,
    required this.id,
  });
}