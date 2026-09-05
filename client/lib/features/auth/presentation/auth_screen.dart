import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/cyber_theme.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/cyber_button.dart';
import '../../../shared/widgets/shards_background.dart';
import '../providers/auth_providers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _successMessage;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _isLoading = true;
    });

    final authService = ref.read(authServiceProvider);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (_isSignUp) {
        final name = _nameController.text.trim();
        final confirmPassword = _confirmPasswordController.text;

        if (password != confirmPassword) {
          throw Exception("Passwords do not match.");
        }

        await authService.signUp(
          email: email,
          password: password,
          displayName: name,
        );

        setState(() {
          _successMessage = "Account created successfully! Logging into enclave...";
        });
      } else {
        await authService.signInWithPassword(
          email: email,
          password: password,
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text.trim());
    bool isSending = false;
    String? resetError;
    String? resetSuccess;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: GlassContainer(
                width: 420,
                glow: true,
                borderColor: CyberTheme.cyanGlow,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lock_reset, color: CyberTheme.cyan, size: 24),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'ACCOUNT RECOVERY',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: CyberTheme.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: CyberTheme.textMuted),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Enter your registered email address. We will verify your account and dispatch a cryptographic password recovery link.',
                      style: TextStyle(fontSize: 12, color: CyberTheme.textSecondary, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: resetEmailController,
                      hintText: 'name@example.com',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    if (resetError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        resetError!,
                        style: const TextStyle(fontSize: 11, color: CyberTheme.coral, fontWeight: FontWeight.bold),
                      ),
                    ],
                    if (resetSuccess != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        resetSuccess!,
                        style: const TextStyle(fontSize: 11, color: CyberTheme.emerald, fontWeight: FontWeight.bold),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        CyberButton(
                          variant: CyberButtonVariant.glassPill,
                          height: 38,
                          onTap: () => Navigator.pop(dialogContext),
                          child: const Text('CANCEL'),
                        ),
                        const SizedBox(width: 12),
                        CyberButton(
                          variant: CyberButtonVariant.whitePill,
                          height: 38,
                          isLoading: isSending,
                          onTap: () async {
                            setDialogState(() {
                              isSending = true;
                              resetError = null;
                              resetSuccess = null;
                            });
                            try {
                              await ref.read(authServiceProvider).resetPasswordForEmail(resetEmailController.text);
                              setDialogState(() {
                                isSending = false;
                                resetSuccess = 'Recovery email dispatched! Please check your inbox.';
                              });
                            } catch (e) {
                              setDialogState(() {
                                isSending = false;
                                resetError = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
                              });
                            }
                          },
                          child: const Text('SEND RECOVERY LINK'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: CyberTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CyberTheme.borderBright),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(
          color: CyberTheme.textPrimary,
          fontSize: 13,
          fontFamily: 'monospace',
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          icon: Icon(prefixIcon, color: CyberTheme.textMuted, size: 18),
          hintText: hintText,
          hintStyle: const TextStyle(color: CyberTheme.textMuted, fontSize: 13),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyberTheme.background,
      body: Stack(
        children: [
          // 1. 3D Prismatic Shards ("Wind Sculpture") Interactive Engine
          const Positioned.fill(
            child: ShardsBackground(),
          ),

          // Central Authentication Card
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: GlassContainer(
                width: 460,
                padding: const EdgeInsets.all(36),
                glow: true,
                glowColor: CyberTheme.accentColor,
                borderColor: CyberTheme.borderAccent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Badge (React Bits / Project Kerberos)
                    Center(
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: CyberTheme.shardGradient,
                          boxShadow: [
                            BoxShadow(
                              color: CyberTheme.accentColor.withValues(alpha: 0.4),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.all_inclusive_rounded, color: Colors.white, size: 30),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        'PROJECT KERBEROS',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          color: CyberTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Center(
                      child: Text(
                        'REACT BITS // ZERO-TRUST PROVENANCE ENCLAVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: CyberTheme.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Tab Selector: Sign In vs Create Account
                    Container(
                      decoration: BoxDecoration(
                        color: CyberTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: CyberTheme.border),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _isSignUp = false;
                                _errorMessage = null;
                                _successMessage = null;
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !_isSignUp ? CyberTheme.surfaceElevated : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: !_isSignUp ? Border.all(color: CyberTheme.borderAccent) : null,
                                ),
                                child: Center(
                                  child: Text(
                                    'SIGN IN',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                      color: !_isSignUp ? const Color(0xFFC084FC) : CyberTheme.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _isSignUp = true;
                                _errorMessage = null;
                                _successMessage = null;
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _isSignUp ? CyberTheme.surfaceElevated : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: _isSignUp ? Border.all(color: CyberTheme.borderAccent) : null,
                                ),
                                child: Center(
                                  child: Text(
                                    'CREATE ACCOUNT',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                      color: _isSignUp ? const Color(0xFFC084FC) : CyberTheme.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Display Name Field (Only on Sign Up)
                    if (_isSignUp) ...[
                      _buildTextField(
                        controller: _nameController,
                        hintText: 'Full Name / Agent Alias',
                        prefixIcon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Email Field
                    _buildTextField(
                      controller: _emailController,
                      hintText: 'name@organization.com',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    _buildTextField(
                      controller: _passwordController,
                      hintText: _isSignUp ? 'Password (min. 6 characters)' : 'Password',
                      prefixIcon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: CyberTheme.textMuted,
                          size: 18,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),

                    // Confirm Password Field (Only on Sign Up)
                    if (_isSignUp) ...[
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _confirmPasswordController,
                        hintText: 'Confirm Password',
                        prefixIcon: Icons.lock_clock_outlined,
                        obscureText: _obscurePassword,
                      ),
                    ],

                    // Forgot Password Link (Only on Sign In)
                    if (!_isSignUp) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: CyberTheme.cyan,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],

                    // Error Message Banner
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CyberTheme.coral.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: CyberTheme.coral.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: CyberTheme.coral, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Success Message Banner
                    if (_successMessage != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CyberTheme.emerald.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: CyberTheme.emerald.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: CyberTheme.emerald, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _successMessage!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Primary Submit Button
                    CyberButton(
                      isExpanded: true,
                      variant: CyberButtonVariant.whitePill,
                      height: 44,
                      isLoading: _isLoading,
                      onTap: _submit,
                      child: Text(_isSignUp ? 'REGISTER & ENTER ENCLAVE' : 'INITIALIZE ENCLAVE SESSION'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
