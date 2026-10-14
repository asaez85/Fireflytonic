// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:animations/animations.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:logging/logging.dart';
import 'package:material_color_utilities/material_color_utilities.dart'
    show CorePalette;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/extensions.dart';
import 'package:waterflyiii/generated/l10n/app_localizations.dart';
import 'package:waterflyiii/notificationlistener.dart';
import 'package:waterflyiii/pages/settings/connection.dart';
import 'package:waterflyiii/pages/settings/debug.dart';
import 'package:waterflyiii/pages/settings/notifications.dart';
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
        const Divider(),
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
          subtitle: Text(S.of(context).settingsUseServerTimezoneHelp),
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
        const Divider(),
        if (!kIsWeb && Platform.isAndroid)
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
        if (!kIsWeb && Platform.isAndroid) const Divider(),
        ListTile(
          title: Text(S.of(context).settingsFAQ),
          subtitle: Text(S.of(context).settingsFAQHelp),
          leading: const CircleAvatar(child: Icon(Icons.question_answer)),
          onTap: () async {
            final Uri uri = Uri.parse(
              "https://github.com/asaez85/Fireflytonic/blob/main/FAQ.md",
            );
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            } else {
              throw Exception("Could not open URL");
            }
          },
        ),
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
        if (!kIsWeb && Platform.isAndroid) ...<Widget>[
          const Divider(),
          FutureBuilder<UpdateChannel>(
            future: AppUpdater.getUpdateChannel(),
            builder: (BuildContext _, AsyncSnapshot<UpdateChannel> snapshot) {
              final UpdateChannel currentChannel =
                  snapshot.data ?? UpdateChannel.stable;
              return ListTile(
                title: const Text("Canal de actualizaciones"),
                subtitle: Text(
                  "${currentChannel.label} — ${currentChannel.description}",
                ),
                leading: const CircleAvatar(
                  child: Icon(Icons.alt_route_rounded),
                ),
                onTap: () async {
                  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(
                    context,
                  );
                  final UpdateChannel? selected =
                      await showDialog<UpdateChannel>(
                        context: context,
                        builder: (BuildContext dialogContext) => SimpleDialog(
                          title: const Text("Canal de actualizaciones"),
                          children: <Widget>[
                            RadioListTile<UpdateChannel>.adaptive(
                              value: UpdateChannel.stable,
                              groupValue: currentChannel,
                              title: const Text("Estable"),
                              subtitle: const Text(
                                "Versiones oficiales y probadas",
                              ),
                              onChanged: (UpdateChannel? val) {
                                Navigator.pop(dialogContext, val);
                              },
                            ),
                            RadioListTile<UpdateChannel>.adaptive(
                              value: UpdateChannel.beta,
                              groupValue: currentChannel,
                              title: const Text("Beta"),
                              subtitle: const Text(
                                "Versiones preliminares con novedades",
                              ),
                              onChanged: (UpdateChannel? val) {
                                Navigator.pop(dialogContext, val);
                              },
                            ),
                          ],
                        ),
                      );
                  if (selected != null && selected != currentChannel) {
                    await AppUpdater.setUpdateChannel(selected);
                    if (!mounted) return;
                    setState(() {});
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text("Canal cambiado a: ${selected.label}"),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              );
            },
          ),
          ListTile(
            title: const Text("Buscar actualizaciones"),
            subtitle: const Text(
              "Comprobar e instalar nueva versión de Fireflytonic",
            ),
            leading: const CircleAvatar(
              child: Icon(Icons.system_update_rounded),
            ),
            onTap: () async {
              final ScaffoldMessengerState messenger = ScaffoldMessenger.of(
                context,
              );
              messenger.showSnackBar(
                const SnackBar(
                  content: Text("Comprobando actualizaciones..."),
                  duration: Duration(seconds: 2),
                ),
              );
              try {
                final AppUpdateInfo? update = await AppUpdater.instance
                    .checkForUpdate(isManual: true);
                if (!context.mounted) return;
                if (update != null) {
                  await AppUpdater.showUpdateDialog(
                    context: context,
                    updateInfo: update,
                  );
                } else {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text("Ya tienes la última versión instalada."),
                    ),
                  );
                }
              } catch (e) {
                if (!context.mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text("Error al buscar actualizaciones: $e"),
                  ),
                );
              }
            },
          ),
        ],
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
