/// OnboardingScreen — Login, Register, Forgot Password, Guest mode.
/// Mirrors OnboardingScreen.tsx from the React app.
/// All sizes are percentage-based via MediaQuery to prevent overflow.
library;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../main.dart';
import '../services/app_state.dart';
import '../services/language_service.dart';
import '../widgets/lang_toggle.dart';
import 'package:flutter_svg/flutter_svg.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  /// Modes: 'main', 'login', 'register', 'forgot', 'reset-success'
  String _mode = 'main';

  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();

  bool _loading = false;
  String _error = '';

  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    // Check if user is already signed in (restored session)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (!appState.user.isGuest) {
        context.go('/library');
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _newPasswordCtrl.dispose();
    super.dispose();
  }

  void _resetForm() {
    _usernameCtrl.clear();
    _emailCtrl.clear();
    _passwordCtrl.clear();
    _newPasswordCtrl.clear();
    setState(() => _error = '');
  }

  Future<void> _handleLogin() async {
    if (_usernameCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) return;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await context.read<AppState>().signIn(
            _usernameCtrl.text,
            _passwordCtrl.text,
          );
      if (mounted) context.go('/library');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleRegister() async {
    if (_usernameCtrl.text.isEmpty ||
        _emailCtrl.text.isEmpty ||
        _passwordCtrl.text.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await context.read<AppState>().register(
            _usernameCtrl.text,
            _emailCtrl.text,
            _passwordCtrl.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! Logging you in...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        context.go('/library');
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await context.read<AppState>().signInWithGoogle();
      if (mounted) context.go('/library');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleResetPassword() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await context.read<AppState>().api.resetPassword(
            _usernameCtrl.text,
            _emailCtrl.text,
            _newPasswordCtrl.text,
          );
      setState(() => _mode = 'reset-success');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startGuest() {
    context.read<AppState>().startGuest();
    context.go('/library');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageService>().t;
    final appState = context.watch<AppState>();
    final screenSize = MediaQuery.of(context).size;
    final sw = screenSize.width;
    final sh = screenSize.height;

    return Scaffold(
      backgroundColor: KColors.background,
      body: Stack(
        children: [
          // Language toggle — top right
          Positioned(
            top: sh * 0.06,
            right: sw * 0.025,
            child: const LangToggle(),
          ),

          // Background glow
          Center(
            child: Container(
              width: sw * 0.4,
              height: sw * 0.4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    KColors.emerald.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main content — horizontal layout for landscape
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: sw * 0.05,
                vertical: sh * 0.04,
              ),
              child: Flex(
                direction: sw < sh ? Axis.vertical : Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left side: logo + title
                  SizedBox(
                    width: sw < sh ? sw * 0.9 : sw * 0.35,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo icon
                        AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (context, child) {
                            final scale =
                                1.0 + (_pulseCtrl.value * 0.05);
                            final rotation =
                                (_pulseCtrl.value - 0.5) * 0.1;
                            return Transform.scale(
                              scale: scale,
                              child: Transform.rotate(
                                angle: rotation,
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            width: sh * 0.18,
                            height: sh * 0.18,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                sh * 0.04,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: KColors.emerald
                                      .withOpacity(0.2),
                                  blurRadius: sh * 0.07,
                                  spreadRadius: sh * 0.012,
                                ),
                              ],
                            ),
                            child: SvgPicture.asset(
                              'assets/dombra_icon_green.svg',
                              width: sh * 0.18,
                              height: sh * 0.18,
                            ),
                          ),
                        )
                            .animate()
                            .scale(
                              begin: const Offset(0.8, 0.8),
                              duration: 800.ms,
                              curve: Curves.easeOut,
                            )
                            .fadeIn(duration: 800.ms),

                        SizedBox(height: sh * 0.04),

                        // Title
                        Text(
                          t.appTitle,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: sh * 0.08,
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -2,
                          ),
                        ),

                        SizedBox(height: sh * 0.015),

                        // Subtitle
                        Text(
                          t.appSubtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: sh * 0.032,
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),

                        SizedBox(height: sh * 0.03),

                        // Footer
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _footerText(t.tradition, sw, sh),
                            _dot(sh),
                            _footerText(t.technology, sw, sh),
                            _dot(sh),
                            _footerText(t.mastery, sw, sh),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(
                    width: sw < sh ? 0 : sw * 0.06,
                    height: sw < sh ? sh * 0.06 : 0,
                  ),

                  // Right side: form content
                  SizedBox(
                    width: sw < sh ? sw * 0.9 : sw * 0.3,
                    child: _buildModeContent(t, appState, sw, sh),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeContent(
      dynamic t, AppState appState, double sw, double sh) {
    switch (_mode) {
      case 'login':
        return _buildLoginForm(t, sw, sh);
      case 'register':
        return _buildRegisterForm(t, sw, sh);
      case 'forgot':
        return _buildForgotForm(t, sw, sh);
      case 'reset-success':
        return _buildResetSuccess(t, sw, sh);
      default:
        return _buildMainMenu(t, appState, sw, sh);
    }
  }

  Widget _buildMainMenu(
      dynamic t, AppState appState, double sw, double sh) {
    final btnPadV = sh * 0.04;
    final btnRadius = sh * 0.04;
    final iconSize = sh * 0.05;
    final gap = sh * 0.03;

    return Column(
      children: [
        // Start Playing (Guest)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _startGuest,
            icon: Icon(Icons.person, size: iconSize),
            label: Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(t.startPlaying, style: TextStyle(fontSize: sh * 0.038)),
              ),
            ),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: btnPadV),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(btnRadius),
              ),
            ),
          ),
        ),
        SizedBox(height: gap),

        // Sign In
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: appState.backendOnline
                ? () {
                    _resetForm();
                    setState(() => _mode = 'login');
                  }
                : null,
            icon: Icon(Icons.login, size: iconSize),
            label: Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(t.signIn, style: TextStyle(fontSize: sh * 0.038)),
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: btnPadV),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(btnRadius),
              ),
            ),
          ),
        ),
        SizedBox(height: gap),

        // Create Account
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: appState.backendOnline
                ? () {
                    _resetForm();
                    setState(() => _mode = 'register');
                  }
                : null,
            icon: Icon(Icons.person_add, size: iconSize),
            label: Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(t.createAccount, style: TextStyle(fontSize: sh * 0.038)),
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: btnPadV),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(btnRadius),
              ),
            ),
          ),
        ),
        SizedBox(height: gap),

        // Sign in with Google
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _loading ? null : _handleGoogleLogin,
            icon: Icon(Icons.g_mobiledata, size: iconSize, color: Colors.white),
            label: Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Continue with Google', style: TextStyle(fontSize: sh * 0.038, color: Colors.white)),
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: btnPadV),
              side: const BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(btnRadius),
              ),
            ),
          ),
        ),

        if (_error.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: gap),
            child: Row(
              children: [
                Icon(Icons.error_outline,
                    size: sh * 0.035, color: Colors.redAccent),
                SizedBox(width: sw * 0.006),
                Expanded(
                  child: Text(_error,
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: sh * 0.032)),
                ),
              ],
            ),
          ),

        if (!appState.backendOnline)
          Padding(
            padding: EdgeInsets.only(top: sh * 0.03),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: sh * 0.03,
                    color: Colors.white.withOpacity(0.3)),
                SizedBox(width: sw * 0.005),
                Flexible(
                  child: Text(
                    t.backendOffline,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: sh * 0.028,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLoginForm(dynamic t, double sw, double sh) {
    final titleSize = sh * 0.05;
    final labelSize = sh * 0.032;
    final iconSize = sh * 0.05;
    final gap = sh * 0.03;
    final gapSm = sh * 0.02;
    final btnPadV = sh * 0.04;
    final spinnerSize = sh * 0.05;

    return Column(
      children: [
        Text(
          t.signIn,
          style: TextStyle(
              fontSize: titleSize, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: btnPadV),
        TextField(
          controller: _usernameCtrl,
          decoration: InputDecoration(hintText: t.username),
          style: TextStyle(
              color: Colors.white, fontSize: labelSize),
        ),
        SizedBox(height: gap),
        TextField(
          controller: _passwordCtrl,
          obscureText: true,
          decoration: InputDecoration(hintText: t.password),
          style: TextStyle(
              color: Colors.white, fontSize: labelSize),
        ),
        if (_error.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: gap),
            child: Row(
              children: [
                Icon(Icons.error_outline,
                    size: sh * 0.035, color: Colors.redAccent),
                SizedBox(width: sw * 0.006),
                Expanded(
                  child: Text(_error,
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: labelSize)),
                ),
              ],
            ),
          ),
        SizedBox(height: btnPadV),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _handleLogin,
            icon: _loading
                ? SizedBox(
                    width: spinnerSize,
                    height: spinnerSize,
                    child: const CircularProgressIndicator(
                        strokeWidth: 2),
                  )
                : Icon(Icons.login, size: iconSize),
            label: Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(_loading ? t.signingIn : t.signIn, style: TextStyle(fontSize: sh * 0.038)),
              ),
            ),
          ),
        ),
        SizedBox(height: gapSm),
        TextButton(
          onPressed: () {
            _resetForm();
            setState(() => _mode = 'forgot');
          },
          child: Text(
            t.forgotPassword,
            style: TextStyle(
              color: KColors.emerald.withOpacity(0.6),
              fontSize: labelSize,
            ),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _mode = 'main'),
          child: Text(
            t.back,
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: labelSize,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm(dynamic t, double sw, double sh) {
    final titleSize = sh * 0.05;
    final labelSize = sh * 0.032;
    final iconSize = sh * 0.05;
    final gap = sh * 0.03;
    final gapSm = sh * 0.02;
    final btnPadV = sh * 0.04;
    final spinnerSize = sh * 0.05;

    return Column(
      children: [
        Text(
          t.createAccount,
          style: TextStyle(
              fontSize: titleSize, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: btnPadV),
        TextField(
          controller: _usernameCtrl,
          decoration: InputDecoration(hintText: t.username),
          style: TextStyle(
              color: Colors.white, fontSize: labelSize),
        ),
        SizedBox(height: gap),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(hintText: t.email),
          style: TextStyle(
              color: Colors.white, fontSize: labelSize),
        ),
        SizedBox(height: gap),
        TextField(
          controller: _passwordCtrl,
          obscureText: true,
          decoration: InputDecoration(hintText: t.password),
          style: TextStyle(
              color: Colors.white, fontSize: labelSize),
        ),
        if (_error.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: gap),
            child: Row(
              children: [
                Icon(Icons.error_outline,
                    size: sh * 0.035, color: Colors.redAccent),
                SizedBox(width: sw * 0.006),
                Expanded(
                  child: Text(_error,
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: labelSize)),
                ),
              ],
            ),
          ),
        SizedBox(height: btnPadV),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _handleRegister,
            icon: _loading
                ? SizedBox(
                    width: spinnerSize,
                    height: spinnerSize,
                    child: const CircularProgressIndicator(
                        strokeWidth: 2),
                  )
                : Icon(Icons.person_add, size: iconSize),
            label: Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(_loading ? t.creating : t.createAccount, style: TextStyle(fontSize: sh * 0.038)),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: KColors.emerald,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        SizedBox(height: gapSm),
        TextButton(
          onPressed: () => setState(() => _mode = 'main'),
          child: Text(
            t.back,
            style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: labelSize),
          ),
        ),
      ],
    );
  }

  Widget _buildForgotForm(dynamic t, double sw, double sh) {
    final titleSize = sh * 0.05;
    final labelSize = sh * 0.032;
    final iconSize = sh * 0.05;
    final gap = sh * 0.03;
    final gapSm = sh * 0.02;
    final btnPadV = sh * 0.04;
    final spinnerSize = sh * 0.05;
    final keyBoxSize = sh * 0.14;
    final keyIconSize = sh * 0.07;

    return Column(
      children: [
        Container(
          width: keyBoxSize,
          height: keyBoxSize,
          decoration: BoxDecoration(
            color: KColors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(sh * 0.04),
          ),
          child: Icon(Icons.vpn_key_rounded,
              size: keyIconSize, color: KColors.amber),
        ),
        SizedBox(height: gap),
        Text(
          t.resetPassword,
          style: TextStyle(
              fontSize: titleSize, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: sh * 0.01),
        Text(
          t.resetPasswordDesc,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: labelSize,
            color: Colors.white.withOpacity(0.4),
          ),
        ),
        SizedBox(height: btnPadV),
        TextField(
          controller: _usernameCtrl,
          decoration: InputDecoration(hintText: t.username),
          style: TextStyle(
              color: Colors.white, fontSize: labelSize),
        ),
        SizedBox(height: gap),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(hintText: t.email),
          style: TextStyle(
              color: Colors.white, fontSize: labelSize),
        ),
        SizedBox(height: gap),
        TextField(
          controller: _newPasswordCtrl,
          obscureText: true,
          decoration: InputDecoration(hintText: t.newPassword),
          style: TextStyle(
              color: Colors.white, fontSize: labelSize),
        ),
        if (_error.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: gap),
            child: Row(
              children: [
                Icon(Icons.error_outline,
                    size: sh * 0.035, color: Colors.redAccent),
                SizedBox(width: sw * 0.006),
                Expanded(
                  child: Text(_error,
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: labelSize)),
                ),
              ],
            ),
          ),
        SizedBox(height: btnPadV),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _handleResetPassword,
            icon: _loading
                ? SizedBox(
                    width: spinnerSize,
                    height: spinnerSize,
                    child: const CircularProgressIndicator(
                        strokeWidth: 2),
                  )
                : Icon(Icons.vpn_key_rounded, size: iconSize),
            label: Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(_loading ? t.resetting : t.resetPassword, style: TextStyle(fontSize: sh * 0.038)),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: KColors.amber,
              foregroundColor: Colors.black,
            ),
          ),
        ),
        SizedBox(height: gapSm),
        TextButton(
          onPressed: () {
            _resetForm();
            setState(() => _mode = 'login');
          },
          child: Text(
            t.backToSignIn,
            style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: labelSize),
          ),
        ),
      ],
    );
  }

  Widget _buildResetSuccess(dynamic t, double sw, double sh) {
    final titleSize = sh * 0.05;
    final labelSize = sh * 0.032;
    final iconSize = sh * 0.05;
    final btnPadV = sh * 0.04;
    final circleSize = sh * 0.2;
    final checkSize = sh * 0.1;

    return Column(
      children: [
        Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            color: KColors.emerald.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_circle,
              size: checkSize, color: KColors.emerald),
        ),
        SizedBox(height: btnPadV),
        Text(
          t.passwordResetDone,
          style: TextStyle(
              fontSize: titleSize, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: sh * 0.02),
        Text(
          t.passwordResetDoneDesc,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: labelSize,
            color: Colors.white.withOpacity(0.4),
          ),
        ),
        SizedBox(height: sh * 0.05),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              _resetForm();
              setState(() => _mode = 'login');
            },
            icon: Icon(Icons.login, size: iconSize),
            label: Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(t.signInNow, style: TextStyle(fontSize: sh * 0.038)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _footerText(String text, double sw, double sh) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: sw * 0.012),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: sh * 0.025,
          fontFamily: 'monospace',
          color: Colors.white.withOpacity(0.2),
          letterSpacing: 3,
        ),
      ),
    );
  }

  Widget _dot(double sh) {
    return Text(
      '•',
      style: TextStyle(
        fontSize: sh * 0.025,
        color: Colors.white.withOpacity(0.2),
      ),
    );
  }
}
