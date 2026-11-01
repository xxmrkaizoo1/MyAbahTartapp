import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/shop_models.dart';
import '../../services/shop_repository.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

/// Where staff keep the Billplz and Lalamove details, ready for when a server is added.
///
/// Nothing here calls those services yet: their secret keys must never live in the
/// customer app, so a server (e.g. Firebase Cloud Functions) has to make the calls.
class IntegrationsScreen extends StatefulWidget {
  const IntegrationsScreen({super.key});

  @override
  State<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends State<IntegrationsScreen> {
  static const _textFields = {
    'billplz_api_key': 'API secret key',
    'billplz_collection_id': 'Collection ID',
    'billplz_x_signature': 'X Signature key',
    'lalamove_api_key': 'API key',
    'lalamove_api_secret': 'API secret',
    'lalamove_market': 'Market (e.g. MY)',
    'lalamove_pickup_address': 'Pickup address',
  };

  /// The vehicle options the website offers (app/Services/Lalamove.php).
  static const _serviceTypes = ['MOTORCYCLE', 'CAR', 'MPV', 'VAN', 'TRUCK330', 'TRUCK550'];

  final _controllers = {for (final key in _textFields.keys) key: TextEditingController()};
  final _hidden = <String>{'billplz_api_key', 'billplz_x_signature', 'lalamove_api_secret'};
  bool _billplzSandbox = true;
  bool _lalamoveSandbox = true;
  String _serviceType = 'MOTORCYCLE';
  bool _onlinePayment = false;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await context.read<ShopRepository>().integrations().first;
      if (!mounted) return;
      setState(() {
        for (final MapEntry(key: key, value: controller) in _controllers.entries) {
          controller.text = values[key] as String? ?? (key == 'lalamove_market' ? 'MY' : '');
        }
        _billplzSandbox = values['billplz_sandbox'] as bool? ?? true;
        _lalamoveSandbox = values['lalamove_sandbox'] as bool? ?? true;
        _serviceType = _serviceTypes.contains(values['lalamove_service_type']) ? values['lalamove_service_type'] as String : 'MOTORCYCLE';
        _onlinePayment = context.read<Storefront>().get('payment_online_enabled') == '1';
        _loaded = true;
      });
    } catch (error) {
      if (mounted) showMessage(context, 'Couldn’t load: $error');
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final repository = context.read<ShopRepository>();
    setState(() => _saving = true);
    try {
      await repository.saveIntegrations(<String, dynamic>{
        for (final entry in _controllers.entries) entry.key: entry.value.text.trim(),
        'billplz_sandbox': _billplzSandbox,
        'lalamove_sandbox': _lalamoveSandbox,
        'lalamove_service_type': _serviceType,
      });
      await repository.saveStorefront({'payment_online_enabled': _onlinePayment ? '1' : '0'});
      if (mounted) showMessage(context, 'Saved. These details are kept for staff only.');
    } catch (error) {
      if (mounted) showMessage(context, 'Couldn’t save: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String key) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: _controllers[key],
      obscureText: _hidden.contains(key),
      decoration: InputDecoration(
        labelText: _textFields[key],
        suffixIcon: key.endsWith('key') || key.endsWith('secret')
            ? IconButton(
                icon: Icon(_hidden.contains(key) ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _hidden.contains(key) ? _hidden.remove(key) : _hidden.add(key)),
              )
            : null,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payments & delivery APIs')),
      body: !_loaded
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: staggered([
                Panel(
                  color: context.tart.accent.withValues(alpha: 0.12),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Not connected yet. The app saves these details but never calls Billplz or Lalamove itself, '
                          'because secret keys must stay off customers’ phones. They will be used once a server '
                          '(e.g. Firebase Cloud Functions) is added. Until then checkout offers cash only and '
                          'express delivery uses its flat fee.',
                          style: TextStyle(height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SectionTitle('Billplz · online payment', padding: EdgeInsets.fromLTRB(4, 20, 0, 10)),
                _field('billplz_api_key'),
                _field('billplz_collection_id'),
                _field('billplz_x_signature'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sandbox (test) mode'),
                  value: _billplzSandbox,
                  onChanged: (value) => setState(() => _billplzSandbox = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show online payment at checkout'),
                  subtitle: const Text('Customers see it as “coming soon” until the server is connected'),
                  value: _onlinePayment,
                  onChanged: (value) => setState(() => _onlinePayment = value),
                ),
                const SectionTitle('Lalamove · express delivery quotes', padding: EdgeInsets.fromLTRB(4, 20, 0, 10)),
                _field('lalamove_api_key'),
                _field('lalamove_api_secret'),
                _field('lalamove_market'),
                DropdownButtonFormField<String>(
                  initialValue: _serviceType,
                  decoration: const InputDecoration(labelText: 'Vehicle'),
                  items: [for (final type in _serviceTypes) DropdownMenuItem(value: type, child: Text(type))],
                  onChanged: (value) => setState(() => _serviceType = value ?? _serviceType),
                ),
                const SizedBox(height: 12),
                _field('lalamove_pickup_address'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sandbox (test) mode'),
                  value: _lalamoveSandbox,
                  onChanged: (value) => setState(() => _lalamoveSandbox = value),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
              ]),
            ),
    );
  }
}
