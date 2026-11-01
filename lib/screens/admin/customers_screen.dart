import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/order.dart';
import '../../models/shop_models.dart';
import '../../services/format.dart';
import '../../services/shop_repository.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import 'admin_orders.dart';

/// One customer with everything they bought: an app account, a customer copied from the website, or both
/// (matched by email).
class CustomerSummary {
  CustomerSummary({required this.profiles, required this.orders});

  final List<AppUser> profiles;
  final List<ShopOrder> orders;

  /// The app account wins over the website copy for contact details.
  AppUser get main => profiles.firstWhere((profile) => !profile.fromWebsite, orElse: () => profiles.first);

  bool get hasAppAccount => profiles.any((profile) => !profile.fromWebsite && !profile.isSample);

  bool get isSample => profiles.every((profile) => profile.isSample);

  bool get fromWebsite => profiles.any((profile) => profile.fromWebsite);

  List<ShopOrder> get completed => orders.where((order) => order.status == OrderStatus.completed).toList();

  double get spent => completed.fold(0.0, (acc, order) => acc + order.netTotal);

  DateTime? get lastOrder => orders.isEmpty ? null : orders.first.createdAt;

  DateTime? get joinedAt => profiles
      .map((profile) => profile.joinedAt)
      .whereType<DateTime>()
      .fold<DateTime?>(null, (earliest, date) => earliest == null || date.isBefore(earliest) ? date : earliest);

  static List<CustomerSummary> build(List<AppUser> users, List<ShopOrder> allOrders) {
    // Counter sales are walk-ins, never tied to a customer.
    final orders = allOrders.where((order) => order.channel == SalesChannel.online);
    final byEmail = <String, List<AppUser>>{};
    for (final user in users) {
      byEmail.putIfAbsent(user.email.trim().toLowerCase().isEmpty ? user.uid : user.email.trim().toLowerCase(), () => []).add(user);
    }
    return [
      for (final MapEntry(key: email, value: profiles) in byEmail.entries)
        CustomerSummary(
          profiles: profiles,
          orders:
              orders
                  .where((order) => profiles.any((profile) => profile.uid == order.userId) || (order.email.isNotEmpty && order.email.toLowerCase() == email))
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        ),
    ]..sort((a, b) => b.spent != a.spent ? b.spent.compareTo(a.spent) : a.main.name.toLowerCase().compareTo(b.main.name.toLowerCase()));
  }
}

/// Every customer, from the app and from the website, with what they've ordered.
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  late final Stream<List<AppUser>> _customers = context.read<ShopRepository>().customers();
  late final Stream<List<ShopOrder>> _orders = context.read<ShopRepository>().recentOrders(limit: 1000);
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: StreamBuilder<List<AppUser>>(
        stream: _customers,
        builder: (context, users) => StreamBuilder<List<ShopOrder>>(
          stream: _orders,
          builder: (context, orders) {
            if (users.hasError || orders.hasError) return ErrorView(users.error ?? orders.error);
            if (users.data == null || orders.data == null) return const LoadingView();

            final all = CustomerSummary.build(users.data!, orders.data!);
            final shown = all.where((customer) {
              if (_query.isEmpty) return true;
              final user = customer.main;
              return '${user.name} ${user.email} ${user.phone ?? ''}'.toLowerCase().contains(_query);
            }).toList();
            final spent = all.fold(0.0, (acc, customer) => acc + customer.spent);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: staggered([
                Row(
                  children: [
                    Expanded(
                      child: Panel(
                        child: _Figure(label: 'Customers', value: '${all.length}'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Panel(
                        child: _Figure(label: 'Spent (completed)', value: rm(spent)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                  decoration: const InputDecoration(hintText: 'Search name, email or phone', prefixIcon: Icon(Icons.search_rounded)),
                ),
                const SizedBox(height: 12),
                if (shown.isEmpty) const Panel(child: Text('No customers found.')),
                for (final customer in shown) _CustomerTile(customer: customer),
              ]),
            );
          },
        ),
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.customer});

  final CustomerSummary customer;

  @override
  Widget build(BuildContext context) {
    final user = customer.main;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => Theme(
                data: kitchenThemeData,
                child: CustomerDetailScreen(customer: customer),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: context.tart.accent,
                  child: Text(
                    user.initials,
                    style: TextStyle(fontWeight: FontWeight.w800, color: context.tart.onAccent),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        [user.email, if (user.phone?.isNotEmpty ?? false) user.phone!].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: muted),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (customer.hasAppAccount) Tag('App', color: context.tart.successSoft, foreground: context.tart.successInk),
                          if (customer.fromWebsite) Tag('Website', color: context.tart.line, foreground: context.tart.ink),
                          if (customer.isSample) Tag('Sample', color: context.tart.line, foreground: context.tart.inkSoft),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      rm(customer.spent),
                      style: TextStyle(fontWeight: FontWeight.w800, color: context.tart.accent),
                    ),
                    Text('${customer.orders.length} order${customer.orders.length == 1 ? '' : 's'}', style: TextStyle(fontSize: 12, color: muted)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A customer's contact details and order history.
class CustomerDetailScreen extends StatelessWidget {
  const CustomerDetailScreen({super.key, required this.customer});

  final CustomerSummary customer;

  @override
  Widget build(BuildContext context) {
    final user = customer.main;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final average = customer.completed.isEmpty ? 0.0 : customer.spent / customer.completed.length;

    Widget detail(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: muted),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(user.name, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: staggered([
          Panel(
            title: 'Contact',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                detail(Icons.mail_outline_rounded, user.email.isEmpty ? '—' : user.email),
                detail(Icons.phone_outlined, user.phone?.isNotEmpty ?? false ? user.phone! : '—'),
                detail(Icons.home_outlined, user.address?.isNotEmpty ?? false ? user.address! : '—'),
                detail(
                  Icons.badge_outlined,
                  [
                    if (customer.hasAppAccount) 'Has an app account',
                    if (customer.fromWebsite) 'Website customer',
                    if (customer.isSample) 'Sample customer (made up)',
                    if (customer.joinedAt != null) 'joined ${shortDateTime(customer.joinedAt!).split(',').first}',
                  ].join(' · '),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Panel(
                  child: _Figure(label: 'Spent', value: rm(customer.spent)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Panel(
                  child: _Figure(label: 'Orders', value: '${customer.orders.length}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Panel(
                  child: _Figure(label: 'Average', value: rm(average)),
                ),
              ),
            ],
          ),
          const SectionTitle('Orders', padding: EdgeInsets.fromLTRB(4, 18, 0, 8)),
          if (customer.orders.isEmpty) const Panel(child: Text('No orders yet.')),
          for (final order in customer.orders)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => Theme(
                        data: kitchenThemeData,
                        child: AdminOrderDetail(code: order.code),
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(order.code, style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text(
                                '${shortDateTime(order.createdAt)} · ${order.itemCount} item${order.itemCount == 1 ? '' : 's'}',
                                style: TextStyle(fontSize: 12.5, color: muted),
                              ),
                              const SizedBox(height: 6),
                              StatusChip(order.status, label: order.statusLabel),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(rm(order.total), style: const TextStyle(fontWeight: FontWeight.w800)),
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
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // A fixed line height keeps side-by-side figures the same size while long amounts shrink to fit.
      SizedBox(
        height: MediaQuery.textScalerOf(context).scale(30),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: displayFont(context, size: 22, color: context.tart.accent)),
        ),
      ),
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );
}
