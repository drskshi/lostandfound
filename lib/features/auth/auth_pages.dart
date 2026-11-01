import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../backend/campus_remote.dart';
import '../../backend/google_auth.dart';
import '../../backend/supabase_bootstrap.dart';
import '../../data/store.dart';
import '../../domain/access_role.dart';
import '../../theme/campus_theme.dart';
import '../../widgets/common.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 700), _open);
  }

  void _open() {
    if (!mounted) return;
    final store = CampusScope.of(context);
    if (!store.seenOnboarding) {
      context.go('/onboarding');
    } else if (store.me == null) {
      context.go('/login');
    } else if (!store.me!.emailVerified) {
      context.go('/verify');
    } else {
      context.go(
        signedInHome(
          role: store.me!.role,
          isStaff: store.me!.isStaff,
          serverAccount: store.serverAccount,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: campusBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CampusLogo(size: 52, light: true),
            SizedBox(height: 16),
            Text(
              'Good things find their way back.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final pages = const [
      (
        Icons.dynamic_feed_outlined,
        'Your campus feed',
        'Post what you lost or what you found. Photos, place and colour stay with the post.',
      ),
      (
        Icons.lock_outline,
        'Private claims',
        'Ownership details are not shown on the feed. A person at the office or the finder reviews them.',
      ),
      (
        Icons.pin_outlined,
        'Collect with a code',
        'An approved claim gets a 6-digit code. It expires, and it works once at handover.',
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CampusLogo(),
              const Spacer(),
              for (final page in pages) ...[
                Icon(page.$1, color: campusBlue, size: 28),
                const SizedBox(height: 8),
                Text(
                  page.$2,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  page.$3,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
              ],
              const Spacer(),
              FilledButton(
                onPressed: () => CampusScope.of(context).finishOnboarding(),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _google = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.68);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                const CampusLogo(),
                const SizedBox(height: 20),
                const Text(
                  'Your campus.\nA little more connected.',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Sign in to see what your campus has found. New accounts join as students.',
                  style: TextStyle(color: muted, height: 1.45),
                ),
                const SizedBox(height: 22),
                const InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'University',
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                  child: Text('Northbridge College'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('email-field'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'University email',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('password-field'),
                  controller: _password,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _showPassword ? 'Hide password' : 'Show password',
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _submit(store),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () => context.push('/recover'),
                    child: const Text('Forgot password'),
                  ),
                ),
                if ((_error ?? store.authMessage) != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _error ?? store.authMessage!,
                    style: const TextStyle(color: Color(0xFFB42318), height: 1.4),
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton(
                  key: const Key('sign-in-button'),
                  onPressed: () => _submit(store),
                  child: const Text('Sign in'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or', style: TextStyle(color: muted)),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _google ? null : () => _googleSignIn(),
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: Text(
                    _google ? 'Opening Google…' : 'Continue with Google',
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('New here?', style: TextStyle(color: muted)),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: const Text('Create an account'),
                    ),
                  ],
                ),
                Center(
                  child: TextButton(
                    onPressed: () => context.push('/privacy'),
                    child: const Text('Privacy'),
                  ),
                ),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit(CampusStore store) {
    if (!SupabaseBootstrap.isReady) {
      setState(() => _error = store.signIn(_email.text, _password.text));
      return;
    }
    setState(() => _error = null);
    CampusRemote.signIn(store, _email.text, _password.text).then((error) {
      if (!mounted) return;
      setState(() => _error = error);
    });
  }

  Future<void> _googleSignIn() async {
    setState(() {
      _google = true;
      _error = null;
    });
    final error = await GoogleAuth.start();
    if (!mounted) return;
    setState(() {
      _google = false;
      _error = error;
    });
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _department = TextEditingController();
  bool _terms = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _department.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
            const Text(
              'New accounts join as students. Staff access is granted on the server, not chosen here.',
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'name@university.ac.uk',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              helperText: 'At least 10 characters',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _department,
            decoration: const InputDecoration(labelText: 'Department'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _terms,
            onChanged: (value) => setState(() => _terms = value ?? false),
            title: const Text(
              'I agree to keep contact on the app and not to ask for payment.',
            ),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () async {
              if (!_terms) {
                setState(
                  () => _error =
                      'Please agree to the community rules to continue.',
                );
                return;
              }
              final error = await CampusRemote.register(
                CampusScope.of(context),
                name: _name.text,
                email: _email.text,
                password: _password.text,
                department: _department.text,
              );
              if (!mounted) return;
              setState(() => _error = error);
            },
            child: const Text('Create account'),
          ),
        ],
      ),
    );
  }
}

class VerifyPage extends StatelessWidget {
  const VerifyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    final code = store.me?.verifyCode;
    final controller = TextEditingController();
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm your email')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Email delivery is not connected, so the code is shown on this phone. It is not a message from a university.',
          ),
          const SizedBox(height: 16),
          if (code != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: campusSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  letterSpacing: 8,
                  fontWeight: FontWeight.w800,
                  color: campusBlueDark,
                ),
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '6-digit code'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final error = store.verify(controller.text);
              if (error != null) toast(context, error);
            },
            child: const Text('Confirm'),
          ),
          TextButton(
            onPressed: () {
              store.resendCode();
              toast(context, 'A new code is shown above.');
            },
            child: const Text('Send a new code'),
          ),
          TextButton(onPressed: store.signOut, child: const Text('Sign out')),
        ],
      ),
    );
  }
}

class RecoverPage extends StatefulWidget {
  const RecoverPage({super.key});

  @override
  State<RecoverPage> createState() => _RecoverPageState();
}

class _RecoverPageState extends State<RecoverPage> {
  final _email = TextEditingController();
  String? _message;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Password reset email is sent by the server, not by this app.',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          const Text(
            'The app never sees the mail password. If mail is not connected yet, nothing is sent.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    final error = await CampusRemote.sendPasswordReset(
                      _email.text,
                    );
                    if (!mounted) return;
                    setState(() {
                      _busy = false;
                      _message = error ??
                          'If that account can receive mail, a reset link is on its way.';
                    });
                  },
            child: Text(_busy ? 'Sending…' : 'Send reset link'),
          ),
        ],
      ),
    );
  }
}
