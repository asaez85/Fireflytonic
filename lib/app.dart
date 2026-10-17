import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_sharing_intent/flutter_sharing_intent.dart';
import 'package:flutter_sharing_intent/model/sharing_file.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/generated/l10n/app_localizations.dart';
import 'package:waterflyiii/layout.dart';
import 'package:waterflyiii/notificationlistener.dart';
import 'package:waterflyiii/pages/lock.dart';
import 'package:waterflyiii/pages/login.dart';
import 'package:waterflyiii/pages/navigation.dart';
import 'package:waterflyiii/pages/splash.dart';
import 'package:waterflyiii/pages/transaction.dart';
import 'package:waterflyiii/theme.dart';
import 'package:waterflyiii/settings.dart';
import 'package:waterflyiii/updater.dart';

final Logger log = Logger("App");

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(
  debugLabel: "Main Navigator",
);

class WaterflyApp extends StatefulWidget {
  const WaterflyApp({super.key});

  @override
  State<WaterflyApp> createState() => _WaterflyAppState();
}

class _WaterflyAppState extends State<WaterflyApp> {
  bool _startup = true;
  String? _quickAction;
  NotificationTransaction? _notificationPayload;
  // Not needed right now, as sharing while the app is open does not work
  //late StreamSubscription<List<SharedFile>> _intentDataStreamSubscription;
  List<SharedFile>? _filesSharedToApp;
  DateTime? _lcLastOpen;

  final FireflyService _fireflyService = FireflyService();
  final SettingsProvider _settingsProvider = SettingsProvider();
  final LayoutProvider _layoutProvider = LayoutProvider();

  @override
  void initState() {
    super.initState();

    _initializePlatformServices();
    _handleStartup();
  }

  void _initializePlatformServices() {
    if (kIsWeb) return;
    // Notifications (Android only)
    if (!kIsWeb && Platform.isAndroid) {
      _initNotifications();
    }
    // Quick Actions (Android + iOS)
    _initQuickActions();
    // Share to Waterfly III
    _initSharingIntent();
    // App Lifecycle State
    _initLifecycleListener();
  }

  void _initNotifications() {
    FlutterLocalNotificationsPlugin().initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_notification'),
      ),
      onDidReceiveNotificationResponse: nlNotificationTap,
    );

    FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails().then((
      NotificationAppLaunchDetails? details,
    ) {
      log.config("checking NotificationAppLaunchDetails");
      if ((details?.didNotificationLaunchApp ?? false) &&
          (details?.notificationResponse?.payload?.isNotEmpty ?? false)) {
        log.info("Was launched from notification!");
        _notificationPayload = .fromJson(
          jsonDecode(details!.notificationResponse!.payload!),
        );
      }
    });
  }

  void _initQuickActions() {
    const QuickActions quickActions = QuickActions();
    quickActions.initialize((String shortcutType) {
      log.info("Was launched from QuickAction $shortcutType");
      _quickAction = shortcutType;
      if (!_startup && navigatorKey.currentState != null) {
        log.finest(() => "App already started, pushing route");
        navigatorKey.currentState!.push(
          MaterialPageRoute<Widget>(
            builder: (BuildContext context) => const TransactionPage(),
          ),
        );
      }
    });
    quickActions.clearShortcutItems();
  }

  void _initSharingIntent() {
    // While the app is open...
    /* Sharing while app is open is currently not supported :(
       The fix from https://github.com/bhagat-techind/flutter_sharing_intent/issues/33
       does not seem to work, unfortunately.

    _intentDataStreamSubscription = FlutterSharingIntent.instance
        .getMediaStream()
        .listen((List<SharedFile> value) {
      setState(() {
        list = value;
      });
      debugPrint(
          "Shared: getMediaStream ${value.map((SharedFile f) => f.value).join(",")}");
    }, onError: (Object err) {
      debugPrint("getIntentDataStream error: $err");
    });*/

    // For sharing images coming from outside the app while the app is closed
    FlutterSharingIntent.instance.getInitialSharing().then((
      List<SharedFile> value,
    ) {
      log.config("App was opened via file sharing");
      log.finest(
        () => "files: ${value.map((SharedFile f) => f.value).join(",")}",
      );
      _filesSharedToApp = value;
    });
  }

  void _initLifecycleListener() {
    AppLifecycleListener(
      onResume: () {
        log.finest(() => "Lifecycle: Resume");
        // If lock is enabled, check if we need to re-authenticate based on timeout (10 mins)
        if (_settingsProvider.lock &&
            (_lcLastOpen?.isBefore(
                  DateTime.now().subtract(const Duration(minutes: 10)),
                ) ??
                false)) {
          log.finest(() => "App resuming, timeout reached. Requiring re-auth.");
          _settingsProvider.sessionLock();
          if (mounted) {
            setState(() => _lcLastOpen = null);
          }
        }
      },
      onPause: () {
        log.finest(() => "Lifecycle: Pause");
        if (_settingsProvider.lock) {
          _lcLastOpen ??= DateTime.now();
        }
      },
    );
  }

  Future<void> _handleStartup() async {
    log.finer(() => "Load Step 1: Loading Settings");
    await _settingsProvider.loadSettings();

    log.finer(() => "Load Step 2: Sign in");
    // Modo demo automático para previsualizar la UI sin servidor:
    // flutter run/build --dart-define=FIREFLY_DEMO=true
    const bool demoMode = bool.fromEnvironment("FIREFLY_DEMO");
    if (demoMode) {
      await _fireflyService.signInDemo();
    } else {
      await _fireflyService.signInFromStorage();
    }

    log.finer(() => "Loading done.");
    if (mounted) {
      setState(() => _startup = false);
    }

    // Comprobación de actualizaciones en segundo plano al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdatesOnStartup();
    });
  }

  Future<void> _checkUpdatesOnStartup() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final AppUpdateInfo? update = await AppUpdater.instance.checkForUpdate();
      if (update != null && mounted) {
        final BuildContext? currentCtx = navigatorKey.currentContext;
        if (currentCtx != null && currentCtx.mounted) {
          await AppUpdater.showUpdateDialog(
            context: currentCtx,
            updateInfo: update,
          );
        }
      }
    } catch (e) {
      log.fine("Error comprobando actualizaciones al inicio: $e");
    }
  }

  @override
  void dispose() {
    _fireflyService.dispose();
    _settingsProvider.dispose();
    _layoutProvider.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mounted) {
      _layoutProvider.updateSize(context);
    }
  }

  Widget _getHome(SettingsProvider settings, FireflyService firefly) {
    // 1. Show Splash during initial startup or until settings are loaded
    if (_startup || !settings.loaded) {
      log.finest(
        () =>
            "_getHome: showing splash (startup: $_startup, settings: ${settings.loaded})",
      );
      return const SplashPage();
    }

    // 2. Show LockPage overlay if security is enabled and user isn't authenticated
    final Widget content;
    // 3. Handle Login/Errors
    if (firefly.storageSignInException != null) {
      log.finest(() => "_getHome: showing splash (storageSignInException)");
      content = const SplashPage();
    } else if (!firefly.signedIn) {
      log.finest(() => "_getHome: showing login");
      content = const LoginPage();
    } else if (_notificationPayload != null ||
        _quickAction == "action_transaction_add" ||
        (_filesSharedToApp?.isNotEmpty ?? false)) {
      // 4. Handle Deep Links
      log.finest(() => "_getHome: showing transaction");
      content = TransactionPage(
        notification: _notificationPayload,
        files: _filesSharedToApp,
      );
    } else {
      // 5. Default to Home
      log.finest(() => "_getHome: showing navpage");
      content = const NavPage();
    }

    if (settings.lock && !settings.isSessionAuthed) {
      log.finest(
        () =>
            "_getHome: showing lockpage overlay (authed: ${settings.isSessionAuthed})",
      );
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          content,
          LockPage(onSuccess: settings.sessionAuthed),
        ],
      );
    }

    return content;
  }

  @override
  Widget build(BuildContext context) {
    log.fine(() => "WaterflyApp() building");

    return Builder(
      builder: (BuildContext context) {
        return MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<FireflyService>.value(
              value: _fireflyService,
            ),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: _settingsProvider,
            ),
            ChangeNotifierProvider<LayoutProvider>.value(
              value: _layoutProvider,
            ),
          ],
          builder: (BuildContext context, _) {
            final SettingsProvider settings = context.watch<SettingsProvider>();
            final FireflyService firefly = context.watch<FireflyService>();

            return MaterialApp(
              title: 'Fireflytonic',
              theme: FtTheme.light().copyWith(
                pageTransitionsTheme: const PageTransitionsTheme(
                  builders: <TargetPlatform, PageTransitionsBuilder>{
                    TargetPlatform.android:
                        PredictiveBackPageTransitionsBuilder(),
                  },
                ),
              ),
              darkTheme: FtTheme.dark(),
              themeMode: settings.theme,
              localizationsDelegates: S.localizationsDelegates,
              supportedLocales: S.supportedLocales,
              locale: settings.locale,
              navigatorKey: navigatorKey,
              home: _getHome(settings, firefly),
            );
          },
        );
      },
    );
  }
}
