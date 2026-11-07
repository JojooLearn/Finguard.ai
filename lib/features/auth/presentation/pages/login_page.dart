import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthCubit>().signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email jangan kosong, kocak!';
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Format email lu ngaco!';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Kata sandi diisi dulu lah!';
    }
    if (value.length < 6) {
      return 'Bisa baca gak sih? minimal 6 tolol.';
    }
    return null;
  }

  String _formatAuthError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials') ||
        lower.contains('invalid email or password')) {
      return 'Email atau password lu salah, kocak! Cek lagi dah.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Email lu belom dikonfirmasi, jangan buru-buru!';
    }
    if (lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('connection')) {
      return 'Sinyal lu bapuk banget, cek koneksi dulu!';
    }
    if (lower.contains('rate limit') || lower.contains('too many requests')) {
      return 'Sabar napa! Kebanyakan nyoba, tunggu bentar.';
    }
    return 'Gagal masuk! Cek kelengkapan data lu lagi.';
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is Authenticated) {
          context.go('/');
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _formatAuthError(state.message),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
      child: Scaffold(
        body: Container(
          height: double.infinity,
          decoration: const BoxDecoration(gradient: AppColors.screenBackground),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sideMargin,
                vertical: 24,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    // App Logo 3D Squircle
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'assets/icons/app_logo.png',
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Masuk ke FinGuard', style: AppTypography.screenTitle),
                    const SizedBox(height: 6),
                    Text(
                      'Navigasi Keuangan Cerdas & Terdisiplin',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Fields
                    AppTextField(
                      label: 'Email',
                      hint: 'nama@email.com',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      label: 'Kata sandi',
                      hint: '••••••••',
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      validator: _validatePassword,
                      suffixIcon: IconButton(
                        icon: PhosphorIcon(
                          _obscurePassword
                              ? PhosphorIconsRegular.eye
                              : PhosphorIconsRegular.eyeSlash,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Button Masuk
                    BlocBuilder<AuthCubit, AuthState>(
                      builder: (context, state) {
                        return AppButton(
                          label: 'Masuk',
                          isLoading: state is AuthLoading,
                          onPressed: _login,
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Bottom Register Link
                    Center(
                      child: GestureDetector(
                        onTap: () => context.push('/register'),
                        child: RichText(
                          text: TextSpan(
                            text: 'Belum punya akun? ',
                            style: AppTypography.caption,
                            children: [
                              TextSpan(
                                text: 'Daftar sekarang',
                                style: AppTypography.caption.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
