part of 'notification_bloc.dart';

abstract class NotificationState {
  const NotificationState();
}

class NotificationInitial extends NotificationState {
  const NotificationInitial();
}

class NotificationLoading extends NotificationState {
  const NotificationLoading();
}

class NotificationLoaded extends NotificationState {
  final List<NotificationItem> items;
  const NotificationLoaded(this.items);
}

class NotificationError extends NotificationState {
  final String message;
  const NotificationError(this.message);
}
