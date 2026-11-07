import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/floating_nav_bar.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../budgets/presentation/pages/budget_page.dart';
import '../../../coach/presentation/pages/coach_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../transactions/presentation/pages/transaction_list_page.dart';
import 'home_page.dart';

class MainScaffold extends StatefulWidget {
  final int initialIndex;

  const MainScaffold({super.key, this.initialIndex = 0});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    final pages = [
      HomePage(
        onSwitchTab: _switchTab,
      ),
      const TransactionListPage(),
      CoachPage(isKeyboardOpen: isKeyboardOpen),
      const BudgetPage(),
      const ProfilePage(),
    ];

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is Unauthenticated) {
          context.go('/login');
        }
      },
      child: Scaffold(
        extendBody: true,
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.screenBackground,
          ),
          child: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _currentIndex,
              children: pages,
            ),
          ),
        ),
        bottomNavigationBar: isKeyboardOpen
            ? const SizedBox.shrink()
            : FloatingNavBar(
                currentIndex: _currentIndex,
                onTap: (index) {
                  setState(() => _currentIndex = index);
                },
              ),
      ),
    );
  }
}
