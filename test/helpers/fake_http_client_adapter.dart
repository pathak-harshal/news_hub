import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Produces the adapter's result for one request.
///
/// Return a [ResponseBody] to simulate a server reply, or complete with an
/// error to simulate a transport failure.
typedef FakeResponder = Future<ResponseBody> Function(RequestOptions options);

/// A scripted [HttpClientAdapter] for tests: no real network is touched.
///
/// Requests go through the real `Dio` pipeline (interceptors, `validateStatus`,
/// the JSON transformer); only the transport is replaced.
///
/// Responders are used in order, one per request. The last responder repeats
/// for any further requests, so a single responder answers every call and
/// `[failure, success]` scripts a retry.
final class FakeHttpClientAdapter implements HttpClientAdapter {
  /// Throws [ArgumentError] if [responders] is empty.
  FakeHttpClientAdapter(List<FakeResponder> responders)
    : _responders = List<FakeResponder>.of(responders) {
    if (_responders.isEmpty) {
      throw ArgumentError.value(
        responders,
        'responders',
        'must contain at least one responder',
      );
    }
  }

  final List<FakeResponder> _responders;
  final List<RequestOptions> _requests = <RequestOptions>[];
  bool _closed = false;

  /// Every request that reached the transport, oldest first.
  List<RequestOptions> get requests =>
      List<RequestOptions>.unmodifiable(_requests);

  /// Whether `Dio.close()` has closed this adapter.
  bool get isClosed => _closed;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    _requests.add(options);
    final FakeResponder responder = _responders.length > 1
        ? _responders.removeAt(0)
        : _responders.single;
    return responder(options);
  }

  @override
  void close({bool force = false}) {
    _closed = true;
  }
}

/// Replies with [statusCode] and [body] encoded as JSON, with an
/// `application/json` content type, so Dio decodes it into a `Map` / `List`.
FakeResponder jsonResponse(int statusCode, Object? body) {
  return rawResponse(
    statusCode,
    jsonEncode(body),
    contentType: Headers.jsonContentType,
  );
}

/// Replies with [statusCode] and [body] exactly as given.
///
/// Use `contentType: Headers.jsonContentType` with an invalid body to make
/// Dio's transformer throw a `FormatException`, or the default `text/plain`
/// (or `text/html`) to receive [body] as a `String`.
FakeResponder rawResponse(
  int statusCode,
  String body, {
  String contentType = 'text/plain',
}) {
  return (RequestOptions options) async => ResponseBody.fromString(
    body,
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[contentType],
    },
  );
}

/// Fails the request with the error built by [errorFor].
///
/// Build a `DioException` (for example `DioException.connectionTimeout`) to
/// simulate what a real adapter throws; any other error reaches the caller
/// as `DioExceptionType.unknown` with that error attached.
FakeResponder throwing(Object Function(RequestOptions options) errorFor) {
  return (RequestOptions options) =>
      Future<ResponseBody>.error(errorFor(options), StackTrace.current);
}
