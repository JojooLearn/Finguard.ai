abstract class Failure {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  String toString() => 'Failure(message: $message, code: $code)';
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.code});
}

class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code});
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Koneksi internet terputus', String? code]) : super(code: code);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code});
}
