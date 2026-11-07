import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:myabahtartlejen/models/enums.dart';
import 'package:myabahtartlejen/models/order.dart';
import 'package:myabahtartlejen/screens/admin/ai_insights_screen.dart';
import 'package:myabahtartlejen/services/local_ai_service.dart';
import 'package:myabahtartlejen/services/sales_forecast.dart';
import 'package:myabahtartlejen/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

final now = DateTime(2026, 11, 5, 15);
final today = DateTime(2026, 11, 5);

DateTime daysAgo(int days) => DateTime(today.year, today.month, today.day - days, 12);

ShopOrder order(
  DateTime at, {
  double total = 100,
  String name = 'Pineapple Tart',
  int quantity = 1,
  OrderStatus status = OrderStatus.completed,
  double refunded = 0,
  SalesChannel channel = SalesChannel.online,
  String customer = 'Siti Aminah',
}) => ShopOrder(
  code: 'T${at.millisecondsSinceEpoch}$name',
  userId: 'u1',
  customerName: customer,
  email: 'siti@example.com',
  phone: '0123456789',
  status: status,
  deliveryMethod: DeliveryMethod.values.first,
  createdAt: at,
  total: total,
  refundedAmount: refunded,
  channel: channel,
  items: [OrderItem(productId: name, name: name, unitPrice: total / quantity, quantity: quantity, lineTotal: total)],
);

void main() {
  group('SalesHistory', () {
    test('leaves out today, cancelled orders and refunded money, and fills quiet days with 0', () {
      final history = SalesHistory.fromOrders([
        order(daysAgo(3), total: 50, quantity: 2),
        order(daysAgo(3), total: 30, refunded: 10),
        order(daysAgo(1), total: 999, status: OrderStatus.cancelled),
        order(daysAgo(1), total: 20),
        order(now, total: 500),
      ], now);

      expect(history.firstDay, DateTime(2026, 11, 2));
      expect(history.revenue, [70, 0, 20]);
      expect(history.items, [3, 0, 1]);
    });

    test('is empty with no orders', () {
      expect(SalesHistory.fromOrders(const [], now).revenue, isEmpty);
    });
  });

  group('Forecast', () {
    final monday = DateTime(2026, 8, 3);

    test('needs enough history', () {
      expect(Forecast.compute(List.filled(13, 100), monday, 7), isNull);
      expect(Forecast.compute([...List.filled(26, 0.0), 1, 1, 1, 1], monday, 7), isNull);
    });

    test('steady sales forecast the same level with a tight range and high confidence', () {
      final forecast = Forecast.compute(List.filled(70, 100), monday, 7)!;
      expect(forecast.total, closeTo(700, 1));
      expect(forecast.low, closeTo(700, 1));
      expect(forecast.high, closeTo(700, 1));
      expect(forecast.pastError, closeTo(0, 0.01));
      expect(forecast.confidence, ForecastConfidence.high);
      expect(forecast.firstDay, monday.add(const Duration(days: 70)));
    });

    test('picks up the weekly pattern on the right weekdays', () {
      // 8 weeks from a Monday, so the forecast starts on a Monday too.
      final values = [for (var day = 0; day < 56; day++) day % 7 == 5 ? 300.0 : 100.0];
      final forecast = Forecast.compute(values, monday, 7)!;
      expect(forecast.daily[5], greaterThan(forecast.daily[0] * 2));
      expect(forecast.total, closeTo(900, 45));
    });

    test('a closed day stays close to nothing', () {
      final values = [for (var day = 0; day < 56; day++) day % 7 == 6 ? 0.0 : 100.0];
      final forecast = Forecast.compute(values, monday, 7)!;
      expect(forecast.daily[6], lessThan(forecast.daily[0] * 0.2));
    });

    test('follows growth but does not run away with it', () {
      final values = [for (var day = 0; day < 56; day++) 100.0 + day * 5];
      final forecast = Forecast.compute(values, monday, 30)!;
      final lastDay = values.last;
      expect(forecast.daily.first, greaterThan(lastDay));
      // Straight-line growth would add 150 by day 30; the fade limits it to about 45.
      expect(forecast.daily.last, lessThan(lastDay + 50));
    });

    test('falling sales never forecast below zero', () {
      final values = [for (var day = 0; day < 30; day++) 300.0 - day * 10];
      final forecast = Forecast.compute(values, monday, 30)!;
      expect(forecast.daily.every((value) => value >= 0), isTrue);
      expect(forecast.low, greaterThanOrEqualTo(0));
    });

    test('short history is tested less, so confidence stays low', () {
      final forecast = Forecast.compute(List.filled(15, 100), monday, 7)!;
      expect(forecast.pastError, isNull);
      expect(forecast.confidence, ForecastConfidence.low);
    });

    test('erratic sales lower the confidence', () {
      final values = [for (var day = 0; day < 70; day++) day >= 63 ? 500.0 : (day % 3 == 0 ? 200.0 : 20.0)];
      expect(Forecast.compute(values, monday, 7)!.confidence, ForecastConfidence.low);
    });
  });

  group('TrendReport', () {
    test('compares two full periods and finds rising and falling products', () {
      final report = TrendReport.fromOrders([
        order(daysAgo(5), total: 300, name: 'Pineapple Tart', quantity: 8),
        order(daysAgo(6), total: 100, name: 'Cheese Tart', quantity: 2),
        order(daysAgo(40), total: 100, name: 'Pineapple Tart', quantity: 3),
        order(daysAgo(41), total: 100, name: 'Cheese Tart', quantity: 6),
        order(daysAgo(60), total: 0, name: 'Egg Tart', quantity: 1),
      ], now);

      expect(report.hasComparison, isTrue);
      expect(report.revenue, 400);
      expect(report.revenueChange, closeTo(100, 0.01));
      expect(report.rising.single.name, 'Pineapple Tart');
      expect(report.rising.single.change, closeTo(166.7, 0.1));
      expect(report.falling.single.name, 'Cheese Tart');
    });

    test('does not claim growth when the earlier period is only partly covered', () {
      final report = TrendReport.fromOrders([
        order(daysAgo(5), total: 300, quantity: 8),
        order(daysAgo(35), total: 100, quantity: 2),
      ], now);

      expect(report.hasComparison, isFalse);
      expect(report.revenueChange, isNull);
      expect(report.rising, isEmpty);
    });

    test('ignores products with too few sales to mean anything', () {
      final report = TrendReport.fromOrders([
        order(daysAgo(5), name: 'Rare Tart', quantity: 2),
        order(daysAgo(40), name: 'Rare Tart', quantity: 1),
        order(daysAgo(60), name: 'Other', quantity: 1),
      ], now);

      expect(report.hasComparison, isTrue);
      expect(report.rising, isEmpty);
    });

    test('finds the best weekday and the online share', () {
      final saturday = DateTime(2026, 10, 31, 12);
      final tuesday = DateTime(2026, 11, 3, 12);
      final report = TrendReport.fromOrders([
        order(saturday, total: 300),
        order(tuesday, total: 100, channel: SalesChannel.counter),
      ], now);

      expect(report.bestWeekday, 'Saturday');
      expect(report.onlineShare, closeTo(75, 0.01));
    });

    test('counts neither today nor cancelled orders', () {
      final report = TrendReport.fromOrders([order(now, total: 500), order(daysAgo(2), total: 80, status: OrderStatus.cancelled)], now);
      expect(report.orders, 0);
      expect(report.bestWeekday, isNull);
    });
  });

  test('the prompt carries the facts but no customer details', () {
    final orders = [for (var day = 1; day <= 70; day++) order(daysAgo(day), total: 100, quantity: 2)];
    final history = SalesHistory.fromOrders(orders, now);
    final prompt = buildInsightPrompt(
      days: 7,
      revenue: Forecast.compute(history.revenue, history.firstDay, 7),
      sales: Forecast.compute(history.items, history.firstDay, 7),
      trend: TrendReport.fromOrders(orders, now),
    );

    expect(prompt, contains('Revenue forecast for the next 7 days: RM 700'));
    expect(prompt, contains('Do not calculate'));
    for (final private in ['Siti', 'siti@example.com', '0123456789', 'u1']) {
      expect(prompt, isNot(contains(private)));
    }
  });

  group('LocalAiService', () {
    test('tidies the address', () {
      expect(LocalAiService.normalizeUrl(' 192.168.1.10:11434/ '), 'http://192.168.1.10:11434');
      expect(LocalAiService.normalizeUrl('http://localhost:11434'), 'http://localhost:11434');
    });

    test('keeps a saved model, otherwise picks the best installed one', () {
      expect(LocalAiService.pickModel(['llama3.2:1b', 'phi3:mini'], 'llama3.2:1b'), 'llama3.2:1b');
      expect(LocalAiService.pickModel(['llama3.2:1b', 'phi3:mini'], 'gone:latest'), 'phi3:mini');
      expect(LocalAiService.pickModel(['other:7b'], null), 'other:7b');
      expect(LocalAiService.pickModel(const [], null), isNull);
    });

    test('lists models and sends the prompt without streaming', () async {
      late Map<String, dynamic> sent;
      final service = LocalAiService(
        baseUrl: 'http://pc:11434/',
        client: MockClient((request) async {
          if (request.url.path == '/api/tags') {
            return http.Response(jsonEncode({'models': [{'name': 'phi3:mini'}]}), 200);
          }
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response.bytes(utf8.encode(jsonEncode({'response': '  Jualan naik ✓ \n'})), 200);
        }),
      );

      expect(await service.models(), ['phi3:mini']);
      expect(await service.generate(model: 'phi3:mini', prompt: 'hello'), 'Jualan naik ✓');
      expect(sent['stream'], isFalse);
      expect(sent['model'], 'phi3:mini');
    });

    test('explains each kind of failure', () async {
      LocalAiService replying(http.Response response) => LocalAiService(baseUrl: 'http://pc:11434', client: MockClient((_) async => response));

      await expectLater(
        LocalAiService(baseUrl: 'http://pc:11434', client: MockClient((_) async => throw http.ClientException('refused'))).models(),
        throwsA(isA<LocalAiException>().having((error) => error.message, 'message', contains('Ollama is running'))),
      );
      await expectLater(replying(http.Response('<html>', 200)).models(), throwsA(isA<LocalAiException>().having((error) => error.message, 'message', contains('look like Ollama'))));
      await expectLater(
        replying(http.Response(jsonEncode({'error': 'model not found'}), 404)).generate(model: 'x', prompt: 'y'),
        throwsA(isA<LocalAiException>().having((error) => error.message, 'message', contains('model not found'))),
      );
      await expectLater(replying(http.Response(jsonEncode({'response': ' '}), 200)).generate(model: 'x', prompt: 'y'), throwsA(isA<LocalAiException>()));
    });
  });

  group('AiInsightsView', () {
    setUp(() {
      GoogleFonts.config.allowRuntimeFetching = false;
      SharedPreferences.setMockInitialValues({});
    });

    Future<void> pump(WidgetTester tester, List<ShopOrder> orders, MockClient client) async {
      tester.view.physicalSize = const Size(360, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: kitchenThemeData.extensions.values),
          home: Scaffold(
            body: AiInsightsView(
              orders: orders,
              now: now,
              aiFactory: (url) => LocalAiService(baseUrl: url, client: client),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final busy = [for (var day = 1; day <= 70; day++) order(daysAgo(day), total: 100, quantity: 2)];

    testWidgets('shows all three features and writes a summary on request', (tester) async {
      await pump(
        tester,
        busy,
        MockClient((request) async {
          if (request.url.path == '/api/tags') {
            return http.Response(jsonEncode({'models': [{'name': 'phi3:mini'}]}), 200);
          }
          return http.Response(jsonEncode({'response': '- Sales are steady.'}), 200);
        }),
      );

      expect(find.text('AI Revenue Forecast'), findsOneWidget);
      expect(find.text('AI Sales Forecast'), findsOneWidget);
      expect(find.text('AI Trend Analysis'), findsOneWidget);
      expect(find.text('Likely RM 700.00 to RM 700.00'), findsOneWidget);

      await tester.tap(find.text('Explain these numbers'));
      await tester.pumpAndSettle();
      expect(find.text('- Sales are steady.'), findsOneWidget);
      expect(find.textContaining('Written by phi3:mini'), findsOneWidget);
    });

    testWidgets('forecasts still show when the AI server is off', (tester) async {
      await pump(tester, busy, MockClient((_) async => throw http.ClientException('refused')));

      expect(find.text('Likely RM 700.00 to RM 700.00'), findsOneWidget);
      expect(find.text('Not connected'), findsOneWidget);
      expect(find.textContaining('Check that Ollama is running'), findsOneWidget);
      expect(find.text('Explain these numbers'), findsNothing);
    });

    testWidgets('says so when there is too little history', (tester) async {
      await pump(tester, [order(daysAgo(1))], MockClient((_) async => http.Response(jsonEncode({'models': []}), 200)));

      expect(find.textContaining('Not enough sales yet'), findsNWidgets(2));
      expect(find.textContaining('no models'), findsOneWidget);
    });
  });
}
