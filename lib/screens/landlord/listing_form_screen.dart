import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/room.dart';
import '../../providers/session_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/payment_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../utils/geo.dart';
import '../../utils/image_utils.dart';
import '../../utils/validators.dart';
import '../../widgets/app_image.dart';
import '../../widgets/common.dart';
import '../../widgets/map_widgets.dart';
import '../../widgets/payment_sheet.dart';

class ListingFormScreen extends StatefulWidget {
  final Room? existing;
  const ListingFormScreen({super.key, this.existing});

  @override
  State<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends State<ListingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _address;
  late final TextEditingController _campusName;
  late final TextEditingController _rent;
  late final TextEditingController _deposit;
  final _ruleInput = TextEditingController();
  String? _city;
  String _roomType = 'single';
  LatLng? _location;
  LatLng? _campus;
  List<String> _rules = [];
  List<String> _photos = [];
  bool _busy = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _title = TextEditingController(text: r?.title ?? '');
    _description = TextEditingController(text: r?.description ?? '');
    _address = TextEditingController(text: r?.address ?? '');
    _campusName = TextEditingController(text: r?.campusName ?? '');
    _rent = TextEditingController(text: r == null ? '' : r.rent.round().toString());
    _deposit =
        TextEditingController(text: r == null ? '' : r.deposit.round().toString());
    if (r != null) {
      _city = AppConstants.cities.containsKey(r.city) ? r.city : null;
      _roomType = AppConstants.roomTypes.contains(r.roomType) ? r.roomType : 'single';
      _location = LatLng(r.lat, r.lng);
      _campus = LatLng(r.campusLat, r.campusLng);
      _rules = [...r.rules];
      _photos = [...r.photos];
    }
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _address,
      _campusName,
      _rent,
      _deposit,
      _ruleInput
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _currency => AppConstants.cities[_city]?.currency ?? 'USD';
  LatLng get _cityCenter =>
      AppConstants.cities[_city]?.center ?? const LatLng(51.5072, -0.1276);

  Future<void> _pickLocation({required bool campus}) async {
    final current = campus ? _campus : _location;
    final result = await Navigator.of(context).push<LatLng>(MaterialPageRoute(
      builder: (_) => LocationPickerScreen(
        title: campus ? 'Campus location' : 'Room location',
        initial: current ?? _cityCenter,
        hasInitialPoint: current != null,
      ),
    ));
    if (result != null) {
      setState(() => campus ? _campus = result : _location = result);
    }
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= 3) return;
    try {
      final b64 = await ImageUtils.pickBase64();
      if (b64 != null) setState(() => _photos.add(b64));
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  void _addRule() {
    final t = _ruleInput.text.trim();
    if (t.isEmpty || _rules.contains(t)) return;
    setState(() {
      _rules.add(t);
      _ruleInput.clear();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_location == null) {
      showSnack(context, 'Tap "Set on map" to choose the room location',
          error: true);
      return;
    }
    if (_campus == null) {
      showSnack(context, 'Choose the nearby campus location', error: true);
      return;
    }
    final me = context.read<SessionProvider>().appUser!;
    final data = <String, dynamic>{
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'city': _city,
      'address': _address.text.trim(),
      'lat': _location!.latitude,
      'lng': _location!.longitude,
      'campusName': _campusName.text.trim(),
      'campusLat': _campus!.latitude,
      'campusLng': _campus!.longitude,
      'rent': double.parse(_rent.text.trim()),
      'deposit': double.parse(_deposit.text.trim()),
      'currency': _currency,
      'roomType': _roomType,
      'rules': _rules,
      'photos': _photos,
      'landlordId': me.uid,
      'landlordName': me.name,
    };

    setState(() => _busy = true);
    try {
      final fs = FirestoreService.instance;
      if (_editing) {
        final r = widget.existing!;
        // Rejected listings go back into the review queue after editing.
        if (r.status == RoomStatus.rejected) data['status'] = RoomStatus.pending;
        await fs.updateRoom(r.id, data);
        if (!mounted) return;
        showSnack(context, 'Listing updated');
        Navigator.pop(context);
        return;
      }
      final needsPayment = me.freeListingsUsed >= AppConstants.freeListings;
      if (needsPayment) {
        setState(() => _busy = false);
        final paid = await showPaymentSheet(
          context,
          userId: me.uid,
          amount: AppConstants.listingPrice,
          type: PaymentType.extraListing,
          title: 'Extra listing',
          description: 'Your 2 free listings are used',
        );
        if (!paid || !mounted) return;
        setState(() => _busy = true);
      }
      await fs.createRoom(data);
      await fs.updateUser(me.uid, {'freeListingsUsed': FieldValue.increment(1)});
      if (!mounted) return;
      showSnack(context, 'Listing submitted – pending admin approval');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<SessionProvider>().appUser;
    final needsPayment = !_editing &&
        (me?.freeListingsUsed ?? 0) >= AppConstants.freeListings;
    final campuses =
        AppConstants.campuses.where((c) => c.city == _city).toList();
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit listing' : 'New listing')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
          children: [
            if (!_editing)
              Card(
                color: (needsPayment ? AppColors.indigo : AppColors.success)
                    .withValues(alpha: 0.07),
                child: ListTile(
                  leading: Icon(
                      needsPayment
                          ? Icons.payments_outlined
                          : Icons.card_giftcard_rounded,
                      color: needsPayment ? AppColors.indigo : AppColors.success),
                  title: Text(needsPayment
                      ? 'This listing costs ${formatUsd(AppConstants.listingPrice)}'
                      : 'This listing is free'),
                  subtitle: Text(needsPayment
                      ? 'You have used your 2 free listings.'
                      : '${AppConstants.freeListings - (me?.freeListingsUsed ?? 0)} of 2 free listings left. New listings are reviewed by an admin.'),
                ),
              ),
            const SectionTitle('Photos (up to 3)'),
            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < _photos.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: AppImage(_photos[i], width: 140, height: 110),
                          ),
                          Positioned(
                            right: 4,
                            top: 4,
                            child: InkWell(
                              onTap: () => setState(() => _photos.removeAt(i)),
                              child: const CircleAvatar(
                                radius: 13,
                                backgroundColor: Colors.black54,
                                child: Icon(Icons.close_rounded,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_photos.length < 3)
                    InkWell(
                      onTap: _addPhoto,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 140,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined,
                                color: AppColors.primary),
                            SizedBox(height: 6),
                            Text('Add photo',
                                style: TextStyle(color: AppColors.primary)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SectionTitle('Details'),
            TextFormField(
              controller: _title,
              maxLength: 70,
              decoration: const InputDecoration(
                  labelText: 'Title', hintText: 'e.g. Bright ensuite near UCL'),
              validator: (v) => (v == null || v.trim().length < 8)
                  ? 'Title must be at least 8 characters'
                  : null,
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                  labelText: 'Description', alignLabelWithHint: true),
              validator: (v) => (v == null || v.trim().length < 20)
                  ? 'Describe the room (at least 20 characters)'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _city,
              decoration: const InputDecoration(labelText: 'City'),
              items: [
                for (final c in AppConstants.cities.values)
                  DropdownMenuItem(
                      value: c.name, child: Text('${c.name} (${c.currency})')),
              ],
              onChanged: (v) => setState(() => _city = v),
              validator: (v) => v == null ? 'Choose a city' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(
                  labelText: 'Full address',
                  prefixIcon: Icon(Icons.place_outlined)),
              validator: (v) => Validators.required(v, 'Address'),
            ),
            const SizedBox(height: 10),
            _LocationRow(
              label: 'Room location',
              value: _location,
              onTap: _city == null
                  ? () => showSnack(context, 'Choose a city first', error: true)
                  : () => _pickLocation(campus: false),
            ),
            const SectionTitle('Nearby campus'),
            if (campuses.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in campuses)
                    ChoiceChip(
                      label: Text(c.name),
                      selected: _campusName.text == c.name,
                      onSelected: (_) => setState(() {
                        _campusName.text = c.name;
                        _campus = LatLng(c.lat, c.lng);
                      }),
                    ),
                ],
              ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _campusName,
              decoration: const InputDecoration(
                  labelText: 'Campus name',
                  prefixIcon: Icon(Icons.school_outlined)),
              validator: (v) => Validators.required(v, 'Campus name'),
            ),
            const SizedBox(height: 10),
            _LocationRow(
              label: 'Campus location',
              value: _campus,
              onTap: () => _pickLocation(campus: true),
            ),
            if (_location != null && _campus != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Distance to campus: ${formatKm(haversineKm(_location!.latitude, _location!.longitude, _campus!.latitude, _campus!.longitude))}',
                  style: const TextStyle(
                      color: AppColors.indigo, fontWeight: FontWeight.w600),
                ),
              ),
            const SectionTitle('Price & type'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _rent,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: 'Monthly rent', suffixText: _currency),
                    validator: (v) => Validators.positiveNumber(v, 'Rent'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _deposit,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: 'Deposit', suffixText: _currency),
                    validator: (v) => Validators.positiveNumber(v, 'Deposit'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in AppConstants.roomTypes)
                  ChoiceChip(
                    label: Text(capitalize(t)),
                    selected: _roomType == t,
                    onSelected: (_) => setState(() => _roomType = t),
                  ),
              ],
            ),
            const SectionTitle('House rules'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ruleInput,
                    decoration:
                        const InputDecoration(hintText: 'e.g. No smoking'),
                    onSubmitted: (_) => _addRule(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                    onPressed: _addRule, icon: const Icon(Icons.add_rounded)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in _rules)
                  InputChip(
                    label: Text(r),
                    onDeleted: () => setState(() => _rules.remove(r)),
                  ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(_editing ? Icons.save_rounded : Icons.send_rounded),
            label: Text(_editing
                ? 'Save changes'
                : needsPayment
                    ? 'Pay ${formatUsd(AppConstants.listingPrice)} & submit'
                    : 'Submit for approval'),
          ),
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final String label;
  final LatLng? value;
  final VoidCallback onTap;
  const _LocationRow(
      {required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: value == null ? AppColors.border : AppColors.success),
      ),
      child: Row(
        children: [
          Icon(value == null ? Icons.map_outlined : Icons.check_circle_rounded,
              color: value == null ? AppColors.muted : AppColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value == null
                  ? '$label not set'
                  : '$label: ${value!.latitude.toStringAsFixed(4)}, ${value!.longitude.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          TextButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.touch_app_outlined, size: 18),
            label: const Text('Set on map'),
          ),
        ],
      ),
    );
  }
}
