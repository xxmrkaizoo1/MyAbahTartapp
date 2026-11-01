import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/counter_menu.dart';
import '../../models/enums.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../models/shop_models.dart';
import '../../services/auth_service.dart';
import '../../services/cart.dart';
import '../../services/format.dart';
import '../../services/shop_repository.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/tart_art.dart';

DateTime get _today {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

void _pushKitchen(BuildContext context, Widget screen) => Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => Theme(data: kitchenThemeData, child: screen),
  ),
);

/// The point-of-sale screen for walk-in customers, like the website's admin/pos.
class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  late final _repository = context.read<ShopRepository>();
  late final Stream<CounterMenu> _menu = _repository.counterMenu(_today);
  late final Stream<List<ShopOrder>> _todayOrders = _repository.ordersSince(_today);
  final Map<String, CartLine> _ticket = {};
  bool _showAll = false;

  int _inTicket(Product product, [ProductSize? size]) =>
      _ticket.values.where((line) => line.product.id == product.id && (size == null || line.size == size)).fold(0, (acc, line) => acc + line.quantity);

  void _add(Product product, ProductSize? size, int left) {
    if (left <= 0) return showMessage(context, 'No more ${product.name} left at the counter.');
    final key = '${product.id}|${size?.code ?? ''}';
    setState(() {
      final line = _ticket[key];
      _ticket[key] = CartLine(product: product, size: size, quantity: (line?.quantity ?? 0) + 1);
    });
  }

  Future<void> _pickSize(Product product, CounterMenu menu, CounterSales sales) async {
    final size = await showModalBottomSheet<ProductSize>(
      context: context,
      builder: (context) => Theme(
        data: kitchenThemeData,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(product.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final size in product.sizes)
                ListTile(
                  enabled: sales.sellable(product, size, menu) - _inTicket(product, size) > 0,
                  title: Text(product.sizeLabel(size)),
                  subtitle: Text('${sales.sellable(product, size, menu) - _inTicket(product, size)} left'),
                  trailing: Text(rm(product.priceFor(size)), style: const TextStyle(fontWeight: FontWeight.w800)),
                  onTap: () => Navigator.pop(context, size),
                ),
            ],
          ),
        ),
      ),
    );
    if (size != null) _add(product, size, sales.sellable(product, size, menu) - _inTicket(product, size));
  }

  Future<void> _openTicket() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Theme(
        data: kitchenThemeData,
        child: StatefulBuilder(
          builder: (context, setSheetState) => _TicketSheet(
            ticket: _ticket,
            onChanged: () {
              setState(() {});
              setSheetState(() {});
            },
          ),
        ),
      ),
    );
    if (code == null || !mounted) return;
    setState(_ticket.clear);
    _pushKitchen(context, ReceiptScreen(code: code));
  }

  @override
  Widget build(BuildContext context) {
    final products = (context.watch<List<Product>?>() ?? const <Product>[]).where((product) => product.isActive).toList();

    return StreamBuilder<CounterMenu>(
      stream: _menu,
      builder: (context, menuSnapshot) => StreamBuilder<List<ShopOrder>>(
        stream: _todayOrders,
        builder: (context, salesSnapshot) {
          final menu = menuSnapshot.data ?? CounterMenu(date: CounterMenu.keyFor(_today));
          final counterSales = (salesSnapshot.data ?? const <ShopOrder>[])
              .where((order) => order.isCounterSale && order.status != OrderStatus.cancelled)
              .toList();
          final sales = CounterSales([
            for (final order in counterSales)
              for (final item in order.items) (productId: item.productId, size: item.size, quantity: item.quantity),
          ]);
          final shown = menu.isEmpty || _showAll ? products : products.where((product) => menu.items.containsKey(product.id)).toList();
          final ticketTotal = _ticket.values.fold(0.0, (acc, line) => acc + line.lineTotal);
          final ticketCount = _ticket.values.fold(0, (acc, line) => acc + line.quantity);

          return Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Panel(
                          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Counter today', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12.5)),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '${counterSales.length} sale${counterSales.length == 1 ? '' : 's'} · ${rm(counterSales.fold(0.0, (acc, order) => acc + order.netTotal))}',
                                        style: displayFont(context, size: 20, color: context.tart.accent),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton.filledTonal(
                                tooltip: 'Counter menu',
                                onPressed: () => _pushKitchen(context, const CounterMenuScreen()),
                                icon: const Icon(Icons.checklist_rounded),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (menu.isEmpty)
                          Text(
                            'No counter menu for today, so every product is shown.',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                          )
                        else
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text('Show products not on today’s counter'),
                            value: _showAll,
                            onChanged: (value) => setState(() => _showAll = value),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 180,
                      mainAxisExtent: 82 + MediaQuery.textScalerOf(context).scale(68),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final product = shown[index];
                      final left = sales.sellable(product, null, menu) - _inTicket(product);
                      final inTicket = _inTicket(product);
                      return FadeSlideIn(
                        index: index,
                        child: Pressable(
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => product.hasSizes ? _pickSize(product, menu, sales) : _add(product, null, left),
                              child: Opacity(
                                opacity: left > 0 ? 1 : 0.4,
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    children: [
                                      Badge(
                                        isLabelVisible: inTicket > 0,
                                        label: Text('$inTicket'),
                                        child: TartArt(art: product.art, imageUrl: product.imageUrl, size: 64),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        product.name,
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w700, height: 1.15),
                                      ),
                                      const Spacer(),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          '${product.hasSizes ? 'from ' : ''}${rm(product.fromPrice)} · $left left',
                                          style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }, childCount: shown.length),
                  ),
                ),
              ],
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
            floatingActionButton: ticketCount == 0
                ? null
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                      onPressed: _openTicket,
                      icon: const Icon(Icons.point_of_sale_rounded),
                      label: Text('$ticketCount item${ticketCount == 1 ? '' : 's'} · ${rm(ticketTotal)} · Charge'),
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _TicketSheet extends StatefulWidget {
  const _TicketSheet({required this.ticket, required this.onChanged});

  final Map<String, CartLine> ticket;
  final VoidCallback onChanged;

  @override
  State<_TicketSheet> createState() => _TicketSheetState();
}

class _TicketSheetState extends State<_TicketSheet> {
  final _discount = TextEditingController();
  final _tendered = TextEditingController();
  final _customer = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  bool _charging = false;

  @override
  void dispose() {
    _discount.dispose();
    _tendered.dispose();
    _customer.dispose();
    super.dispose();
  }

  Future<void> _charge(double total) async {
    final staff = context.read<AuthService>().profile?.name ?? 'Staff';
    setState(() => _charging = true);
    try {
      final code = await context.read<ShopRepository>().recordCounterSale(
        lines: widget.ticket.values.toList(),
        discount: double.tryParse(_discount.text) ?? 0,
        paymentMethod: _method,
        amountTendered: _method == PaymentMethod.cash ? double.tryParse(_tendered.text) : null,
        customerName: _customer.text,
        servedBy: staff,
      );
      if (mounted) Navigator.pop(context, code);
    } catch (error) {
      if (mounted) showMessage(context, '$error');
    } finally {
      if (mounted) setState(() => _charging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.ticket.values.toList();
    final subtotal = round2(lines.fold(0.0, (acc, line) => acc + line.lineTotal));
    final discount = (double.tryParse(_discount.text) ?? 0).clamp(0, subtotal).toDouble();
    final total = round2(subtotal - discount);
    final tendered = double.tryParse(_tendered.text);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Current sale', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${line.product.name}${line.size == null ? '' : ' (${line.size!.label})'}\n${rm(line.unitPrice)} each',
                        style: const TextStyle(height: 1.3),
                      ),
                    ),
                    QuantityStepper(
                      compact: true,
                      min: 0,
                      value: line.quantity,
                      onChanged: (value) {
                        if (value == 0) {
                          widget.ticket.remove(line.key);
                        } else {
                          line.quantity = value;
                        }
                        widget.onChanged();
                        if (widget.ticket.isEmpty) Navigator.pop(context);
                      },
                    ),
                    SizedBox(
                      width: 78,
                      child: Text(
                        rm(line.lineTotal),
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _discount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Discount (RM)', isDense: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _customer,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Customer (optional)', isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<PaymentMethod>(
              segments: [
                for (final method in PaymentMethod.forCounter)
                  ButtonSegment(value: method, icon: Icon(method.icon), label: Text(method.label.split(' ').first)),
              ],
              selected: {_method},
              onSelectionChanged: (value) => setState(() => _method = value.first),
            ),
            if (_method == PaymentMethod.cash) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _tendered,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Cash received (RM)', isDense: true),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final amount in {total, (total / 10).ceil() * 10.0, (total / 50).ceil() * 50.0, 100.0}.where((amount) => amount >= total))
                    ActionChip(
                      label: Text(amount == total ? 'Exact' : rm(amount)),
                      onPressed: () => setState(() => _tendered.text = amount.toStringAsFixed(2)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            _row('Subtotal', rm(subtotal), muted),
            if (discount > 0) _row('Discount', '− ${rm(discount)}', muted),
            _row('Total', rm(total), null, bold: true),
            if (_method == PaymentMethod.cash && tendered != null && tendered >= total) _row('Change', rm(tendered - total), context.tart.accent, bold: true),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _charging || (_method == PaymentMethod.cash && (tendered ?? 0) < total) ? null : () => _charge(total),
              child: Text(_charging ? 'Recording…' : 'Charge ${rm(total)}'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, Color? color, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontWeight: bold ? FontWeight.w800 : null, color: bold ? null : color),
          ),
        ),
        Text(
          value,
          style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: bold ? 18 : 14.5, color: bold ? color : null),
        ),
      ],
    ),
  );
}

/// A printable-looking receipt for a counter sale.
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.code});

  final String code;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  late final Stream<ShopOrder?> _order = context.read<ShopRepository>().order(widget.code);

  @override
  Widget build(BuildContext context) {
    final storefront = context.watch<Storefront>();
    const ink = Color(0xFF1B1B1B);
    const paperText = TextStyle(color: ink, fontFamily: 'monospace', fontSize: 13.5, height: 1.4);

    Widget line(String left, String right, {bool bold = false}) => Row(
      children: [
        Expanded(
          child: Text(left, style: paperText.copyWith(fontWeight: bold ? FontWeight.w800 : null)),
        ),
        Text(right, style: paperText.copyWith(fontWeight: bold ? FontWeight.w800 : null)),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Receipt')),
      body: StreamBuilder<ShopOrder?>(
        stream: _order,
        builder: (context, snapshot) {
          final order = snapshot.data;
          if (order == null) return snapshot.hasError ? ErrorView(snapshot.error) : const LoadingView();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: staggered([
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: const Color(0xFFFFFDF8), borderRadius: BorderRadius.circular(6)),
                child: Column(
                  children: [
                    const TartArt(art: 'pineapple', size: 46),
                    const SizedBox(height: 6),
                    Text('MyAbah Tart Lejen', style: paperText.copyWith(fontSize: 16, fontWeight: FontWeight.w800)),
                    Text(storefront.get('address'), textAlign: TextAlign.center, style: paperText.copyWith(fontSize: 12)),
                    const SizedBox(height: 10),
                    line('Receipt', order.code, bold: true),
                    line(shortDateTime(order.createdAt), order.servedBy ?? ''),
                    if (order.customerName != 'Walk-in customer') line('Customer', order.customerName),
                    Text('- ' * 24, style: paperText, maxLines: 1, overflow: TextOverflow.clip),
                    for (final item in order.items) ...[
                      line(item.displayName, rm(item.lineTotal)),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('  ${item.quantity} × ${rm(item.unitPrice)}', style: paperText.copyWith(fontSize: 12)),
                      ),
                    ],
                    Text('- ' * 24, style: paperText, maxLines: 1, overflow: TextOverflow.clip),
                    line('Subtotal', rm(order.subtotal)),
                    if (order.discount > 0) line('Discount', '-${rm(order.discount)}'),
                    line('TOTAL', rm(order.total), bold: true),
                    line(order.paymentMethod.label, rm(order.amountTendered ?? order.total)),
                    if ((order.changeGiven ?? 0) > 0) line('Change', rm(order.changeGiven!), bold: true),
                    const SizedBox(height: 12),
                    Text('Terima kasih! Come again.', style: paperText),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.add_rounded), label: const Text('New sale')),
            ]),
          );
        },
      ),
    );
  }
}

/// Choose which products go out to the counter today or tomorrow, and how many.
class CounterMenuScreen extends StatefulWidget {
  const CounterMenuScreen({super.key});

  @override
  State<CounterMenuScreen> createState() => _CounterMenuScreenState();
}

class _CounterMenuScreenState extends State<CounterMenuScreen> {
  bool _tomorrow = false;
  bool _loading = true;
  bool _saving = false;
  final Set<String> _selected = {};
  final Map<String, TextEditingController> _amounts = {};

  DateTime get _day => _tomorrow ? _today.add(const Duration(days: 1)) : _today;

  @override
  void initState() {
    super.initState();
    _load(_day);
  }

  @override
  void dispose() {
    for (final controller in _amounts.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _amount(String key) => _amounts.putIfAbsent(key, TextEditingController.new);

  /// Fills the form from the menu saved for [from] (the shown day, or the day before when copying).
  Future<void> _load(DateTime from) async {
    setState(() => _loading = true);
    final menu = await context.read<ShopRepository>().counterMenuOnce(from);
    if (!mounted) return;
    setState(() {
      _selected
        ..clear()
        ..addAll(menu.items.keys);
      for (final controller in _amounts.values) {
        controller.clear();
      }
      for (final MapEntry(key: id, value: allowance) in menu.items.entries) {
        if (allowance.quantity != null) _amount(id).text = '${allowance.quantity}';
        for (final MapEntry(key: size, value: quantity) in allowance.sizes.entries) {
          if (quantity != null) _amount('$id|$size').text = '$quantity';
        }
      }
      _loading = false;
    });
  }

  Future<void> _save(List<Product> products) async {
    int? number(String key) => int.tryParse(_amounts[key]?.text.trim() ?? '');
    final items = <String, CounterAllowance>{};
    for (final product in products.where((product) => _selected.contains(product.id))) {
      if (!product.hasSizes) {
        items[product.id] = CounterAllowance(quantity: number(product.id));
        continue;
      }
      final sizes = {for (final size in product.sizes) size.code: number('${product.id}|${size.code}')};
      // The total is only capped when every size has a number, as on the website.
      items[product.id] = CounterAllowance(
        quantity: sizes.values.contains(null) ? null : sizes.values.fold<int>(0, (acc, value) => acc + value!),
        sizes: sizes.values.every((value) => value == null) ? const {} : sizes,
      );
    }

    setState(() => _saving = true);
    try {
      await context.read<ShopRepository>().saveCounterMenu(CounterMenu(date: CounterMenu.keyFor(_day), items: items));
      if (mounted) {
        showMessage(context, '${items.length} item${items.length == 1 ? '' : 's'} set for the counter ${_tomorrow ? 'tomorrow' : 'today'}.');
        if (!_tomorrow) Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) showMessage(context, 'Couldn’t save: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = (context.watch<List<Product>?>() ?? const <Product>[]).where((product) => product.isActive).toList();
    final categories = {for (final category in context.watch<List<MenuCategory>>()) category.id: category.name};
    final grouped = <String, List<Product>>{};
    for (final product in products) {
      grouped.putIfAbsent(categories[product.categoryId] ?? 'Other', () => []).add(product);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Counter menu')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: staggered([
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Today')),
              ButtonSegment(value: true, label: Text('Tomorrow')),
            ],
            selected: {_tomorrow},
            onSelectionChanged: (value) {
              setState(() => _tomorrow = value.first);
              _load(_day);
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tick what goes out. Leave a number empty for no limit.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                ),
              ),
              TextButton(onPressed: _loading ? null : () => _load(_day.subtract(const Duration(days: 1))), child: const Text('Copy previous day')),
            ],
          ),
          if (_loading)
            const LoadingView()
          else
            for (final MapEntry(key: group, value: items) in grouped.entries) ...[
              SectionTitle(group, padding: const EdgeInsets.fromLTRB(4, 14, 0, 4)),
              for (final product in items)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          contentPadding: const EdgeInsets.only(left: 8),
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _selected.contains(product.id),
                          onChanged: (value) => setState(() => value == true ? _selected.add(product.id) : _selected.remove(product.id)),
                          title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${product.stock} in stock'),
                          secondary: TartArt(art: product.art, imageUrl: product.imageUrl, size: 36),
                        ),
                        if (_selected.contains(product.id))
                          Row(
                            children: [
                              const SizedBox(width: 12),
                              for (final key in product.hasSizes ? [for (final size in product.sizes) '${product.id}|${size.code}'] : [product.id])
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: TextField(
                                      controller: _amount(key),
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        labelText: key.contains('|') ? '${ProductSize.fromCode(key.split('|').last)!.label} brought' : 'Brought out',
                                        hintText: 'No limit',
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
            ],
        ]),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          onPressed: _saving || _loading ? null : () => _save(products),
          child: Text(_saving ? 'Saving…' : 'Save ${_selected.length} for ${_tomorrow ? 'tomorrow' : 'today'}'),
        ),
      ),
    );
  }
}
