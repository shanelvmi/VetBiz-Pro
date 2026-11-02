import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/sentence_capitalization_formatter.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/transaction_provider.dart';
import '../../providers/facility_provider.dart';
import '../../models/transaction.dart';
import '../../services/auth_service.dart';
import '../../widgets/payment_method_selector.dart';
import '../../utils/thousands_input_formatter.dart';
import '../../data/collections.dart';
import '../../config/money.dart';
import '../../config/app_defaults.dart';
import '../../config/payment_methods.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_layout.dart';
import '../../ui/feedback/app_feedback.dart';
import '../../widgets/field_message_slot.dart';
import '../../widgets/phone_form/form_action_bar.dart';
import '../../widgets/phone_form/phone_discard_scope.dart';
import '../../widgets/phone_form/picker_sheet.dart';
import '../../l10n/l10n.dart';
import '../../constants/transaction_categories.dart';
import '../../widgets/app_sheet.dart';
import '../../utils/subscription_guard.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? transaction;
  final bool isModal;

  /// Null: the app's own Firestore. Tests pass an in-memory one (PH2a).
  final FirebaseFirestore? firestore;

  /// Null: a new AuthService (the app's own sign-in). Tests pass a fake (PH2a),
  /// as LoginScreen.authService.
  final AuthService? authService;

  const AddTransactionScreen({super.key, this.transaction, this.isModal = false, this.firestore, this.authService});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  // Null widget.firestore: the app's own Firestore (PH2a seam).
  FirebaseFirestore get _db => widget.firestore ?? FirebaseFirestore.instance;

  bool _isSaving = false;
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  String? selectedCategory;
  String? type = 'expense';
  String? paymentMethod;

  // PH6 (phones only): a save with an entry missing shows "Required" in the
  // line kept under each field, instead of the message at the bottom; and
  // leaving after typing asks first (PhoneDiscardScope).
  bool _attempted = false;
  late final String _initialEntries;

  bool get _isPhone => AppLayout.isPhone(context);

  String get _entries => [type, selectedCategory, descriptionController.text, amountController.text, noteController.text, paymentMethod]
      .join('\u0001');


  late final AuthService _authService = widget.authService ?? AuthService();


  Future<String?> _fetchCurrentUserFullName() async {
    final user = _authService.getCurrentUser();
    if (user == null) return null;

    final doc = await _db.collection(Collections.users).doc(user.uid).get();
    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    return data['fullName'] as String?;
  }

  void _saveTransaction(BuildContext context) async {
    if (_isSaving) return; // guards against a double-tap firing two saves at once

    final description = descriptionController.text.trim();

    // Remove commas to parse
    final amount = parseThousands(amountController.text);
    final category = selectedCategory ?? '';
    final note = noteController.text.trim().isEmpty ? null : noteController.text.trim();

    if (description.isEmpty || amount <= 0 || type == null || category.isEmpty) {
      if (_isPhone) return setState(() => _attempted = true);
      AppFeedback.warning(L10n.current.transactions_fillRequired);
      return;
    }

    if (paymentMethod == null) {
      if (_isPhone) return setState(() => _attempted = true);
      AppFeedback.warning(L10n.current.transactions_selectPaymentMethod);
      return;
    }

    setState(() => _isSaving = true);

    final provider = Provider.of<TransactionProvider>(context, listen: false);
    // Read before the awaits below, so the save still uses this facility.
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;

    if (widget.transaction != null) {
      // Editing - keep the original id, date, and who recorded it; only
      // the fields the user can actually change here get updated. Built
      // directly rather than via copyWith, since copyWith's standard
      // null-coalescing can't actually clear paymentMethod back to null
      // when switching from other income to expense - it would just
      // silently keep the stale value instead.
      final updated = TransactionModel(
        id: widget.transaction!.id,
        date: widget.transaction!.date,
        description: description,
        amount: amount,
        type: type!,
        category: category,
        recordedBy: widget.transaction!.recordedBy,
        paymentMethod: paymentMethod,
        note: note,
      );
      try {
        await provider.updateTransaction(updated, facilityId);
        if (!context.mounted) return;
        AppFeedback.success(L10n.current.transactions_updated);
        Navigator.pop(context);
      } catch (e, st) {
        AppFeedback.error(L10n.current.transactions_updateFailed, error: e, stackTrace: st);
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
      return;
    }

    String? userName = await _fetchCurrentUserFullName();
    if (userName == null || userName.isEmpty) {
      userName = 'Unknown User';
    }

    final newTx = TransactionModel(
      id: '',
      date: DateTime.now(),
      description: description,
      amount: amount,
      type: type!, // stored lowercase
      category: category,
      recordedBy: userName,
      paymentMethod: paymentMethod,
      note: note,
    );

    try {
      await provider.addTransaction(newTx, facilityId);
      if (!context.mounted) return;

      AppFeedback.success(L10n.current.transactions_saved);

      Navigator.pop(context);
    } catch (e, st) {
      AppFeedback.error(L10n.current.transactions_saveFailed, error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void initState() {
    super.initState();

    if (widget.transaction != null) {
      final tx = widget.transaction!;
      type = tx.type;
      descriptionController.text = tx.description;
      selectedCategory = tx.category.isEmpty ? null : tx.category;
      amountController.text = Money.plain(tx.amount.round());
      paymentMethod = tx.paymentMethod;
      noteController.text = tx.note ?? '';
    }
    _initialEntries = _entries;
  }

  @override
  void dispose() {
    descriptionController.dispose();
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.transaction != null;

    final body = LayoutBuilder(
      builder: (context, constraints) {
        final isTwoColumn = constraints.maxWidth >= AppBreakpoints.formTwoColumn;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: isTwoColumn
                  ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: _buildTransactionDetailsCard()),
                          const SizedBox(width: AppSpacing.s16),
                          Expanded(flex: 1, child: _buildAmountPaymentCard()),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        _buildTransactionDetailsCard(),
                        const SizedBox(height: AppSpacing.s16),
                        _buildAmountPaymentCard(),
                      ],
                    ),
            ),
          ),
        );
      },
    );

    final scaffold = Scaffold(
      backgroundColor: context.colors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          color: context.colors.brandSurface,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Icon(Icons.receipt_long_outlined, color: context.colors.onBrandSurface, size: AppIconSize.i22),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(isEditing ? context.l10n.transactions_edit : context.l10n.transactions_record,
                      style: TextStyle(color: context.colors.onBrandSurface, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f18)),
                ),
                if (widget.isModal)
                  IconButton(
                    icon: Icon(Icons.close, color: context.colors.onBrandSurface),
                    tooltip: context.l10n.common_close,
                    onPressed: () => Navigator.of(context).pop(),
                  )
                else
                  BackButton(color: context.colors.onBrandSurface),
              ],
            ),
          ),
        ),
      ),
      body: _isPhone ? closeKeyboardOnTapOutside(context, body) : body,
      bottomNavigationBar: _isPhone
          ? FormActionBar(
              primaryLabel: isEditing ? context.l10n.transactions_update : context.l10n.transactions_record,
              primaryIcon: Icons.receipt_long_outlined,
              onPrimary: () => _saveTransaction(context),
              busy: _isSaving,
              secondaryLabel: context.l10n.common_cancel,
              onSecondary: () => Navigator.of(context).maybePop(),
            )
          : _buildFooter(isEditing),
    );
    if (!_isPhone) return scaffold;
    return PhoneDiscardScope(kind: 'transaction', isDirty: () => _entries != _initialEntries, child: scaffold);
  }

  // ==================== PHONE (PH6) ====================

  /// A field's label: 14 on a phone (S3), as before elsewhere.
  Widget _label(String text) => Text(text,
      style: TextStyle(fontWeight: AppFontWeight.semibold, fontSize: _isPhone ? PhoneFormMetrics.label : AppFontSize.f13));

  /// The line kept under a field on a phone: "Required" once a save found
  /// it empty, so the form never changes height (the G5 technique).
  Widget _phoneError(bool missing) => FieldMessageSlot(
        message: _attempted && missing ? context.l10n.common_required : null,
        reserve: [context.l10n.common_required],
        maxLines: 1,
        style: TextStyle(fontSize: PhoneFormMetrics.error, color: context.colors.danger),
      );

  /// A picker's field on a phone: the chosen label (or the placeholder),
  /// at least 48 high; a tap opens the picker's sheet.
  Widget _phoneChoiceField({required String text, required bool chosen, IconData? icon, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.r10),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: PhoneFormMetrics.fieldMinHeight),
        padding: const EdgeInsets.symmetric(horizontal: PhoneFormMetrics.fieldPaddingH),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.r10),
          border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a40)),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: AppIconSize.i18, color: context.colors.primary),
              const SizedBox(width: AppSpacing.s10),
            ],
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: PhoneFormMetrics.body, color: chosen ? context.colors.textPrimary : context.colors.textHint)),
            ),
            Icon(Icons.expand_more, size: AppIconSize.i18, color: context.colors.textMuted),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTypePhone() async {
    final picked = await showPickerSheet<String>(
      context,
      title: context.l10n.common_type,
      selected: type,
      options: [
        for (final t in const ['other income', 'expense']) PickerOption(t, _toTitleCase(context.l10n.transactionTypeLabel(t))),
      ],
    );
    if (picked == null) return;
    // As the dropdown: a category picked under one type is cleared.
    setState(() {
      type = picked;
      selectedCategory = null;
    });
  }

  Future<void> _pickCategoryPhone() async {
    final l10n = context.l10n;
    final picked = await showPickerSheet<String>(
      context,
      title: l10n.transactions_selectCategoryTitle,
      selected: selectedCategory,
      searchHint: l10n.transactions_searchCategories,
      emptyText: l10n.transactions_noCategories,
      // Typed text matches the stored category, as before, or the label shown.
      matches: (o, q) => o.value.toLowerCase().contains(q),
      options: type == 'expense'
          ? [
              for (final group in kExpenseCategoryGroups.entries)
                for (final c in group.value)
                  PickerOption(c, l10n.transactionCategoryLabel(c), group: l10n.expenseGroupLabel(group.key)),
            ]
          : [for (final c in kIncomeCategories) PickerOption(c, l10n.transactionCategoryLabel(c))],
    );
    if (picked != null) setState(() => selectedCategory = picked);
  }

  Future<void> _pickMethodPhone() async {
    final picked = await showPickerSheet<String>(
      context,
      title: context.l10n.payments_method,
      selected: paymentMethod,
      options: [
        for (final m in kPaymentMethods) PickerOption(m, context.l10n.paymentMethodLabel(m), icon: iconForPaymentMethod(m)),
      ],
    );
    if (picked != null) setState(() => paymentMethod = picked);
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: AppIconSize.i18, color: context.colors.primary),
        const SizedBox(width: AppSpacing.s8),
        // On a phone the title wraps (Kiswahili at 360); elsewhere as before.
        if (_isPhone)
          Flexible(child: Text(title, style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15, color: context.colors.primary)))
        else
          Text(title, style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15, color: context.colors.primary)),
      ],
    );
  }

  InputDecoration _fieldDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: context.colors.surface,
      isDense: true,
      // At least 48 high on a phone (PH6).
      contentPadding: _isPhone
          ? const EdgeInsets.symmetric(vertical: PhoneFormMetrics.fieldPaddingV, horizontal: PhoneFormMetrics.fieldPaddingH)
          : const EdgeInsets.symmetric(vertical: AppSpacing.s12, horizontal: AppSpacing.s12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.r10),
        borderSide: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a40)),
      ),
    );
  }

  // Title case (capitalize each word)
  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}').join(' ');
  }

  Widget _buildTransactionDetailsCard() {
    const dropdownOptions = ['other income', 'expense'];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.swap_horiz, context.l10n.transactions_detailsTitle),
          const SizedBox(height: AppSpacing.s14),
          _label(context.l10n.common_requiredLabel(context.l10n.common_type)),
          const SizedBox(height: AppSpacing.s6),
          if (_isPhone)
            _phoneChoiceField(
              text: _toTitleCase(context.l10n.transactionTypeLabel(type ?? '')),
              chosen: type != null,
              onTap: _pickTypePhone,
            )
          else
          DropdownButtonFormField<String>(
            initialValue: type,
            items: dropdownOptions.map((val) {
              return DropdownMenuItem(value: val, child: Text(_toTitleCase(context.l10n.transactionTypeLabel(val))));
            }).toList(),
            onChanged: (val) => setState(() {
              type = val;
              // A category picked under one type rarely makes sense
              // under the other (an expense category shouldn't
              // silently persist after switching to income) - clear it
              // rather than leave a mismatched selection in place.
              selectedCategory = null;
            }),
            decoration: _fieldDecoration(),
          ),
          const SizedBox(height: AppSpacing.s14),
          _label(context.l10n.common_requiredLabel(context.l10n.common_category)),
          const SizedBox(height: AppSpacing.s6),
          if (_isPhone) ...[
            _phoneChoiceField(
              text: selectedCategory == null
                  ? context.l10n.transactions_selectCategory
                  : context.l10n.transactionCategoryLabel(selectedCategory!),
              chosen: selectedCategory != null,
              onTap: _pickCategoryPhone,
            ),
            _phoneError(selectedCategory == null),
          ] else
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.r10),
            onTap: _showCategoryPickerDialog,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s12),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.r10),
                border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a40)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedCategory == null ? context.l10n.transactions_selectCategory : context.l10n.transactionCategoryLabel(selectedCategory!),
                      style: TextStyle(
                        fontSize: AppFontSize.f14,
                        color: selectedCategory != null ? context.colors.textPrimary : context.colors.textHint,
                      ),
                    ),
                  ),
                  Icon(Icons.expand_more, size: AppIconSize.i18, color: context.colors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s14),
          _label(context.l10n.common_requiredLabel(context.l10n.common_description)),
          const SizedBox(height: AppSpacing.s6),
          TextField(
            controller: descriptionController,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [SentenceCapitalizationFormatter()],
            decoration: _fieldDecoration(hintText: context.l10n.transactions_descriptionHint),
            textInputAction: _isPhone ? TextInputAction.next : null,
            onChanged: _isPhone ? (_) => _attempted ? setState(() {}) : null : null,
          ),
          if (_isPhone) _phoneError(descriptionController.text.trim().isEmpty),
          const SizedBox(height: AppSpacing.s14),
          _label(context.l10n.transactions_noteLabel),
          const SizedBox(height: AppSpacing.s6),
          TextField(
            controller: noteController,
            maxLines: 4,
            minLines: 4,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [SentenceCapitalizationFormatter()],
            decoration: _fieldDecoration(hintText: context.l10n.transactions_noteHint),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountPaymentCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.receipt_long_outlined, context.l10n.transactions_amountPayment),
          const SizedBox(height: AppSpacing.s14),
          _label(context.l10n.transactions_amountRequired(AppDefaults.currencySymbol)),
          const SizedBox(height: AppSpacing.s6),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
            decoration: _fieldDecoration(hintText: '0.00'),
            textInputAction: _isPhone ? TextInputAction.done : null,
            onChanged: _isPhone ? (_) => _attempted ? setState(() {}) : null : null,
          ),
          if (_isPhone) _phoneError(parseThousands(amountController.text) <= 0),
          const SizedBox(height: AppSpacing.s16),
          Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: AppAlpha.a05),
                borderRadius: BorderRadius.circular(AppRadius.r12),
                border: Border.all(color: context.colors.primary.withValues(alpha: AppAlpha.a15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.credit_card_outlined, size: AppIconSize.i16, color: context.colors.primary),
                      const SizedBox(width: AppSpacing.s8),
                      Text(context.l10n.payments_method,
                          style: TextStyle(
                              fontWeight: AppFontWeight.semibold,
                              fontSize: _isPhone ? PhoneFormMetrics.label : AppFontSize.f13,
                              color: context.colors.primary)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s10),
                  if (_isPhone) ...[
                    _phoneChoiceField(
                      text: paymentMethod == null
                          ? context.l10n.transactions_selectMethod
                          : context.l10n.paymentMethodLabel(paymentMethod!),
                      chosen: paymentMethod != null,
                      icon: iconForPaymentMethod(paymentMethod ?? PaymentMethod.cash.key),
                      onTap: _pickMethodPhone,
                    ),
                    _phoneError(paymentMethod == null),
                  ] else
                  PopupMenuButton<String>(
                    initialValue: paymentMethod,
                    onSelected: (method) => setState(() => paymentMethod = method),
                    itemBuilder: (context) => kPaymentMethods.map((method) {
                      return PopupMenuItem(
                        value: method,
                        child: Row(
                          children: [
                            Icon(iconForPaymentMethod(method), size: AppIconSize.i18, color: context.colors.primary),
                            const SizedBox(width: AppSpacing.s10),
                            Text(context.l10n.paymentMethodLabel(method)),
                          ],
                        ),
                      );
                    }).toList(),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.r10),
                        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
                      ),
                      child: Row(
                        children: [
                          Icon(iconForPaymentMethod(paymentMethod ?? PaymentMethod.cash.key), size: AppIconSize.i18, color: context.colors.primary),
                          const SizedBox(width: AppSpacing.s10),
                          Expanded(child: Text(paymentMethod == null ? context.l10n.transactions_selectMethod : context.l10n.paymentMethodLabel(paymentMethod!))),
                          Icon(Icons.expand_more, size: AppIconSize.i18, color: context.colors.textMuted),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // The category picker - grouped section headers for expenses
  // (matching the proposed structure), a flat list for income. Same
  // dialog pattern already established for Browse Products elsewhere
  // in this app: a search field plus a scrollable list, rather than a
  // cramped inline dropdown that can't comfortably hold 15+ grouped
  // options.
  Future<void> _showCategoryPickerDialog() async {
    final isExpense = type == 'expense';
    String query = '';

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final lowerQuery = query.trim().toLowerCase();
            bool matchesQuery(String c) =>
                c.toLowerCase().contains(lowerQuery) ||
                context.l10n.transactionCategoryLabel(c).toLowerCase().contains(lowerQuery);

            Widget content;
            if (isExpense) {
              final filteredGroups = <String, List<String>>{};
              for (final entry in kExpenseCategoryGroups.entries) {
                // Typed text matches the stored category, as before, or the label shown.
                final matches = entry.value.where(matchesQuery).toList();
                if (matches.isNotEmpty) filteredGroups[entry.key] = matches;
              }
              content = filteredGroups.isEmpty
                  ? Center(child: Text(context.l10n.transactions_noCategories))
                  : ListView(
                      children: filteredGroups.entries.expand((entry) {
                        return [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.s4, AppSpacing.s12, AppSpacing.s4, AppSpacing.s4),
                            child: Text(context.l10n.expenseGroupLabel(entry.key),
                                style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f12_5, color: context.colors.primary)),
                          ),
                          ...entry.value.map((category) => ListTile(
                                dense: true,
                                title: Text(context.l10n.transactionCategoryLabel(category)),
                                trailing: selectedCategory == category
                                    ? Icon(Icons.check, size: AppIconSize.i18, color: context.colors.primary)
                                    : null,
                                onTap: () {
                                  setState(() => selectedCategory = category);
                                  Navigator.pop(dialogContext);
                                },
                              )),
                        ];
                      }).toList(),
                    );
            } else {
              final filtered = kIncomeCategories.where(matchesQuery).toList();
              content = filtered.isEmpty
                  ? Center(child: Text(context.l10n.transactions_noCategories))
                  : ListView(
                      children: filtered
                          .map((category) => ListTile(
                                dense: true,
                                title: Text(context.l10n.transactionCategoryLabel(category)),
                                trailing: selectedCategory == category
                                    ? Icon(Icons.check, size: AppIconSize.i18, color: context.colors.primary)
                                    : null,
                                onTap: () {
                                  setState(() => selectedCategory = category);
                                  Navigator.pop(dialogContext);
                                },
                              ))
                          .toList(),
                    );
            }

            return AlertDialog(
              title: Text(context.l10n.transactions_selectCategoryTitle),
              content: SizedBox(
                width: 420,
                height: 440,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: context.l10n.transactions_searchCategories,
                        prefixIcon: const Icon(Icons.search, size: AppIconSize.i20),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
                      ),
                      onChanged: (val) => setDialogState(() => query = val),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Expanded(child: content),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(context.l10n.common_cancel)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFooter(bool isEditing) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.s20, AppSpacing.s14, AppSpacing.s20, AppSpacing.s14 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a15))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.close, size: AppIconSize.i16),
            label: Text(context.l10n.common_cancel),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.textPrimary,
              side: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a40)),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20, vertical: AppSpacing.s12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
            ),
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            onPressed: _isSaving ? null : () => _saveTransaction(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.background,
              disabledBackgroundColor: context.colors.primary.withValues(alpha: AppAlpha.a50),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s22, vertical: AppSpacing.s12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
            ),
            child: _isSaving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: AppIconSize.i16),
                      const SizedBox(width: AppSpacing.s8),
                      Text(isEditing ? context.l10n.transactions_update : context.l10n.transactions_record),
                      const SizedBox(width: AppSpacing.s6),
                      const Icon(Icons.arrow_forward, size: AppIconSize.i16),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// The one entry point for opening Add/Edit Transaction - same
/// reasoning and threshold as showAddSaleScreen elsewhere in this app:
/// a full-screen push on mobile, a large, centered, dismissable modal
/// on desktop/tablet-width screens.
///
/// A new transaction goes through the locked-facility guard (PH6 finding a:
/// every entry point, at every width, gets the friendly locked message and
/// no form); editing an existing one does not.
Future<void> showAddTransactionScreen(BuildContext context, {TransactionModel? transaction}) async {
  Future<void> open() => showAdaptiveForm(
        context,
        barrierLabel: transaction != null ? context.l10n.transactions_edit : context.l10n.transactions_record,
        size: AdaptiveFormSize.formCapped,
        builder: (isModal) => AddTransactionScreen(transaction: transaction, isModal: isModal),
      );
  if (transaction != null) return open();
  await navigateOrShowLockedDialog(context, const AddTransactionScreen(), onNavigate: open);
}
