import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/order.dart';
import '../../services/format.dart';
import '../../services/shop_repository.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

/// Headline figures for one channel over a period, compared with the period before.
class _ChannelSummary {
  _ChannelSummary(List<ShopOrder> current, List<ShopOrder> previous)
    : revenue = _net(current),
      refunded = current.fold(0.0, (acc, order) => acc + order.refundedAmount),
      orders = current.length,
      items = current.fold(0, (acc, order) => acc + order.itemCount),
      revenueChange = _change(_net(current), _net(previous)),
      ordersChange = _change(current.length.toDouble(), previous.length.toDouble());

  final double revenue;
  final double refunded;
  final int orders;
  final int items;
  final double? revenueChange;
  final double? ordersChange;

  double get average => orders == 0 ? 0 : revenue / orders;

  static double _net(List<ShopOrder> orders) => orders.fold(0.0, (acc, order) => acc + order.netTotal);

  static double? _change(double current, double previous) => previous <= 0 ? null : (current - previous) / previous * 100;
}

/// Online orders and counter sales side by side, like the website's admin/sales page.
class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  int _days = 30;
  late Stream<List<ShopOrder>> _orders = _load();

  DateTime get _startOfToday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Twice the period, so it can be compared with the one before.
  Stream<List<ShopOrder>> _load() => context.read<ShopRepository>().ordersSince(_startOfToday.subtract(Duration(days: _days * 2 - 1)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales report')),
      body: StreamBuilder<List<ShopOrder>>(
        stream: _orders,
        builder: (context, snapshot) {
          if (snapshot.hasError) return ErrorView(snapshot.error);
          if (!snapshot.hasData) return const LoadingView();

          final from = _startOfToday.subtract(Duration(days: _days - 1));
          final counted = snapshot.data!.where((order) => order.status != OrderStatus.cancelled).toList();
          final current = counted.where((order) => !order.createdAt.isBefore(from)).toList();
          final previous = counted.where((order) => order.createdAt.isBefore(from)).toList();
          List<ShopOrder> only(List<ShopOrder> list, SalesChannel channel) => list.where((order) => order.channel == channel).toList();

          final online = _ChannelSummary(only(current, SalesChannel.online), only(previous, SalesChannel.online));
          final counter = _ChannelSummary(only(current, SalesChannel.counter), only(previous, SalesChannel.counter));

          final days = [for (var i = 0; i < _days; i++) from.add(Duration(days: i))];
          final daily = {
            for (final day in days) day: <SalesChannel, double>{SalesChannel.online: 0, SalesChannel.counter: 0},
          };
          for (final order in current) {
            final day = DateTime(order.createdAt.year, order.createdAt.month, order.createdAt.day);
            daily[day]?[order.channel] = daily[day]![order.channel]! + order.netTotal;
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: staggered([
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text('7 days')),
                  ButtonSegment(value: 30, label: Text('30 days')),
                  ButtonSegment(value: 90, label: Text('90 days')),
                ],
                selected: {_days},
                onSelectionChanged: (value) => setState(() {
                  _days = value.first;
                  _orders = _load();
                }),
              ),
              const SizedBox(height: 14),
              Panel(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Net sales · last $_days days', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          CountUpText(
                            value: online.revenue + counter.revenue,
                            format: rm,
                            style: displayFont(context, size: 32, color: context.tart.accent),
                          ),
                          Text(
                            '${online.orders + counter.orders} orders${online.refunded + counter.refunded > 0 ? ' · ${rm(online.refunded + counter.refunded)} refunded' : ''}',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ChannelCard(channel: SalesChannel.online, summary: online),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ChannelCard(channel: SalesChannel.counter, summary: counter),
                  ),
                ],
              ),
              const SectionTitle('Net sales per day', padding: EdgeInsets.fromLTRB(4, 22, 0, 8)),
              Panel(
                child: _DailyChart(days: days, daily: daily),
              ),
              const SizedBox(height: 4),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: const Text('Show as table', style: TextStyle(fontWeight: FontWeight.w700)),
                  children: [
                    for (final day in days.reversed)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                        child: Row(
                          children: [
                            Expanded(child: Text(shortDateTime(day).split(',').first)),
                            SizedBox(width: 92, child: Text(rm(daily[day]![SalesChannel.online]!), textAlign: TextAlign.end)),
                            SizedBox(width: 92, child: Text(rm(daily[day]![SalesChannel.counter]!), textAlign: TextAlign.end)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              for (final channel in SalesChannel.values) ...[
                SectionTitle('Best sellers · ${channel.label.toLowerCase()}', padding: const EdgeInsets.fromLTRB(4, 18, 0, 8)),
                _TopProducts(orders: only(current, channel)),
              ],
              const SectionTitle('How online orders were received', padding: EdgeInsets.fromLTRB(4, 18, 0, 8)),
              _Breakdown(
                rows: [
                  for (final method in DeliveryMethod.values)
                    (
                      method.icon,
                      method.name[0].toUpperCase() + method.name.substring(1),
                      only(current, SalesChannel.online).where((order) => order.deliveryMethod == method).toList(),
                    ),
                ],
              ),
              const SectionTitle('How counter customers paid', padding: EdgeInsets.fromLTRB(4, 18, 0, 8)),
              _Breakdown(
                rows: [
                  for (final method in PaymentMethod.forCounter)
                    (method.icon, method.label, only(current, SalesChannel.counter).where((order) => order.paymentMethod == method).toList()),
                ],
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.channel, required this.summary});

  final SalesChannel channel;
  final _ChannelSummary summary;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final change = summary.revenueChange;

    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: channel.color, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 6),
              Text(channel.label, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            child: CountUpText(value: summary.revenue, format: rm, style: displayFont(context, size: 22)),
          ),
          Text('${summary.orders} orders · ${summary.items} items', style: TextStyle(fontSize: 12, color: muted)),
          Text('Avg ${rm(summary.average)}', style: TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 4),
          Text(
            change == null ? 'No earlier sales to compare' : '${change >= 0 ? '▲' : '▼'} ${change.abs().toStringAsFixed(1)}% vs previous',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: change == null ? muted : null),
          ),
        ],
      ),
    );
  }
}

/// Stacked daily bars: online at the base, counter on top, 2px surface gap between them.
class _DailyChart extends StatefulWidget {
  const _DailyChart({required this.days, required this.daily});

  final List<DateTime> days;
  final Map<DateTime, Map<SalesChannel, double>> daily;

  @override
  State<_DailyChart> createState() => _DailyChartState();
}

class _DailyChartState extends State<_DailyChart> {
  DateTime? _focused;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final totals = [for (final day in widget.days) widget.daily[day]!.values.fold(0.0, (acc, value) => acc + value)];
    final peak = totals.fold(0.0, (acc, value) => value > acc ? value : acc);
    final focused = _focused ?? widget.days.last;
    final focusedValues = widget.daily[focused]!;
    const chartHeight = 150.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final channel in SalesChannel.values) ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: channel.color, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 5),
              Text(channel.label, style: TextStyle(fontSize: 12, color: muted)),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('peak ${rm(peak)}', style: TextStyle(fontSize: 12, color: muted)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '${shortDateTime(focused).split(',').first}: online ${rm(focusedValues[SalesChannel.online]!)} · counter ${rm(focusedValues[SalesChannel.counter]!)}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: chartHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slot = constraints.maxWidth / widget.days.length;
              final barWidth = (slot * 0.7).clamp(2.0, 18.0);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => setState(() => _focused = widget.days[(details.localPosition.dx / slot).floor().clamp(0, widget.days.length - 1)]),
                onHorizontalDragUpdate: (details) =>
                    setState(() => _focused = widget.days[(details.localPosition.dx / slot).floor().clamp(0, widget.days.length - 1)]),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outline)),
                  ),
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(widget.days.length),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, grow, _) => Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final day in widget.days)
                          SizedBox(
                            width: slot,
                            child: Center(
                              child: Opacity(
                                opacity: day == focused ? 1 : 0.75,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    for (final channel in SalesChannel.values.reversed)
                                      if (widget.daily[day]![channel]! > 0 && peak > 0)
                                        Container(
                                          width: barWidth,
                                          height: (widget.daily[day]![channel]! / peak * (chartHeight - 8) * grow).clamp(2.0, chartHeight),
                                          margin: EdgeInsets.only(top: channel == SalesChannel.online && widget.daily[day]![SalesChannel.counter]! > 0 ? 2 : 0),
                                          decoration: BoxDecoration(
                                            color: channel.color,
                                            borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(channel == SalesChannel.counter || widget.daily[day]![SalesChannel.counter]! == 0 ? 4 : 0),
                                            ),
                                          ),
                                        ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(shortDateTime(widget.days.first).split(',').first, style: TextStyle(fontSize: 11, color: muted)),
            const Spacer(),
            Text('Today', style: TextStyle(fontSize: 11, color: muted)),
          ],
        ),
      ],
    );
  }
}

class _TopProducts extends StatelessWidget {
  const _TopProducts({required this.orders});

  final List<ShopOrder> orders;

  @override
  Widget build(BuildContext context) {
    final units = <String, int>{};
    final revenue = <String, double>{};
    for (final order in orders) {
      for (final item in order.items) {
        units[item.name] = (units[item.name] ?? 0) + item.quantity;
        revenue[item.name] = (revenue[item.name] ?? 0) + item.lineTotal;
      }
    }
    final ranked = units.keys.toList()..sort((a, b) => units[b]!.compareTo(units[a]!));
    if (ranked.isEmpty) return const Panel(child: Text('No sales in this period.'));

    return Panel(
      child: Column(
        children: [
          for (final (index, name) in ranked.take(5).indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text('${index + 1}', style: displayFont(context, size: 16, color: context.tart.accent)),
                  ),
                  Expanded(child: Text(name)),
                  Text('${units[name]} · ${rm(revenue[name]!)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.rows});

  final List<(IconData, String, List<ShopOrder>)> rows;

  @override
  Widget build(BuildContext context) {
    final sorted = [...rows]..sort((a, b) => b.$3.fold(0.0, (acc, o) => acc + o.netTotal).compareTo(a.$3.fold(0.0, (acc, o) => acc + o.netTotal)));
    return Panel(
      child: Column(
        children: [
          for (final (icon, label, orders) in sorted)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(child: Text(label)),
                  Text('${orders.length} · ${rm(orders.fold(0.0, (acc, order) => acc + order.netTotal))}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
