import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/api_service.dart';

/// Public Islamic calculators (Zakat, Inheritance, Qibla) wired to the real
/// backend `/api/tools/*` endpoints. No login required, no fabricated data.
class CalculatorsScreen extends StatefulWidget {
  CalculatorsScreen({super.key, ApiService? api, this.initialTab = 0})
      : api = api ?? ApiService(baseUrl: ApiConfig.baseUrl);

  final ApiService api;
  final int initialTab;

  @override
  State<CalculatorsScreen> createState() => _CalculatorsScreenState();
}

class _CalculatorsScreenState extends State<CalculatorsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final tab = widget.initialTab.clamp(0, 2);
    _tabController = TabController(length: 3, vsync: this, initialIndex: tab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Islamic Calculators'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Zakat'),
            Tab(text: 'Inheritance'),
            Tab(text: 'Qibla'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ZakatTab(api: widget.api),
          _InheritanceTab(api: widget.api),
          _QiblaTab(api: widget.api),
        ],
      ),
    );
  }
}

class _ZakatTab extends StatefulWidget {
  const _ZakatTab({required this.api});
  final ApiService api;
  @override
  State<_ZakatTab> createState() => _ZakatTabState();
}

class _ZakatTabState extends State<_ZakatTab> {
  final _cash = TextEditingController(text: '0');
  final _business = TextEditingController(text: '0');
  final _liabilities = TextEditingController(text: '0');
  final _silverPrice = TextEditingController(text: '0.70');
  final _goldPrice = TextEditingController(text: '60');
  String? _result;
  String? _error;
  bool _loading = false;

  double _n(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  Future<void> _calc() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final r = await widget.api.calculateZakat({
        'cash': _n(_cash),
        'business_assets': _n(_business),
        'liabilities': _n(_liabilities),
        'silver_price_per_gram': _n(_silverPrice),
        'gold_price_per_gram': _n(_goldPrice),
      });
      setState(() {
        _result = (r['eligible'] == true)
            ? 'Zakat due: ${r['zakat_due']} (2.5% of ${r['net_zakatable']}). Nisab: ${r['nisab_used']}.'
            : 'Below nisab (${r['nisab_used']}). No zakat due on ${r['net_zakatable']}.';
      });
    } catch (e) {
      setState(() => _error = 'Could not calculate: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _field(_cash, 'Cash & savings'),
      _field(_business, 'Business assets'),
      _field(_liabilities, 'Liabilities / debts'),
      _field(_silverPrice, 'Silver price per gram'),
      _field(_goldPrice, 'Gold price per gram'),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _loading ? null : _calc,
        child: Text(_loading ? 'Calculating…' : 'Calculate Zakat'),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      if (_result != null)
        Card(
          margin: const EdgeInsets.only(top: 12),
          child: Padding(padding: const EdgeInsets.all(16), child: Text(_result!)),
        ),
    ]);
  }
}

class _InheritanceTab extends StatefulWidget {
  const _InheritanceTab({required this.api});
  final ApiService api;
  @override
  State<_InheritanceTab> createState() => _InheritanceTabState();
}

class _InheritanceTabState extends State<_InheritanceTab> {
  final _estate = TextEditingController(text: '0');
  final _sons = TextEditingController(text: '0');
  final _daughters = TextEditingController(text: '0');
  final _wives = TextEditingController(text: '0');
  bool _husband = false;
  bool _father = false;
  bool _mother = false;
  List<dynamic>? _shares;
  String? _error;
  bool _loading = false;

  Future<void> _calc() async {
    setState(() {
      _loading = true;
      _error = null;
      _shares = null;
    });
    try {
      final r = await widget.api.calculateInheritance({
        'estate': double.tryParse(_estate.text.trim()) ?? 0,
        'husband': _husband,
        'father': _father,
        'mother': _mother,
        'wives': int.tryParse(_wives.text.trim()) ?? 0,
        'sons': int.tryParse(_sons.text.trim()) ?? 0,
        'daughters': int.tryParse(_daughters.text.trim()) ?? 0,
      });
      setState(() => _shares = r['shares'] as List<dynamic>?);
    } catch (e) {
      setState(() => _error = 'Could not calculate: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _field(_estate, 'Total estate value'),
      CheckboxListTile(
        value: _husband,
        onChanged: (v) => setState(() => _husband = v ?? false),
        title: const Text('Husband'),
      ),
      _field(_wives, 'Number of wives'),
      CheckboxListTile(
        value: _father,
        onChanged: (v) => setState(() => _father = v ?? false),
        title: const Text('Father alive'),
      ),
      CheckboxListTile(
        value: _mother,
        onChanged: (v) => setState(() => _mother = v ?? false),
        title: const Text('Mother alive'),
      ),
      _field(_sons, 'Number of sons'),
      _field(_daughters, 'Number of daughters'),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _loading ? null : _calc,
        child: Text(_loading ? 'Calculating…' : 'Calculate Shares'),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'Core faraid only (spouse, parents, sons, daughters). Verify complex estates with a scholar.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      if (_shares != null)
        ..._shares!.map((s) => ListTile(
              title: Text(s['heir'].toString()),
              trailing: Text('${s['amount']}  (${s['fraction']})'),
            )),
    ]);
  }
}

class _QiblaTab extends StatefulWidget {
  const _QiblaTab({required this.api});
  final ApiService api;
  @override
  State<_QiblaTab> createState() => _QiblaTabState();
}

class _QiblaTabState extends State<_QiblaTab> {
  // Defaults to London; GPS auto-detect requires location permission (future work).
  final _lat = TextEditingController(text: '51.5074');
  final _lng = TextEditingController(text: '-0.1278');
  String? _result;
  String? _error;
  bool _loading = false;

  Future<void> _calc() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final r = await widget.api.qiblaDirection(
        lat: double.tryParse(_lat.text.trim()) ?? 0,
        lng: double.tryParse(_lng.text.trim()) ?? 0,
      );
      setState(() =>
          _result = 'Qibla bearing: ${r['bearing_degrees']}° from true north.');
    } catch (e) {
      setState(() => _error = 'Could not calculate: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Enter your latitude and longitude (GPS auto-detect coming later).'),
      _field(_lat, 'Latitude'),
      _field(_lng, 'Longitude'),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _loading ? null : _calc,
        child: Text(_loading ? 'Calculating…' : 'Find Qibla'),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      if (_result != null)
        Card(
          margin: const EdgeInsets.only(top: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Icon(Icons.explore, size: 32),
              const SizedBox(width: 12),
              Expanded(child: Text(_result!)),
            ]),
          ),
        ),
    ]);
  }
}

Widget _field(TextEditingController c, String label) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
