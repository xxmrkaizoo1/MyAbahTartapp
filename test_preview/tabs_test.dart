// ignore_for_file: invalid_use_of_visible_for_testing_member
// Taps through the bottom bar like a person would, catching layout errors between and after tab switches.
// Run: flutter test test_preview/tabs_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:myabahtartlejen/screens/shop/shop_shell.dart';
import 'package:myabahtartlejen/services/cart.dart';
import 'package:myabahtartlejen/theme.dart';

import 'preview_test.dart' as preview;

void main() {
  setUpAll(() async {
    useGoogleFonts = false;
    await preview.loadFonts();
  });

  for (final theme in TartTheme.all) {
    for (final cartItems in [false, true]) {
      testWidgets('tab switching · ${theme.id} · cart ${cartItems ? 'full' : 'empty'}', (tester) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final errors = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          final where = RegExp(r'(\w+):file:///\S*?/(lib/[^:\s]+:\d+)').firstMatch(details.toString());
          errors.add('${details.exceptionAsString().split('\n').first}${where == null ? '' : ' — ${where[1]} ${where[2]}'}');
        };
        try {
          final cart = Cart();
          if (cartItems) cart.add(preview.products[1], null, 2);
          await tester.pumpWidget(
            preview.harness(
              ShopShell(key: shopShellKey),
              theme: theme,
              cart: cart,
              noOrders: true,
            ),
          );
          await tester.pump(const Duration(seconds: 1));
          for (final label in ['Orders', 'Me', 'Shop', 'Cart', 'Orders', 'Home', 'Me', 'Orders']) {
            await tester.tap(find.text(label).last);
            // Check partway through the switch animation as well as after it.
            for (var i = 0; i < 6; i++) {
              await tester.pump(const Duration(milliseconds: 60));
            }
            await tester.pump(const Duration(seconds: 1));
          }
        } finally {
          FlutterError.onError = previous;
        }
        expect(errors.toSet().toList(), isEmpty);
      });
    }
  }
}
