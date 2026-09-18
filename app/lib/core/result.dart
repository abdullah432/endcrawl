/// The result type every repository call returns, so callers handle failure
/// explicitly instead of catching exceptions across layer boundaries.
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.err(AppFailure failure) = Err<T>;

  bool get isOk => this is Ok<T>;

  /// The value, or null when this is a failure.
  T? get valueOrNull => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => null,
      };

  /// The failure, or null when this succeeded.
  AppFailure? get failureOrNull => switch (this) {
        Ok<T>() => null,
        Err<T>(:final failure) => failure,
      };
}

final class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
}

final class Err<T> extends Result<T> {
  final AppFailure failure;
  const Err(this.failure);
}

enum FailureKind {
  /// The requested document does not exist.
  notFound,

  /// Reading or writing the underlying store failed.
  storage,

  /// A document exists but could not be parsed into the domain model.
  serialization,

  /// The caller is not allowed to read or write this document.
  /// Unused by the local store; here for the Firestore implementation.
  permission,

  /// The backend could not be reached. Unused by the local store.
  network,

  unknown,
}

class AppFailure {
  final FailureKind kind;
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const AppFailure(this.kind, this.message, {this.cause, this.stackTrace});

  const AppFailure.notFound(String message) : this(FailureKind.notFound, message);

  @override
  String toString() => 'AppFailure(${kind.name}): $message${cause == null ? '' : ' — $cause'}';
}
