import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/brand.dart';

/// Sign in or create an account. Pops with `true` once signed in.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.startWithRegister = false, this.reason});

  final bool startWithRegister;
  final String? reason;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  late bool _register = widget.startWithRegister;
  bool _busy = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<AuthService>();
    setState(() => _busy = true);
    try {
      if (_register) {
        await auth.register(name: _name.text, email: _email.text, password: _password.text, phone: _phone.text);
      } else {
        await auth.signIn(_email.text, _password.text);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      showMessage(context, _register ? 'Welcome! Check your inbox to confirm your email.' : 'Welcome back!');
    } catch (error) {
      if (mounted) showMessage(context, authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = TextEditingController(text: _email.text);
    final send = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset your password'),
        content: TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send link')),
        ],
      ),
    );
    if (send != true || !mounted) return;
    try {
      await context.read<AuthService>().sendPasswordReset(email.text);
      if (mounted) showMessage(context, 'If that email has an account, a reset link is on its way.');
    } catch (error) {
      if (mounted) showMessage(context, authErrorMessage(error));
    } finally {
      email.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          children: staggered([
            const Align(alignment: Alignment.centerLeft, child: BrandLogo(size: 64)),
            const SizedBox(height: 18),
            Text(_register ? 'Create your account' : 'Welcome back', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 6),
            Text(
              widget.reason ?? (_register ? 'It takes less than a minute.' : 'Sign in to order and track your tarts.'),
              style: TextStyle(color: context.tart.inkSoft, fontSize: 15),
            ),
            const SizedBox(height: 22),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Sign in')),
                ButtonSegment(value: true, label: Text('New here')),
              ],
              selected: {_register},
              onSelectionChanged: (value) => setState(() => _register = value.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: context.tart.deep,
                selectedForegroundColor: context.tart.accent,
                side: BorderSide(color: context.tart.line),
              ),
            ),
            const SizedBox(height: 20),
            if (_register) ...[
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Your name', prefixIcon: Icon(Icons.person_outline)),
                validator: (value) => (value ?? '').trim().isEmpty ? 'Tell us your name.' : null,
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded)),
              validator: (value) => (value ?? '').contains('@') ? null : 'Enter a valid email.',
            ),
            if (_register) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone (optional)', prefixIcon: Icon(Icons.phone_outlined)),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: !_showPassword,
              autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                  icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                ),
              ),
              validator: (value) => _register && (value ?? '').length < 8
                  ? 'Use at least 8 characters.'
                  : (value ?? '').isEmpty
                  ? 'Enter your password.'
                  : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (!_register)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: _forgotPassword, child: const Text('Forgot password?')),
              ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Just a moment…' : (_register ? 'Create account' : 'Sign in'))),
          ]),
        ),
      ),
    );
  }
}
