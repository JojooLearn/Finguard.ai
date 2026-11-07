import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';

class WalkthroughPage extends StatefulWidget {
  const WalkthroughPage({super.key});

  @override
  State<WalkthroughPage> createState() => _WalkthroughPageState();
}

class _WalkthroughPageState extends State<WalkthroughPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<WalkthroughSlideData> _slides = const [
    WalkthroughSlideData(
      imagePath: 'assets/images/walkthrough_chat_coach.png',
      badge: 'AI Coach Tongkrongan',
      heading: 'Ngobrol Santai Sama AI Coach',
      description:
          'Catat pengeluaran, cek uang dingin, sampai di-roast karena boros, semuanya tinggal chat aja kayak di tongkrongan! Bebas ribet, 100% akurat.',
    ),
    WalkthroughSlideData(
      imagePath: 'assets/images/walkthrough_smart_blueprint.png',
      badge: 'Alokasi Cerdas 50/30/20',
      heading: 'Jatah Belanja Otomatis Beres',
      description:
          'Nggak usah pusing ngatur duit secara manual. Cukup masukin gajimu, dan sistem kita bakal nyusun peta keuangan 50/30/20 buatmu dalam hitungan detik.',
    ),
    WalkthroughSlideData(
      imagePath: 'assets/images/walkthrough_shopping_consultation.png',
      badge: 'Boleh Beli Gak?',
      heading: 'Anti Boncos Sebelum Belanja',
      description:
          'Lapar mata pengen beli barang mahal? Tanya "Boleh Beli Gak?" ke Coach biar dihitungin kelayakannya. Kalo bahaya, siap-siap disuruh ngerem!',
    ),
  ];

  Future<void> _completeWalkthrough() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_walkthrough', true);
    if (!mounted) return;
    context.go('/login');
  }

  void _onNextPressed() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeWalkthrough();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgGradientBottom,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.screenBackground,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar: Logo & Skip Button
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sideMargin,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/icons/app_logo.png',
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'FinGuard',
                          style: AppTypography.screenTitle.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    if (_currentPage < _slides.length - 1)
                      TextButton(
                        onPressed: _completeWalkthrough,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          textStyle: const TextStyle(
                            fontFamily: 'Urbanist',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Lewati'),
                      )
                    else
                      const SizedBox(width: 60),
                  ],
                ),
              ),

              // PageView Content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    final item = _slides[index];
                    return Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sideMargin,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Visual Illustration
                              Container(
                                constraints: const BoxConstraints(
                                  maxHeight: 240,
                                  maxWidth: 280,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.12),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Image.asset(
                                    item.imagePath,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              // Feature Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  item.badge,
                                  style: const TextStyle(
                                    fontFamily: 'Urbanist',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              // Heading
                              Text(
                                item.heading,
                                style: AppTypography.pageHeader.copyWith(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              // Description
                              Text(
                                item.description,
                                style: AppTypography.bodyText.copyWith(
                                  fontSize: 13.5,
                                  height: 1.45,
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom Area: Indicators & Navigation Action
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sideMargin),
                child: Column(
                  children: [
                    // Smooth Animated Dot Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _slides.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? AppColors.primaryDark
                                : AppColors.surfaceFieldFill,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Next / Get Started Button
                    _currentPage == _slides.length - 1
                        ? AppButton(
                            label: 'Mulai Sekarang',
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            onPressed: _completeWalkthrough,
                          )
                        : Row(
                            children: [
                              if (_currentPage > 0) ...[
                                Expanded(
                                  flex: 1,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      _pageController.previousPage(
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      side: const BorderSide(
                                        color: AppColors.surfaceFieldFill,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: const Text(
                                      'Kembali',
                                      style: TextStyle(
                                        fontFamily: 'Urbanist',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                flex: 2,
                                child: AppButton(
                                  label: 'Lanjut',
                                  icon: const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  onPressed: _onNextPressed,
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WalkthroughSlideData {
  final String imagePath;
  final String badge;
  final String heading;
  final String description;

  const WalkthroughSlideData({
    required this.imagePath,
    required this.badge,
    required this.heading,
    required this.description,
  });
}
