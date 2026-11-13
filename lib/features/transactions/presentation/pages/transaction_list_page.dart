import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/formatters/date_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../cubit/transaction_cubit.dart';
import '../cubit/transaction_state.dart';

class _DateGroupedTransactions {
  final DateTime date;
  final List<TransactionEntity> transactions;
  final double totalIncome;
  final double totalExpense;

  _DateGroupedTransactions({
    required this.date,
    required this.transactions,
    required this.totalIncome,
    required this.totalExpense,
  });
}

class TransactionListPage extends StatefulWidget {
  const TransactionListPage({super.key});

  @override
  State<TransactionListPage> createState() => _TransactionListPageState();
}

class _TransactionListPageState extends State<TransactionListPage> {
  String _filter = 'all'; // all, income, expense
  String _searchQuery = '';
  String? _selectedCategoryFilter;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 15;
  int _displayedLimit = _pageSize;
  bool _isLoadingMore = false;
  int _totalItemsCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    context.read<TransactionCubit>().loadTransactions();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 200) {
      if (!_isLoadingMore && _displayedLimit < _totalItemsCount) {
        setState(() {
          _isLoadingMore = true;
        });
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted) {
            setState(() {
              _displayedLimit += _pageSize;
              _isLoadingMore = false;
            });
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onFilterChanged(String value) {
    setState(() {
      _filter = value;
      _displayedLimit = _pageSize;
    });
    TransactionType? type;
    if (value == 'income') type = TransactionType.income;
    if (value == 'expense') type = TransactionType.expense;
    context.read<TransactionCubit>().loadTransactions(filterType: type);
  }

  void _showFilterSheet(BuildContext context) {
    String tempType = _filter;
    String? tempCategory = _selectedCategoryFilter;
    const categories = [
      'Makan & Minum',
      'Transportasi',
      'Hiburan',
      'Belanja Harian',
      'Tagihan & Utilitas',
      'Gaji & Upah',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding:
              const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 32),
          decoration: const BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Filter Transaksi',
                style: AppTypography.screenTitle.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 16),
              Text(
                'Jenis',
                style: AppTypography.sectionLabel.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildModalChip(
                    label: 'Semua',
                    selected: tempType == 'all',
                    onTap: () => setModalState(() => tempType = 'all'),
                  ),
                  _buildModalChip(
                    label: 'Pengeluaran',
                    selected: tempType == 'expense',
                    onTap: () => setModalState(() => tempType = 'expense'),
                  ),
                  _buildModalChip(
                    label: 'Pemasukan',
                    selected: tempType == 'income',
                    onTap: () => setModalState(() => tempType = 'income'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Kategori',
                style: AppTypography.sectionLabel.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildModalChip(
                    label: 'Semua kategori',
                    selected: tempCategory == null,
                    onTap: () => setModalState(() => tempCategory = null),
                  ),
                  ...categories.map(
                    (cat) => _buildModalChip(
                      label: cat,
                      selected: tempCategory == cat,
                      onTap: () => setModalState(() => tempCategory = cat),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Reset',
                      variant: AppButtonVariant.secondary,
                      onPressed: () {
                        setState(() {
                          _selectedCategoryFilter = null;
                        });
                        _onFilterChanged('all');
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: 'Terapkan',
                      onPressed: () {
                        setState(() {
                          _selectedCategoryFilter = tempCategory;
                        });
                        _onFilterChanged(tempType);
                        Navigator.pop(ctx);
                      },
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

  Widget _buildModalChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceFieldFill,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  void _showTransactionDetailSheet(
    BuildContext context,
    TransactionEntity tx,
  ) {
    final isIncome = tx.transactionType == TransactionType.income;
    final catName = tx.category?.name ?? 'Umum';
    final rawTitle = tx.note?.isNotEmpty == true ? tx.note! : catName;
    final title = rawTitle.startsWith('Pemasukan Bulanan Awal') ? 'Gaji Bulanan' : rawTitle;
    final isFromCoach = tx.source == TransactionSource.chat;
    final sourceLabel = isFromCoach ? 'AI Coach (Konsultasi Chat)' : 'Manual';
    final accountName = tx.account?.name ?? 'Kas Utama';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding:
            const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 32),
        decoration: const BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Detail Transaksi',
                  style: AppTypography.screenTitle.copyWith(fontSize: 20),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isIncome ? AppColors.successTint : AppColors.surfaceFieldFill,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    isIncome ? 'Pemasukan' : 'Pengeluaran',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isIncome ? AppColors.success : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              CurrencyFormatter.formatSigned(tx.amount, isIncome: isIncome),
              style: AppTypography.bigNumber.copyWith(
                fontSize: 32,
                color: isIncome ? AppColors.success : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceFieldFill,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Kategori', catName),
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    'Tanggal Transaksi',
                    DateFormatter.formatFullDate(tx.transactionDate),
                  ),
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    'Waktu Pencatatan',
                    DateFormatter.formatTimeWithZone(tx.createdAt),
                  ),
                  const SizedBox(height: 10),
                  _buildDetailRow('Akun Kas', accountName),
                  const SizedBox(height: 10),
                  _buildDetailRow('Sumber Input', sourceLabel),
                  if (tx.note != null && tx.note!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildDetailRow('Catatan', title),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConfirmationDialog(context, tx);
              },
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.dangerTint,
                  borderRadius: BorderRadius.circular(100),
                ),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Hapus Transaksi',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.caption),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTypography.sectionLabel.copyWith(fontSize: 13),
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirmationDialog(
    BuildContext context,
    TransactionEntity tx,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.dangerTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                  size: 24,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Hapus Transaksi?',
                style: AppTypography.screenTitle.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                'Catatan ini akan dihapus permanen dari riwayat transaksi.',
                textAlign: TextAlign.center,
                style: AppTypography.caption,
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
                          borderRadius: BorderRadius.circular(100),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Batal',
                          style: TextStyle(
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
                        context
                            .read<TransactionCubit>()
                            .deleteTransaction(tx.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Transaksi berhasil dihapus.',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            backgroundColor: AppColors.danger,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Hapus',
                          style: TextStyle(
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

  IconData _getCategoryIcon(String? iconKey, String? categoryName, bool isIncome) {
    final key = (iconKey ?? '').toLowerCase();
    switch (key) {
      case 'utensils':
      case 'food':
        return PhosphorIcons.forkKnife();
      case 'car':
      case 'transport':
        return PhosphorIcons.car();
      case 'receipt':
      case 'bill':
        return PhosphorIcons.receipt();
      case 'shopping-cart':
      case 'shopping':
        return PhosphorIcons.shoppingCart();
      case 'heart-pulse':
      case 'health':
        return PhosphorIcons.heartbeat();
      case 'ticket':
      case 'entertainment':
        return PhosphorIcons.ticket();
      case 'coffee':
        return PhosphorIcons.coffee();
      case 'wallet':
        return PhosphorIcons.wallet();
      case 'gift':
        return PhosphorIcons.gift();
      case 'store':
        return PhosphorIcons.storefront();
      case 'trending-up':
        return PhosphorIcons.trendUp();
    }

    final cat = (categoryName ?? '').toLowerCase();
    if (cat.contains('makan') || cat.contains('minum') || cat.contains('food')) {
      return PhosphorIcons.forkKnife();
    }
    if (cat.contains('transpor') || cat.contains('bensin') || cat.contains('ojol')) {
      return PhosphorIcons.car();
    }
    if (cat.contains('tagihan') || cat.contains('listrik') || cat.contains('air') || cat.contains('pulsa')) {
      return PhosphorIcons.receipt();
    }
    if (cat.contains('belanja') || cat.contains('mart') || cat.contains('pasar')) {
      return PhosphorIcons.shoppingCart();
    }
    if (cat.contains('sehat') || cat.contains('obat') || cat.contains('dokter')) {
      return PhosphorIcons.heartbeat();
    }
    if (cat.contains('hiburan') || cat.contains('nonton') || cat.contains('game')) {
      return PhosphorIcons.ticket();
    }
    if (cat.contains('gaji') || cat.contains('upah') || cat.contains('salary')) {
      return PhosphorIcons.wallet();
    }
    if (cat.contains('bonus') || cat.contains('thr') || cat.contains('hadiah')) {
      return PhosphorIcons.gift();
    }

    return isIncome ? PhosphorIcons.arrowDownLeft() : PhosphorIcons.arrowUpRight();
  }

  List<_DateGroupedTransactions> _groupByDate(List<TransactionEntity> list) {
    final Map<String, List<TransactionEntity>> map = {};
    for (final tx in list) {
      final d = tx.transactionDate.toLocal();
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(tx);
    }

    final groups = <_DateGroupedTransactions>[];
    for (final entry in map.entries) {
      final txs = entry.value;
      double inc = 0;
      double exp = 0;
      for (final t in txs) {
        if (t.transactionType == TransactionType.income) {
          inc += t.amount;
        } else {
          exp += t.amount;
        }
      }
      // Sort inside group: newest recording time on top
      txs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      groups.add(
        _DateGroupedTransactions(
          date: txs.first.transactionDate,
          transactions: txs,
          totalIncome: inc,
          totalExpense: exp,
        ),
      );
    }

    // Sort groups: newest date on top
    groups.sort((a, b) => b.date.compareTo(a.date));
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.screenBackground,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Standardized Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Catatan Transaksi',
                      style: AppTypography.pageHeader,
                    ),
                    AppIconButton(
                      icon: Icons.tune_rounded,
                      onPressed: () => _showFilterSheet(context),
                    ),
                  ],
                ),
              ),

              // Search Pill Input
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: AppSpacing.softShadow,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() {
                      _searchQuery = val.trim().toLowerCase();
                      _displayedLimit = _pageSize;
                    }),
                    style: AppTypography.body,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _displayedLimit = _pageSize;
                                });
                              },
                            )
                          : null,
                      hintText: 'Cari transaksi',
                      hintStyle: AppTypography.bodySecondary,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),

              // Filter Chips
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Semua', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pengeluaran', 'expense'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pemasukan', 'income'),
                      if (_selectedCategoryFilter != null) ...[
                        const SizedBox(width: 8),
                        ActionChip(
                          label: Text(_selectedCategoryFilter!),
                          onPressed: () =>
                              setState(() => _selectedCategoryFilter = null),
                          backgroundColor: AppColors.primary,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100)),
                          labelStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 4),

              // Transaction List Grouped by Date
              Expanded(
                child: BlocBuilder<TransactionCubit, TransactionState>(
                  builder: (context, state) {
                    if (state is TransactionLoading) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primaryDark),
                      );
                    }

                    if (state is TransactionError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: AppColors.danger, size: 48),
                              const SizedBox(height: 12),
                              Text(state.message, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              AppButton(
                                label: 'Coba lagi',
                                onPressed: () => context
                                    .read<TransactionCubit>()
                                    .loadTransactions(),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (state is TransactionLoaded) {
                      final items = state.transactions.where((tx) {
                        final catName = (tx.category?.name ?? 'Umum');
                        final note = (tx.note ?? '');
                        final matchesSearch = _searchQuery.isEmpty ||
                            catName.toLowerCase().contains(_searchQuery) ||
                            note.toLowerCase().contains(_searchQuery);
                        final matchesCat = _selectedCategoryFilter == null ||
                            catName.toLowerCase() ==
                                _selectedCategoryFilter!.toLowerCase() ||
                            note
                                .toLowerCase()
                                .contains(_selectedCategoryFilter!.toLowerCase());
                        return matchesSearch && matchesCat;
                      }).toList();

                      if (items.isEmpty) {
                        return Center(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 32,
                              ),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 32,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceCard,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.cardRadius,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primaryLight,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Icon(
                                          PhosphorIcons.receipt(),
                                          color: AppColors.primary,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'Belum Ada Transaksi',
                                      style: AppTypography.itemTitle.copyWith(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Ketuk tombol + di pojok kanan atas atau langsung curhat pengeluaranmu ke AI Coach!',
                                      style: AppTypography.captionText.copyWith(
                                        color: AppColors.textSecondary,
                                        height: 1.4,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      _totalItemsCount = items.length;
                      final displayedItems =
                          items.take(_displayedLimit).toList();
                      final groups = _groupByDate(displayedItems);
                      final bool hasMore = _displayedLimit < items.length;

                      return RefreshIndicator(
                        onRefresh: () async {
                          setState(() {
                            _displayedLimit = _pageSize;
                          });
                          TransactionType? type;
                          if (_filter == 'income') type = TransactionType.income;
                          if (_filter == 'expense') {
                            type = TransactionType.expense;
                          }
                          await context
                              .read<TransactionCubit>()
                              .loadTransactions(filterType: type);
                        },
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          itemCount: groups.length +
                              (items.length > _pageSize ? 1 : 0),
                          itemBuilder: (context, groupIndex) {
                            if (groupIndex == groups.length) {
                              if (hasMore) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 20),
                                  child: Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Memuat transaksi berikutnya...',
                                          style: AppTypography.caption.copyWith(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              } else {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 20),
                                  child: Center(
                                    child: Text(
                                      'Semua ${items.length} transaksi telah ditampilkan',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                );
                              }
                            }
                            final group = groups[groupIndex];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Date Header with daily subtotals
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: groupIndex == 0 ? 4 : 16,
                                    bottom: 10,
                                    left: 4,
                                    right: 4,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        DateFormatter.formatTransactionDateHeader(
                                          group.date,
                                        ),
                                        style: AppTypography.sectionLabel
                                            .copyWith(
                                          fontSize: 13,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (group.totalExpense > 0 || group.totalIncome > 0)
                                        Text(
                                          group.totalExpense > 0 && group.totalIncome > 0
                                              ? '+${CurrencyFormatter.format(group.totalIncome)} · -${CurrencyFormatter.format(group.totalExpense)}'
                                              : group.totalIncome > 0
                                                  ? '+${CurrencyFormatter.format(group.totalIncome)}'
                                                  : '-${CurrencyFormatter.format(group.totalExpense)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: group.totalIncome > 0 && group.totalExpense == 0
                                                ? AppColors.success
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // Transaction items in this date group
                                ...group.transactions.map((tx) {
                                  final isIncome = tx.transactionType ==
                                      TransactionType.income;
                                  final catName =
                                      tx.category?.name ?? 'Umum';
                                  final iconKey = tx.category?.iconKey;
                                  final rawTitle = tx.note?.isNotEmpty == true
                                      ? tx.note!
                                      : catName;
                                  final title = rawTitle.startsWith(
                                          'Pemasukan Bulanan Awal')
                                      ? 'Gaji Bulanan'
                                      : rawTitle;
                                  final isFromCoach =
                                      tx.source == TransactionSource.chat;
                                  final timeString =
                                      DateFormatter.formatTime(tx.createdAt);

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: GestureDetector(
                                      onTap: () =>
                                          _showTransactionDetailSheet(
                                              context, tx),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 14),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceCard,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          boxShadow: AppSpacing.softShadow,
                                        ),
                                        child: Row(
                                          children: [
                                            // Category Icon Container
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: isIncome
                                                    ? AppColors.successTint
                                                    : AppColors.primary
                                                        .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: Icon(
                                                _getCategoryIcon(
                                                    iconKey, catName, isIncome),
                                                color: isIncome
                                                    ? AppColors.success
                                                    : AppColors.primary,
                                                size: 22,
                                              ),
                                            ),
                                            const SizedBox(width: 14),

                                            // Note & Metadata (Category + Time + Coach Pill)
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    title,
                                                    style: AppTypography
                                                        .sectionLabel
                                                        .copyWith(fontSize: 14.5),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Row(
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          '$catName · $timeString',
                                                          style: AppTypography
                                                              .caption
                                                              .copyWith(
                                                                  fontSize: 12),
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                        ),
                                                      ),
                                                      if (isFromCoach) ...[
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: AppColors
                                                                .primary
                                                                .withValues(
                                                                    alpha: 0.1),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        6),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Icon(
                                                                PhosphorIcons
                                                                    .sparkle(
                                                                  PhosphorIconsStyle
                                                                      .fill,
                                                                ),
                                                                size: 10,
                                                                color: AppColors
                                                                    .primary,
                                                              ),
                                                              const SizedBox(
                                                                  width: 3),
                                                              const Text(
                                                                'AI Coach',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 9.5,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: AppColors
                                                                      .primary,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Signed Amount
                                            Text(
                                              CurrencyFormatter.formatSigned(
                                                tx.amount,
                                                isIncome: isIncome,
                                              ),
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w700,
                                                color: isIncome
                                                    ? AppColors.success
                                                    : AppColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return ChoiceChip(
      showCheckmark: false,
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceCard,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
      onSelected: (_) => _onFilterChanged(value),
    );
  }
}
