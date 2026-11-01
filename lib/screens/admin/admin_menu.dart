import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/product.dart';
import '../../services/format.dart';
import '../../services/shop_repository.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/tart_art.dart';
import 'product_form_screen.dart';

class AdminMenuScreen extends StatefulWidget {
  const AdminMenuScreen({super.key});

  @override
  State<AdminMenuScreen> createState() => _AdminMenuScreenState();
}

class _AdminMenuScreenState extends State<AdminMenuScreen> {
  String _query = '';

  void _openForm([Product? product]) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Theme(
        data: kitchenThemeData,
        child: ProductFormScreen(product: product),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final products = (context.watch<List<Product>?>() ?? const <Product>[])
        .where((product) => _query.isEmpty || product.name.toLowerCase().contains(_query))
        .toList();
    final categories = {for (final category in context.watch<List<MenuCategory>>()) category.id: category.name};

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: _openForm, icon: const Icon(Icons.add_rounded), label: const Text('New tart')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: staggered([
          TextField(
            onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
            decoration: const InputDecoration(hintText: 'Search the menu', prefixIcon: Icon(Icons.search_rounded)),
          ),
          const SizedBox(height: 12),
          if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No products yet.')),
            )
          else
            for (final product in products)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _openForm(product),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                      child: Row(
                        children: [
                          Opacity(
                            opacity: product.isActive ? 1 : 0.4,
                            child: TartArt(art: product.art, imageUrl: product.imageUrl, size: 54),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(product.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text(
                                  '${categories[product.categoryId] ?? 'No collection'} · ${product.hasSizes ? 'from ' : ''}${rm(product.fromPrice)}',
                                  style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 6),
                                _StockBadge(product: product, onTap: () => _editStock(product)),
                              ],
                            ),
                          ),
                          Switch(value: product.isActive, onChanged: (value) => context.read<ShopRepository>().setProductActive(product, value)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        ]),
      ),
    );
  }

  Future<void> _editStock(Product product) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Theme(
      data: kitchenThemeData,
      child: _StockSheet(product: product),
    ),
  );
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = product.isSoldOut
        ? Theme.of(context).colorScheme.error
        : product.isLowStock
        ? context.tart.accent
        : const Color(0xFF7FD1A8);
    final text = product.hasSizes
        ? product.sizes.map((size) => '${size.code} ${product.stockFor(size)}').join(' · ')
        : product.isSoldOut
        ? 'Sold out'
        : '${product.stock} in stock';

    return InkWell(
      onTap: onTap,
      borderRadius: context.tart.radius(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: context.tart.radius(99)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockSheet extends StatefulWidget {
  const _StockSheet({required this.product});

  final Product product;

  @override
  State<_StockSheet> createState() => _StockSheetState();
}

class _StockSheetState extends State<_StockSheet> {
  late final List<ProductSize?> _sizes = widget.product.hasSizes ? widget.product.sizes : [null];
  late final Map<ProductSize?, int> _counts = {for (final size in _sizes) size: widget.product.stockFor(size)};
  late final Map<ProductSize?, int> _received = {for (final size in _sizes) size: 0};

  /// Receiving adds to stock (safe while sales happen); counting overwrites it.
  bool _receiving = true;
  bool _saving = false;

  Future<void> _save() async {
    final repository = context.read<ShopRepository>();
    setState(() => _saving = true);
    try {
      if (_receiving) {
        for (final MapEntry(key: size, value: quantity) in _received.entries) {
          await repository.restock(widget.product, size, quantity);
        }
      } else {
        await repository.setStock(widget.product, _counts);
      }
      if (mounted) {
        Navigator.pop(context);
        final added = _received.values.fold(0, (acc, quantity) => acc + quantity);
        showMessage(context, _receiving ? 'Received $added × ${widget.product.name}.' : '${widget.product.name} stock updated.');
      }
    } catch (error) {
      if (mounted) showMessage(context, 'Couldn’t save stock: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final values = _receiving ? _received : _counts;
    final nothingReceived = _receiving && _received.values.every((quantity) => quantity == 0);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Stock · ${widget.product.name}', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, icon: Icon(Icons.move_to_inbox_rounded), label: Text('Receive delivery')),
              ButtonSegment(value: false, icon: Icon(Icons.inventory_2_outlined), label: Text('Count stock')),
            ],
            selected: {_receiving},
            onSelectionChanged: (value) => setState(() => _receiving = value.first),
          ),
          const SizedBox(height: 6),
          Text(
            _receiving ? 'Adds to what’s on the shelf, without overwriting sales made meanwhile.' : 'Sets the exact number on the shelf after a stock count.',
            style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          for (final size in _sizes)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${size?.label ?? (_receiving ? 'Received' : 'In stock')}${_receiving ? '\nnow ${widget.product.stockFor(size)}' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700, height: 1.3),
                    ),
                  ),
                  for (final step in _receiving ? [10, 20] : [-10, 10])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(step > 0 ? '+$step' : '$step'),
                        onPressed: () => setState(() => values[size] = (values[size]! + step).clamp(0, 9999)),
                      ),
                    ),
                  QuantityStepper(value: values[size]!, min: 0, max: 9999, onChanged: (value) => setState(() => values[size] = value)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving || nothingReceived ? null : _save,
              child: Text(_saving ? 'Saving…' : (_receiving ? 'Add to stock' : 'Save count')),
            ),
          ),
        ],
      ),
    );
  }
}
