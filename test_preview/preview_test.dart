// ignore_for_file: invalid_use_of_visible_for_testing_member
// Renders every screen with sample data and saves screenshots, collecting layout errors.
// Run: flutter test test_preview --update-goldens
// Screenshots land in test_preview/shots/.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:myabahtartlejen/models/counter_menu.dart';
import 'package:myabahtartlejen/models/enums.dart';
import 'package:myabahtartlejen/models/order.dart';
import 'package:myabahtartlejen/models/product.dart';
import 'package:myabahtartlejen/models/refund.dart';
import 'package:myabahtartlejen/models/shop_models.dart';
import 'package:myabahtartlejen/screens/admin/admin_orders.dart';
import 'package:myabahtartlejen/screens/admin/customers_screen.dart';
import 'package:myabahtartlejen/screens/admin/admin_shell.dart';
import 'package:myabahtartlejen/screens/admin/integrations_screen.dart';
import 'package:myabahtartlejen/screens/admin/pos_screen.dart';
import 'package:myabahtartlejen/screens/admin/product_form_screen.dart';
import 'package:myabahtartlejen/screens/admin/refunds_screen.dart';
import 'package:myabahtartlejen/screens/admin/sales_report_screen.dart';
import 'package:myabahtartlejen/screens/admin/admin_more.dart';
import 'package:myabahtartlejen/screens/auth/sign_in_screen.dart';
import 'package:myabahtartlejen/screens/shop/checkout_screen.dart';
import 'package:myabahtartlejen/screens/shop/home_screen.dart';
import 'package:myabahtartlejen/widgets/theme_picker.dart';
import 'package:myabahtartlejen/screens/shop/order_detail_screen.dart';
import 'package:myabahtartlejen/screens/shop/product_screen.dart';
import 'package:myabahtartlejen/screens/shop/shop_shell.dart';
import 'package:myabahtartlejen/services/auth_service.dart';
import 'package:myabahtartlejen/services/cart.dart';
import 'package:myabahtartlejen/services/seed_data.dart';
import 'package:myabahtartlejen/services/shop_repository.dart';
import 'package:myabahtartlejen/theme.dart';
import 'package:provider/provider.dart';

final now = DateTime.now();

final categories = [for (final MapEntry(key: id, value: data) in seedCategories.entries) MenuCategory.fromMap(id, data)];

final products = [
  for (final MapEntry(key: id, value: data) in seedProducts.entries)
    Product.fromMap(id, {
      ...data,
      // Exercise the badges and the home page's bestseller and limited-edition sections.
      if (id == 'rempeyek-kacang-bilis' || id == 'kerepek-bawang') 'isBestseller': true,
      if (id == 'keropok-ikan-pedas') ...{'isSeasonal': true, 'stock': 6},
    }),
];

extension on AppUser {
  /// The sample customer as a plain customer (the harness signs in as staff).
  AppUser copyAsCustomer() => AppUser(uid: uid, name: name, email: email, phone: phone, address: address);
}

const customer = AppUser(
  uid: 'u1',
  name: 'Nurul Aisyah binti Abdullah',
  email: 'aisyah.abdullah@example.com',
  phone: '012-345 6789',
  address: '12, Jalan Telawi 5, Bangsar Baru, 59100 Kuala Lumpur',
  role: 'admin',
);

ShopOrder sampleOrder(String code, OrderStatus status, {int minutesAgo = 30, SalesChannel channel = SalesChannel.online, double refunded = 0}) => ShopOrder(
  code: code,
  userId: channel == SalesChannel.online ? 'u1' : '',
  customerName: channel == SalesChannel.online ? customer.name : 'Walk-in customer',
  email: customer.email,
  status: status,
  channel: channel,
  paymentMethod: channel == SalesChannel.counter ? PaymentMethod.cash : PaymentMethod.cash,
  amountTendered: channel == SalesChannel.counter ? 100 : null,
  servedBy: channel == SalesChannel.counter ? 'Firas' : null,
  deliveryMethod: channel == SalesChannel.counter ? DeliveryMethod.pickup : DeliveryMethod.standard,
  phone: customer.phone!,
  address: customer.address,
  notes: 'Please call when you arrive, the gate is locked after 6 pm.',
  items: const [
    OrderItem(
      productId: 'rempeyek-kacang-bilis',
      name: 'Rempeyek Kacang Bilis',
      unitPrice: 35,
      quantity: 2,
      lineTotal: 70,
      art: 'nutty',
      imageUrl: 'asset:assets/images/products/rempeyek-kacang-bilis.jpg',
    ),
    OrderItem(
      productId: 'tart-lejen',
      name: 'Tart Lejen',
      size: ProductSize.large,
      unitPrice: 30,
      quantity: 1,
      lineTotal: 30,
      art: 'pineapple',
      imageUrl: 'asset:assets/images/products/tart-lejen-l.jpg',
    ),
    OrderItem(
      productId: 'kerepek-bawang',
      name: 'Kerepek Bawang',
      unitPrice: 25,
      quantity: 3,
      lineTotal: 75,
      art: 'caramel',
      imageUrl: 'asset:assets/images/products/kerepek-bawang.jpg',
    ),
  ],
  subtotal: 175,
  deliveryFee: 0,
  discount: 10,
  total: 165,
  voucherCode: 'WELCOME10',
  isPaid: status == OrderStatus.completed,
  refundedAmount: refunded,
  createdAt: now.subtract(Duration(minutes: minutesAgo)),
  preparingAt: status.index >= 1 && status != OrderStatus.cancelled ? now.subtract(Duration(minutes: minutesAgo - 5)) : null,
  readyAt: status.index >= 2 && status != OrderStatus.cancelled ? now.subtract(Duration(minutes: minutesAgo - 15)) : null,
  completedAt: status == OrderStatus.completed ? now.subtract(Duration(minutes: minutesAgo - 25)) : null,
  cancelledAt: status == OrderStatus.cancelled ? now : null,
  cancellationReason: status == OrderStatus.cancelled ? CancellationReason.changedMind : null,
);

final orders = [
  sampleOrder('TL-NEW01', OrderStatus.received, minutesAgo: 4),
  sampleOrder('TL-PREP2', OrderStatus.preparing, minutesAgo: 18),
  sampleOrder('TL-REDY3', OrderStatus.ready, minutesAgo: 40),
  sampleOrder('TL-DONE4', OrderStatus.completed, minutesAgo: 600, refunded: 25),
  sampleOrder('TL-CANC5', OrderStatus.cancelled, minutesAgo: 900),
  for (var i = 0; i < 12; i++) sampleOrder('TL-CTR${i}X', OrderStatus.completed, minutesAgo: 60 * 24 * i + 90, channel: SalesChannel.counter),
  for (var i = 1; i < 25; i += 2) sampleOrder('TL-OLD${i}Y', OrderStatus.completed, minutesAgo: 60 * 24 * i),
];

final refunds = [
  Refund(
    id: 'r1',
    orderCode: 'TL-DONE4',
    userId: 'u1',
    customerName: customer.name,
    status: RefundStatus.requested,
    reason: RefundReason.damaged,
    details: 'Two tarts were crushed in the box.',
    items: const [RefundItem(index: 0, name: 'Rempeyek Kacang Bilis', quantity: 1, unitPrice: 35)],
    createdAt: now.subtract(const Duration(hours: 2)),
  ),
  Refund(
    id: 'r2',
    orderCode: 'TL-DONE4',
    userId: 'u1',
    customerName: customer.name,
    status: RefundStatus.approved,
    reason: RefundReason.quality,
    items: const [RefundItem(index: 2, name: 'Kerepek Bawang', quantity: 1, unitPrice: 25)],
    amount: 25,
    method: RefundMethod.bankTransfer,
    restocked: false,
    adminNote: 'Sorry about that! Refunded to your bank.',
    createdAt: now.subtract(const Duration(days: 1)),
    processedAt: now.subtract(const Duration(hours: 20)),
  ),
];

/// Returns sample data for every read; writes do nothing.
class FakeRepository implements ShopRepository {
  FakeRepository({this.noOrders = false});

  /// A customer who hasn't ordered anything yet.
  final bool noOrders;

  @override
  Stream<List<ShopOrder>> myOrders(String uid) => Stream.value(noOrders ? const [] : orders.where((order) => order.userId == uid).toList());
  @override
  Stream<ShopOrder?> order(String code) => Stream.value(orders.firstWhere((order) => order.code == code));
  @override
  Stream<Product?> product(String id) => Stream.value(products.firstWhere((product) => product.id == id));
  @override
  Stream<List<Review>> reviews(String productId) => Stream.value([
    Review(
      userId: 'x',
      userName: 'Siti Hajar',
      rating: 5,
      comment: 'Rangup dan tak terlalu masin. Satu balang habis dalam sehari, memang sedap!',
      createdAt: now,
    ),
    Review(userId: 'y', userName: 'Daniel', rating: 4, comment: 'Lovely, arrived well packed.', createdAt: now),
  ]);
  @override
  Stream<List<ShopOrder>> recentOrders({int limit = 300}) => Stream.value(orders);
  @override
  Stream<List<ShopOrder>> ordersSince(DateTime from) => Stream.value(orders.where((order) => !order.createdAt.isBefore(from)).toList());
  @override
  Stream<List<Refund>> refundsForOrder(String orderCode, {String? userId}) => Stream.value(refunds.where((refund) => refund.orderCode == orderCode).toList());
  @override
  Stream<List<Refund>> allRefunds() => Stream.value(refunds);
  @override
  Stream<CounterMenu> counterMenu(DateTime day) => Stream.value(
    CounterMenu(
      date: CounterMenu.keyFor(day),
      items: {
        products[0].id: const CounterAllowance(sizes: {'S': 10, 'L': 2}),
        products[1].id: const CounterAllowance(quantity: 20),
        products[3].id: const CounterAllowance(),
      },
    ),
  );
  @override
  Future<CounterMenu> counterMenuOnce(DateTime day) => counterMenu(day).first;
  @override
  Stream<List<Voucher>> vouchers() => Stream.value([
    for (final voucher in seedVouchers)
      Voucher(
        code: voucher['code'] as String,
        description: voucher['description'] as String,
        type: voucher['type'] as String,
        value: (voucher['value'] as num).toDouble(),
        minSubtotal: (voucher['minSubtotal'] as num).toDouble(),
      ),
  ]);
  @override
  Stream<List<AppUser>> customers() => Stream.value([
    customer.copyAsCustomer(),
    AppUser(
      uid: 'web-5',
      name: 'Siti Hajar binti Ismail',
      email: customer.email,
      phone: '013-222 4455',
      fromWebsite: true,
      joinedAt: now.subtract(const Duration(days: 40)),
    ),
    AppUser(
      uid: 'web-6',
      name: 'Daniel Lim',
      email: 'daniel.lim@example.com',
      phone: '017-604 2108',
      address: 'Petaling Jaya',
      fromWebsite: true,
      joinedAt: now,
    ),
  ]);

  @override
  Stream<Json> integrations() => Stream.value(const {'lalamove_market': 'MY'});

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    if (name.contains('Stream')) return const Stream<Never>.empty();
    return Future<void>.value();
  }
}

Future<void> loadFonts() async {
  final sdk = Platform.environment['FLUTTER_ROOT'] ?? r'C:\Users\HP\flutter\flutter';
  final fonts = '$sdk/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, Map<String, String> files) async {
    final loader = FontLoader(family);
    for (final file in files.values) {
      final bytes = await File('$fonts/$file').readAsBytes();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  const roboto = {'400': 'roboto-regular.ttf', '500': 'roboto-medium.ttf', '700': 'roboto-bold.ttf', '900': 'roboto-black.ttf'};
  await load('Roboto', roboto);
  // The same font files google_fonts downloads on phones (fetch them with fetch_fonts.py), so text measures like a real device.
  for (final folder in Directory('test_preview/fonts').listSync().whereType<Directory>()) {
    final loader = FontLoader(folder.uri.pathSegments.where((segment) => segment.isNotEmpty).last);
    for (final file in folder.listSync().whereType<File>()) {
      final bytes = await file.readAsBytes();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
  await load('MaterialIcons', {'icons': 'materialicons-regular.otf'});
}

Widget harness(Widget child, {required TartTheme theme, bool signedIn = true, Cart? cart, bool noOrders = false}) {
  final repository = FakeRepository(noOrders: noOrders);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeController(null)..select(theme)),
      Provider<ShopRepository>.value(value: repository),
      ChangeNotifierProvider(create: (_) => AuthService.preview(repository, profile: signedIn ? customer : null)),
      ChangeNotifierProvider(create: (_) => cart ?? Cart()),
      Provider<List<Product>?>.value(value: products),
      Provider<List<MenuCategory>>.value(value: categories),
      Provider<Storefront>.value(value: Storefront.fromMap(const {'payment_online_enabled': '1'})),
    ],
    child: Consumer<ThemeController>(
      builder: (context, themes, _) => MaterialApp(debugShowCheckedModeBanner: false, theme: themeDataFor(themes.theme), home: child),
    ),
  );
}

final problems = <String>[];

/// The phone's text size setting (Settings → Display → Font size); 1.3 is a common "large".
double textScale = 1;

/// Photos decode off the fake clock, so load the ones on screen for real before the screenshot.
Future<void> loadPhotos(WidgetTester tester) async {
  final images = find.byType(Image).evaluate().toList();
  if (images.isEmpty) return;
  await tester.runAsync(() async {
    final context = images.first;
    await precacheImage(const AssetImage('assets/images/logo.jpg'), context);
    for (final element in images) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> shoot(
  WidgetTester tester,
  String name,
  Widget screen, {
  TartTheme theme = TartTheme.matcha,
  Size size = const Size(360, 760),
  bool signedIn = true,
  Cart? cart,
  Future<void> Function()? then,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  final tag = '${theme.id}_${size.width.toInt()}${textScale == 1 ? '' : '_x$textScale'}';
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    // Name the widget that overflowed, e.g. "Row lib/screens/shop/cart_screen.dart:120".
    final report = details.toString();
    final where = RegExp(r'(\w+):file:///\S*?/(lib/[^:\s]+:\d+)').firstMatch(report);
    problems.add('[$name $tag] ${details.exceptionAsString().split('\n').first}${where == null ? '' : ' — ${where[1]} ${where[2]}'}');
  };
  try {
    // A fresh key so each shot starts with new providers instead of reusing the last screen's.
    await tester.pumpWidget(
      KeyedSubtree(
        key: UniqueKey(),
        child: harness(screen, theme: theme, signedIn: signedIn, cart: cart),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    if (then != null) {
      await then();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
    }
    await loadPhotos(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/${name}_$tag.png'));
  } finally {
    FlutterError.onError = previous;
  }
}

void main() {
  setUpAll(() async {
    useGoogleFonts = false;
    await loadFonts();
  });

  tearDownAll(() {
    // ignore: avoid_print
    print(problems.isEmpty ? 'NO LAYOUT PROBLEMS' : 'LAYOUT PROBLEMS:\n${problems.toSet().join('\n')}');
  });

  Cart fullCart() => Cart()
    ..add(products[1], null, 2)
    ..add(products[0], ProductSize.large, 1)
    ..add(products[5], null, 3)
    ..applyVoucher(const Voucher(code: 'WELCOME10', description: 'RM10 off orders over RM60', value: 10, minSubtotal: 60));

  final themes = [TartTheme.matcha, TartTheme.byId('midnight'), TartTheme.byId('caramel'), TartTheme.byId('lavender')];

  const phones = [Size(360, 760), Size(412, 915)];
  // Small phones with large text are where overflows show up first.
  const stress = [Size(320, 640), Size(360, 760)];
  final runs = [for (final theme in themes) (theme, phones, 1.0), (TartTheme.matcha, stress, 1.3), (TartTheme.byId('caramel'), stress, 1.3)];

  for (final (theme, sizes, scale) in runs) {
    testWidgets('customer screens · ${theme.id} · text x$scale', (tester) async {
      textScale = scale;
      addTearDown(() => textScale = 1);
      for (final size in sizes) {
        await shoot(
          tester,
          'home',
          ShopShell(key: shopShellKey),
          theme: theme,
          size: size,
        );
        for (final page in [1, 2, 3, 4, 5]) {
          await shoot(
            tester,
            'home$page',
            ShopShell(key: shopShellKey),
            theme: theme,
            size: size,
            cart: page == 2 ? fullCart() : null,
            then: () async {
              await tester.drag(find.byType(CustomScrollView).first, Offset(0, -size.height * 0.8 * page), warnIfMissed: false);
            },
          );
        }
        await shoot(
          tester,
          'menu',
          ShopShell(key: shopShellKey),
          theme: theme,
          size: size,
          then: () async => shopShellKey.currentState!.goTo(ShopShell.menu),
        );
        await shoot(
          tester,
          'cart',
          ShopShell(key: shopShellKey),
          theme: theme,
          size: size,
          cart: fullCart(),
          then: () async => shopShellKey.currentState!.goTo(ShopShell.cart),
        );
        await shoot(
          tester,
          'orders',
          ShopShell(key: shopShellKey),
          theme: theme,
          size: size,
          then: () async => shopShellKey.currentState!.goTo(ShopShell.orders),
        );
        await shoot(
          tester,
          'profile',
          ShopShell(key: shopShellKey),
          theme: theme,
          size: size,
          then: () async => shopShellKey.currentState!.goTo(ShopShell.profile),
        );
        await shoot(
          tester,
          'signedout',
          ShopShell(key: shopShellKey),
          theme: theme,
          size: size,
          signedIn: false,
          then: () async => shopShellKey.currentState!.goTo(ShopShell.profile),
        );
        await shoot(
          tester,
          'product',
          ProductScreen(productId: products[0].id),
          theme: theme,
          size: size,
        );
        await shoot(tester, 'checkout', const CheckoutScreen(), theme: theme, size: size, cart: fullCart());
        await shoot(
          tester,
          'order_active',
          const OrderDetailScreen(code: 'TL-PREP2', justPlaced: true),
          theme: theme,
          size: size,
        );
        await shoot(
          tester,
          'order_done',
          const OrderDetailScreen(code: 'TL-DONE4'),
          theme: theme,
          size: size,
        );
        await shoot(tester, 'signin', const SignInScreen(startWithRegister: true), theme: theme, size: size, signedIn: false);
        await shoot(
          tester,
          'themes',
          ShopShell(key: shopShellKey),
          theme: theme,
          size: size,
          then: () async {
            showThemePicker(tester.element(find.byType(HomeScreen)));
          },
        );
      }
    });
  }

  for (final (sizes, scale) in [(phones, 1.0), (stress, 1.3)]) {
    testWidgets('kitchen screens · text x$scale', (tester) async {
      textScale = scale;
      addTearDown(() => textScale = 1);
      Widget kitchen(Widget child) => Theme(data: kitchenThemeData, child: child);
      for (final size in sizes) {
        await shoot(tester, 'k_today', const AdminShell(), size: size);
        for (final (index, name) in const [(1, 'k_orders'), (2, 'k_counter'), (3, 'k_menu'), (4, 'k_more')]) {
          await shoot(
            tester,
            name,
            const AdminShell(),
            size: size,
            then: () async {
              await tester.tap(find.byType(NavigationDestination).at(index));
            },
          );
        }
        await shoot(tester, 'k_order', kitchen(const AdminOrderDetail(code: 'TL-DONE4')), size: size);
        await shoot(tester, 'k_counter_sale', kitchen(const AdminOrderDetail(code: 'TL-CTR0X')), size: size);
        await shoot(tester, 'k_report', kitchen(const SalesReportScreen()), size: size);
        await shoot(tester, 'k_refunds', kitchen(const RefundsScreen()), size: size);
        await shoot(tester, 'k_countermenu', kitchen(const CounterMenuScreen()), size: size);
        await shoot(tester, 'k_receipt', kitchen(const ReceiptScreen(code: 'TL-CTR0X')), size: size);
        await shoot(tester, 'k_apis', kitchen(const IntegrationsScreen()), size: size);
        await shoot(tester, 'k_product', kitchen(ProductFormScreen(product: products[1])), size: size);
        await shoot(tester, 'k_customers', kitchen(const CustomersScreen()), size: size);
        await shoot(
          tester,
          'k_customer',
          kitchen(CustomerDetailScreen(customer: CustomerSummary.build([customer.copyAsCustomer()], orders).first)),
          size: size,
        );
        await shoot(tester, 'k_vouchers', kitchen(const VouchersScreen()), size: size);
        await shoot(tester, 'k_settings', kitchen(const StorefrontSettingsScreen()), size: size);
      }
    });
  }
}
