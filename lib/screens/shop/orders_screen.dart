import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/order.dart';
import '../../services/auth_service.dart';
import '../../services/format.dart';
import '../../services/shop_repository.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/order_widgets.dart';
import 'order_detail_screen.dart';
import 'profile_screen.dart';
import 'shop_shell.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.select<AuthService, String?>((auth) => auth.uid);
    if (uid == null) {
      return const SafeArea(
        child: SignInPrompt(title: 'Track your orders', message: 'Sign in to follow your order live, from the oven to your door.'),
      );
    }
    return _OrdersList(key: ValueKey(uid), uid: uid);
  }
}

class _OrdersList extends StatefulWidget {
  const _OrdersList({super.key, required this.uid});

  final String uid;

  @override
  State<_OrdersList> createState() => _OrdersListState();
}

class _OrdersListState extends State<_OrdersList> {
  late final Stream<List<ShopOrder>> _orders = context.read<ShopRepository>().myOrders(widget.uid);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: StreamBuilder<List<ShopOrder>>(
        stream: _orders,
        builder: (context, snapshot) {
          if (snapshot.hasError) return ErrorView(snapshot.error);
          if (!snapshot.hasData) return const LoadingView();

          final orders = snapshot.data!;
          if (orders.isEmpty) {
            return EmptyState(
              art: 'caramel',
              title: 'No orders yet',
              message: 'Your first order is just a few taps away.',
              action: 'Order something',
              onAction: () => ShopShell.of(context).openMenu(),
            );
          }

          final active = orders.where((order) => order.status.isActive).toList();
          final past = orders.where((order) => !order.status.isActive).toList();

          return ListView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, navClearance(context)),
            children: [
              Text('Your orders', style: Theme.of(context).textTheme.headlineMedium),
              if (active.isNotEmpty) ...[
                const SectionTitle('In the oven', padding: EdgeInsets.only(top: 20, bottom: 10)),
                for (final (index, order) in active.indexed)
                  FadeSlideIn(
                    index: index,
                    child: _OrderTile(order: order, highlighted: true),
                  ),
              ],
              if (past.isNotEmpty) ...[
                const SectionTitle('Past orders', padding: EdgeInsets.only(top: 20, bottom: 10)),
                for (final (index, order) in past.indexed)
                  FadeSlideIn(
                    index: active.length + index,
                    child: _OrderTile(order: order),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, this.highlighted = false});

  final ShopOrder order;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: highlighted ? context.tart.deep : context.tart.surface,
        shape: RoundedRectangleBorder(
          borderRadius: context.tart.radius(24),
          side: BorderSide(color: highlighted ? context.tart.deep : context.tart.line),
        ),
        child: InkWell(
          borderRadius: context.tart.radius(24),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(code: order.code))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                TartStack(arts: order.items.map((item) => item.art).toList(), size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              order.code,
                              style: TextStyle(fontWeight: FontWeight.w800, color: highlighted ? context.tart.onDeep : context.tart.ink),
                            ),
                          ),
                          Text(
                            rm(order.total),
                            style: TextStyle(fontWeight: FontWeight.w800, color: highlighted ? context.tart.accent : context.tart.ink),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${shortDateTime(order.createdAt)} · ${order.itemCount} item${order.itemCount == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 12.5, color: highlighted ? context.tart.onDeep.withValues(alpha: 0.7) : context.tart.inkSoft),
                      ),
                      const SizedBox(height: 8),
                      StatusChip(order.status, label: order.statusLabel, onDark: highlighted),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: highlighted ? context.tart.accent : context.tart.inkSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
