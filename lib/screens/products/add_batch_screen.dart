import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../providers/facility_provider.dart';
import '../../utils/thousands_input_formatter.dart';
import '../../config/money.dart';
import '../../config/app_defaults.dart';
import '../../config/app_ranges.dart';
import '../../data/data_keys.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_motion.dart';
import '../../ui/feedback/app_feedback.dart';
import '../../l10n/l10n.dart';

/// Records a new delivery of an existing product as its own batch - a
/// separate batch number, expiry, and quantity, never overwriting an
/// existing batch's real data. This is the fix for "adding stock changes
/// the expiry of stock already there".
class AddBatchScreen extends StatefulWidget {
  final Product product;
  final bool isModal;
  const AddBatchScreen({super.key, required this.product, this.isModal = false});

  @override
  State<AddBatchScreen> createState() => _AddBatchScreenState();
}

class _AddBatchScreenState extends State<AddBatchScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _batchController;
  late final TextEditingController _quantityController;
  late final TextEditingController _buyPriceController;
  late final TextEditingController _expiryController;
  DateTime? _selectedExpiry;
  bool _isSaving = false;
  // Real deliveries don't always go through the Stock Store first - a
  // small top-up picked up on the way to the counter can go straight to
  // the shelf instead.
  String _destination = 'stock';

  @override
  void initState() {
    super.initState();
    _batchController = TextEditingController();
    _quantityController = TextEditingController();
    _buyPriceController = TextEditingController(
      text: Money.decimal(widget.product.buyPrice.round()),
    );
    _expiryController = TextEditingController();
  }

  @override
  void dispose() {
    _batchController.dispose();
    _quantityController.dispose();
    _buyPriceController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(AppRanges.year),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedExpiry = picked;
        _expiryController.text = DateFormat(DataKeys.isoDay).format(picked);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) return;

    setState(() => _isSaving = true);

    try {
      final wasMerged = await Provider.of<ProductProvider>(context, listen: false).addBatch(
        facilityId: facilityId,
        productId: widget.product.id,
        batchNo: _batchController.text.trim().isEmpty ? null : _batchController.text.trim(),
        expiry: _selectedExpiry,
        buyPrice: _buyPriceController.text.trim().isEmpty
            ? widget.product.buyPrice
            : parseThousands(_buyPriceController.text),
        stockQty: int.tryParse(_quantityController.text.trim()) ?? 0,
        destination: _destination,
      );

      if (!mounted) return;
      Navigator.pop(context);
      AppFeedback.success(
        wasMerged
            ? L10n.current.batch_mergedIntoExisting
            : L10n.current.batch_added,
      );
    } catch (e, st) {
      AppFeedback.error(L10n.current.batch_addFailed, error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.products_addNewBatch),
        centerTitle: true,
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
        automaticallyImplyLeading: !widget.isModal,
        leading: widget.isModal
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: context.l10n.common_close,
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.s16),
              children: [
                Text(widget.product.name, style: const TextStyle(fontSize: AppFontSize.f18, fontWeight: AppFontWeight.bold)),
                Text(
                  context.l10n.batch_addIntro,
                  style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted),
                ),
                const SizedBox(height: AppSpacing.s20),
                TextFormField(
                  controller: _batchController,
                  decoration: InputDecoration(labelText: context.l10n.batch_batchNoOptional, border: const OutlineInputBorder()),
                ),
                const SizedBox(height: AppSpacing.s12),
                TextFormField(
                  controller: _expiryController,
                  readOnly: true,
                  onTap: _pickExpiry,
                  decoration: InputDecoration(
                    labelText: context.l10n.batch_expiryDate,
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                Text(context.l10n.batch_addStockTo, style: const TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13)),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(context.l10n.store_title),
                  subtitle: Text(context.l10n.batch_storeHint, style: const TextStyle(fontSize: AppFontSize.f11_5)),
                  value: 'stock',
                  groupValue: _destination,
                  activeColor: context.colors.primary,
                  onChanged: (value) => setState(() => _destination = value!),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(context.l10n.batch_sellableOption),
                  subtitle: Text(context.l10n.batch_sellableHint, style: const TextStyle(fontSize: AppFontSize.f11_5)),
                  value: 'sellable',
                  groupValue: _destination,
                  activeColor: context.colors.primary,
                  onChanged: (value) => setState(() => _destination = value!),
                ),
                const SizedBox(height: AppSpacing.s8),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: context.l10n.batch_quantityReceived, border: const OutlineInputBorder()),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0) return context.l10n.batch_validQuantity;
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s12),
                TextFormField(
                  controller: _buyPriceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
                  decoration: InputDecoration(labelText: context.l10n.batch_buyPriceLabel(AppDefaults.currencySymbol), border: const OutlineInputBorder()),
                ),
                const SizedBox(height: AppSpacing.s24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary, foregroundColor: context.colors.onPrimary),
                    child: _isSaving
                        ? SizedBox(width: AppSpacing.s22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: context.colors.onPrimary))
                        : Text(context.l10n.batch_addBatch),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The one entry point for opening Add Batch - same reasoning and
/// threshold as showAddSaleScreen elsewhere in this app: a full-screen
/// push on mobile, a large, centered, dismissable modal on
/// desktop/tablet-width screens.
Future<void> showAddBatchScreen(BuildContext context, {required Product product}) async {
  final isWideScreen = MediaQuery.of(context).size.width >= AppBreakpoints.medium;

  if (!isWideScreen) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddBatchScreen(product: product)),
    );
    return;
  }

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.l10n.batch_addBatch,
    barrierColor: context.colors.scrim.withValues(alpha: AppAlpha.a50),
    transitionDuration: AppMotion.normal,
    pageBuilder: (context, animation, secondaryAnimation) {
      final screenSize = MediaQuery.of(context).size;
      final modalWidth = (screenSize.width * 0.60).clamp(0, 940).toDouble();
      // Never shorter than 480px, fixed - 88% of screen height
      // comfortably exceeds that on most windows, but this guarantees
      // it even on a smaller one.
      final modalHeight = (screenSize.height * 0.88) < 480 ? 480.0 : screenSize.height * 0.88;
      return Center(
        child: SizedBox(
          width: modalWidth,
          height: modalHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r16),
            child: Material(
              child: AddBatchScreen(product: product, isModal: true),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}
