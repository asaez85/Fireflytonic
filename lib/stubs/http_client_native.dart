import 'dart:io';
import 'package:cronet_http/cronet_http.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart' as http;
import 'package:waterflyiii/offline_cache.dart';

http.Client getPlatformHttpClient() {
  final http.Client baseClient = Platform.isAndroid
      ? CronetClient.fromCronetEngine(
          CronetEngine.build(
            cacheMode: CacheMode.memory,
            cacheMaxSize: 2 * 1024 * 1024,
          ),
          closeEngine: false,
        )
      : Platform.isIOS
      ? CupertinoClient.fromSessionConfiguration(
          URLSessionConfiguration.ephemeralSessionConfiguration()
            ..cache = URLCache.withCapacity(memoryCapacity: 2 * 1024 * 1024),
        )
      : http.Client();

  return OfflineCachingClient(baseClient);
}
