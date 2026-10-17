import 'dart:convert';

import 'package:chopper/chopper.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/generated/l10n/app_localizations.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/settings.dart';
import 'package:waterflyiii/theme.dart';
import 'package:waterflyiii/widgets/ft_category_icon.dart';

final Logger log = Logger("Pages.Categories.AddEdit");

class CategoryAddEditDialog extends StatefulWidget {
  const CategoryAddEditDialog({super.key, this.category});

  final CategoryRead? category;

  @override
  State<CategoryAddEditDialog> createState() => _CategoryAddEditDialogState();
}

class _CategoryAddEditDialogState extends State<CategoryAddEditDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  bool loaded = false;
  bool includeInSum = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    if (widget.category == null) {
      loaded = true;
      return;
    }

    titleController.text = widget.category!.attributes.name;

    context
        .read<FireflyService>()
        .api
        .v1CategoriesIdGet(id: widget.category!.id)
        .then((Response<CategorySingle> resp) {
          if (!resp.isSuccessful || resp.body == null) {
            log.severe("Error fetching information", resp.error);
            if (mounted) {
              Navigator.of(context).pop();
            }
          }
          if (mounted) {
            setState(() {
              includeInSum = !context
                  .read<SettingsProvider>()
                  .categoriesSumExcluded
                  .contains(widget.category!.id);
              notesController.text = resp.body?.data.attributes.notes ?? "";
              loaded = true;
            });
          }
        });
  }

  @override
  void dispose() {
    titleController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.category != null;
    final String currentTitle = titleController.text.trim();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        !isEditing
            ? S.of(context).categoryTitleAdd
            : S.of(context).categoryTitleEdit,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      clipBehavior: Clip.hardEdge,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: <Widget>[
        if (isEditing)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.5),
              ),
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(MaterialLocalizations.of(context).deleteButtonTooltip),
            onPressed: _isSaving
                ? null
                : () async {
                    final FireflyIii api = context.read<FireflyService>().api;

                    final bool? ok = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext context) =>
                          const DeletionConfirmDialog(),
                    );
                    if (!(ok ?? false)) {
                      return;
                    }

                    setState(() {
                      _isSaving = true;
                    });

                    await api.v1CategoriesIdDelete(id: widget.category!.id);

                    if (context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
          ),
        TextButton(
          onPressed: _isSaving
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _isSaving
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) {
                    return;
                  }

                  setState(() {
                    _isSaving = true;
                  });

                  final ScaffoldMessengerState msg = ScaffoldMessenger.of(
                    context,
                  );

                  late Response<CategorySingle> resp;
                  try {
                    if (widget.category == null) {
                      resp = await context
                          .read<FireflyService>()
                          .api
                          .v1CategoriesPost(
                            body: CategoryStore(
                              name: titleController.text.trim(),
                              notes: notesController.text.trim(),
                            ),
                          );
                    } else {
                      resp = await context
                          .read<FireflyService>()
                          .api
                          .v1CategoriesIdPut(
                            id: widget.category!.id,
                            body: CategoryUpdate(
                              name: titleController.text.trim(),
                              notes: notesController.text.trim(),
                            ),
                          );
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() {
                        _isSaving = false;
                      });
                      msg.showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    return;
                  }

                  // Check if insert/update was successful
                  if (!resp.isSuccessful || resp.body == null) {
                    if (mounted) {
                      setState(() {
                        _isSaving = false;
                      });
                    }
                    late String error;
                    try {
                      final ValidationErrorResponse valError = .fromJson(
                        json.decode(resp.error.toString()),
                      );
                      error =
                          valError.message ??
                          (context.mounted
                              ? S.of(context).errorUnknown
                              : "[nocontext] Unknown error.");
                    } catch (_) {
                      error = context.mounted
                          ? S.of(context).errorUnknown
                          : "[nocontext] Unknown error.";
                    }

                    msg.showSnackBar(
                      SnackBar(
                        content: Text(error),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  if (context.mounted && widget.category != null) {
                    if (includeInSum) {
                      await context
                          .read<SettingsProvider>()
                          .categoryRemoveSumExcluded(widget.category!.id);
                    } else {
                      await context
                          .read<SettingsProvider>()
                          .categoryAddSumExcluded(widget.category!.id);
                    }
                  }
                  if (context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator.adaptive(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(MaterialLocalizations.of(context).saveButtonLabel),
        ),
      ],
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (currentTitle.isNotEmpty) ...<Widget>[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: FtCategoryIconWidget(
                        icon: FtCategoryIcon.forName(currentTitle),
                        color: FtColors.categoryColor(
                          currentTitle,
                          context: context,
                        ),
                        size: 32,
                        padding: 14,
                      ),
                    ),
                  ),
                ],
                TextFormField(
                  controller: titleController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.label_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelText: S.of(context).categoryFormLabelName,
                    hintText: 'ej. Supermercado, Restaurantes...',
                  ),
                  validator: (String? val) {
                    if (val == null || val.trim().isEmpty) {
                      return S.of(context).categoryFormLabelName;
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: notesController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.notes_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelText: S.of(context).transactionFormLabelNotes,
                  ),
                  enabled: loaded == true || widget.category == null,
                  minLines: 2,
                  maxLines: 4,
                ),
                if (isEditing) ...<Widget>[
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile.adaptive(
                      title: Text(
                        S.of(context).categoryFormLabelIncludeInSum,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Incluir los importes de esta categoría en los balances y totales globales.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      value: includeInSum,
                      isThreeLine: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      onChanged: loaded != true
                          ? null
                          : (bool value) => setState(() {
                              includeInSum = value;
                            }),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DeletionConfirmDialog extends StatelessWidget {
  const DeletionConfirmDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: Icon(
        Icons.warning_amber_rounded,
        color: Theme.of(context).colorScheme.error,
        size: 32,
      ),
      title: Text(
        S.of(context).categoryTitleDelete,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      clipBehavior: Clip.hardEdge,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: <Widget>[
        TextButton(
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onError,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(MaterialLocalizations.of(context).deleteButtonTooltip),
          onPressed: () {
            Navigator.of(context).pop(true);
          },
        ),
      ],
      content: Text(
        S.of(context).categoryDeleteConfirm,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
