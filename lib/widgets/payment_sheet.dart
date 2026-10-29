import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/payment_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'common.dart';

/// Shows the simulated checkout. Resolves to true only if payment succeeded.
Future<bool> showPaymentSheet(
  BuildContext context, {
  required String userId,
  required double amount,
  required String type,
  required String title,
  required String description,
  String refId = '',
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PaymentSheet(
      userId: userId,
      amount: amount,
      type: type,
      title: title,
      description: description,
      refId: refId,
    ),
  );
  return ok ?? false;
}

enum _Stage { form, processing, success, failed }

class _PaymentSheet extends StatefulWidget {
  final String userId;
  final double amount;
  final String type;
  final String title;
  final String description;
  final String refId;

  const _PaymentSheet({
    required this.userId,
    required this.amount,
    required this.type,
    required this.title,
    required this.description,
    required this.refId,
  });

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _card = TextEditingController();
  final _expiry = TextEditingController();
  final _cvc = TextEditingController();
  final _name = TextEditingController();
  _Stage _stage = _Stage.form;
  String _error = '';

  @override
  void dispose() {
    _card.dispose();
    _expiry.dispose();
    _cvc.dispose();
    _name.dispose();
    super.dispose();
  }

  void _fillTestCard({bool failing = false}) {
    setState(() {
      _card.text = failing ? '4000 0000 0000 0002' : '4242 4242 4242 4242';
      _expiry.text = '12/29';
      _cvc.text = '123';
      if (_name.text.isEmpty) _name.text = 'Demo Student';
    });
  }

  Future<void> _pay() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _stage = _Stage.processing);
    try {
      await PaymentService().pay(
        userId: widget.userId,
        amount: widget.amount,
        type: widget.type,
        cardNumber: _card.text,
        refId: widget.refId,
      );
      if (!mounted) return;
      setState(() => _stage = _Stage.success);
    } on PaymentDeclined catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.failed;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.failed;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: switch (_stage) {
          _Stage.form => _form(),
          _Stage.processing => _processing(),
          _Stage.success => _success(),
          _Stage.failed => _failed(),
        },
      ),
    );
  }

  Widget _header() => Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lock_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 17)),
                Text(widget.description,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12.5)),
              ],
            ),
          ),
          Text(formatUsd(widget.amount),
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: AppColors.primary)),
        ],
      );

  Widget _form() {
    return SingleChildScrollView(
      key: const ValueKey('form'),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            const SizedBox(height: 18),
            TextFormField(
              controller: _card,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(16),
                _CardNumberFormatter(),
              ],
              decoration: const InputDecoration(
                labelText: 'Card number',
                hintText: '4242 4242 4242 4242',
                prefixIcon: Icon(Icons.credit_card_rounded),
              ),
              validator: (v) {
                final d = (v ?? '').replaceAll(' ', '');
                return d.length != 16 ? 'Enter a 16-digit card number' : null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _expiry,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                      _ExpiryFormatter(),
                    ],
                    decoration: const InputDecoration(
                        labelText: 'Expiry', hintText: 'MM/YY'),
                    validator: _validateExpiry,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cvc,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: const InputDecoration(
                        labelText: 'CVC', hintText: '123'),
                    validator: (v) =>
                        (v ?? '').length < 3 ? 'Invalid CVC' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name on card',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (v) =>
                  (v ?? '').trim().length < 2 ? 'Enter the cardholder name' : null,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.bolt_rounded, size: 16),
                  label: const Text('Use test card'),
                  onPressed: () => _fillTestCard(),
                ),
                ActionChip(
                  avatar: const Icon(Icons.block_rounded, size: 16),
                  label: const Text('Declining card'),
                  onPressed: () => _fillTestCard(failing: true),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _pay,
              icon: const Icon(Icons.lock_outline_rounded, size: 18),
              label: Text('Pay ${formatUsd(widget.amount)}'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Demo checkout – no real money is charged.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateExpiry(String? v) {
    final s = (v ?? '').replaceAll('/', '');
    if (s.length != 4) return 'MM/YY';
    final m = int.tryParse(s.substring(0, 2)) ?? 0;
    final y = int.tryParse(s.substring(2)) ?? 0;
    if (m < 1 || m > 12) return 'Invalid month';
    final now = DateTime.now();
    final exp = DateTime(2000 + y, m + 1);
    if (exp.isBefore(now)) return 'Card expired';
    return null;
  }

  Widget _processing() => const SizedBox(
        key: ValueKey('processing'),
        height: 260,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
                width: 54,
                height: 54,
                child: CircularProgressIndicator(strokeWidth: 5)),
            SizedBox(height: 20),
            Text('Processing payment…',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            SizedBox(height: 4),
            Text('Contacting your bank securely',
                style: TextStyle(color: AppColors.muted)),
          ],
        ),
      );

  Widget _success() => SizedBox(
        key: const ValueKey('success'),
        height: 300,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1),
              duration: const Duration(milliseconds: 450),
              curve: Curves.elasticOut,
              builder: (_, s, child) => Transform.scale(scale: s, child: child),
              child: const CircleAvatar(
                radius: 38,
                backgroundColor: AppColors.success,
                child: Icon(Icons.check_rounded, color: Colors.white, size: 44),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Payment successful',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19)),
            const SizedBox(height: 4),
            Text(
              '${formatUsd(widget.amount)} paid for ${PaymentType.label(widget.type).toLowerCase()}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

  Widget _failed() => SizedBox(
        key: const ValueKey('failed'),
        height: 320,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CircleAvatar(
              radius: 38,
              backgroundColor: AppColors.danger,
              child: Icon(Icons.close_rounded, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 18),
            const Text('Payment failed',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19)),
            const SizedBox(height: 4),
            Text(_error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => setState(() => _stage = _Stage.form),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(' ', '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final s = buf.toString();
    return TextEditingValue(
        text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('/', '');
    final s = digits.length > 2
        ? '${digits.substring(0, 2)}/${digits.substring(2)}'
        : digits;
    return TextEditingValue(
        text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}
