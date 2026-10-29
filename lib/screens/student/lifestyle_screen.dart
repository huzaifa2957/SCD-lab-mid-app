import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/session_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/common.dart';

class LifestyleScreen extends StatefulWidget {
  const LifestyleScreen({super.key});

  @override
  State<LifestyleScreen> createState() => _LifestyleScreenState();
}

class _LifestyleScreenState extends State<LifestyleScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _course;
  late final TextEditingController _university;
  late final TextEditingController _budget;
  late final TextEditingController _bio;
  late Set<String> _languages;
  late String _sleep;
  late double _clean;
  late String _diet;
  late String _smoking;
  String? _city;
  late PrivacySettings _privacy;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<SessionProvider>().appUser!;
    final l = u.lifestyle;
    _course = TextEditingController(text: l.course);
    _university = TextEditingController(text: l.university);
    _budget = TextEditingController(text: l.budget.round().toString());
    _bio = TextEditingController(text: l.bio);
    _languages = {...l.languages};
    _sleep = AppConstants.sleepSchedules.contains(l.sleepSchedule)
        ? l.sleepSchedule
        : 'normal';
    _clean = l.cleanliness.toDouble();
    _diet = AppConstants.diets.contains(l.diet) ? l.diet : 'no preference';
    _smoking = AppConstants.smokingOptions.contains(l.smoking)
        ? l.smoking
        : 'non-smoker';
    _city = AppConstants.cities.containsKey(l.city) ? l.city : null;
    _privacy = u.privacy;
  }

  @override
  void dispose() {
    _course.dispose();
    _university.dispose();
    _budget.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_languages.isEmpty) {
      showSnack(context, 'Pick at least one language', error: true);
      return;
    }
    final u = context.read<SessionProvider>().appUser!;
    setState(() => _busy = true);
    try {
      final l = Lifestyle(
        course: _course.text.trim(),
        university: _university.text.trim(),
        languages: _languages.toList(),
        sleepSchedule: _sleep,
        cleanliness: _clean.round(),
        diet: _diet,
        smoking: _smoking,
        budget: double.parse(_budget.text.trim()),
        city: _city ?? '',
        bio: _bio.text.trim(),
      );
      await FirestoreService.instance.saveLifestyle(u.uid, l, _privacy);
      if (!mounted) return;
      showSnack(context, 'Profile saved');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final universities = {
      for (final c in AppConstants.campuses) c.name,
    }.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Lifestyle profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
          children: [
            const Text(
              'Your answers power roommate matching. Only lifestyle preferences are used – never ethnicity, nationality, religion or gender.',
              style: TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
            const SectionTitle('Studies'),
            TextFormField(
              controller: _course,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Course', hintText: 'e.g. MSc Computer Science'),
              validator: (v) => Validators.required(v, 'Course'),
            ),
            const SizedBox(height: 12),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _university.text),
              optionsBuilder: (v) => universities.where((u) =>
                  u.toLowerCase().contains(v.text.toLowerCase())),
              onSelected: (v) => _university.text = v,
              fieldViewBuilder: (context, ctrl, focus, onSubmit) {
                return TextFormField(
                  controller: ctrl,
                  focusNode: focus,
                  onChanged: (v) => _university.text = v,
                  decoration: const InputDecoration(
                      labelText: 'University',
                      prefixIcon: Icon(Icons.school_outlined)),
                  validator: (v) => Validators.required(v, 'University'),
                );
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _city,
              decoration: const InputDecoration(
                  labelText: 'City you are moving to',
                  prefixIcon: Icon(Icons.location_city_rounded)),
              items: [
                for (final c in AppConstants.cities.keys)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _city = v),
              validator: (v) => v == null ? 'Choose a city' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _budget,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Monthly budget (USD)',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined)),
              validator: (v) {
                final n = double.tryParse((v ?? '').trim());
                if (n == null) return 'Enter a number';
                if (n < 100 || n > 10000) return 'Enter a budget between 100 and 10,000';
                return null;
              },
            ),
            const SectionTitle('Languages'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in AppConstants.languages)
                  FilterChip(
                    label: Text(l),
                    selected: _languages.contains(l),
                    onSelected: (s) => setState(
                        () => s ? _languages.add(l) : _languages.remove(l)),
                  ),
              ],
            ),
            const SectionTitle('Daily life'),
            const Text('Sleep schedule',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                for (final s in AppConstants.sleepSchedules)
                  ButtonSegment(value: s, label: Text(capitalize(s))),
              ],
              selected: {_sleep},
              onSelectionChanged: (s) => setState(() => _sleep = s.first),
            ),
            const SizedBox(height: 16),
            Row(children: [
              const Expanded(
                  child: Text('Cleanliness',
                      style: TextStyle(fontWeight: FontWeight.w600))),
              Text('${_clean.round()} / 5 · ${_cleanLabel(_clean.round())}',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w700)),
            ]),
            Slider(
              value: _clean,
              min: 1,
              max: 5,
              divisions: 4,
              label: _clean.round().toString(),
              onChanged: (v) => setState(() => _clean = v),
            ),
            const Text('Diet', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in AppConstants.diets)
                  ChoiceChip(
                    label: Text(capitalize(d)),
                    selected: _diet == d,
                    onSelected: (_) => setState(() => _diet = d),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Smoking', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in AppConstants.smokingOptions)
                  ChoiceChip(
                    label: Text(capitalize(s)),
                    selected: _smoking == s,
                    onSelected: (_) => setState(() => _smoking = s),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bio,
              maxLines: 3,
              maxLength: 200,
              decoration: const InputDecoration(
                  labelText: 'Short bio (optional)', alignLabelWithHint: true),
            ),
            const SectionTitle('Privacy – what others can see'),
            Card(
              child: Column(
                children: [
                  _toggle('Show my course', _privacy.showCourse,
                      (v) => _setPrivacy(showCourse: v)),
                  _toggle('Show my university', _privacy.showUniversity,
                      (v) => _setPrivacy(showUniversity: v)),
                  _toggle('Show my languages', _privacy.showLanguages,
                      (v) => _setPrivacy(showLanguages: v)),
                  _toggle('Show my budget', _privacy.showBudget,
                      (v) => _setPrivacy(showBudget: v)),
                  _toggle('Show lifestyle habits', _privacy.showLifestyle,
                      (v) => _setPrivacy(showLifestyle: v)),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded),
            label: const Text('Save profile'),
          ),
        ),
      ),
    );
  }

  String _cleanLabel(int v) => const [
        'Relaxed',
        'Easy-going',
        'Average',
        'Tidy',
        'Spotless'
      ][(v - 1).clamp(0, 4)];

  Widget _toggle(String title, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(title: Text(title), value: value, onChanged: onChanged);

  void _setPrivacy({
    bool? showCourse,
    bool? showUniversity,
    bool? showLanguages,
    bool? showBudget,
    bool? showLifestyle,
  }) {
    setState(() {
      _privacy = PrivacySettings(
        showCourse: showCourse ?? _privacy.showCourse,
        showUniversity: showUniversity ?? _privacy.showUniversity,
        showLanguages: showLanguages ?? _privacy.showLanguages,
        showBudget: showBudget ?? _privacy.showBudget,
        showLifestyle: showLifestyle ?? _privacy.showLifestyle,
      );
    });
  }
}
