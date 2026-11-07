import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/profile_state.dart';
import '../cubit/user_preferences_cubit.dart';
import '../cubit/user_preferences_state.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    context.read<ProfileCubit>().loadProfile();
    context.read<UserPreferencesCubit>().loadPreferences();
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.expenseRedBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    PhosphorIcons.signOut(),
                    color: AppColors.expenseRed,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Lah Mau Cabut Tod?',
                style: AppTypography.itemTitle.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                'Yakin mau logout? Nanti dompet lu ga ada yang jagain tolol!',
                textAlign: TextAlign.center,
                style: AppTypography.captionText.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(dialogCtx),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceFieldFill,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusPill,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Gajadi Dah',
                          style: AppTypography.captionText.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(dialogCtx);
                        context.read<AuthCubit>().signOut();
                      },
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.expenseRed,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusPill,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Bacot Tod',
                          style: AppTypography.captionText.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCoachBadgeLabel(int level) {
    switch (level) {
      case 1:
      case 2:
        return 'Suportif';
      case 3:
        return 'Profesional';
      case 4:
      case 5:
        return 'Mode Kritis';
      default:
        return 'Coach Disiplin';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, profileState) {
        String displayName = 'Teman FinGuard';
        String email = 'user@finguard.id';
        double income = 0;
        int strictness = 3;

        if (profileState is ProfileLoaded) {
          final p = profileState.profile;
          displayName = p.displayName.isNotEmpty
              ? p.displayName
              : 'Teman FinGuard';
          email = p.email.isNotEmpty ? p.email : 'user@finguard.id';
          income = p.monthlyIncome;
          strictness = p.strictnessLevel;
        } else if (profileState is ProfileUpdating) {
          final p = profileState.currentProfile;
          displayName = p.displayName.isNotEmpty
              ? p.displayName
              : 'Teman FinGuard';
          email = p.email.isNotEmpty ? p.email : 'user@finguard.id';
          income = p.monthlyIncome;
          strictness = p.strictnessLevel;
        }

        final initial = displayName.isNotEmpty
            ? displayName[0].toUpperCase()
            : 'F';

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(
            left: AppSpacing.screenHorizontalMargin,
            right: AppSpacing.screenHorizontalMargin,
            top: 14,
            bottom: 120,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profil', style: AppTypography.pageHeader),
              const SizedBox(height: 16),

              // Header Card: User Identity (Clean Bento Architecture, Zero Shadows)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(
                    AppSpacing.radiusSectionCard,
                  ),
                ),
                child: Column(
                  children: [
                    // Top Row: Avatar + User Info + Compact Edit Action Button
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: AppTypography.itemTitle.copyWith(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.captionText.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Sleek Compact Edit Button (Top Right Anchor)
                        GestureDetector(
                          onTap: () => context.push('/profile/edit'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceFieldFill,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusPill,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  PhosphorIcons.pencilSimple(),
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Edit',
                                  style: AppTypography.captionText.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Bottom Row: Meta Badges Strip
                    Row(
                      children: [
                        if (income > 0) ...[
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.incomeGreenBg,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusInnerElement,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    PhosphorIcons.wallet(
                                      PhosphorIconsStyle.fill,
                                    ),
                                    size: 14,
                                    color: AppColors.incomeGreen,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Gaji: ${CurrencyFormatter.format(income)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.captionText.copyWith(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.incomeGreen,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: strictness >= 4
                                  ? AppColors.expenseRedBg
                                  : AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusInnerElement,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  strictness >= 4
                                      ? PhosphorIcons.fire(
                                          PhosphorIconsStyle.fill,
                                        )
                                      : PhosphorIcons.sparkle(
                                          PhosphorIconsStyle.fill,
                                        ),
                                  size: 14,
                                  color: strictness >= 4
                                      ? AppColors.roastRed
                                      : AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _getCoachBadgeLabel(strictness),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.captionText.copyWith(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: strictness >= 4
                                          ? AppColors.roastRed
                                          : AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Group 1: Manajemen Finansial
              _buildSectionLabel('Manajemen Finansial'),
              const SizedBox(height: 8),
              _buildCardGroup([
                _buildRowItem(
                  icon: PhosphorIcons.sparkle(),
                  title: 'Atur Peta Keuangan',
                  subtitle:
                      'Simulasi pembagian gaji 50/30/20 & update batas belanja',
                  onTap: () => context.push('/blueprint'),
                ),
                _buildDivider(),
                _buildRowItem(
                  icon: PhosphorIcons.piggyBank(),
                  title: 'Target Tabungan (Celengan)',
                  subtitle: 'Pantau celengan dana darurat & tujuan impian',
                  onTap: () => context.push('/goals'),
                ),
              ]),

              const SizedBox(height: 20),

              // Group 2: Fitur & Analisis Cerdas
              _buildSectionLabel('Fitur & Analisis Cerdas'),
              const SizedBox(height: 8),
              _buildCardGroup([
                _buildRowItem(
                  icon: PhosphorIcons.chartLineUp(),
                  title: 'Cek & Analisa Saham',
                  subtitle: 'Analisis teknikal, bandarmologi & kapasitas saldo',
                  onTap: () => context.push('/stock-analysis'),
                ),
                _buildDivider(),
                _buildRowItem(
                  icon: PhosphorIcons.chartBar(),
                  title: 'Evaluasi Bulanan',
                  subtitle: 'Laporan surplus uang dingin & evaluasi berkala',
                  onTap: () => context.push('/review'),
                ),
                _buildDivider(),
                _buildRowItem(
                  icon: PhosphorIcons.calculator(),
                  title: 'Kalkulator Cuan & Cicilan',
                  subtitle: 'Simulasi dana darurat, nabung rutin & rasio utang',
                  onTap: () => context.push('/calculators'),
                ),
                _buildDivider(),
                _buildRowItem(
                  icon: PhosphorIcons.shoppingBag(),
                  title: 'Boleh Beli Gak?',
                  subtitle: 'Analisis kelayakan beli barang sebelum checkout',
                  onTap: () => context.push('/consultation'),
                ),
              ]),

              const SizedBox(height: 20),

              // Group 3: Preferensi & Notifikasi Langsung
              _buildSectionLabel('Preferensi & Pengaturan'),
              const SizedBox(height: 8),
              BlocBuilder<UserPreferencesCubit, UserPreferencesState>(
                builder: (context, prefState) {
                  bool notifEnabled = true;
                  bool alertEnabled = true;
                  bool stockEnabled = true;

                  if (prefState is UserPreferencesLoaded) {
                    notifEnabled = prefState.preferences.notificationsEnabled;
                    alertEnabled = prefState.preferences.budgetAlertsEnabled;
                    stockEnabled = prefState.preferences.stockSignalsEnabled;
                  }

                  return _buildCardGroup([
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                      ),
                      activeThumbColor: AppColors.primary,
                      title: Text(
                        'Notifikasi & Pengingat',
                        style: AppTypography.itemTitle.copyWith(fontSize: 14),
                      ),
                      subtitle: Text(
                        'Pengingat pencatatan transaksi & target',
                        style: AppTypography.captionText.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      value: notifEnabled,
                      onChanged: (val) {
                        context
                            .read<UserPreferencesCubit>()
                            .toggleNotifications(val);
                      },
                    ),
                    _buildDivider(),
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                      ),
                      activeThumbColor: AppColors.primary,
                      title: Text(
                        'Peringatan Limit Budget',
                        style: AppTypography.itemTitle.copyWith(fontSize: 14),
                      ),
                      subtitle: Text(
                        'Peringatan otomatis saat pengeluaran melampaui 85%',
                        style: AppTypography.captionText.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      value: alertEnabled,
                      onChanged: (val) {
                        context.read<UserPreferencesCubit>().toggleBudgetAlerts(
                          val,
                        );
                      },
                    ),
                    _buildDivider(),
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                      ),
                      activeThumbColor: AppColors.primary,
                      title: Text(
                        'Notifikasi Sinyal Saham',
                        style: AppTypography.itemTitle.copyWith(fontSize: 14),
                      ),
                      subtitle: Text(
                        'Radar sinyal teknikal BUY/SELL TradingView & rekomendasi AI Coach',
                        style: AppTypography.captionText.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      value: stockEnabled,
                      onChanged: (val) {
                        context.read<UserPreferencesCubit>().toggleStockSignals(
                          val,
                        );
                      },
                    ),
                  ]);
                },
              ),

              const SizedBox(height: 20),

              // Danger Card: Keluar
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(
                    AppSpacing.radiusBentoAndItem,
                  ),
                  boxShadow: AppSpacing.softShadow,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 4,
                  ),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.expenseRedBg,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        PhosphorIcons.signOut(),
                        color: AppColors.expenseRed,
                        size: 18,
                      ),
                    ),
                  ),
                  title: Text(
                    'Keluar dari Akun',
                    style: AppTypography.itemTitle.copyWith(
                      fontSize: 15,
                      color: AppColors.expenseRed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: Icon(
                    PhosphorIcons.caretRight(),
                    color: AppColors.expenseRed,
                    size: 18,
                  ),
                  onTap: () => _showSignOutDialog(context),
                ),
              ),

              const SizedBox(height: 32),

              // Clean Branding & Version Info (Created by johdev)
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceFieldFill,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusPill,
                        ),
                      ),
                      child: Text(
                        'FinGuard v1.0.0+1',
                        style: AppTypography.captionText.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPlaceholder,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Dibuat dengan ',
                          style: AppTypography.captionText.copyWith(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Icon(
                          PhosphorIcons.heart(PhosphorIconsStyle.fill),
                          size: 13,
                          color: AppColors.expenseRed,
                        ),
                        Text(
                          ' oleh ',
                          style: AppTypography.captionText.copyWith(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'johdev',
                          style: AppTypography.captionText.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '© 2026 FinGuard • All rights reserved',
                      style: AppTypography.captionText.copyWith(
                        fontSize: 10.5,
                        color: AppColors.textPlaceholder,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: AppTypography.captionText.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildCardGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusBentoAndItem),
        boxShadow: AppSpacing.softShadow,
      ),
      child: Column(children: children),
    );
  }

  Widget _buildRowItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: AppColors.surfaceFieldFill,
          shape: BoxShape.circle,
        ),
        child: Center(child: Icon(icon, color: AppColors.primary, size: 18)),
      ),
      title: Text(title, style: AppTypography.itemTitle.copyWith(fontSize: 14)),
      subtitle: Text(
        subtitle,
        style: AppTypography.captionText.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      trailing: Icon(
        PhosphorIcons.caretRight(),
        color: AppColors.textPlaceholder,
        size: 18,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 68,
      endIndent: 18,
      color: Colors.black.withValues(alpha: 0.05),
    );
  }
}
