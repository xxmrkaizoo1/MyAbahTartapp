import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/product.dart';
import 'models/shop_models.dart';
import 'screens/shop/shop_shell.dart';
import 'services/auth_service.dart';
import 'services/cart.dart';
import 'services/shop_repository.dart';
import 'theme.dart';

class TartLejenApp extends StatelessWidget {
  const TartLejenApp({super.key, this.preferences});

  /// Where the chosen theme is remembered. Null when device storage is unavailable.
  final SharedPreferences? preferences;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeController>(create: (_) => ThemeController(preferences)),
        Provider<ShopRepository>(create: (_) => ShopRepository()),
        ChangeNotifierProvider<AuthService>(create: (context) => AuthService(context.read<ShopRepository>())),
        ChangeNotifierProvider<Cart>(create: (_) => Cart()),
        StreamProvider<List<Product>?>(
          create: (context) => context.read<ShopRepository>().products(),
          initialData: null,
          catchError: (_, error) {
            debugPrint('Products stream failed: $error');
            return const [];
          },
        ),
        StreamProvider<List<MenuCategory>>(
          create: (context) => context.read<ShopRepository>().categories(),
          initialData: const [],
          catchError: (_, _) => const [],
        ),
        StreamProvider<Storefront>(
          create: (context) => context.read<ShopRepository>().storefront(),
          initialData: Storefront.fallback,
          catchError: (_, _) => Storefront.fallback,
        ),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themes, _) => MaterialApp(
          title: 'MyAbah Tart Lejen',
          debugShowCheckedModeBanner: false,
          theme: themeDataFor(themes.theme),
          // Follow the phone's font size, but cap it where every screen has been checked to still fit.
          builder: (context, child) => MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: child!),
          home: ShopShell(key: shopShellKey),
        ),
      ),
    );
  }
}
