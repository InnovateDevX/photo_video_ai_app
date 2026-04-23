class Result<T> {
  final T? data;
  final String? error;

  bool get isSuccess => error == null;

  Result.success(this.data) : error = null;
  Result.failure(this.error) : data = null;
}
