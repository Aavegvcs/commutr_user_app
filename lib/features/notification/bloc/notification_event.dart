part of 'notification_bloc.dart';

abstract class NotificationEvent {
  const NotificationEvent();
}

class FetchNotifications extends NotificationEvent {
  final String contactNumber;
  const FetchNotifications(this.contactNumber);
}
