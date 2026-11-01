import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../theme.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/product_card.dart';
import '../../widgets/tart_art.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key, required this.category});

  /// The collection to show, set by other tabs. Null shows everything.
  final ValueNotifier<String?> category;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<List<Product>?>();
    final categories = context
        .watch<List<MenuCategory>>()
        .where((category) => (all ?? const <Product>[]).any((product) => product.isActive && product.categoryId == category.id))
        .toList();

    return SafeArea(
      bottom: false,
      child: ValueListenableBuilder<String?>(
        valueListenable: widget.category,
        builder: (context, selected, _) {
          final products =
              (all ?? const <Product>[])
                  .where((product) => product.isActive)
                  .where((product) => selected == null || product.categoryId == selected)
                  .where((product) => _query.isEmpty || '${product.name} ${product.tagline}'.toLowerCase().contains(_query))
                  .toList()
                ..sort((a, b) => a.isSoldOut == b.isSoldOut ? 0 : (a.isSoldOut ? 1 : -1));

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(eyebrow: 'Shop all', title: 'Our menu'),
                      const SizedBox(height: 6),
                      Text('Prepared fresh for every order. Grab them while they last.', style: TextStyle(color: context.tart.inkSoft)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _search,
                        textInputAction: TextInputAction.search,
                        onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Search products',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () => setState(() {
                                    _search.clear();
                                    _query = '';
                                  }),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 68,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    children: [
                      _chip('All', selected == null, () => widget.category.value = null),
                      for (final category in categories)
                        _chip(category.name, selected == category.id, () => widget.category.value = category.id, category: category),
                    ],
                  ),
                ),
              ),
              if (all == null)
                const SliverToBoxAdapter(child: LoadingView())
              else if (products.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: EmptyState(art: 'lemon', title: 'Nothing here yet', message: 'Try another collection or search for something else.'),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, navClearance(context)),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      // Size cards to their content so there is no empty gap under the price.
                      const spacing = 14.0;
                      final columns = (constraints.crossAxisExtent / 240).ceil().clamp(2, 4);
                      final cardWidth = (constraints.crossAxisExtent - spacing * (columns - 1)) / columns;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: spacing,
                          crossAxisSpacing: spacing,
                          mainAxisExtent: ProductCard.heightFor(context, cardWidth),
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (_, index) => FadeSlideIn(
                            // A new key per filter replays the cascade when the list changes.
                            key: ValueKey('$selected|$_query|${products[index].id}'),
                            index: index,
                            child: ProductCard(product: products[index], heroScope: 'menu'),
                          ),
                          childCount: products.length,
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, {MenuCategory? category}) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      avatar: category == null
          ? null
          : SizedBox.square(
              dimension: 26,
              child: ClipOval(
                child: ProductPhoto(art: category.art, imageUrl: category.imageUrl),
              ),
            ),
      onSelected: (_) => onTap(),
    ),
  );
}
