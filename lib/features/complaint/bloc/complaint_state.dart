import 'package:equatable/equatable.dart';

import '../data/model/complaint_response.dart';

class ComplaintLookupLoading extends ComplaintState {
  const ComplaintLookupLoading();
}

class ComplaintLookupLoaded extends ComplaintState {
  final List<ComplaintLookupItem> items;

  const ComplaintLookupLoaded(this.items);

  @override
  List<Object?> get props => [items];
}

class ComplaintLookupError extends ComplaintState {
  final String message;

  const ComplaintLookupError(this.message);

  @override
  List<Object?> get props => [message];
}

abstract class ComplaintState extends Equatable {
  const ComplaintState();

  @override
  List<Object?> get props => [];
}

class ComplaintInitial extends ComplaintState {
  const ComplaintInitial();
}

class ComplaintLoading extends ComplaintState {
  const ComplaintLoading();
}

class ComplaintLoaded extends ComplaintState {
  final List<ComplaintItem> items;

  const ComplaintLoaded(this.items);

  @override
  List<Object?> get props => [items];
}

class ComplaintError extends ComplaintState {
  final String message;

  const ComplaintError(this.message);

  @override
  List<Object?> get props => [message];
}

class ComplaintUnauthorized extends ComplaintState {
  final String message;

  const ComplaintUnauthorized([
    this.message = 'Your session has expired. Please log in again.',
  ]);

  @override
  List<Object?> get props => [message];
}

class ComplaintDetailLoading extends ComplaintState {
  const ComplaintDetailLoading();
}

class ComplaintDetailLoaded extends ComplaintState {
  final ComplaintDetailItem detail;
  const ComplaintDetailLoaded(this.detail);

  @override
  List<Object?> get props => [detail];
}

class ComplaintDetailError extends ComplaintState {
  final String message;
  const ComplaintDetailError(this.message);

  @override
  List<Object?> get props => [message];
}

class ComplaintListLoading extends ComplaintState {
  const ComplaintListLoading();
}

class ComplaintListLoaded extends ComplaintState {
  final List<ComplaintListItem> items;
  const ComplaintListLoaded(this.items);

  @override
  List<Object?> get props => [items];
}

class ComplaintListError extends ComplaintState {
  final String message;
  const ComplaintListError(this.message);

  @override
  List<Object?> get props => [message];
}

class ComplaintSubmitting extends ComplaintState {
  const ComplaintSubmitting();
}

class ComplaintSubmitSuccess extends ComplaintState {
  const ComplaintSubmitSuccess();
}

class ComplaintSubmitError extends ComplaintState {
  final String message;

  const ComplaintSubmitError(this.message);

  @override
  List<Object?> get props => [message];
}
