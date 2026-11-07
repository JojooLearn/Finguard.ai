import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:email_validator/email_validator.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _register() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthCubit>().signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _nameController.text.trim(),
    );
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nama jangan kosong, kocak!';
    }
    return null;
  }

  static const Set<String> _disposableDomains = {
    'mailinator.com',
    'tempmail.com',
    'temp-mail.org',
    '10minutemail.com',
    'guerrillamail.com',
    'guerrillamail.net',
    'guerrillamail.org',
    'yopmail.com',
    'sharklasers.com',
    'throwawaymail.com',
    'getairmail.com',
    'dispostable.com',
    'mohmal.com',
    'burnermail.io',
    'fakeinbox.com',
    'trashmail.com',
    'trashmail.net',
    'crazymailing.com',
    'tempail.com',
    'fakemailgenerator.com',
    'generator.email',
    'inboxkitten.com',
    'nada.ltd',
    'getnada.com',
    'maildrop.cc',
    'harakirimail.com',
    'trashmail.me',
    'tempinbox.com',
    'mytemp.email',
    'dropmail.me',
    'emailondeck.com',
    'minuteinbox.com',
  };

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email wajib diisi lah!';
    final email = value.trim();

    // 1. Validasi sintaks RFC 5322 via package email_validator
    if (!EmailValidator.validate(email)) {
      return 'Buta matamu!, format emailmu tidak valid/tidak lengkap!';
    }

    // 2. Validasi struktur domain & TLD
    final atIndex = email.lastIndexOf('@');
    if (atIndex <= 0 || atIndex >= email.length - 1) {
      return 'Anjing Nipu! Format emailmu tidak valid!';
    }

    final localPart = email.substring(0, atIndex);
    final domain = email.substring(atIndex + 1).toLowerCase();

    if (localPart.length < 2) {
      return 'Username email terlalu pendek! Dasar goblok!';
    }

    final dotIndex = domain.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex >= domain.length - 2) {
      return 'Domain email tidak valid! Mau nipu tod?';
    }

    final tld = domain.substring(dotIndex + 1);
    if (!RegExp(r'^[a-zA-Z]{2,}$').hasMatch(tld)) {
      return 'Akhiran domain email (.com, .id, dll) tidak valid! Dasar gaptek!';
    }

    // 3. Blokir bot dan email sementara / disposable
    if (_disposableDomains.contains(domain)) {
      return 'Anjing Email palsu ya? Gunakan email asli ya tod.';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Kata sandi jangan kosong!';
    if (value.length < 8) return 'Tolol, kependekan! Minimal 8 karakter.';
    return null;
  }

  String _formatRegisterError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('already registered') ||
        lower.contains('user already exists')) {
      return 'Email ini udah terdaftar, njir! Langsung login aja.';
    }
    if (lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('connection')) {
      return 'Sinyal lu bapuk banget, cek koneksi dulu!';
    }
    return 'Gagal daftar boss! Cek kelengkapan data lu lagi.';
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
                _formatRegisterError(state.message),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              backgroundColor: Colors.red.shade700,
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppIconButton(
                          icon: Icons.arrow_back_rounded,
                          onPressed: () => Navigator.pop(context),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/icons/app_logo.png',
                            width: 38,
                            height: 38,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('Daftar', style: AppTypography.screenTitle),
                    const SizedBox(height: 4),
                    Text(
                      'Mulai kebiasaan finansial yang sehat',
                      style: AppTypography.caption,
                    ),
                    const SizedBox(height: 28),

                    AppTextField(
                      label: 'Nama Lengkap',
                      hint: 'Anna Sulistyo',
                      controller: _nameController,
                      validator: _validateName,
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      label: 'Email',
                      hint: 'anna@example.com',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      helperText:
                          'Gunakan email aktif bossku, untuk verifikasi akun',
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      label: 'Kata sandi',
                      hint: '••••••••',
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      helperText: 'Minimal 8 karakter Boss',
                      validator: _validatePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.primaryDark,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    BlocBuilder<AuthCubit, AuthState>(
                      builder: (context, state) {
                        return AppButton(
                          label: 'Daftar',
                          isLoading: state is AuthLoading,
                          onPressed: _register,
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: RichText(
                          text: TextSpan(
                            text: 'Lah, sudah punya akun? ',
                            style: AppTypography.caption,
                            children: [
                              TextSpan(
                                text: 'Masuk',
                                style: AppTypography.caption.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
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
