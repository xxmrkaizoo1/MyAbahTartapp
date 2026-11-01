import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/product.dart';
import '../../services/shop_repository.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/tart_art.dart';

/// Creates a new product, or edits [product] when given.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Product? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _SizeFields {
  _SizeFields(Product? product, ProductSize size)
    : enabled = product?.sizePrices.containsKey(size.code) ?? false,
      price = TextEditingController(text: product?.sizePrices[size.code]?.toStringAsFixed(2) ?? ''),
      stock = TextEditingController(text: '${product?.sizeStock[size.code] ?? 0}'),
      pieces = TextEditingController(text: product?.sizePieces[size.code]?.toString() ?? '');

  bool enabled;
  final TextEditingController price;
  final TextEditingController stock;
  final TextEditingController pieces;

  void dispose() {
    price.dispose();
    stock.dispose();
    pieces.dispose();
  }
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _form = GlobalKey<FormState>();
  late final Product? _original = widget.product;
  late final _name = TextEditingController(text: _original?.name);
  late final _tagline = TextEditingController(text: _original?.tagline);
  late final _description = TextEditingController(text: _original?.description);
  late final _price = TextEditingController(text: _original?.price.toStringAsFixed(2));
  late final _unit = TextEditingController(text: _original?.unitLabel ?? 'Single');
  late final _weight = TextEditingController(text: _original?.weightGrams?.toString());
  late final _stock = TextEditingController(text: '${_original?.stock ?? 20}');
  late final _lowStock = TextEditingController(text: '${_original?.lowStockThreshold ?? 10}');
  late final _image = TextEditingController(text: _original?.imageUrl);
  late final _sizes = {for (final size in ProductSize.values) size: _SizeFields(_original, size)};

  late String? _categoryId = _original?.categoryId;
  late String _art = _original?.art ?? 'pineapple';
  late bool _hasSizes = _original?.hasSizes ?? false;
  late bool _active = _original?.isActive ?? true;
  late bool _bestseller = _original?.isBestseller ?? false;
  late bool _seasonal = _original?.isSeasonal ?? false;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [_name, _tagline, _description, _price, _unit, _weight, _stock, _lowStock, _image]) {
      controller.dispose();
    }
    for (final fields in _sizes.values) {
      fields.dispose();
    }
    super.dispose();
  }

  String? _money(String? value) => (double.tryParse(value ?? '') ?? -1) < 0 ? 'Enter a price, e.g. 12.50' : null;

  String? _count(String? value) => (int.tryParse(value ?? '') ?? -1) < 0 ? 'Enter a whole number' : null;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final offered = _sizes.entries.where((entry) => entry.value.enabled).toList();
    if (_hasSizes && offered.isEmpty) {
      showMessage(context, 'Switch on at least one size, or turn sizes off.');
      return;
    }

    final product = Product(
      id: _original?.id ?? '',
      name: _name.text.trim(),
      categoryId: _categoryId ?? '',
      tagline: _tagline.text.trim(),
      description: _description.text.trim(),
      price: double.tryParse(_price.text) ?? 0,
      sizePrices: _hasSizes ? {for (final entry in offered) entry.key.code: double.parse(entry.value.price.text)} : const {},
      sizeStock: _hasSizes ? {for (final entry in offered) entry.key.code: int.parse(entry.value.stock.text)} : const {},
      sizePieces: _hasSizes
          ? {
              for (final entry in offered)
                if ((int.tryParse(entry.value.pieces.text) ?? 0) > 0) entry.key.code: int.parse(entry.value.pieces.text),
            }
          : const {},
      sizeImages: _original?.sizeImages ?? const {},
      unitLabel: _unit.text.trim().isEmpty ? 'Single' : _unit.text.trim(),
      weightGrams: (int.tryParse(_weight.text) ?? 0) > 0 ? int.parse(_weight.text) : null,
      art: _art,
      imageUrl: _image.text.trim().isEmpty ? null : _image.text.trim(),
      stock: int.tryParse(_stock.text) ?? 0,
      lowStockThreshold: int.tryParse(_lowStock.text) ?? 10,
      isActive: _active,
      isBestseller: _bestseller,
      isSeasonal: _seasonal,
    );

    setState(() => _saving = true);
    try {
      await context.read<ShopRepository>().saveProduct(product, isNew: _original == null);
      if (mounted) {
        Navigator.pop(context);
        showMessage(context, '${product.name} saved.');
      }
    } catch (error) {
      if (mounted) showMessage(context, 'Couldn’t save: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final repository = context.read<ShopRepository>();
    final navigator = Navigator.of(context);
    final ok = await confirm(
      context,
      title: 'Delete ${_original!.name}?',
      message: 'Past orders keep their details. To hide it for now, switch it off instead.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await repository.deleteProduct(_original.id);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<List<MenuCategory>>();
    const gap = SizedBox(height: 12);

    return Scaffold(
      appBar: AppBar(
        title: Text(_original == null ? 'New tart' : 'Edit tart'),
        actions: [if (_original != null) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded), tooltip: 'Delete')],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: staggered([
            Center(
              child: TartArt(art: _art, imageUrl: _image.text.trim(), size: 130),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Give it a name' : null,
            ),
            gap,
            TextFormField(
              controller: _tagline,
              decoration: const InputDecoration(labelText: 'Tagline', hintText: 'Slow-cooked Morris pineapple jam'),
            ),
            gap,
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true),
            ),
            gap,
            DropdownButtonFormField<String>(
              initialValue: categories.any((category) => category.id == _categoryId) ? _categoryId : null,
              decoration: const InputDecoration(labelText: 'Collection'),
              items: [for (final category in categories) DropdownMenuItem(value: category.id, child: Text(category.name))],
              onChanged: (value) => setState(() => _categoryId = value),
              validator: (value) => value == null ? 'Pick a collection' : null,
            ),
            gap,
            DropdownButtonFormField<String>(
              initialValue: _art,
              decoration: const InputDecoration(labelText: 'Illustration (shown when there’s no photo)'),
              items: [
                for (final MapEntry(key: art, value: label) in tartArtLabels.entries)
                  DropdownMenuItem(
                    value: art,
                    child: Row(
                      children: [
                        TartArt(art: art, size: 26),
                        const SizedBox(width: 10),
                        Text(label),
                      ],
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _art = value ?? _art),
            ),
            gap,
            TextFormField(
              controller: _image,
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Photo URL (optional)', hintText: 'https://… or asset:assets/images/…'),
            ),
            gap,
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _unit,
                    decoration: const InputDecoration(labelText: 'Sold as', hintText: 'Balang, Peket…'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _weight,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Weight (g)', hintText: 'Optional'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sold in sizes (S / M / L)'),
              value: _hasSizes,
              onChanged: (value) => setState(() => _hasSizes = value),
            ),
            if (!_hasSizes)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Price (RM)'),
                      validator: _money,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _stock,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'In stock'),
                      validator: _count,
                    ),
                  ),
                ],
              )
            else
              for (final MapEntry(key: size, value: fields) in _sizes.entries)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(size.label, style: const TextStyle(fontWeight: FontWeight.w800)),
                          value: fields.enabled,
                          onChanged: (value) => setState(() => fields.enabled = value ?? false),
                        ),
                        if (fields.enabled)
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: fields.price,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(labelText: 'RM'),
                                  validator: _money,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: fields.stock,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Stock'),
                                  validator: _count,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: fields.pieces,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Pieces'),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
            gap,
            TextFormField(
              controller: _lowStock,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Warn me when stock falls to'),
              validator: _count,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('On the menu'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bestseller badge'),
              value: _bestseller,
              onChanged: (value) => setState(() => _bestseller = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Limited edition'),
              value: _seasonal,
              onChanged: (value) => setState(() => _seasonal = value),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save tart')),
          ]),
        ),
      ),
    );
  }
}
