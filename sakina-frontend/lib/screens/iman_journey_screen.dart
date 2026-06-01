import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/api_service.dart';

class ImanJourneyScreen extends StatefulWidget {
  ImanJourneyScreen({
    super.key,
    ApiService? api,
    String? userId,
  })  : api = api ?? ApiService(baseUrl: ApiConfig.baseUrl),
        userId = userId ??
            const String.fromEnvironment(
              'SAKINA_USER_ID',
              defaultValue: '00000000-0000-0000-0000-000000000000',
            );

  final ApiService api;
  final String userId;

  @override
  State<ImanJourneyScreen> createState() => _ImanJourneyScreenState();
}

class _ImanJourneyScreenState extends State<ImanJourneyScreen> {
  final TextEditingController _duaController = TextEditingController();
  ImanJourneyResponseDto? _journey;
  bool _loading = true;
  bool _savingPrivacy = false;
  String? _error;
  String? _status;
  bool _personalizationEnabled = false;
  bool _remindersEnabled = false;
  bool _storeJourneyEnabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final journey = await widget.api.getImanJourney(widget.userId);
      if (!mounted) return;
      setState(() {
        _journey = journey;
        _personalizationEnabled = journey.privacySettings.personalizationEnabled;
        _remindersEnabled = journey.privacySettings.remindersEnabled;
        _storeJourneyEnabled = journey.privacySettings.storeJourneyEnabled;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _savePrivacy() async {
    if (_savingPrivacy) return;
    setState(() => _savingPrivacy = true);
    try {
      final updated = await widget.api.updateImanJourneyPrivacy(
        widget.userId,
        ImanJourneyPrivacySettingsDto(
          personalizationEnabled: _personalizationEnabled,
          remindersEnabled: _remindersEnabled,
          storeJourneyEnabled: _storeJourneyEnabled,
        ),
      );
      if (!mounted) return;
      setState(() {
        _personalizationEnabled = updated.personalizationEnabled;
        _remindersEnabled = updated.remindersEnabled;
        _storeJourneyEnabled = updated.storeJourneyEnabled;
        _status = 'Privacy settings saved.';
      });
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _savingPrivacy = false);
      }
    }
  }

  Future<void> _addDua() async {
    final value = _duaController.text.trim();
    if (value.isEmpty) return;
    try {
      await widget.api.addDuaItem(widget.userId, value);
      _duaController.clear();
      if (!mounted) return;
      setState(() => _status = 'Dua added.');
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final journey = _journey;
    if (journey == null) {
      return const Center(child: Text('No journey data available.'));
    }
    final fallback = journey.religiousReminder.safeFallback;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_status != null) ...[
            Text(_status!),
            const SizedBox(height: 8),
          ],
          _section(
            'Today\'s Iman Focus',
            Text(journey.todayFocus),
          ),
          _section(
            'Continue Yesterday\'s Topic',
            Text(journey.continueYesterdayTopic ?? 'Not set yet'),
          ),
          _section(
            'Prayer / Qur\'an / Dhikr Progress',
            Text(
              'Prayer: ${journey.progress.prayer} | Qur\'an: ${journey.progress.quran} | Dhikr: ${journey.progress.dhikr}',
            ),
          ),
          _section(
            'Personal Dua List',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...journey.personalDuaList.map(
                  (item) => Text('- ${item.duaText}'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _duaController,
                  decoration: const InputDecoration(
                    labelText: 'Add dua',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _addDua,
                  child: const Text('Add Dua'),
                ),
              ],
            ),
          ),
          _section(
            'Family Reminder',
            Text(
              journey.familyReminder.consentGranted
                  ? (journey.familyReminder.reminderText ?? 'Reminder not set')
                  : 'Consent not granted',
            ),
          ),
          _section(
            'Ask Sakina with today context',
            Text(journey.askSakinaTodayContext ?? 'Not set yet'),
          ),
          _section(
            'Tomorrow Follow-up',
            Text(journey.tomorrowFollowUp ?? 'Not set yet'),
          ),
          _section(
            'Notification/privacy settings',
            Column(
              children: [
                SwitchListTile(
                  title: const Text('Personalization'),
                  value: _personalizationEnabled,
                  onChanged: (value) =>
                      setState(() => _personalizationEnabled = value),
                ),
                SwitchListTile(
                  title: const Text('Reminders'),
                  value: _remindersEnabled,
                  onChanged: (value) => setState(() => _remindersEnabled = value),
                ),
                SwitchListTile(
                  title: const Text('Store journey data'),
                  value: _storeJourneyEnabled,
                  onChanged: (value) => setState(() => _storeJourneyEnabled = value),
                ),
                ElevatedButton(
                  onPressed: _savingPrivacy ? null : _savePrivacy,
                  child: Text(_savingPrivacy ? 'Saving...' : 'Save Privacy'),
                ),
              ],
            ),
          ),
          _section(
            'Evidence bundle enforcement',
            journey.religiousReminder.evidenceBundle.isEmpty
                ? const Text('No verified evidence bundle found.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: journey.religiousReminder.evidenceBundle
                        .map(
                          (item) => Text(
                            '- ${item.sourceReference}: ${item.citation}',
                          ),
                        )
                        .toList(),
                  ),
          ),
          _section(
            'Safe fallback if evidence is missing',
            fallback == null
                ? Text(journey.religiousReminder.text ?? 'Reminder ready')
                : Text(fallback.message),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _duaController.dispose();
    widget.api.close();
    super.dispose();
  }
}
