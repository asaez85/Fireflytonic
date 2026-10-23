// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:animations/animations.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:logging/logging.dart';
import 'package:material_color_utilities/material_color_utilities.dart'
    show CorePalette;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:waterflyiii/app.dart';
import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/extensions.dart';
import 'package:waterflyiii/generated/l10n/app_localizations.dart';
import 'package:waterflyiii/notificationlistener.dart';
import 'package:waterflyiii/pages/settings/connection.dart';
import 'package:waterflyiii/pages/settings/debug.dart';
import 'package:waterflyiii/pages/settings/notifications.dart';
import 'package:waterflyiii/pages/settings/ai_categorizer.dart';
import 'package:waterflyiii/settings.dart';
import 'package:waterflyiii/updater.dart';

final Logger log = Logger("Pages.Settings");

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  final Logger log = Logger("Pages.Settings.Page");

  @override
  Widget build(BuildContext context) {
    log.finest(() => "build()");

    final SettingsProvider settings = context.read<SettingsProvider>();

    return ListView(
      padding: const .symmetric(horizontal: 24),
      primary: false,
      children: <Widget>[
        const SettingsSectionHeader(title: "Apariencia y gráficos"),
        ListTile(
          title: Text(S.of(context).settingsLanguage),
          subtitle: Text(S.of(context).localeName),
          leading: const CircleAvatar(child: Icon(Icons.language)),
          onTap: () {
            showDialog<Locale?>(
              context: context,
              builder: (BuildContext context) => const LanguageDialog(),
            ).then((Locale? locale) async {
              if (locale == null) {
                return;
              }
              await settings.setLocale(locale);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                const QuickActions().setShortcutItems(<ShortcutItem>[
                  ShortcutItem(
                    type: "action_transaction_add",
                    localizedTitle: S.of(context).transactionTitleAdd,
                    icon: "action_icon_add",
                  ),
                ]);
              });
            });
          },
        ),
        FutureBuilder<CorePalette?>(
          future: DynamicColorPlugin.getCorePalette(),
          builder: (BuildContext context, AsyncSnapshot<CorePalette?> snapshot) {
            String dynamicColor = "";
            bool dynamicColorAvailable = false;
            if (snapshot.connectionState == .done &&
                snapshot.hasData &&
                snapshot.data != null) {
              // Dynamic color support available
              dynamicColorAvailable = true;
              if (context.select((SettingsProvider s) => s.dynamicColors)) {
                dynamicColor = " - ${S.of(context).settingsThemeDynamicColors}";
              }
            }
            return ListTile(
              title: Text(S.of(context).settingsTheme),
              subtitle: Text(
                "${S.of(context).settingsThemeValue(context.select((SettingsProvider s) => s.theme).toString().split('.').last)}$dynamicColor",
              ),
              leading: const CircleAvatar(child: Icon(Icons.format_paint)),
              onTap: () {
                showDialog<ThemeMode?>(
                  context: context,
                  builder: (BuildContext context) =>
                      ThemeDialog(dynamicColorAvailable: dynamicColorAvailable),
                ).then((ThemeMode? theme) {
                  if (theme == null) {
                    return;
                  }
                  settings.setTheme(theme);
                });
              },
            );
          },
        ),
        ListTile(
          title: const Text("Periodo por defecto de los gráficos"),
          subtitle: Text(
            "${context.select((SettingsProvider s) => s.homePatrimonyPeriod.label)} • Patrimonio y Evolución",
          ),
          leading: const CircleAvatar(child: Icon(Icons.show_chart)),
          onTap: () {
            showDialog<HomePatrimonyPeriod>(
              context: context,
              builder: (BuildContext context) =>
                  const HomePatrimonyPeriodDialog(),
            ).then((HomePatrimonyPeriod? period) {
              if (period != null) {
                settings.setHomePatrimonyPeriod(period);
              }
            });
          },
        ),
        const Divider(),
        const SettingsSectionHeader(title: "Servidor y seguridad"),
        ListTile(
          title: Text(S.of(context).settingsServerConnection),
          subtitle: Text(
            context.select((FireflyService f) {
              final Uri? host = f.user?.host;
              if (host == null) {
                return "";
              }
              final List<String> segments = <String>[...host.pathSegments];
              if (segments.isNotEmpty && segments.last == "api") {
                segments.removeLast();
              }
              return host.replace(pathSegments: segments).toString();
            }),
            maxLines: 2,
          ),
          leading: const CircleAvatar(child: Icon(Icons.cloud_outlined)),
          onTap: () {
            showDialog<void>(
              context: context,
              builder: (BuildContext context) => const ConnectionDialog(),
            );
          },
        ),
        SwitchListTile.adaptive(
          title: Text(S.of(context).settingsUseServerTimezone),
          value: context.select((SettingsProvider s) => s.useServerTime),
          secondary: CircleAvatar(
            child: Icon(
              context.select((SettingsProvider s) => s.useServerTime)
                  ? Icons.schedule
                  : Icons.schedule_outlined,
            ),
          ),
          onChanged: (bool value) async {
            await context.read<FireflyService>().tzHandler.setUseServerTime(
              value,
            );
            settings.useServerTime = value;
          },
        ),
        const Divider(),
        SwitchListTile.adaptive(
          title: Text(S.of(context).settingsLockscreen),
          subtitle: Text(S.of(context).settingsLockscreenHelp),
          value: context.select((SettingsProvider s) => s.lock),
          secondary: CircleAvatar(
            child: Icon(
              context.select((SettingsProvider s) => s.lock)
                  ? Icons.lock
                  : Icons.lock_outline,
            ),
          ),
          onChanged: (bool value) async {
            final S l10n = S.of(context);
            final ScaffoldMessengerState msg = ScaffoldMessenger.of(context);
            final String cancelButtonLabel = MaterialLocalizations.of(
              context,
            ).cancelButtonLabel;
            if (value == true) {
              final LocalAuthentication auth = LocalAuthentication();
              final bool canAuth =
                  await auth.isDeviceSupported() ||
                  await auth.canCheckBiometrics;
              if (!canAuth) {
                log.warning("no auth method supported");
                return;
              }
              log.finest("trying authentication");
              late bool authed;
              try {
                authed = await auth.authenticate(
                  localizedReason: l10n.settingsLockscreenInitial,
                  persistAcrossBackgrounding: true,
                  sensitiveTransaction: false,
                  biometricOnly: false,
                  authMessages: <AuthMessages>[
                    AndroidAuthMessages(
                      signInTitle: l10n.settingsLockscreen,
                      signInHint: l10n.settingsLockscreenInitial,
                      cancelButton: cancelButtonLabel,
                    ),
                  ],
                );
              } catch (e, stackTrace) {
                log.severe("auth failed", e, stackTrace);
                msg.showSnackBar(
                  SnackBar(
                    content: Text(l10n.errorUnknown),
                    behavior: .floating,
                  ),
                );
                return;
              }

              if (!authed) {
                log.warning("authentication was cancelled");
                return;
              }
            }
            settings.lock = value;
          },
        ),
        if (!kIsWeb && Platform.isAndroid) ...<Widget>[
          const Divider(),
          const SettingsSectionHeader(title: "Notificaciones"),
          FutureBuilder<NotificationListenerStatus>(
            future: nlStatus(),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<NotificationListenerStatus> snapshot,
                ) {
                  final S l10n = S.of(context);

                  late String subtitle;
                  if (snapshot.connectionState == .done && snapshot.hasData) {
                    if (!snapshot.data!.servicePermission ||
                        !snapshot.data!.notificationPermission) {
                      subtitle = l10n.settingsNLPermissionNotGranted;
                    } else if (!snapshot.data!.serviceRunning) {
                      subtitle = l10n.settingsNLServiceStopped;
                    } else {
                      subtitle = l10n.settingsNLServiceRunning;
                    }
                  } else if (snapshot.hasError) {
                    log.severe(
                      "error getting nlStatus",
                      snapshot.error,
                      snapshot.stackTrace,
                    );
                    subtitle = S
                        .of(context)
                        .settingsNLServiceCheckingError(
                          snapshot.error.toString(),
                        );
                  } else {
                    subtitle = S.of(context).settingsNLServiceChecking;
                  }
                  return OpenContainer(
                    openBuilder:
                        (BuildContext context, Function closedContainer) =>
                            const SettingsNotifications(),
                    openColor: Theme.of(context).cardColor,
                    closedColor: Theme.of(context).cardColor,
                    closedElevation: 0,
                    closedBuilder:
                        (BuildContext context, Function openContainer) =>
                            ListTile(
                              title: Text(
                                S.of(context).settingsNotificationListener,
                              ),
                              subtitle: Text(subtitle, maxLines: 2),
                              leading: const CircleAvatar(
                                child: Icon(Icons.notifications),
                              ),
                              onTap: () => openContainer(),
                            ),
                    onClosed: (_) => setState(() {}),
                  );
                },
          ),
        ],
        const AICategorizerSettingsSection(),
        const Divider(),
        const SettingsSectionHeader(title: "Acerca de"),
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
            return ListTile(
              title: Text(S.of(context).settingsVersion),
              subtitle: Text(
                (snapshot.data != null)
                    ? "Fireflytonic, ${snapshot.data!.version}+${snapshot.data!.buildNumber}"
                    : S.of(context).settingsVersionChecking,
              ),
              leading: const CircleAvatar(
                child: Icon(Icons.info_outline_rounded),
              ),
              onTap: () => showDialog(
                context: context,
                builder: (BuildContext context) => const DebugDialog(),
              ),
            );
          },
        ),
        if (!kIsWeb && Platform.isAndroid)
          FutureBuilder<UpdateChannel>(
            future: AppUpdater.getUpdateChannel(),
            builder:
                (BuildContext context, AsyncSnapshot<UpdateChannel> snapshot) {
                  final UpdateChannel currentChannel =
                      snapshot.data ?? UpdateChannel.stable;
                  return ListTile(
                    title: const Text("Actualizaciones"),
                    subtitle: Text(
                      "Canal ${currentChannel.label} • Buscar nueva versión",
                    ),
                    leading: const CircleAvatar(
                      child: Icon(Icons.system_update_rounded),
                    ),
                    onTap: () async {
                      await showDialog<void>(
                        context: context,
                        builder: (BuildContext dialogContext) =>
                            UpdateSettingsDialog(
                              currentChannel: currentChannel,
                            ),
                      );
                      if (mounted) setState(() {});
                    },
                  );
                },
          ),
      ],
    );
  }
}

class LanguageDialog extends StatelessWidget {
  const LanguageDialog({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint("current locale: ${S.of(context).localeName}");
    return SimpleDialog(
      title: Text(S.of(context).settingsDialogLanguageTitle),
      children: <Widget>[
        RadioGroup<Locale>(
          groupValue: LocaleExt.fromLanguageTag(S.of(context).localeName),
          onChanged: (Locale? locale) {
            Navigator.pop(context, locale);
          },
          child: Column(
            children: <Widget>[
              ...S.supportedLocales.map(
                (Locale locale) => RadioListTile<Locale>.adaptive(
                  value: locale,
                  title: Text(locale.toLanguageTag()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ThemeDialog extends StatelessWidget {
  const ThemeDialog({super.key, required this.dynamicColorAvailable});

  final bool dynamicColorAvailable;

  @override
  Widget build(BuildContext context) {
    final SettingsProvider settings = context.read<SettingsProvider>();
    return SimpleDialog(
      title: Text(S.of(context).settingsDialogThemeTitle),
      children: <Widget>[
        dynamicColorAvailable
            ? SwitchListTile.adaptive(
                title: Text(S.of(context).settingsThemeDynamicColors),
                value: context.select((SettingsProvider s) => s.dynamicColors),
                isThreeLine: false,
                onChanged: (bool value) => settings.dynamicColors = value,
              )
            : const SizedBox.shrink(),
        RadioGroup<ThemeMode>(
          groupValue: settings.theme,
          onChanged: (ThemeMode? theme) {
            Navigator.pop(context, theme);
          },
          child: Column(
            children: <Widget>[
              ...ThemeMode.values.map(
                (ThemeMode theme) => RadioListTile<ThemeMode>.adaptive(
                  value: theme,
                  title: Text(
                    S
                        .of(context)
                        .settingsThemeValue(theme.toString().split('.').last),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class HomePatrimonyPeriodDialog extends StatelessWidget {
  const HomePatrimonyPeriodDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsProvider settings = context.read<SettingsProvider>();
    return SimpleDialog(
      title: const Text("Periodo por defecto de los gráficos"),
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: Text(
            "Selecciona el periodo inicial que se aplicará a los gráficos de patrimonio y a la pantalla de Evolución.",
            style: TextStyle(fontSize: 13),
          ),
        ),
        RadioGroup<HomePatrimonyPeriod>(
          groupValue: settings.homePatrimonyPeriod,
          onChanged: (HomePatrimonyPeriod? period) {
            Navigator.pop(context, period);
          },
          child: Column(
            children: <Widget>[
              ...HomePatrimonyPeriod.values.map(
                (HomePatrimonyPeriod p) =>
                    RadioListTile<HomePatrimonyPeriod>.adaptive(
                      value: p,
                      title: Text(p.label),
                      subtitle: p == HomePatrimonyPeriod.oneYear
                          ? const Text("Recomendado (1 año)")
                          : null,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class UpdateSettingsDialog extends StatefulWidget {
  const UpdateSettingsDialog({super.key, required this.currentChannel});

  final UpdateChannel currentChannel;

  @override
  State<UpdateSettingsDialog> createState() => _UpdateSettingsDialogState();
}

class _UpdateSettingsDialogState extends State<UpdateSettingsDialog> {
  late UpdateChannel _selectedChannel;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _selectedChannel = widget.currentChannel;
  }

  Future<void> _checkUpdates() async {
    setState(() => _checking = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    try {
      final AppUpdateInfo? update = await AppUpdater.instance.checkForUpdate(
        isManual: true,
      );
      if (!mounted) return;
      setState(() => _checking = false);
      if (update != null) {
        navigator.pop();
        final BuildContext? targetContext = navigatorKey.currentContext;
        if (targetContext != null && targetContext.mounted) {
          await AppUpdater.showUpdateDialog(
            context: targetContext,
            updateInfo: update,
          );
        }
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Ya tienes la última versión instalada."),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _checking = false);
      messenger.showSnackBar(
        SnackBar(content: Text("Error al buscar actualizaciones: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Actualizaciones"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              "Canal de distribución",
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            RadioListTile<UpdateChannel>.adaptive(
              value: UpdateChannel.stable,
              groupValue: _selectedChannel,
              title: const Text("Estable"),
              subtitle: const Text("Versiones oficiales y probadas"),
              contentPadding: EdgeInsets.zero,
              onChanged: (UpdateChannel? val) async {
                if (val != null && val != _selectedChannel) {
                  setState(() => _selectedChannel = val);
                  await AppUpdater.setUpdateChannel(val);
                }
              },
            ),
            RadioListTile<UpdateChannel>.adaptive(
              value: UpdateChannel.beta,
              groupValue: _selectedChannel,
              title: const Text("Beta"),
              subtitle: const Text("Versiones preliminares con novedades"),
              contentPadding: EdgeInsets.zero,
              onChanged: (UpdateChannel? val) async {
                if (val != null && val != _selectedChannel) {
                  setState(() => _selectedChannel = val);
                  await AppUpdater.setUpdateChannel(val);
                }
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                icon: _checking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: Text(
                  _checking ? "Comprobando..." : "Buscar actualizaciones ahora",
                ),
                onPressed: _checking ? null : _checkUpdates,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}

class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6, left: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
