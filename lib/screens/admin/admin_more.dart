import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/product.dart';
import '../../models/shop_models.dart';
import '../../services/format.dart';
import '../../services/shop_repository.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/tart_art.dart';
import 'customers_screen.dart';
import 'integrations_screen.dart';
import 'pos_screen.dart';
import 'refunds_screen.dart';
import 'sales_report_screen.dart';

class AdminMoreScreen extends StatelessWidget {
  const AdminMoreScreen({super.key});

  void _push(BuildContext context, Widget screen) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Theme(data: kitchenThemeData, child: screen),
    ),
  );

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String title, String subtitle, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          leading: Icon(icon, color: context.tart.accent),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: staggered([
        tile(Icons.people_alt_outlined, 'Customers', 'Everyone who has ordered, with what they spent', () => _push(context, const CustomersScreen())),
        tile(Icons.bar_chart_rounded, 'Sales report', 'Online vs counter, best sellers, last 7–90 days', () => _push(context, const SalesReportScreen())),
        tile(Icons.undo_rounded, 'Refunds', 'Approve or decline customer requests', () => _push(context, const RefundsScreen())),
        tile(Icons.checklist_rounded, 'Counter menu', 'What goes out to the counter today or tomorrow', () => _push(context, const CounterMenuScreen())),
        tile(Icons.confirmation_number_outlined, 'Vouchers', 'Discount codes customers can use', () => _push(context, const VouchersScreen())),
        tile(Icons.category_outlined, 'Collections', 'Group the menu, e.g. Classics', () => _push(context, const CollectionsScreen())),
        tile(
          Icons.local_shipping_outlined,
          'Delivery & shop info',
          'Fees, free delivery, address, home page text',
          () => _push(context, const StorefrontSettingsScreen()),
        ),
        tile(Icons.key_rounded, 'Payments & delivery APIs', 'Billplz and Lalamove keys (not connected yet)', () => _push(context, const IntegrationsScreen())),
        tile(Icons.download_rounded, 'Import website menu', 'Copies the website’s products, collections, vouchers and settings', () async {
          if (!await confirm(
            context,
            title: 'Import the website menu?',
            message: 'Copies the website’s collections, products (including stock), vouchers and shop settings exactly as they are on the website, replacing the app’s copies, and removes the old sample tarts.',
            confirmLabel: 'Import',
          )) {
            return;
          }
          if (!context.mounted) return;
          try {
            final created = await context.read<ShopRepository>().importStarterCatalog();
            if (context.mounted) showMessage(context, 'Copied $created items from the website.');
          } catch (error) {
            if (context.mounted) showMessage(context, 'Import failed: $error');
          }
        }),
        tile(Icons.group_add_outlined, 'Add sample customers & sales', '20 made-up customers and their orders, to try the reports', () async {
          final repository = context.read<ShopRepository>();
          final menu = context.read<List<Product>?>() ?? const <Product>[];
          final storefront = context.read<Storefront>();
          if (!await confirm(
            context,
            title: 'Add sample data?',
            message:
                'Adds 20 made-up customers and 24 sales from the last month (20 online, 4 at the counter) using your real menu. '
                'Stock isn’t changed, and you can remove them all again with “Remove sample data”.',
            confirmLabel: 'Add',
          )) {
            return;
          }
          try {
            final (customers, orders) = await repository.addSampleData(menu, storefront);
            if (context.mounted) showMessage(context, 'Added $customers sample customers and $orders sales.');
          } catch (error) {
            if (context.mounted) showMessage(context, 'Couldn’t add sample data: $error');
          }
        }),
        tile(Icons.delete_sweep_outlined, 'Remove sample data', 'Deletes only the made-up customers and sales', () async {
          final repository = context.read<ShopRepository>();
          if (!await confirm(
            context,
            title: 'Remove sample data?',
            message: 'Deletes the made-up customers and sales. Real customers and orders stay.',
            confirmLabel: 'Remove',
            destructive: true,
          )) {
            return;
          }
          try {
            final removed = await repository.removeSampleData();
            if (context.mounted) showMessage(context, removed == 0 ? 'There was no sample data.' : 'Removed $removed sample records.');
          } catch (error) {
            if (context.mounted) showMessage(context, 'Couldn’t remove sample data: $error');
          }
        }),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Vouchers

class VouchersScreen extends StatefulWidget {
  const VouchersScreen({super.key});

  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> {
  late final Stream<List<Voucher>> _vouchers = context.read<ShopRepository>().vouchers();

  Future<void> _edit([Voucher? voucher]) async {
    final saved = await showModalBottomSheet<Voucher>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Theme(
        data: kitchenThemeData,
        child: _VoucherSheet(voucher: voucher),
      ),
    );
    if (saved == null || !mounted) return;
    try {
      await context.read<ShopRepository>().saveVoucher(saved);
    } catch (error) {
      if (mounted) showMessage(context, 'Couldn’t save: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<ShopRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Vouchers')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _edit, icon: const Icon(Icons.add_rounded), label: const Text('New voucher')),
      body: StreamBuilder<List<Voucher>>(
        stream: _vouchers,
        builder: (context, snapshot) {
          if (snapshot.hasError) return ErrorView(snapshot.error);
          final vouchers = snapshot.data;
          if (vouchers == null) return const LoadingView();
          if (vouchers.isEmpty) return const Center(child: Text('No vouchers yet.'));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: staggered([
              for (final voucher in vouchers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      onTap: () => _edit(voucher),
                      contentPadding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
                      title: Text('${voucher.code} · ${voucher.valueLabel}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                        [
                          if (voucher.description.isNotEmpty) voucher.description,
                          if (voucher.minSubtotal > 0) 'Min. spend ${rm(voucher.minSubtotal)}',
                          if (voucher.expiresAt != null) voucher.expiresAt!.isBefore(DateTime.now()) ? 'Expired' : 'Ends ${shortDateTime(voucher.expiresAt!)}',
                        ].join('\n'),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: voucher.isActive,
                            onChanged: (value) => repository.saveVoucher(
                              Voucher(
                                code: voucher.code,
                                description: voucher.description,
                                type: voucher.type,
                                value: voucher.value,
                                minSubtotal: voucher.minSubtotal,
                                isActive: value,
                                expiresAt: voucher.expiresAt,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () async {
                              if (await confirm(
                                context,
                                title: 'Delete ${voucher.code}?',
                                message: 'Customers won’t be able to use it any more.',
                                confirmLabel: 'Delete',
                                destructive: true,
                              )) {
                                await repository.deleteVoucher(voucher.code);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }
}

class _VoucherSheet extends StatefulWidget {
  const _VoucherSheet({this.voucher});

  final Voucher? voucher;

  @override
  State<_VoucherSheet> createState() => _VoucherSheetState();
}

class _VoucherSheetState extends State<_VoucherSheet> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.voucher?.code);
  late final _description = TextEditingController(text: widget.voucher?.description);
  late final _value = TextEditingController(text: widget.voucher?.value.toString());
  late final _minimum = TextEditingController(text: widget.voucher?.minSubtotal.toString() ?? '0');
  late String _type = widget.voucher?.type ?? Voucher.typeFixed;
  late DateTime? _expiresAt = widget.voucher?.expiresAt;

  @override
  void dispose() {
    for (final controller in [_code, _description, _value, _minimum]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.voucher == null ? 'New voucher' : 'Edit ${widget.voucher!.code}', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              TextFormField(
                controller: _code,
                enabled: widget.voucher == null,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Code', hintText: 'RAYA20'),
                validator: (value) => RegExp(r'^[A-Za-z0-9_-]{3,20}$').hasMatch(value?.trim() ?? '') ? null : 'Use 3–20 letters or numbers',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description', hintText: 'RM10 off orders over RM60'),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: Voucher.typeFixed, label: Text('RM off')),
                  ButtonSegment(value: Voucher.typePercent, label: Text('% off')),
                ],
                selected: {_type},
                onSelectionChanged: (value) => setState(() => _type = value.first),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _value,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: _type == Voucher.typePercent ? 'Percent' : 'Amount (RM)'),
                      validator: (value) {
                        final number = double.tryParse(value ?? '') ?? 0;
                        if (number <= 0) return 'Must be above 0';
                        if (_type == Voucher.typePercent && number > 100) return 'At most 100';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _minimum,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Min. spend (RM)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(_expiresAt == null ? 'Never expires' : 'Expires ${shortDateTime(_expiresAt!)}'),
                trailing: _expiresAt == null ? null : IconButton(onPressed: () => setState(() => _expiresAt = null), icon: const Icon(Icons.close_rounded)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                    initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) setState(() => _expiresAt = DateTime(picked.year, picked.month, picked.day, 23, 59));
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (!_form.currentState!.validate()) return;
                    Navigator.pop(
                      context,
                      Voucher(
                        code: _code.text.trim().toUpperCase(),
                        description: _description.text.trim(),
                        type: _type,
                        value: double.parse(_value.text),
                        minSubtotal: double.tryParse(_minimum.text) ?? 0,
                        isActive: widget.voucher?.isActive ?? true,
                        expiresAt: _expiresAt,
                      ),
                    );
                  },
                  child: const Text('Save voucher'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Collections

class CollectionsScreen extends StatelessWidget {
  const CollectionsScreen({super.key});

  Future<void> _edit(BuildContext context, List<MenuCategory> existing, [MenuCategory? category]) async {
    final repository = context.read<ShopRepository>();
    final name = TextEditingController(text: category?.name);
    var art = category?.art ?? 'pineapple';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(category == null ? 'New collection' : 'Edit collection'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: art,
                decoration: const InputDecoration(labelText: 'Picture'),
                items: [
                  for (final MapEntry(key: key, value: label) in tartArtLabels.entries)
                    DropdownMenuItem(
                      value: key,
                      child: Row(
                        children: [
                          TartArt(art: key, size: 24),
                          const SizedBox(width: 10),
                          Text(label),
                        ],
                      ),
                    ),
                ],
                onChanged: (value) => setDialogState(() => art = value ?? art),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, name.text.trim().isNotEmpty), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (saved == true) {
      await repository.saveCategory(
        MenuCategory(
          id: category?.id ?? ShopRepository.slugify(name.text.trim()),
          name: name.text.trim(),
          art: art,
          imageUrl: category?.imageUrl,
          sortOrder: category?.sortOrder ?? existing.length,
        ),
      );
    }
    name.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<List<MenuCategory>>();
    final products = context.watch<List<Product>?>() ?? const <Product>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Collections')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, categories),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New collection'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: staggered([
          for (final category in categories)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  onTap: () => _edit(context, categories, category),
                  leading: TartArt(art: category.art, imageUrl: category.imageUrl, size: 40),
                  title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${products.where((product) => product.categoryId == category.id).length} products'),
                  trailing: IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      if (products.any((product) => product.categoryId == category.id)) {
                        showMessage(context, 'Move its products to another collection first.');
                        return;
                      }
                      final repository = context.read<ShopRepository>();
                      if (await confirm(
                        context,
                        title: 'Delete ${category.name}?',
                        message: 'This collection is empty.',
                        confirmLabel: 'Delete',
                        destructive: true,
                      )) {
                        await repository.deleteCategory(category.id);
                      }
                    },
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- Storefront

class StorefrontSettingsScreen extends StatefulWidget {
  const StorefrontSettingsScreen({super.key});

  @override
  State<StorefrontSettingsScreen> createState() => _StorefrontSettingsScreenState();
}

class _StorefrontSettingsScreenState extends State<StorefrontSettingsScreen> {
  late final Map<String, String> _values = Map.of(context.read<Storefront>().values);
  late final Map<String, TextEditingController> _text = {
    for (final key in Storefront.defaults.keys)
      if (!key.endsWith('_enabled')) key: TextEditingController(text: _values[key]),
  };
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in _text.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<ShopRepository>().saveStorefront({..._values, for (final entry in _text.entries) entry.key: entry.value.text.trim()});
      if (mounted) {
        Navigator.pop(context);
        showMessage(context, 'Shop settings saved.');
      }
    } catch (error) {
      if (mounted) showMessage(context, 'Couldn’t save: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String key, String label, {bool money = false, int lines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: _text[key],
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 2,
      keyboardType: money ? const TextInputType.numberWithOptions(decimal: true) : null,
      decoration: InputDecoration(labelText: label, alignLabelWithHint: lines > 1),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery & shop info')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: staggered([
          for (final method in DeliveryMethod.values)
            Panel(
              title: method.name,
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Offer at checkout'),
                    value: _values['delivery_${method.name}_enabled'] == '1',
                    onChanged: (value) => setState(() => _values['delivery_${method.name}_enabled'] = value ? '1' : '0'),
                  ),
                  _field('delivery_${method.name}_label', 'Name'),
                  _field('delivery_${method.name}_description', 'Description'),
                  _field('delivery_${method.name}_fee', 'Fee (RM)', money: true),
                ],
              ),
            ),
          const SizedBox(height: 12),
          _field('delivery_free_over', 'Free standard delivery from (RM, 0 = never)', money: true),
          const SectionTitle('Shop info', padding: EdgeInsets.fromLTRB(4, 12, 0, 12)),
          _field('address', 'Address', lines: 2),
          _field('opening_hours', 'Opening hours'),
          _field('announcement', 'Announcement line'),
          const SectionTitle('Home page', padding: EdgeInsets.fromLTRB(4, 12, 0, 12)),
          _field('hero_badge', 'Badge'),
          _field('hero_title_start', 'Headline start'),
          _field('hero_title_highlight', 'Headline highlight'),
          _field('hero_title_end', 'Headline end'),
          _field('hero_intro', 'Intro', lines: 3),
          for (var step = 1; step <= 3; step++) ...[_field('step_${step}_title', 'Step $step title'), _field('step_${step}_text', 'Step $step text', lines: 2)],
          const SizedBox(height: 8),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save settings')),
        ]),
      ),
    );
  }
}
