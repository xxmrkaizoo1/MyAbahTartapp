import 'dart:math' as math;

import '../models/enums.dart';
import '../models/order.dart';

const _weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

DateTime _dayOf(DateTime time) => DateTime(time.year, time.month, time.day);

/// Sales per day, from the first sale up to yesterday. Today is left out because
/// a half-finished day would look like a drop in sales.
class SalesHistory {
  const SalesHistory({required this.firstDay, required this.revenue, required this.items});

  factory SalesHistory.fromOrders(List<ShopOrder> orders, DateTime now) {
    final today = _dayOf(now);
    final counted = orders.where((order) => order.status != OrderStatus.cancelled && _dayOf(order.createdAt).isBefore(today)).toList();
    if (counted.isEmpty) return SalesHistory(firstDay: today, revenue: const [], items: const []);

    final firstDay = counted.map((order) => _dayOf(order.createdAt)).reduce((a, b) => a.isBefore(b) ? a : b);
    final length = _daysBetween(firstDay, today);
    final revenue = List<double>.filled(length, 0);
    final items = List<double>.filled(length, 0);
    for (final order in counted) {
      final index = _daysBetween(firstDay, _dayOf(order.createdAt));
      revenue[index] += order.netTotal;
      items[index] += order.itemCount;
    }
    return SalesHistory(firstDay: firstDay, revenue: revenue, items: items);
  }

  final DateTime firstDay;
  final List<double> revenue;
  final List<double> items;

  static int _daysBetween(DateTime from, DateTime to) => DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
}

enum ForecastConfidence {
  low('Low'),
  medium('Medium'),
  high('High');

  const ForecastConfidence(this.label);
  final String label;
}

/// A trend line with a weekly pattern, fitted to daily figures.
class _Fit {
  _Fit._(this._level, this._slope, this._weekdayFactors, this._firstWeekday, this._length, this.errorPerDay);

  factory _Fit.to(List<double> values, DateTime firstDay) {
    final n = values.length;

    // Straight line through the figures: returns (intercept, slope).
    (double, double) line(List<double> series) {
      final meanT = (n - 1) / 2;
      final meanY = series.reduce((a, b) => a + b) / n;
      var top = 0.0;
      var bottom = 0.0;
      for (var t = 0; t < n; t++) {
        top += (t - meanT) * (series[t] - meanY);
        bottom += (t - meanT) * (t - meanT);
      }
      final slope = bottom == 0 ? 0.0 : top / bottom;
      return (meanY - slope * meanT, slope);
    }

    // Weekdays are measured against the trend, not the overall average, or
    // growth would make the later days of the week look busier than they are.
    final (roughIntercept, roughSlope) = line(values);
    final totals = List<double>.filled(7, 0);
    final counts = List<int>.filled(7, 0);
    for (var t = 0; t < n; t++) {
      final expected = roughIntercept + roughSlope * t;
      if (expected <= 0) continue;
      final slot = (firstDay.weekday - 1 + t) % 7;
      totals[slot] += values[t] / expected;
      counts[slot]++;
    }

    // A weekday seen only a few times is pulled towards "average" so that one
    // busy Saturday isn't taken for a pattern.
    final raw = [for (var slot = 0; slot < 7; slot++) (totals[slot] + 1) / (counts[slot] + 1)];
    final rawMean = raw.reduce((a, b) => a + b) / 7;
    final factors = [for (final factor in raw) factor / rawMean];

    double factorAt(int t) => factors[(firstDay.weekday - 1 + t) % 7];

    final (intercept, slope) = line([for (var t = 0; t < n; t++) values[t] / factorAt(t)]);

    var squared = 0.0;
    for (var t = 0; t < n; t++) {
      final residual = values[t] - factorAt(t) * (intercept + slope * t);
      squared += residual * residual;
    }
    return _Fit._(intercept + slope * (n - 1), slope, factors, firstDay.weekday - 1, n, n > 2 ? math.sqrt(squared / (n - 2)) : 0);
  }

  /// How quickly a trend fades. Without this a good fortnight would be projected
  /// as growing forever.
  static const _trendFade = 0.9;

  final double _level;
  final double _slope;
  final List<double> _weekdayFactors;
  final int _firstWeekday;
  final int _length;
  final double errorPerDay;

  List<double> predict(int days) {
    final result = <double>[];
    var drift = 0.0;
    var fade = 1.0;
    for (var ahead = 1; ahead <= days; ahead++) {
      fade *= _trendFade;
      drift += _slope * fade;
      final factor = _weekdayFactors[(_firstWeekday + _length - 1 + ahead) % 7];
      result.add(math.max(0, (_level + drift) * factor));
    }
    return result;
  }
}

/// What the next [daily].length days are likely to bring.
class Forecast {
  const Forecast({required this.firstDay, required this.daily, required this.total, required this.low, required this.high, required this.confidence, this.pastError});

  /// Less history than this gives a guess, not a forecast.
  static const minDays = 14;
  static const minDaysWithSales = 5;
  static const _testDays = 7;

  /// Returns null when there isn't enough history to say anything useful.
  static Forecast? compute(List<double> values, DateTime historyStart, int days) {
    final daysWithSales = values.where((value) => value > 0).length;
    if (values.length < minDays || daysWithSales < minDaysWithSales) return null;

    final fit = _Fit.to(values, historyStart);
    final daily = fit.predict(days);
    final total = daily.fold(0.0, (acc, value) => acc + value);
    // On simulated sales, about 7 forecasts in 10 landed inside this range.
    final spread = 1.28 * fit.errorPerDay * math.sqrt(days);

    final pastError = _testOnRecentDays(values, historyStart);
    return Forecast(
      firstDay: historyStart.add(Duration(days: values.length)),
      daily: daily,
      total: total,
      low: math.max(0, total - spread),
      high: total + spread,
      pastError: pastError,
      confidence: _confidenceFor(values.length, daysWithSales, pastError),
    );
  }

  /// Hides the latest week, predicts it, and compares with what really happened.
  /// Returns how far off that was (0.2 = 20%), or null if it can't be tested.
  static double? _testOnRecentDays(List<double> values, DateTime historyStart) {
    final trainingLength = values.length - _testDays;
    if (trainingLength < minDays) return null;
    final actual = values.skip(trainingLength).fold(0.0, (acc, value) => acc + value);
    if (actual <= 0) return null;
    final predicted = _Fit.to(values.sublist(0, trainingLength), historyStart).predict(_testDays).fold(0.0, (acc, value) => acc + value);
    return (predicted - actual).abs() / actual;
  }

  static ForecastConfidence _confidenceFor(int length, int daysWithSales, double? pastError) {
    if (pastError == null) return ForecastConfidence.low;
    if (length >= 56 && daysWithSales >= length / 2 && pastError <= 0.2) return ForecastConfidence.high;
    if (length >= 28 && pastError <= 0.4) return ForecastConfidence.medium;
    return ForecastConfidence.low;
  }

  final DateTime firstDay;
  final List<double> daily;
  final double total;
  final double low;
  final double high;
  final ForecastConfidence confidence;

  /// How far off a test on the latest week was; null if it couldn't be tested.
  final double? pastError;
}

class ProductTrend {
  const ProductTrend({required this.name, required this.recentUnits, required this.previousUnits});

  final String name;
  final int recentUnits;
  final int previousUnits;

  int get difference => recentUnits - previousUnits;

  /// Null for a product with no sales in the earlier period.
  double? get change => previousUnits == 0 ? null : difference / previousUnits * 100;
}

/// How the latest period compares with the one before it.
class TrendReport {
  const TrendReport({
    required this.days,
    required this.revenue,
    required this.orders,
    required this.items,
    required this.hasComparison,
    this.revenueChange,
    this.ordersChange,
    this.itemsChange,
    this.rising = const [],
    this.falling = const [],
    this.bestWeekday,
    this.slowestWeekday,
    this.onlineShare,
  });

  /// A product needs this many units across both periods to count as a trend,
  /// otherwise selling 2 instead of 1 reads as "+100%".
  static const minUnitsForTrend = 5;

  factory TrendReport.fromOrders(List<ShopOrder> orders, DateTime now, {int days = 30}) {
    final today = _dayOf(now);
    final recentStart = DateTime(today.year, today.month, today.day - days);
    final previousStart = DateTime(today.year, today.month, today.day - days * 2);
    final counted = orders.where((order) => order.status != OrderStatus.cancelled).toList();

    final recent = counted.where((order) => !order.createdAt.isBefore(recentStart) && order.createdAt.isBefore(today)).toList();
    final previous = counted.where((order) => !order.createdAt.isBefore(previousStart) && order.createdAt.isBefore(recentStart)).toList();

    // A shop that started selling halfway through the earlier period would show
    // growth that isn't real, so that period must be complete to compare with it.
    final hasComparison = previous.isNotEmpty && counted.any((order) => !_dayOf(order.createdAt).isAfter(previousStart));

    double net(List<ShopOrder> list) => list.fold(0.0, (acc, order) => acc + order.netTotal);
    int itemsIn(List<ShopOrder> list) => list.fold(0, (acc, order) => acc + order.itemCount);
    double? change(num current, num earlier) => !hasComparison || earlier <= 0 ? null : (current - earlier) / earlier * 100;

    final recentRevenue = net(recent);

    final weekdayRevenue = List<double>.filled(7, 0);
    final weekdayCount = List<int>.filled(7, 0);
    for (var offset = 1; offset <= days; offset++) {
      weekdayCount[DateTime(today.year, today.month, today.day - offset).weekday - 1]++;
    }
    for (final order in recent) {
      weekdayRevenue[order.createdAt.weekday - 1] += order.netTotal;
    }
    final averages = [for (var slot = 0; slot < 7; slot++) weekdayCount[slot] == 0 ? 0.0 : weekdayRevenue[slot] / weekdayCount[slot]];
    var best = 0;
    var slowest = 0;
    for (var slot = 1; slot < 7; slot++) {
      if (averages[slot] > averages[best]) best = slot;
      if (averages[slot] < averages[slowest]) slowest = slot;
    }

    final rising = <ProductTrend>[];
    final falling = <ProductTrend>[];
    if (hasComparison) {
      Map<String, int> unitsBy(List<ShopOrder> list) {
        final units = <String, int>{};
        for (final order in list) {
          for (final item in order.items) {
            units[item.name] = (units[item.name] ?? 0) + item.quantity;
          }
        }
        return units;
      }

      final recentUnits = unitsBy(recent);
      final previousUnits = unitsBy(previous);
      for (final name in {...recentUnits.keys, ...previousUnits.keys}) {
        final trend = ProductTrend(name: name, recentUnits: recentUnits[name] ?? 0, previousUnits: previousUnits[name] ?? 0);
        if (trend.recentUnits + trend.previousUnits < minUnitsForTrend) continue;
        if (trend.difference > 0) rising.add(trend);
        if (trend.difference < 0) falling.add(trend);
      }
      rising.sort((a, b) => b.difference.compareTo(a.difference));
      falling.sort((a, b) => a.difference.compareTo(b.difference));
    }

    final online = recent.where((order) => order.channel == SalesChannel.online).toList();

    return TrendReport(
      days: days,
      revenue: recentRevenue,
      orders: recent.length,
      items: itemsIn(recent),
      hasComparison: hasComparison,
      revenueChange: change(recentRevenue, net(previous)),
      ordersChange: change(recent.length, previous.length),
      itemsChange: change(itemsIn(recent), itemsIn(previous)),
      rising: rising.take(3).toList(),
      falling: falling.take(3).toList(),
      bestWeekday: recent.isEmpty ? null : _weekdayNames[best],
      slowestWeekday: recent.isEmpty || best == slowest ? null : _weekdayNames[slowest],
      onlineShare: recentRevenue <= 0 ? null : net(online) / recentRevenue * 100,
    );
  }

  final int days;
  final double revenue;
  final int orders;
  final int items;

  /// False until there is a full earlier period to compare with.
  final bool hasComparison;
  final double? revenueChange;
  final double? ordersChange;
  final double? itemsChange;
  final List<ProductTrend> rising;
  final List<ProductTrend> falling;
  final String? bestWeekday;
  final String? slowestWeekday;

  /// Percentage of revenue that came from online orders.
  final double? onlineShare;
}

String _signed(double value) => '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}%';

String _trendLine(ProductTrend trend) {
  final change = trend.change;
  return '${trend.name}: ${trend.recentUnits} units, was ${trend.previousUnits}${change == null ? '' : ' (${_signed(change)})'}';
}

/// The prompt for the local model. It only ever sees shop totals and product
/// names, never customer details, and is told not to do its own maths because
/// small models get sums wrong.
String buildInsightPrompt({required int days, required Forecast? revenue, required Forecast? sales, required TrendReport trend}) {
  String money(double value) => 'RM ${value.toStringAsFixed(0)}';

  return [
    'You are a sales analyst for a small tart bakery in Malaysia.',
    'Use ONLY the facts below. Do not calculate, estimate or invent any other numbers.',
    '',
    'FACTS',
    'Last ${trend.days} days: revenue ${money(trend.revenue)}, ${trend.orders} orders, ${trend.items} items sold.',
    if (trend.revenueChange != null) 'Revenue change from the previous ${trend.days} days: ${_signed(trend.revenueChange!)}.',
    if (trend.ordersChange != null) 'Orders change from the previous ${trend.days} days: ${_signed(trend.ordersChange!)}.',
    if (revenue != null) 'Revenue forecast for the next $days days: ${money(revenue.total)} (likely ${money(revenue.low)} to ${money(revenue.high)}, ${revenue.confidence.label.toLowerCase()} confidence).',
    if (sales != null) 'Items forecast for the next $days days: about ${sales.total.round()} (likely ${sales.low.round()} to ${sales.high.round()}).',
    if (trend.bestWeekday != null) 'Best weekday: ${trend.bestWeekday}.',
    if (trend.slowestWeekday != null) 'Slowest weekday: ${trend.slowestWeekday}.',
    if (trend.onlineShare != null) 'Online orders: ${trend.onlineShare!.toStringAsFixed(0)}% of revenue. The rest is counter sales.',
    for (final product in trend.rising) 'Selling more: ${_trendLine(product)}.',
    for (final product in trend.falling) 'Selling less: ${_trendLine(product)}.',
    '',
    'Write exactly 3 short bullet points for the shop owner:',
    '1. What is happening.',
    '2. What to prepare for.',
    '3. One practical action.',
  ].join('\n');
}
