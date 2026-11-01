import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/shop_models.dart';
import '../../services/auth_service.dart';
import '../../services/shop_repository.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/tart_art.dart';
import '../../widgets/theme_picker.dart';
import '../admin/admin_shell.dart';
import '../auth/sign_in_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.isSignedIn) {
      return const SafeArea(
        child: SignInPrompt(title: 'Join the tart club', message: 'Save your address, track orders live and leave reviews.'),
      );
    }
    final profile = auth.profile;
    if (profile == null) return const LoadingView();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, navClearance(context)),
        children: staggered([
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: context.tart.primary,
                child: Text(profile.initials, style: displayFont(context, size: 24, color: Colors.white)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name, style: Theme.of(context).textTheme.headlineSmall),
                    Text(profile.email, style: TextStyle(color: context.tart.inkSoft)),
                  ],
                ),
              ),
            ],
          ),
          if (!auth.emailVerified) ...[const SizedBox(height: 16), const _VerifyEmailCard()],
          if (profile.isAdmin) ...[
            const SizedBox(height: 18),
            _KitchenModeCard(onOpen: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminShell()))),
          ],
          const SizedBox(height: 18),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              leading: Icon(Icons.palette_outlined, color: context.tart.primary),
              title: const Text('App design', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(context.watch<ThemeController>().theme.label),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showThemePicker(context),
            ),
          ),
          const SizedBox(height: 18),
          _ProfileForm(key: ValueKey(profile.uid), profile: profile),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () async {
              if (await confirm(context, title: 'Sign out?', message: 'Your cart stays here until you close the app.', confirmLabel: 'Sign out')) {
                await auth.signOut();
              }
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
        ]),
      ),
    );
  }
}

class _KitchenModeCard extends StatelessWidget {
  const _KitchenModeCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Palette.oven,
      borderRadius: context.tart.radius(26),
      child: InkWell(
        borderRadius: context.tart.radius(26),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: Palette.butter, borderRadius: context.tart.radius(16)),
                child: Icon(Icons.soup_kitchen_rounded, color: Palette.cocoa, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kitchen mode', style: displayFont(context, size: 19, color: Palette.butter)),
                    Text('Orders, stock, menu and vouchers', style: TextStyle(color: Palette.cream.withValues(alpha: 0.7), fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: Palette.butter),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerifyEmailCard extends StatelessWidget {
  const _VerifyEmailCard();

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return Panel(
      color: context.tart.accent.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Confirm your email', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('We sent you a link. Tap it, then come back and press “I’ve confirmed”.', style: TextStyle(fontSize: 13, height: 1.4)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () async {
                  await auth.resendVerification();
                  if (context.mounted) showMessage(context, 'Sent again — check your inbox.');
                },
                child: const Text('Resend link'),
              ),
              TextButton(onPressed: auth.reloadUser, child: const Text('I’ve confirmed')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({super.key, required this.profile});

  final AppUser profile;

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  late final _name = TextEditingController(text: widget.profile.name);
  late final _phone = TextEditingController(text: widget.profile.phone);
  late final _address = TextEditingController(text: widget.profile.address);
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showMessage(context, 'Your name can’t be empty.');
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<ShopRepository>().saveProfile(
        widget.profile.uid,
        name: _name.text.trim(),
        email: widget.profile.email,
        phone: _phone.text.trim(),
        address: _address.text.trim(),
      );
      if (mounted) showMessage(context, 'Profile saved.');
    } catch (error) {
      if (mounted) showMessage(context, 'Couldn’t save: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Your details',
      child: Column(
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_outline)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Delivery address', prefixIcon: Icon(Icons.location_on_outlined), alignLabelWithHint: true),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save details')),
          ),
        ],
      ),
    );
  }
}

/// Shown in tabs that need an account.
class SignInPrompt extends StatelessWidget {
  const SignInPrompt({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    void open(bool register) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SignInScreen(startWithRegister: register)));

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(28, 24, 28, navClearance(context)),
        child: Column(
          children: [
            SizedBox(
              height: 170,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(color: context.tart.accent, shape: BoxShape.circle),
                  ),
                  const Positioned(left: 0, top: 10, child: TartArt(art: 'egg', size: 80)),
                  const Positioned(right: 0, bottom: 0, child: TartArt(art: 'berry', size: 90)),
                  const TartArt(art: 'pineapple', size: 110),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.tart.inkSoft, height: 1.45),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => open(false), child: const Text('Sign in')),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(onPressed: () => open(true), child: const Text('Create an account')),
            ),
            const SizedBox(height: 10),
            TextButton.icon(onPressed: () => showThemePicker(context), icon: const Icon(Icons.palette_outlined), label: const Text('Change app design')),
          ],
        ),
      ),
    );
  }
}
