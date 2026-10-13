import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chopper/chopper.dart'
    show
        Chain,
        HttpMethod,
        Interceptor,
        Request,
        Response,
        StripStringExtension,
        applyHeaders;
import 'package:flutter/material.dart';

import 'package:waterflyiii/stubs/http_client_stub.dart'
    if (dart.library.io) 'package:waterflyiii/stubs/http_client_native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:version/version.dart';
import 'package:waterflyiii/generated/l10n/app_localizations.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/demo.dart';
import 'package:waterflyiii/stock.dart';
import 'package:waterflyiii/timezonehandler.dart';

final Logger log = Logger("Auth");
final Version minApiVersion = Version(6, 3, 2);
final RegExp _httpHeaderNamePattern = RegExp(r"^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$");

String _stripWrappingQuotes(String value) {
  if (value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'")))) {
    return value.substring(1, value.length - 1);
  }
  return value;
}

Map<String, String> parseCustomHeaders(String rawInput) {
  final Map<String, String> headers = <String, String>{};

  final List<String> lines = rawInput.replaceAll('\r', '').strip().split('\n');
  for (int i = 0; i < lines.length; i++) {
    final String line = lines[i].strip();
    if (line.isEmpty) {
      continue;
    }

    final int separator = line.indexOf(':');
    if (separator <= 0 || separator == line.length - 1) {
      throw AuthErrorCustomHeaders(i + 1);
    }

    final String name = line.substring(0, separator).strip();
    String value = line.substring(separator + 1).strip();
    value = _stripWrappingQuotes(value).strip();
    if (name.isEmpty ||
        !_httpHeaderNamePattern.hasMatch(name) ||
        value.isEmpty) {
      throw AuthErrorCustomHeaders(i + 1);
    }

    headers[name] = value;
  }

  return headers;
}

String encodeCustomHeaders(Map<String, String> headers) {
  if (headers.isEmpty) {
    return "";
  }
  return headers.entries
      .map((MapEntry<String, String> entry) {
        return "${entry.key}: ${entry.value}";
      })
      .join('\n');
}

class APITZReply {
  APITZReply(this.data);
  APITZReplyData data;

  factory APITZReply.fromJson(dynamic json) {
    return APITZReply(APITZReplyData.fromJson(json['data']));
  }
}

class APITZReplyData {
  APITZReplyData(this.title, this.value, this.editable);
  String title;
  String value;
  bool editable;

  factory APITZReplyData.fromJson(dynamic json) {
    return APITZReplyData(
      json['title'] as String,
      json['value'] as String,
      json['editable'] as bool,
    );
  }
}

// :TODO: translate strings. cause returns just an identifier for the translation.
class AuthError implements Exception {
  const AuthError(this.cause);

  final String cause;
}

class AuthErrorHost extends AuthError {
  const AuthErrorHost(this.host) : super("Invalid host");

  final String host;
}

class AuthErrorApiKey extends AuthError {
  const AuthErrorApiKey() : super("Invalid API key");
}

class AuthErrorCustomHeaders extends AuthError {
  const AuthErrorCustomHeaders(this.lineNumber)
    : super("Invalid custom headers");

  final int lineNumber;
}

class AuthErrorVersionInvalid extends AuthError {
  const AuthErrorVersionInvalid() : super("Invalid Firefly API version");
}

class AuthErrorVersionTooLow extends AuthError {
  const AuthErrorVersionTooLow(this.requiredVersion)
    : super("Firefly API version too low");

  final Version requiredVersion;
}

class AuthErrorStatusCode extends AuthError {
  const AuthErrorStatusCode(this.code) : super("Unexpected HTTP status code");

  final int code;
}

class AuthErrorNoInstance extends AuthError {
  const AuthErrorNoInstance(this.host)
    : super("Not a valid Firefly III instance");

  final String host;
}

class AuthCredentials {
  const AuthCredentials({this.host, this.apiKey, this.customHeadersRaw});

  final String? host;
  final String? apiKey;
  final String? customHeadersRaw;
}

http.Client get httpClient => getPlatformHttpClient();

class APIRequestInterceptor implements Interceptor {
  APIRequestInterceptor(this.headerFunc);

  final Function() headerFunc;

  @override
  FutureOr<Response<BodyType>> intercept<BodyType>(Chain<BodyType> chain) {
    log.finest(() => "API query ${chain.request.method} ${chain.request.url}");
    if (chain.request.body != null) {
      log.finest(() => "Query Body: ${chain.request.body}");
    }
    final Map<String, String> hdrs = Map<String, String>.from(headerFunc());
    // Firefly III API requires Content-Type header on all POST and PUT requests (returns 415 if empty)
    if (chain.request.headers.containsKey(HttpHeaders.contentTypeHeader)) {
      hdrs[HttpHeaders.contentTypeHeader] =
          chain.request.headers[HttpHeaders.contentTypeHeader]!;
    } else if (chain.request.method == 'POST' ||
        chain.request.method == 'PUT' ||
        chain.request.method == 'PATCH') {
      hdrs[HttpHeaders.contentTypeHeader] = "application/json";
    }

    final Request request = applyHeaders(chain.request, hdrs, override: true);
    request.followRedirects = true;
    request.maxRedirects = 5;
    return chain.proceed(request);
  }
}

class AuthUser {
  late Uri _host;
  late String _apiKey;
  late FireflyIii _api;
  late Map<String, String> _customHeaders;

  //late FireflyIiiV2 _apiV2;

  Uri get host => _host;
  FireflyIii get api => _api;

  //FireflyIiiV2 get apiV2 => _apiV2;

  final Logger log = Logger("Auth.AuthUser");

  /// Usuario ficticio para el modo demo: usa una API falsa con datos
  /// inventados y no realiza ninguna petición de red.
  AuthUser._demo() {
    _host = Uri.parse('https://demo.local/api');
    _apiKey = 'demo';
    _customHeaders = const <String, String>{};
    _api = DemoFireflyIii();
  }

  AuthUser._create(
    Uri host,
    String apiKey,
    Map<String, String>? customHeaders,
  ) {
    log.config("AuthUser->_create($host)");
    _host = host.replace(pathSegments: <String>[...host.pathSegments, "api"]);
    _apiKey = apiKey;
    _customHeaders = customHeaders ?? const <String, String>{};

    _api = FireflyIii.create(
      baseUrl: _host,
      httpClient: httpClient,
      interceptors: <Interceptor>[APIRequestInterceptor(headers)],
    );

    /*_apiV2 = FireflyIiiV2.create(
      baseUrl: _host,
      httpClient: httpClient,
      interceptors: <Interceptor>[APIRequestInterceptor(headers)],
    );*/
  }

  Map<String, String> headers() {
    return <String, String>{
      HttpHeaders.authorizationHeader: "Bearer $_apiKey",
      HttpHeaders.acceptHeader: "application/json",
      HttpHeaders.contentTypeHeader: "application/json",
      ..._customHeaders,
    };
  }

  static Future<AuthUser> create(
    String host,
    String apiKey, {
    Map<String, String>? customHeaders,
  }) async {
    final Logger log = Logger("Auth.AuthUser");
    log.config("AuthUser->create($host)");

    // This call is on purpose not using the Swagger API
    final http.Client client = httpClient;
    late Uri uri;

    try {
      uri = Uri.parse(host);
    } on FormatException {
      throw AuthErrorHost(host);
    }

    final Uri aboutUri = uri.replace(
      pathSegments: <String>[...uri.pathSegments, "api", "v1", "about"],
    );

    try {
      final http.Request request = http.Request(HttpMethod.Get, aboutUri);
      request.headers[HttpHeaders.authorizationHeader] = "Bearer $apiKey";
      if (customHeaders?.isNotEmpty ?? false) {
        request.headers.addAll(customHeaders!);
      }
      // See #497, redirect is a bad way to check for (un)successful login.
      request.followRedirects = true;
      request.maxRedirects = 5;
      final http.StreamedResponse response = await client.send(request);

      if (response.statusCode == 401) {
        throw const AuthErrorApiKey();
      }
      if (response.statusCode != 200) {
        throw AuthErrorStatusCode(response.statusCode);
      }

      // If we get an html page with status 200, auth probably got redirected to a login page.
      if (response.headers[HttpHeaders.contentTypeHeader]?.startsWith(
            "text/html",
          ) ??
          true) {
        throw const AuthErrorApiKey();
      }

      final String stringData = await response.stream.bytesToString();
      try {
        SystemInfo.fromJson(json.decode(stringData));
      } on FormatException {
        throw AuthErrorNoInstance(host);
      }
    } finally {
      client.close();
    }

    return AuthUser._create(uri, apiKey, customHeaders);
  }
}

class FireflyService with ChangeNotifier {
  AuthUser? _currentUser;
  AuthUser? get user => _currentUser;
  bool _signedIn = false;
  bool get signedIn => _signedIn;
  String? _lastTriedHost;
  String? get lastTriedHost => _lastTriedHost;
  Object? _storageSignInException;
  Object? get storageSignInException => _storageSignInException;
  Version? _apiVersion;
  Version? get apiVersion => _apiVersion;

  TransStock? _transStock;
  TransStock? get transStock => _transStock;

  bool get hasApi => (_currentUser?.api != null) ? true : false;
  FireflyIii get api {
    if (_currentUser?.api == null) {
      signOut();
      throw Exception("FireflyService.api: API unavailable");
    }
    return _currentUser!.api;
  }

  /*FireflyIiiV2 get apiV2 {
    if (_currentUser?.apiV2 == null) {
      signOut();
      throw Exception("FireflyService.apiV2: API unavailable");
    }
    return _currentUser!.apiV2;
  }*/

  late CurrencyRead defaultCurrency;
  late TimeZoneHandler tzHandler;

  final FlutterSecureStorage storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
  );

  final Logger log = Logger("Auth.FireflyService");

  FireflyService() {
    log.finest(() => "new FireflyService");
  }

  Future<AuthCredentials> readStoredCredentials() async {
    return AuthCredentials(
      host: await storage.read(key: 'api_host'),
      apiKey: await storage.read(key: 'api_key'),
      customHeadersRaw: await storage.read(key: 'api_headers'),
    );
  }

  Future<bool> signInFromStorage() async {
    _storageSignInException = null;
    final AuthCredentials storedCredentials = await readStoredCredentials();
    final String? apiHost = storedCredentials.host;
    final String? apiKey = storedCredentials.apiKey;
    final String? customHeadersRaw = storedCredentials.customHeadersRaw;

    log.config(
      "storage: $apiHost, apiKey ${apiKey?.isEmpty ?? true ? "unset" : "set"}, "
      "customHeaders ${(customHeadersRaw?.isNotEmpty ?? false) ? "set" : "unset"}",
    );

    if (apiHost == null || apiKey == null) {
      return false;
    }

    try {
      await signIn(apiHost, apiKey, customHeadersRaw: customHeadersRaw);
      return true;
    } catch (e) {
      _storageSignInException = e;
      log.finest(() => "notify FireflyService->signInFromStorage");
      notifyListeners();
      return false;
    }
  }

  /// Inicia sesión en modo demo con datos inventados (sin servidor).
  Future<bool> signInDemo() async {
    log.config("FireflyService->signInDemo()");
    final AuthUser demoUser = AuthUser._demo();
    _currentUser = demoUser;
    defaultCurrency = CurrencyRead.fromJson(<String, dynamic>{
      'type': 'currencies',
      'id': '1',
      'attributes': <String, dynamic>{
        'code': 'EUR',
        'name': 'Euro',
        'symbol': '€',
        'decimal_places': 2,
        'default': true,
        'enabled': true,
      },
    });
    _apiVersion = Version(9, 9, 9);
    tzHandler = TimeZoneHandler('Europe/Madrid');
    _signedIn = true;
    _transStock = TransStock(demoUser.api);
    log.finest(() => "notify FireflyService->signInDemo");
    notifyListeners();
    return true;
  }

  Future<void> signOut() async {
    log.config("FireflyService->signOut()");
    _transStock?.clear();
    _currentUser = null;
    _signedIn = false;
    _storageSignInException = null;
    await storage.deleteAll();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    log.finest(() => "notify FireflyService->signOut");
    notifyListeners();
  }

  Future<bool> signIn(
    String host,
    String apiKey, {
    String? customHeadersRaw,
  }) async {
    log.config("FireflyService->signIn($host)");
    host = host.strip().rightStrip('/');
    apiKey = apiKey.strip();

    _lastTriedHost = host;
    final Map<String, String> customHeaders = parseCustomHeaders(
      customHeadersRaw ?? "",
    );

    AuthUser nextUser;
    bool offlineMode = false;
    try {
      nextUser = await AuthUser.create(
        host,
        apiKey,
        customHeaders: customHeaders,
      );
    } catch (e) {
      log.warning("Offline mode: AuthUser.create failed ($e)");
      final AuthCredentials stored = await readStoredCredentials();
      if (stored.host != null && stored.apiKey != null) {
        nextUser = AuthUser._create(Uri.parse(host), apiKey, customHeaders);
        offlineMode = true;
      } else {
        rethrow;
      }
    }

    CurrencyRead nextDefaultCurrency = CurrencyRead.fromJson(<String, dynamic>{
      'type': 'currencies',
      'id': '1',
      'attributes': <String, dynamic>{
        'code': 'EUR',
        'name': 'Euro',
        'symbol': '€',
        'decimal_places': 2,
        'default': true,
        'enabled': true,
      },
    });
    Version nextApiVersion = Version(1, 0, 0);
    TimeZoneHandler nextTzHandler = TimeZoneHandler('Europe/Madrid');

    if (!offlineMode) {
      try {
        final Response<CurrencySingle> currencyInfo = await nextUser.api
            .v1CurrenciesPrimaryGet();
        if (currencyInfo.isSuccessful && currencyInfo.body != null) {
          nextDefaultCurrency = currencyInfo.body!.data;
        }
      } catch (e) {
        log.warning("Offline mode: v1CurrenciesPrimaryGet failed ($e)");
      }

      try {
        final Response<SystemInfo> about = await nextUser.api.v1AboutGet();
        if (about.isSuccessful && about.body != null) {
          String apiVersionStr = about.body?.data?.apiVersion ?? "";
          if (apiVersionStr.startsWith("develop/")) {
            apiVersionStr = "9.9.9";
          }
          nextApiVersion = Version.parse(apiVersionStr);
        }
      } catch (e) {
        log.warning("Offline mode: v1AboutGet failed ($e)");
      }

      final http.Client client = httpClient;
      final Uri tzUri = nextUser.host.replace(
        pathSegments: <String>[
          ...nextUser.host.pathSegments,
          "v1",
          "configuration",
          ConfigValueFilter.appTimezone.value!,
        ],
      );
      try {
        final http.Response response = await client.get(
          tzUri,
          headers: nextUser.headers(),
        );
        final APITZReply reply = .fromJson(json.decode(response.body));
        nextTzHandler = TimeZoneHandler(reply.data.value);
      } catch (e) {
        log.warning("Offline mode: tzUri get failed ($e)");
      } finally {
        client.close();
      }
    }

    _currentUser = nextUser;
    defaultCurrency = nextDefaultCurrency;
    _apiVersion = nextApiVersion;
    tzHandler = nextTzHandler;
    _signedIn = true;
    _transStock = TransStock(nextUser.api);
    log.finest(() => "notify FireflyService->signIn");
    notifyListeners();

    await storage.write(key: 'api_host', value: host);
    await storage.write(key: 'api_key', value: apiKey);
    if (customHeaders.isNotEmpty) {
      await storage.write(
        key: 'api_headers',
        value: encodeCustomHeaders(customHeaders),
      );
    }

    return true;
  }
}

void apiThrowErrorIfEmpty(Response<dynamic> response, BuildContext? context) {
  if (response.isSuccessful && response.body != null) {
    return;
  }
  log.severe("Invalid API response", response.error);
  if (context?.mounted ?? false) {
    throw Exception(
      S.of(context!).errorAPIInvalidResponse(response.error?.toString() ?? ""),
    );
  } else {
    throw Exception("[nocontext] Invalid API response: ${response.error}");
  }
}
