import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widgets/motion.dart';
import 'widgets/tart_art.dart';

/// Fixed colours for Kitchen mode (staff), which keeps its dark oven look in every theme.
class Palette {
  static const cocoa = Color(0xFF2B1A12);
  static const cream = Color(0xFFFFF6E9);
  static const butter = Color(0xFFF6C453);
  static const oven = Color(0xFF17100C);
  static const ovenCard = Color(0xFF241812);
  static const ovenLine = Color(0xFF3A2A21);
  static const ember = Color(0xFFFF7A4D);
}

/// Bottom padding that keeps content clear of the floating navigation bar.
/// The shop shell reports the bar's real height (it grows with the cart pill) as bottom padding.
double navClearance(BuildContext context) => MediaQuery.paddingOf(context).bottom + 24;

/// One look for the customer app: colours, fonts and how rounded corners are.
/// Mirrors the website's themes (app/Enums/Theme.php, default Matcha & Apricot) plus the app's own Cocoa & Butter.
class TartTheme {
  const TartTheme({
    required this.id,
    required this.label,
    required this.description,
    required this.displayFont,
    required this.bodyFont,
    required this.bg,
    required this.surface,
    required this.ink,
    required this.inkSoft,
    required this.primary,
    this.onPrimary = Colors.white,
    required this.accent,
    required this.onAccent,
    required this.deep,
    required this.onDeep,
    required this.success,
    required this.line,
    this.roundness = 1,
    this.isDark = false,
  });

  final String id;
  final String label;
  final String description;
  final String displayFont;
  final String bodyFont;
  final Color bg;
  final Color surface;
  final Color ink;
  final Color inkSoft;
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color onAccent;

  /// Dark surfaces such as the hero card and the navigation bar.
  final Color deep;
  final Color onDeep;
  final Color success;
  final Color line;

  /// Multiplies corner radii: below 1 is sharper, above 1 is rounder.
  final double roundness;
  final bool isDark;

  static const cocoa = TartTheme(
    id: 'cocoa',
    label: 'Cocoa & Butter',
    description: 'Warm bakery browns with a serif headline',
    displayFont: 'Fraunces',
    bodyFont: 'DM Sans',
    bg: Color(0xFFFFF6E9),
    surface: Color(0xFFFFFCF6),
    ink: Color(0xFF2B1A12),
    inkSoft: Color(0xFF7A6052),
    primary: Color(0xFFE2522F),
    accent: Color(0xFFF6C453),
    onAccent: Color(0xFF2B1A12),
    deep: Color(0xFF2B1A12),
    onDeep: Color(0xFFFFF6E9),
    success: Color(0xFF7E9F4E),
    line: Color(0xFFEFE1CC),
  );

  static const matcha = TartTheme(
    id: 'matcha',
    label: 'Matcha & Apricot',
    description: 'Fresh greens, modern and rounded',
    displayFont: 'Bricolage Grotesque',
    bodyFont: 'Plus Jakarta Sans',
    bg: Color(0xFFF7F5EC),
    surface: Colors.white,
    ink: Color(0xFF1C2A1E),
    inkSoft: Color(0xFF5E6A5C),
    primary: Color(0xFF4F8A3C),
    accent: Color(0xFFFFA65C),
    onAccent: Color(0xFF1C2A1E),
    deep: Color(0xFF1C2A1E),
    onDeep: Color(0xFFF7F5EC),
    success: Color(0xFF1F9A9A),
    line: Color(0xFFECE7D6),
  );

  static const all = [
    matcha,
    TartTheme(
      id: 'raspberry',
      label: 'Raspberry & Butter',
      description: 'Bold pink, bright and playful',
      displayFont: 'Bricolage Grotesque',
      bodyFont: 'Plus Jakarta Sans',
      bg: Color(0xFFFFF8F1),
      surface: Colors.white,
      ink: Color(0xFF211425),
      inkSoft: Color(0xFF6E5A6F),
      primary: Color(0xFFCC2257),
      accent: Color(0xFFFFD54F),
      onAccent: Color(0xFF211425),
      deep: Color(0xFF211425),
      onDeep: Color(0xFFFFF8F1),
      success: Color(0xFF1FA57A),
      line: Color(0xFFFBEEE2),
    ),
    TartTheme(
      id: 'blueberry',
      label: 'Blueberry & Coral',
      description: 'Cool blues with an editorial serif',
      displayFont: 'Fraunces',
      bodyFont: 'Plus Jakarta Sans',
      bg: Color(0xFFF6F8FC),
      surface: Colors.white,
      ink: Color(0xFF151B33),
      inkSoft: Color(0xFF5B6482),
      primary: Color(0xFF3451D1),
      accent: Color(0xFFFF8266),
      onAccent: Color(0xFF151B33),
      deep: Color(0xFF151B33),
      onDeep: Color(0xFFF6F8FC),
      success: Color(0xFF12A170),
      line: Color(0xFFE7EDF8),
    ),
    TartTheme(
      id: 'caramel',
      label: 'Caramel Classic',
      description: 'Warm and elegant with sharper edges',
      displayFont: 'Playfair Display',
      bodyFont: 'Plus Jakarta Sans',
      bg: Color(0xFFFBF6EE),
      surface: Colors.white,
      ink: Color(0xFF261B14),
      inkSoft: Color(0xFF6F5E50),
      primary: Color(0xFF9A5422),
      accent: Color(0xFFF3C96E),
      onAccent: Color(0xFF261B14),
      deep: Color(0xFF261B14),
      onDeep: Color(0xFFFBF6EE),
      success: Color(0xFF5A8F3C),
      line: Color(0xFFF2E6D3),
      roundness: 0.4,
    ),
    TartTheme(
      id: 'lavender',
      label: 'Lavender & Lime',
      description: 'Soft purples, extra round and bubbly',
      displayFont: 'Fredoka',
      bodyFont: 'Plus Jakarta Sans',
      bg: Color(0xFFFAF7FF),
      surface: Colors.white,
      ink: Color(0xFF1E1733),
      inkSoft: Color(0xFF685F80),
      primary: Color(0xFF7A3BD9),
      accent: Color(0xFFCDEC5F),
      onAccent: Color(0xFF1E1733),
      deep: Color(0xFF1E1733),
      onDeep: Color(0xFFFAF7FF),
      success: Color(0xFF1F9A7A),
      line: Color(0xFFECE4FB),
      roundness: 1.25,
    ),
    TartTheme(
      id: 'midnight',
      label: 'Midnight Neon',
      description: 'Dark mode with electric violet and cyan',
      displayFont: 'Space Grotesk',
      bodyFont: 'Plus Jakarta Sans',
      bg: Color(0xFF0C0B14),
      surface: Color(0xFF16142A),
      ink: Color(0xFFEEECF8),
      inkSoft: Color(0xFFA29DBD),
      primary: Color(0xFF7C5FFF),
      accent: Color(0xFF3DD9F0),
      onAccent: Color(0xFF0C0B14),
      deep: Color(0xFF221C4A),
      onDeep: Color(0xFFEEECF8),
      success: Color(0xFF3DDC97),
      line: Color(0xFF2A2650),
      isDark: true,
    ),
    TartTheme(
      id: 'mono',
      label: 'Mono Volt',
      description: 'Minimal black and white with a lime spark',
      displayFont: 'Space Grotesk',
      bodyFont: 'Plus Jakarta Sans',
      bg: Color(0xFFF4F4F1),
      surface: Colors.white,
      ink: Color(0xFF0A0A0A),
      inkSoft: Color(0xFF5F5F5A),
      primary: Color(0xFF111111),
      accent: Color(0xFFD4FF3A),
      onAccent: Color(0xFF0A0A0A),
      deep: Color(0xFF0A0A0A),
      onDeep: Color(0xFFF4F4F1),
      success: Color(0xFF2E9D6A),
      line: Color(0xFFE4E4DF),
      roundness: 0.35,
    ),
    TartTheme(
      id: 'aurora',
      label: 'Aurora Glow',
      description: 'Airy teal and pink glow, softly futuristic',
      displayFont: 'Sora',
      bodyFont: 'Plus Jakarta Sans',
      bg: Color(0xFFF3FBFA),
      surface: Colors.white,
      ink: Color(0xFF0B2530),
      inkSoft: Color(0xFF557079),
      primary: Color(0xFF0F9F9A),
      accent: Color(0xFFFF6FAE),
      onAccent: Color(0xFF0B2530),
      deep: Color(0xFF0B2530),
      onDeep: Color(0xFFF3FBFA),
      success: Color(0xFF12A170),
      line: Color(0xFFDCEFEE),
      roundness: 1.1,
    ),
    cocoa,
  ];

  static const kitchen = TartTheme(
    id: 'kitchen',
    label: 'Kitchen',
    description: 'Staff mode',
    displayFont: 'Fraunces',
    bodyFont: 'DM Sans',
    bg: Palette.oven,
    surface: Palette.ovenCard,
    ink: Color(0xFFF7EBDD),
    inkSoft: Color(0xFFB9A595),
    primary: Palette.butter,
    onPrimary: Palette.cocoa,
    accent: Palette.butter,
    onAccent: Palette.cocoa,
    deep: Color(0xFF0E0906),
    onDeep: Palette.cream,
    success: Color(0xFF7FD1A8),
    line: Palette.ovenLine,
    isDark: true,
  );

  static TartTheme byId(String? id) => all.firstWhere((theme) => theme.id == id, orElse: () => matcha);

  /// Primary, accent and dark colours for the theme picker.
  List<Color> get swatches => [primary, accent, deep];

  // Soft tints used for info cards and badges.
  Color get successSoft => Color.lerp(success, bg, isDark ? 0.75 : 0.84)!;
  Color get successInk => isDark ? Color.lerp(success, Colors.white, 0.35)! : Color.lerp(success, Colors.black, 0.4)!;
  Color get primarySoft => Color.lerp(primary, bg, isDark ? 0.7 : 0.86)!;
  Color get accentSoft => Color.lerp(accent, bg, isDark ? 0.75 : 0.65)!;

  /// The flavour background behind a tart picture, dimmed for dark themes.
  Color tint(String art) => isDark ? Color.lerp(tartTint(art), surface, 0.82)! : tartTint(art);

  /// A corner radius scaled to this theme. Pill shapes (99) stay pills unless the theme is sharp.
  BorderRadius radius(double value) {
    if (value >= 90) return BorderRadius.circular(roundness < 1 ? 10 : 99);
    return BorderRadius.circular(value * roundness);
  }

  TextStyle display({double size = 24, FontWeight weight = FontWeight.w700, Color? color, double? height, FontStyle? style}) =>
      _font(displayFont, size: size, weight: weight, color: color ?? ink, height: height, style: style);
}

/// Off in tests, which load fonts from disk instead of downloading them.
@visibleForTesting
bool useGoogleFonts = true;

TextStyle _font(String family, {double? size, FontWeight? weight, Color? color, double? height, FontStyle? style}) => useGoogleFonts
    ? GoogleFonts.getFont(family, fontSize: size, fontWeight: weight, color: color, height: height, fontStyle: style)
    : TextStyle(fontFamily: family, fontSize: size, fontWeight: weight, color: color, height: height, fontStyle: style);

/// Lets any widget read the active [TartTheme] through `context.tart`.
class TartThemeData extends ThemeExtension<TartThemeData> {
  const TartThemeData(this.theme);

  final TartTheme theme;

  @override
  TartThemeData copyWith({TartTheme? theme}) => TartThemeData(theme ?? this.theme);

  @override
  TartThemeData lerp(TartThemeData? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension TartThemeContext on BuildContext {
  TartTheme get tart => Theme.of(this).extension<TartThemeData>()?.theme ?? TartTheme.matcha;
}

/// A headline style in the active theme's display font.
TextStyle displayFont(BuildContext context, {double size = 24, FontWeight weight = FontWeight.w700, Color? color, double? height, FontStyle? style}) =>
    context.tart.display(size: size, weight: weight, color: color, height: height, style: style);

final _built = <String, ThemeData>{};

ThemeData themeDataFor(TartTheme theme) => _built.putIfAbsent(theme.id, () => _build(theme));

/// Built once: screens pushed from Kitchen mode wrap themselves in it.
final ThemeData kitchenThemeData = themeDataFor(TartTheme.kitchen);

ThemeData _build(TartTheme t) {
  final brightness = t.isDark ? Brightness.dark : Brightness.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: t.primary,
    brightness: brightness,
    primary: t.primary,
    onPrimary: t.onPrimary,
    secondary: t.accent,
    onSecondary: t.onAccent,
    surface: t.surface,
    onSurface: t.ink,
    onSurfaceVariant: t.inkSoft,
    outline: t.line,
    error: t.isDark ? const Color(0xFFFF6B6B) : const Color(0xFFC62828),
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
  final body = (useGoogleFonts ? GoogleFonts.getTextTheme(t.bodyFont, base.textTheme) : base.textTheme.apply(fontFamily: t.bodyFont)).apply(
    bodyColor: t.ink,
    displayColor: t.ink,
  );
  TextStyle bodyStyle({double? size, FontWeight? weight, Color? color}) => _font(t.bodyFont, size: size, weight: weight, color: color);
  final border = OutlineInputBorder(
    borderRadius: t.radius(18),
    borderSide: BorderSide(color: t.line),
  );
  final buttonShape = t.roundness < 1 ? RoundedRectangleBorder(borderRadius: t.radius(99)) : const StadiumBorder();

  return base.copyWith(
    scaffoldBackgroundColor: t.bg,
    pageTransitionsTheme: tartPageTransitions,
    extensions: [TartThemeData(t)],
    textTheme: body.copyWith(
      displaySmall: t.display(size: 34, height: 1.05),
      headlineMedium: t.display(size: 28, height: 1.1),
      headlineSmall: t.display(size: 24, height: 1.15),
      titleLarge: t.display(size: 20),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: t.bg,
      foregroundColor: t.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: t.display(size: 22),
    ),
    cardTheme: CardThemeData(
      color: t.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: t.radius(24),
        side: BorderSide(color: t.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.surface,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: BorderSide(color: t.primary, width: 1.6)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.id == 'kitchen' ? t.accent : t.deep,
        foregroundColor: t.id == 'kitchen' ? t.onAccent : t.onDeep,
        minimumSize: const Size(64, 54),
        shape: buttonShape,
        textStyle: bodyStyle(weight: FontWeight.w700, size: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.ink,
        minimumSize: const Size(64, 50),
        shape: buttonShape,
        side: BorderSide(color: t.line, width: 1.4),
        textStyle: bodyStyle(weight: FontWeight.w700, size: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: t.isDark && t.id != 'kitchen' ? t.accent : t.primary,
        textStyle: bodyStyle(weight: FontWeight.w700),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: buttonShape,
      side: BorderSide(color: t.line),
      backgroundColor: t.surface,
      selectedColor: t.deep,
      labelStyle: bodyStyle(weight: FontWeight.w600, color: t.ink),
      secondaryLabelStyle: bodyStyle(weight: FontWeight.w600, color: t.onDeep),
      checkmarkColor: t.onDeep,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.isDark ? t.accent : t.deep,
      contentTextStyle: bodyStyle(color: t.isDark ? t.onAccent : t.onDeep, weight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: t.radius(16)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.bg,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32 * t.roundness))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.bg,
      shape: RoundedRectangleBorder(borderRadius: t.radius(28)),
    ),
    dividerTheme: DividerThemeData(color: t.line, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.surface,
      indicatorColor: t.primary,
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(color: states.contains(WidgetState.selected) ? t.onPrimary : t.inkSoft)),
      labelTextStyle: WidgetStatePropertyAll(bodyStyle(size: 12, weight: FontWeight.w600, color: t.ink)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: t.deep,
        selectedForegroundColor: t.id == 'kitchen' ? t.accent : t.onDeep,
        side: BorderSide(color: t.line),
      ),
    ),
  );
}

/// The customer's chosen theme, remembered on this device.
class ThemeController extends ChangeNotifier {
  ThemeController(this._preferences) : _theme = TartTheme.byId(_preferences?.getString(_key));

  static const _key = 'theme';

  final SharedPreferences? _preferences;
  TartTheme _theme;

  TartTheme get theme => _theme;

  void select(TartTheme theme) {
    if (theme.id == _theme.id) return;
    _theme = theme;
    notifyListeners();
    _preferences?.setString(_key, theme.id).catchError((Object error) {
      debugPrint('Could not save theme: $error');
      return false;
    });
  }
}
