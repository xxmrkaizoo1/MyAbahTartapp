import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/order.dart';
import '../../services/auth_service.dart';
import '../../services/shop_repository.dart';
import '../../theme.dart';
import '../../widgets/motion.dart';
import '../../widgets/common.dart';
import 'admin_dashboard.dart';
import 'admin_menu.dart';
import 'admin_more.dart';
import 'admin_orders.dart';
import 'pos_screen.dart';

/// Kitchen mode: the staff side of the app, in a dark oven theme.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late final Stream<List<ShopOrder>> _orders = context.read<ShopRepository>().recentOrders();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthService, bool>((auth) => auth.isAdmin);

    return Theme(
      data: kitchenThemeData,
      child: Builder(
        builder: (context) {
          if (!isAdmin) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Kitchen mode is for shop staff only.')),
            );
          }

          return StreamBuilder<List<ShopOrder>>(
            stream: _orders,
            builder: (context, snapshot) {
              final orders = snapshot.data;
              final newCount = orders?.where((order) => order.status.name == 'received' && !order.isCounterSale).length ?? 0;

              final Widget body;
              if (snapshot.hasError) {
                body = ErrorView(snapshot.error);
              } else if (orders == null) {
                body = const LoadingView();
              } else {
                body = AnimatedTabStack(
                  index: _index,
                  children: [
                    AdminDashboard(orders: orders, onOpenOrders: () => setState(() => _index = 1)),
                    AdminOrdersScreen(orders: orders),
                    const PosScreen(),
                    const AdminMenuScreen(),
                    const AdminMoreScreen(),
                  ],
                );
              }

              return Scaffold(
                appBar: AppBar(
                  title: Row(
                    children: [
                      Icon(Icons.soup_kitchen_rounded, color: context.tart.accent),
                      const SizedBox(width: 10),
                      Flexible(child: Text(const ['Today', 'Orders', 'Counter', 'Menu & stock', 'More'][_index], overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  actions: [
                    TextButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.storefront_outlined), label: const Text('Shop')),
                    const SizedBox(width: 8),
                  ],
                ),
                body: body,
                bottomNavigationBar: NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (index) => setState(() => _index = index),
                  destinations: [
                    const NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded), label: 'Today'),
                    NavigationDestination(
                      icon: Badge(isLabelVisible: newCount > 0, label: Text('$newCount'), child: const Icon(Icons.receipt_long_outlined)),
                      selectedIcon: const Icon(Icons.receipt_long_rounded),
                      label: 'Orders',
                    ),
                    const NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale_rounded), label: 'Counter'),
                    const NavigationDestination(icon: Icon(Icons.bakery_dining_outlined), selectedIcon: Icon(Icons.bakery_dining_rounded), label: 'Menu'),
                    const NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune_rounded), label: 'More'),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
