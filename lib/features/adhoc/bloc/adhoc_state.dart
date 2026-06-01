import 'package:commutr_main/features/adhoc/data/model/adhoc_list_response.dart';
import 'package:equatable/equatable.dart';

abstract class AdhocState extends Equatable {
  const AdhocState();

  @override
  List<Object?> get props => [];
}

class AdhocInitial extends AdhocState {
  const AdhocInitial();
}

class AdhocSubmitting extends AdhocState {
  const AdhocSubmitting();
}

class AdhocSubmitSuccess extends AdhocState {
  final String message;

  const AdhocSubmitSuccess([this.message = 'Adhoc request submitted successfully']);

  @override
  List<Object?> get props => [message];
}

class AdhocSubmitError extends AdhocState {
  final String message;

  const AdhocSubmitError(this.message);

  @override
  List<Object?> get props => [message];
}

class AdhocUnauthorized extends AdhocState {
  final String message;

  const AdhocUnauthorized([this.message = 'Your session has expired. Please log in again.']);

  @override
  List<Object?> get props => [message];
}

class AdhocListLoading extends AdhocState {
  const AdhocListLoading();
}

class AdhocListLoaded extends AdhocState {
  final List<AdhocRequestItem> items;

  const AdhocListLoaded(this.items);

  @override
  List<Object?> get props => [items];
}

class AdhocListError extends AdhocState {
  final String message;

  const AdhocListError(this.message);

  @override
  List<Object?> get props => [message];
}

class AdhocCancelling extends AdhocState {
  final int reqId;

  const AdhocCancelling(this.reqId);

  @override
  List<Object?> get props => [reqId];
}

class AdhocCancelSuccess extends AdhocState {
  const AdhocCancelSuccess();
}

class AdhocCancelError extends AdhocState {
  final String message;

  const AdhocCancelError(this.message);

  @override
  List<Object?> get props => [message];
}
