import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../theme.dart';
import 'motion.dart';
import 'tart_art.dart';

Future<void> showThemePicker(BuildContext context) =>
    showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => const _ThemePickerSheet());

class _ThemePickerSheet extends StatelessWidget {
  const _ThemePickerSheet();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          Text('Pick a design', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('The same looks as the website. Your choice is saved on this phone.', style: TextStyle(color: context.tart.inkSoft)),
          const SizedBox(height: 18),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // Tall enough for the card's text at the phone's font size.
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 130 + MediaQuery.textScalerOf(context).scale(74),
            ),
            children: [
              for (final (index, theme) in TartTheme.all.indexed)
                FadeSlideIn(
                  index: index,
                  child: Pressable(
                    child: _ThemeCard(theme: theme, selected: theme.id == controller.theme.id, onTap: () => controller.select(theme)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A miniature of the shop drawn in the theme's own colours and font.
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.theme, required this.selected, required this.onTap});

  final TartTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: theme.label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.bg,
            borderRadius: theme.radius(22),
            border: Border.all(color: selected ? context.tart.primary : theme.line, width: selected ? 3 : 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: theme.deep, borderRadius: theme.radius(16)),
                  child: Stack(
                    children: [
                      const Positioned(right: -14, bottom: -14, child: TartArt(art: 'pineapple', size: 64)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tarts worth', style: theme.display(size: 13, color: theme.onDeep, height: 1)),
                          Text(
                            'crossing',
                            style: theme.display(size: 13, color: theme.accent, style: FontStyle.italic, height: 1.1),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: theme.accent, borderRadius: theme.radius(99)),
                            child: Text(
                              'Shop',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: theme.onAccent),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final color in theme.swatches)
                    Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.line),
                      ),
                    ),
                  const Spacer(),
                  if (selected) Icon(Icons.check_circle_rounded, size: 20, color: context.tart.primary),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                theme.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.display(size: 15, color: theme.ink),
              ),
              Text(
                theme.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: theme.inkSoft, height: 1.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
