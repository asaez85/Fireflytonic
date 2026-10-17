import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:logging/logging.dart';
import 'package:waterflyiii/generated/l10n/app_localizations.dart';
import 'package:waterflyiii/widgets/logo.dart';

final Logger log = Logger("Pages.Lock");

class LockPage extends StatefulWidget {
  const LockPage({super.key, required this.onSuccess});

  final VoidCallback onSuccess;

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  Future<void> _authenticate() async {
    final LocalAuthentication auth = LocalAuthentication();
    final S? l10n = mounted ? S.of(context) : null;
    try {
      final bool success = await auth.authenticate(
        localizedReason:
            l10n?.settingsLockscreenHelp ?? "Desbloquear Fireflytonic",
        persistAcrossBackgrounding: true,
        sensitiveTransaction: false,
        biometricOnly: false,
        authMessages: <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: l10n?.settingsLockscreen ?? "Pantalla de bloqueo",
            signInHint:
                l10n?.settingsLockscreenHelp ??
                "Requerir autenticación para continuar",
            cancelButton: MaterialLocalizations.of(context).cancelButtonLabel,
          ),
        ],
      );

      if (success) {
        widget.onSuccess();
      }
    } on Exception catch (e) {
      log.shout(() => "Authentication failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color barrierColor = Theme.of(
      context,
    ).scaffoldBackgroundColor.withValues(alpha: 0.7);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
            child: Container(color: barrierColor),
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  const AppLogo(size: 256),
                  const SizedBox(height: 48),
                  IconButton(
                    iconSize: 128,
                    icon: Icon(
                      Icons.fingerprint,
                      color: Theme.of(context).primaryColor,
                    ),
                    onPressed: () {
                      _authenticate();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
