import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/people_mart_logo.dart';
import '../../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final fullName = _nameController.text.trim();

    if (_isSignUp && fullName.isEmpty) {
      setState(() => _errorMessage = 'Please enter your full name.');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider?>(context, listen: false);
    bool success;
    String? error;
    if (authProvider != null) {
      success = _isSignUp
          ? await authProvider.signUp(
              email: email,
              password: password,
              fullName: fullName,
            )
          : await authProvider.signInWithPassword(
              email: email,
              password: password,
            );
      error = authProvider.errorMessage;
    } else {
      try {
        final client = Supabase.instance.client;
        if (_isSignUp) {
          final response = await client.auth.signUp(
            email: email,
            password: password,
            data: {'full_name': fullName},
          );
          success = response.user != null && response.session != null;
          if (response.user != null && response.session == null) {
            error = 'Account created. Check your email to confirm it, then sign in.';
          }
        } else {
          final response = await client.auth.signInWithPassword(
            email: email,
            password: password,
          );
          success = response.user != null;
        }
      } on AuthException catch (exception) {
        success = false;
        error = exception.message;
      } catch (_) {
        success = false;
        error = 'Could not connect to People Mart. Check your internet and try again.';
      }
    }

    if (!mounted) return;
    if (success) {
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
      if (Navigator.canPop(context)) Navigator.pop(context, true);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage =
            error ?? 'Authentication failed. Please check your details.';
      });
    }
  }

  Future<void> _forgotPassword() async {
    final emailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset your password'),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email Address'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, emailController.text.trim()),
            child: const Text('Send link'),
          ),
        ],
      ),
    );
    emailController.dispose();
    if (email == null || !mounted) return;
    if (!email.contains('@')) {
      setState(
        () => _errorMessage =
            'Enter a valid email address to reset your password.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final auth = Provider.of<AuthProvider?>(context, listen: false);
    var sent = false;
    String? error;
    if (auth != null) {
      sent = await auth.sendPasswordResetEmail(email: email);
      error = auth.errorMessage;
    } else {
      try {
        await Supabase.instance.client.auth.resetPasswordForEmail(email);
        sent = true;
      } on AuthException catch (exception) {
        error = exception.message;
      } catch (_) {
        error = 'Could not connect to People Mart. Check your internet and try again.';
      }
    }
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = sent
          ? 'Password reset link sent. Check your email.'
          : error ?? 'Could not send the password reset link.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9FC),
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
          builder: (context, constraints) {
            final wideLayout = constraints.maxWidth >= 760;
            final heroHeight = wideLayout
                ? math.max(420.0, math.min(620.0, constraints.maxHeight))
                : (constraints.maxHeight * .34).clamp(230.0, 330.0).toDouble();
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: wideLayout
                    ? Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1120),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _AuthHero(
                                    height: heroHeight,
                                    width: math.min(
                                      620.0,
                                      constraints.maxWidth * .55,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 440,
                                  child: Center(child: _authPanel(context)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          _AuthHero(
                            height: heroHeight,
                            width: constraints.maxWidth,
                          ),
                          _authPanel(context),
                        ],
                      ),
              ),
            );
          },
        ),
        if (Navigator.of(context).canPop())
          Positioned(
            top: 8,
            left: 8,
            child: Material(
              color: Colors.white.withValues(alpha: 0.8),
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.close, color: AppColors.primary),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
      ],
    ),
  ),
);
  }

  Widget _authPanel(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(26, 23, 26, 26),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF2B0938).withValues(alpha: .08),
          blurRadius: 22,
          offset: const Offset(0, -7),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _modeSelector(),
        const SizedBox(height: 22),
        Text(
          _isSignUp ? 'Create your account' : 'Sign in to People Cart',
          style: const TextStyle(
            fontSize: 29,
            height: 1.1,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          _isSignUp
              ? 'Sign up to start your shopping journey'
              : 'Log in to continue your shopping journey',
          style: const TextStyle(color: Color(0xFF725C7A), fontSize: 14),
        ),
        const SizedBox(height: 21),
        if (_isSignUp) ...[
          _input(
            controller: _nameController,
            label: 'Full Name',
            icon: Icons.person_outline,
            capitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 13),
        ],
        _input(
          controller: _emailController,
          label: 'Email Address',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 13),
        _input(
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock_outline,
          obscureText: !_isPasswordVisible,
          suffix: IconButton(
            tooltip: _isPasswordVisible ? 'Hide password' : 'Show password',
            onPressed: () =>
                setState(() => _isPasswordVisible = !_isPasswordVisible),
            icon: Icon(
              _isPasswordVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppColors.primary,
            ),
          ),
        ),
        if (!_isSignUp)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading ? null : _forgotPassword,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentPink,
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          )
        else
          const SizedBox(height: 13),
        if (_errorMessage != null) ...[
          _AuthMessage(message: _errorMessage!),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          height: 58,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF4B82), AppColors.accentPink],
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentPink.withValues(alpha: .20),
                  blurRadius: 13,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ElevatedButton(
              key: const ValueKey('auth-submit-button'),
              onPressed: _isLoading ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: _isLoading
                  ? const SizedBox.square(
                      dimension: 23,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isSignUp ? 'Create Account' : 'Login',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.arrow_forward_rounded),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 17),
        const Row(
          children: [
            Expanded(child: Divider(color: Color(0xFFEADDEC))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'OR',
                style: TextStyle(
                  color: Color(0xFF94789C),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(child: Divider(color: Color(0xFFEADDEC))),
          ],
        ),
        const SizedBox(height: 13),
        Center(
          child: Text(
            _isSignUp
                ? 'Create your account with email'
                : 'Secure sign in with your email',
            style: const TextStyle(color: Color(0xFF725C7A), fontSize: 13),
          ),
        ),
        const SizedBox(height: 17),
        Center(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(
                color: Color(0xFF806A88),
                fontSize: 12,
                height: 1.5,
              ),
              children: [
                const TextSpan(text: 'By continuing, you agree to our '),
                TextSpan(
                  text: 'Terms & Conditions',
                  style: TextStyle(
                    color: AppColors.accentPink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: TextStyle(
                    color: AppColors.accentPink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );

  Widget _modeSelector() => Container(
    height: 55,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEFF6),
      borderRadius: BorderRadius.circular(32),
    ),
    child: Row(
      children: [
        Expanded(
          child: _isSignUp
              ? TextButton.icon(
                  onPressed: _isLoading ? null : () => _setMode(false),
                  icon: const Icon(Icons.person_outline, size: 20),
                  label: const Text('Login'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _setMode(false),
                  icon: const Icon(Icons.person, size: 20),
                  label: const Text('Login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
        ),
        Expanded(
          child: _isSignUp
              ? ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _setMode(true),
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  label: const Text('Sign Up'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                )
              : TextButton.icon(
                  onPressed: _isLoading ? null : () => _setMode(true),
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  label: const Text('Sign Up'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
        ),
      ],
    ),
  );

  void _setMode(bool signUp) => setState(() {
    _isSignUp = signUp;
    _errorMessage = null;
  });

  Widget _input({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    bool obscureText = false,
    Widget? suffix,
  }) => SizedBox(
    height: 61,
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        prefixIcon: Icon(icon, color: AppColors.primary),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        labelStyle: const TextStyle(color: Color(0xFF806A88)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: Color(0xFFE2D2E7), width: 1.3),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.7),
        ),
      ),
    ),
  );
}

class _AuthHero extends StatelessWidget {
  final double height;
  final double width;
  const _AuthHero({required this.height, required this.width});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(child: CustomPaint(painter: _HeroBackdropPainter())),
        Positioned(
          top: 12,
          left: 0,
          right: 0,
          child: Column(
            children: [
              PeopleMartLogo(
                width: height < 250 ? 136 : 176,
                height: height < 250 ? 58 : 75,
              ),
              Text(
                'G R O C E R I E S .   M O R E .   F A S T E R .',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: height < 250 ? 8 : 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: width * .06,
          top: height * .38,
          width: width * .58,
          child: _HeroCopy(fontSize: width < 360 ? 20 : 24),
        ),
        Positioned(
          right: -width * .025,
          top: height * .35,
          width: width * .52,
          height: height * .57,
          child: Image.asset(
            'assets/images/auth/people_mart_grocery_bag.png',
            fit: BoxFit.contain,
            semanticLabel: 'People Mart bag with fresh groceries',
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 7,
          child: _BenefitsRow(compact: height < 370),
        ),
      ],
    ),
  );
}

class _HeroCopy extends StatelessWidget {
  final double fontSize;
  const _HeroCopy({required this.fontSize});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Fresh Groceries\nDelivered to Your',
        style: TextStyle(
          color: AppColors.primary,
          fontSize: fontSize,
          height: 1.12,
          fontWeight: FontWeight.w900,
          letterSpacing: -.7,
        ),
      ),
      Text(
        'Doorstep',
        style: TextStyle(
          color: AppColors.accentPink,
          fontSize: fontSize + 2,
          height: 1.12,
          fontWeight: FontWeight.w900,
          letterSpacing: -.7,
        ),
      ),
    ],
  );
}

class _BenefitsRow extends StatelessWidget {
  final bool compact;
  const _BenefitsRow({required this.compact});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.start,
    children: [
      _Benefit(
        icon: Icons.bolt_rounded,
        label: 'Super Fast\nDelivery',
        compact: compact,
      ),
      _separator(compact: compact),
      _Benefit(
        icon: Icons.local_offer_rounded,
        label: 'Best\nDeals',
        compact: compact,
      ),
      _separator(compact: compact),
      _Benefit(
        icon: Icons.eco_rounded,
        label: 'Fresh\nProducts',
        compact: compact,
      ),
    ],
  );

  Widget _separator({required bool compact}) => Container(
    height: compact ? 38 : 64,
    width: 1,
    margin: EdgeInsets.symmetric(vertical: compact ? 10 : 20),
    color: const Color(0xFFD8C3DE),
  );
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool compact;
  const _Benefit({
    required this.icon,
    required this.label,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: compact ? 82 : 85,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primary, size: compact ? 22 : 25),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.primary,
            height: 1.15,
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _AuthMessage extends StatelessWidget {
  final String message;
  const _AuthMessage({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF0F2),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Text(
      message,
      style: const TextStyle(color: Color(0xFF9C2446), fontSize: 12),
    ),
  );
}

class _HeroBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Colors.white, Color(0xFFFFF8FB), Color(0xFFF9DDEB)],
        ).createShader(rect),
    );

    final wave = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * .37, 0)
      ..cubicTo(
        size.width * .27,
        size.height * .22,
        size.width * .60,
        size.height * .30,
        size.width * .53,
        size.height * .50,
      )
      ..cubicTo(
        size.width * .47,
        size.height * .70,
        size.width * .77,
        size.height * .74,
        size.width,
        size.height * .96,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      wave,
      Paint()..color = const Color(0xFFF9CFD7).withValues(alpha: .58),
    );

    final skylinePaint = Paint()
      ..color = const Color(0xFFEAB3C0).withValues(alpha: .25);
    final baseY = size.height * .88;
    final buildings = <Rect>[
      Rect.fromLTWH(size.width * .04, baseY - 38, 23, 38),
      Rect.fromLTWH(size.width * .09, baseY - 72, 29, 72),
      Rect.fromLTWH(size.width * .16, baseY - 50, 34, 50),
      Rect.fromLTWH(size.width * .65, baseY - 44, 28, 44),
      Rect.fromLTWH(size.width * .72, baseY - 61, 34, 61),
      Rect.fromLTWH(size.width * .80, baseY - 32, 28, 32),
      Rect.fromLTWH(size.width * .88, baseY - 48, 35, 48),
    ];
    for (final building in buildings) {
      canvas.drawRect(building, skylinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
