import '../errors/failure.dart';

sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is ErrorResult<T>;

  T? get dataOrNull => this is Success<T> ? (this as Success<T>).data : null;
  Failure? get failureOrNull => this is ErrorResult<T> ? (this as ErrorResult<T>).failure : null;

  R fold<R>(R Function(T data) onSuccess, R Function(Failure failure) onFailure) {
    if (this is Success<T>) {
      return onSuccess((this as Success<T>).data);
    } else {
      return onFailure((this as ErrorResult<T>).failure);
    }
  }
}

final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

final class ErrorResult<T> extends Result<T> {
  final Failure failure;
  const ErrorResult(this.failure);
}
