import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/core/network/interceptors/api_key_interceptor.dart';

import '../../../helpers/fake_http_client_adapter.dart';

const String _apiKey = 'test-api-key-123';
const String _path = '/top-headlines';

void main() {
  late FakeHttpClientAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = FakeHttpClientAdapter(<FakeResponder>[
      jsonResponse(200, <String, Object?>{'status': 'ok'}),
    ]);
    dio = Dio(BaseOptions(baseUrl: 'https://newsapi.test/v2'))
      ..httpClientAdapter = adapter
      ..interceptors.add(ApiKeyInterceptor(apiKey: _apiKey));
  });

  group('ApiKeyInterceptor', () {
    test('adds the key in the X-Api-Key header', () async {
      await dio.get<Object?>(_path);

      expect(
        adapter.requests.single.headers[ApiKeyInterceptor.headerName],
        _apiKey,
      );
    });

    test('adds the key to every request', () async {
      await dio.get<Object?>(_path);
      await dio.get<Object?>('/everything');

      expect(adapter.requests, hasLength(2));
      for (final RequestOptions request in adapter.requests) {
        expect(
          request.headers[ApiKeyInterceptor.headerName],
          _apiKey,
          reason: request.path,
        );
      }
    });

    test('replaces a key the caller set, whatever its case, without '
        'duplicating the header', () async {
      await dio.get<Object?>(
        _path,
        options: Options(
          headers: <String, Object?>{'x-api-key': 'caller-supplied-key'},
        ),
      );

      final Map<String, Object?> headers = adapter.requests.single.headers;
      expect(headers[ApiKeyInterceptor.headerName], _apiKey);
      expect(
        headers.keys.where((String key) => key.toLowerCase() == 'x-api-key'),
        hasLength(1),
      );
    });

    test('never puts the key in the URL', () async {
      await dio.get<Object?>(
        _path,
        queryParameters: <String, Object?>{'country': 'us'},
      );

      final Uri uri = adapter.requests.single.uri;
      expect(
        uri.queryParameters.keys.map((String key) => key.toLowerCase()),
        isNot(contains('apikey')),
      );
      expect(uri.toString(), isNot(contains(_apiKey)));
    });

    test("keeps the caller's query parameters and other headers", () async {
      await dio.get<Object?>(
        _path,
        queryParameters: <String, Object?>{'country': 'us'},
        options: Options(
          headers: <String, Object?>{'Accept': 'application/json'},
        ),
      );

      final RequestOptions request = adapter.requests.single;
      expect(request.queryParameters, <String, Object?>{'country': 'us'});
      expect(request.headers['Accept'], 'application/json');
    });

    test('headerName is X-Api-Key (shared with the logging redaction)', () {
      expect(ApiKeyInterceptor.headerName, 'X-Api-Key');
    });
  });
}
