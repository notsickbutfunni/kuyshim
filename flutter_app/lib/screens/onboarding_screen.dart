import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../l10n/strings.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  String _mode = 'main'; // main, login, register, forgot, reset-success
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  bool _loading = false;
  String _error = '';
  late AnimationController _iconAnim;

  @override
  void initState() {
    super.initState();
    _iconAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _iconAnim.dispose();
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
    setState(() { _error = ''; _loading = true; });
    try {
      final provider = context.read<AppProvider>();
      await provider.signIn(_usernameCtrl.text, _passwordCtrl.text);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleRegister() async {
    setState(() { _error = ''; _loading = true; });
    try {
      final provider = context.read<AppProvider>();
      await provider.register(
          _usernameCtrl.text, _emailCtrl.text, _passwordCtrl.text);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleResetPassword() async {
    setState(() { _error = ''; _loading = true; });
    try {
      await ApiService.resetPassword(
          _usernameCtrl.text, _emailCtrl.text, _newPasswordCtrl.text);
      setState(() => _mode = 'reset-success');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final t = provider.t;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Background glow
          Center(
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.emerald.withValues(alpha: 0.1),
              ),
            ),
          ),

          // Language toggle
          Positioned(
            top: 40,
            right: 24,
            child: _LangToggle(),
          ),

          // Content
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: size.width > 600 ? size.width * 0.2 : 32,
                vertical: 48,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated icon
                  AnimatedBuilder(
                    animation: _iconAnim,
                    builder: (_, child) {
                      final scale = 1.0 + _iconAnim.value * 0.05;
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.emerald,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emerald.withValues(alpha: 0.2),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.music_note,
                          color: Colors.white, size: 50),
                    ),
                  ),
                  const SizedBox(height: 32),

                  Text(t.appTitle, style: serifBold(48)),
                  const SizedBox(height: 8),
                  Text(
                    t.appSubtitle,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4), fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Mode-specific content
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildModeContent(t, provider),
                  ),

                  const SizedBox(height: 48),
                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(t.tradition,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.2),
                              fontSize: 10,
                              letterSpacing: 3)),
                      const SizedBox(width: 16),
                      Text('•',
                          style:
                              TextStyle(color: Colors.white.withValues(alpha: 0.2))),
                      const SizedBox(width: 16),
                      Text(t.technology,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.2),
                              fontSize: 10,
                              letterSpacing: 3)),
                      const SizedBox(width: 16),
                      Text('•',
                          style:
                              TextStyle(color: Colors.white.withValues(alpha: 0.2))),
                      const SizedBox(width: 16),
                      Text(t.mastery,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.2),
                              fontSize: 10,
                              letterSpacing: 3)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeContent(dynamic t, AppProvider provider) {
    switch (_mode) {
      case 'login':
        return _buildLoginForm(t);
      case 'register':
        return _buildRegisterForm(t);
      case 'forgot':
        return _buildForgotForm(t);
      case 'reset-success':
        return _buildResetSuccess(t);
      default:
        return _buildMainMenu(t, provider);
    }
  }

  Widget _buildMainMenu(dynamic t, AppProvider provider) {
    return Column(
      key: const ValueKey('main'),
      children: [
        _BigButton(
          label: t.startPlaying,
          icon: Icons.person,
          onTap: () => provider.startGuest(),
          filled: true,
        ),
        const SizedBox(height: 12),
        _BigButton(
          label: t.signIn,
          icon: Icons.login,
          onTap: provider.backendOnline
              ? () {
                  _resetForm();
                  setState(() => _mode = 'login');
                }
              : null,
        ),
        const SizedBox(height: 12),
        _BigButton(
          label: t.createAccount,
          icon: Icons.person_add,
          onTap: provider.backendOnline
              ? () {
                  _resetForm();
                  setState(() => _mode = 'register');
                }
              : null,
        ),
        if (!provider.backendOnline) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 12, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(width: 4),
              Text(t.backendOffline,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildLoginForm(dynamic t) {
    return Column(
      key: const ValueKey('login'),
      children: [
        Text(t.signIn,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(
          controller: _usernameCtrl,
          decoration: const InputDecoration(hintText: 'Username'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordCtrl,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Password'),
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_error,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
        ],
        const SizedBox(height: 16),
        _BigButton(
          label: _loading ? t.signingIn : t.signIn,
          icon: _loading ? null : Icons.login,
          onTap: _loading ? null : _handleLogin,
          filled: true,
          isLoading: _loading,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            _resetForm();
            setState(() => _mode = 'forgot');
          },
          child: Text(t.forgotPassword,
              style: TextStyle(color: AppColors.emerald.withValues(alpha: 0.6))),
        ),
        TextButton(
          onPressed: () => setState(() => _mode = 'main'),
          child: Text(t.back,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
        ),
      ],
    );
  }

  Widget _buildRegisterForm(dynamic t) {
    return Column(
      key: const ValueKey('register'),
      children: [
        Text(t.createAccount,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(
          controller: _usernameCtrl,
          decoration: const InputDecoration(hintText: 'Username'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'Email'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordCtrl,
          obscureText: true,
          decoration: InputDecoration(hintText: t.password),
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_error,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
        ],
        const SizedBox(height: 16),
        _BigButton(
          label: _loading ? t.creating : t.createAccount,
          icon: _loading ? null : Icons.person_add,
          onTap: _loading ? null : _handleRegister,
          filled: true,
          color: AppColors.emerald,
          isLoading: _loading,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _mode = 'main'),
          child: Text(t.back,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
        ),
      ],
    );
  }

  Widget _buildForgotForm(dynamic t) {
    return Column(
      key: const ValueKey('forgot'),
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.key, color: Colors.amber, size: 28),
        ),
        const SizedBox(height: 16),
        Text(t.resetPassword,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(t.resetPasswordDesc,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        TextField(
          controller: _usernameCtrl,
          decoration: const InputDecoration(hintText: 'Username'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'Email'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _newPasswordCtrl,
          obscureText: true,
          decoration: InputDecoration(hintText: t.newPassword),
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_error,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
        ],
        const SizedBox(height: 16),
        _BigButton(
          label: _loading ? t.resetting : t.resetPassword,
          icon: _loading ? null : Icons.key,
          onTap: _loading ? null : _handleResetPassword,
          filled: true,
          color: Colors.amber,
          isLoading: _loading,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            _resetForm();
            setState(() => _mode = 'login');
          },
          child: Text(t.backToSignIn,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
        ),
      ],
    );
  }

  Widget _buildResetSuccess(dynamic t) {
    return Column(
      key: const ValueKey('reset-success'),
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.emerald.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle,
              color: AppColors.emerald, size: 40),
        ),
        const SizedBox(height: 24),
        Text(t.passwordResetDone,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(t.passwordResetDoneDesc,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        _BigButton(
          label: t.signInNow,
          icon: Icons.login,
          onTap: () {
            _resetForm();
            setState(() => _mode = 'login');
          },
          filled: true,
        ),
      ],
    );
  }
}

class _BigButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool filled;
  final Color? color;
  final bool isLoading;

  const _BigButton({
    required this.label,
    this.icon,
    this.onTap,
    this.filled = false,
    this.color,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = filled
        ? (color ?? Colors.white)
        : Colors.white.withValues(alpha: 0.05);
    final fg = filled
        ? (color != null ? Colors.white : Colors.black)
        : Colors.white;
    final border = filled
        ? BorderSide.none
        : BorderSide(color: Colors.white.withValues(alpha: 0.1));

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.fromBorderSide(border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: fg),
                  )
                else if (icon != null)
                  Icon(icon, size: 20, color: fg),
                const SizedBox(width: 12),
                Text(label,
                    style: TextStyle(
                        color: onTap == null
                            ? fg.withValues(alpha: 0.4)
                            : fg,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LangToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    return GestureDetector(
      onTap: () => provider.toggleLanguage(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(
          AppStrings.langLabel(provider.lang),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
