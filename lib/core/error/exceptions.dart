class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
}

class BadRequestException implements Exception {
  final String message;
  BadRequestException(this.message);
}

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);
}

class NotFoundException implements Exception {
  final String message;
  NotFoundException(this.message);
}

class ConflictException implements Exception {
  final String message;
  ConflictException(this.message);
}

class ServerException implements Exception {
  final String title;
  ServerException(this.title);
}
