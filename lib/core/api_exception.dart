class ApiException implements Exception {
  final String message;
  final int? status;
  final dynamic data;

  ApiException(this.message, {this.status, this.data});

  @override
  String toString() => message;
}
