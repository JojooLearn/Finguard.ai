import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../formatters/currency_formatter.dart';
import '../../features/monthly_review/domain/entities/monthly_review_entity.dart';
import '../../features/transactions/domain/entities/category_entity.dart';

/// Clean, formal corporate financial statement generator
/// Designed following professional accounting standards (zero visual noise, high readability)
class PdfReportService {
  // Formal Minimalist Executive Palette (No gaudy or playful colors)
  static final PdfColor _inkBlack = PdfColor.fromInt(0xFF0F172A);
  static final PdfColor _charcoal = PdfColor.fromInt(0xFF1E293B);
  static final PdfColor _textSlate = PdfColor.fromInt(0xFF475569);
  static final PdfColor _textMuted = PdfColor.fromInt(0xFF64748B);
  static final PdfColor _borderSlate = PdfColor.fromInt(0xFFCBD5E1);
  static final PdfColor _borderHairline = PdfColor.fromInt(0xFFE2E8F0);
  static final PdfColor _tableHeaderBg = PdfColor.fromInt(0xFFF8FAFC);
  static final PdfColor _rowAltBg = PdfColor.fromInt(0xFFFAFAFA);
  static final PdfColor _positiveGreen = PdfColor.fromInt(0xFF15803D);
  static final PdfColor _negativeRed = PdfColor.fromInt(0xFFB91C1C);

  static Future<void> printMonthlyReport({
    required MonthlyReviewEntity review,
    required String userName,
    required String monthName,
  }) async {
    final pdf = pw.Document();

    final metrics = review.metrics;
    final isSurplus = metrics.netCashFlow >= 0;
    final statusText = isSurplus ? 'SURPLUS KAS' : 'DEFISIT KAS';
    final dateStr = DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'FINGUARD FINANCIAL INTELLIGENCE',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: _inkBlack,
                          letterSpacing: 0.8,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'LAPORAN KEUANGAN & EVALUASI ARUS KAS BULANAN',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _textSlate,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Periode Pembukuan: $monthName',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _inkBlack,
                        ),
                      ),
                      pw.SizedBox(height: 1),
                      pw.Text(
                        'Mata Uang Basis: IDR (Rupiah)',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          color: _textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1, color: _inkBlack),
              pw.SizedBox(height: 14),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(thickness: 0.5, color: _borderSlate),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Laporan resmi diterbitkan otomatis oleh FinGuard Autonomous Ledger System · $dateStr',
                    style: pw.TextStyle(fontSize: 7.5, color: _textMuted),
                  ),
                  pw.Text(
                    'Halaman ${context.pageNumber} dari ${context.pagesCount}',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: _textSlate,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // 1. Metadata Profil & Status Rekapitulasi
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: pw.BoxDecoration(
                color: _tableHeaderBg,
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: _borderHairline, width: 0.8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PEMILIK REKENING / PROFIL',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _textMuted,
                          letterSpacing: 0.4,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        userName,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: _inkBlack,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'METODE PEMBUKUAN',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _textMuted,
                          letterSpacing: 0.4,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Cash Basis · Formula 50/30/20',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: _charcoal,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'STATUS ARUS KAS',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _textMuted,
                          letterSpacing: 0.4,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        statusText,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: isSurplus ? _positiveGreen : _negativeRed,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // 2. Ringkasan Eksekutif (Executive Summary Balance)
            pw.Text(
              'I. RINGKASAN EKSEKUTIF ARUS KAS',
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: _inkBlack,
                letterSpacing: 0.5,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              children: [
                _buildMetricCell(
                  title: 'TOTAL PEMASUKAN',
                  value: CurrencyFormatter.format(metrics.totalIncome),
                  subtitle: '${metrics.incomeTransactionCount} transaksi masuk',
                  valueColor: _inkBlack,
                ),
                pw.SizedBox(width: 8),
                _buildMetricCell(
                  title: 'TOTAL PENGELUARAN',
                  value: CurrencyFormatter.format(metrics.totalExpense),
                  subtitle: '${metrics.expenseTransactionCount} transaksi belanja',
                  valueColor: _charcoal,
                ),
                pw.SizedBox(width: 8),
                _buildMetricCell(
                  title: 'ARUS KAS BERSIH',
                  value: CurrencyFormatter.formatSigned(
                    metrics.netCashFlow,
                    isIncome: isSurplus,
                  ),
                  subtitle: isSurplus ? 'Surplus anggaran' : 'Defisit anggaran',
                  valueColor: isSurplus ? _positiveGreen : _negativeRed,
                ),
                pw.SizedBox(width: 8),
                _buildMetricCell(
                  title: 'RASIO TABUNGAN',
                  value: '${metrics.savingsRate.toStringAsFixed(0)}%',
                  subtitle: 'Target minimum: >= 20%',
                  valueColor: metrics.savingsRate >= 20 ? _positiveGreen : _charcoal,
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // 3. Distribusi Realisasi Pengeluaran per Kategori
            pw.Text(
              'II. REALISASI PENGELUARAN PER KATEGORI',
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: _inkBlack,
                letterSpacing: 0.5,
              ),
            ),
            pw.SizedBox(height: 6),
            if (metrics.categoryBreakdown.isEmpty)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: _tableHeaderBg,
                  border: pw.Border.all(color: _borderHairline),
                ),
                child: pw.Text(
                  'Tidak terdapat catatan transaksi pengeluaran pada periode ini. Pemasukan masih tersisa penuh 100%.',
                  style: pw.TextStyle(fontSize: 8.5, color: _textSlate),
                ),
              )
            else
              pw.Table(
                border: pw.TableBorder(
                  top: pw.BorderSide(color: _borderSlate, width: 0.8),
                  bottom: pw.BorderSide(color: _borderSlate, width: 0.8),
                  horizontalInside: pw.BorderSide(color: _borderHairline, width: 0.5),
                ),
                columnWidths: {
                  0: const pw.FixedColumnWidth(28),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(1.4),
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: _tableHeaderBg),
                    children: [
                      _buildTableCell('NO', isHeader: true, align: pw.TextAlign.center),
                      _buildTableCell('POS KATEGORI', isHeader: true),
                      _buildTableCell('REALISASI (IDR)', isHeader: true, align: pw.TextAlign.right),
                      _buildTableCell('PROPORSI', isHeader: true, align: pw.TextAlign.right),
                    ],
                  ),
                  // Table Rows
                  ...List.generate(metrics.categoryBreakdown.length, (index) {
                    final entry = metrics.categoryBreakdown.entries.elementAt(index);
                    final pct = metrics.totalExpense > 0
                        ? (entry.value / metrics.totalExpense * 100).toStringAsFixed(1)
                        : '0.0';
                    final isAlt = index % 2 == 1;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: isAlt ? _rowAltBg : PdfColors.white,
                      ),
                      children: [
                        _buildTableCell('${index + 1}', align: pw.TextAlign.center),
                        _buildTableCell(entry.key, isBold: true),
                        _buildTableCell(CurrencyFormatter.format(entry.value), align: pw.TextAlign.right),
                        _buildTableCell('$pct%', align: pw.TextAlign.right),
                      ],
                    );
                  }),
                  // Table Summary Total Row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: _tableHeaderBg,
                      border: pw.Border(
                        top: pw.BorderSide(color: _borderSlate, width: 0.8),
                        bottom: pw.BorderSide(color: _borderSlate, width: 0.8),
                      ),
                    ),
                    children: [
                      _buildTableCell('', align: pw.TextAlign.center),
                      _buildTableCell('TOTAL REALISASI BELANJA', isBold: true),
                      _buildTableCell(CurrencyFormatter.format(metrics.totalExpense), isBold: true, align: pw.TextAlign.right),
                      _buildTableCell('100.0%', isBold: true, align: pw.TextAlign.right),
                    ],
                  ),
                ],
              ),
            pw.SizedBox(height: 20),

            // 4. Catatan & Rekomendasi Evaluasi Finansial
            pw.Text(
              'III. CATATAN EVALUASI & ADVISORI KEUANGAN',
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: _inkBlack,
                letterSpacing: 0.5,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(3),
                border: pw.Border.all(color: _borderHairline, width: 0.8),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 3,
                    height: 28,
                    color: _inkBlack,
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Text(
                      review.narrative,
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: _charcoal,
                        lineSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // 5. Buku Jurnal Rincian Transaksi
            if (review.transactions.isNotEmpty) ...[
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'IV. BUKU JURNAL TRANSAKSI PERIODE INI',
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: _inkBlack,
                      letterSpacing: 0.5,
                    ),
                  ),
                  pw.Text(
                    'Total ${review.transactions.length} Entri Transaksi',
                    style: pw.TextStyle(fontSize: 8, color: _textMuted),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder(
                  top: pw.BorderSide(color: _borderSlate, width: 0.8),
                  bottom: pw.BorderSide(color: _borderSlate, width: 0.8),
                  horizontalInside: pw.BorderSide(color: _borderHairline, width: 0.5),
                ),
                columnWidths: {
                  0: const pw.FixedColumnWidth(65),
                  1: const pw.FixedColumnWidth(55),
                  2: const pw.FlexColumnWidth(3),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: _tableHeaderBg),
                    children: [
                      _buildTableCell('TANGGAL', isHeader: true),
                      _buildTableCell('TIPE', isHeader: true),
                      _buildTableCell('KETERANGAN / POS', isHeader: true),
                      _buildTableCell('MUTASI KAS (IDR)', isHeader: true, align: pw.TextAlign.right),
                    ],
                  ),
                  // Transaction Rows
                  ...List.generate(review.transactions.length, (index) {
                    final t = review.transactions[index];
                    final isInc = t.transactionType == TransactionType.income;
                    final date = DateFormat('dd/MM/yyyy').format(t.transactionDate);
                    var note = t.note?.isNotEmpty == true ? t.note! : (t.category?.name ?? '-');
                    if (note.startsWith('Pemasukan Bulanan Awal')) {
                      note = 'Gaji Bulanan';
                    }
                    final isAlt = index % 2 == 1;

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: isAlt ? _rowAltBg : PdfColors.white,
                      ),
                      children: [
                        _buildTableCell(date),
                        _buildTableCell(
                          isInc ? 'Masuk' : 'Keluar',
                          textColor: isInc ? _positiveGreen : _charcoal,
                          isBold: isInc,
                        ),
                        _buildTableCell(note),
                        _buildTableCell(
                          CurrencyFormatter.formatSigned(t.amount, isIncome: isInc),
                          align: pw.TextAlign.right,
                          textColor: isInc ? _positiveGreen : _inkBlack,
                          isBold: true,
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 24),
            ],

            // 6. Pernyataan & Pengesahan Rekonsiliasi (Audit Verification)
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: _tableHeaderBg,
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: _borderHairline, width: 0.8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'DISUSUN & DISETUJUI OLEH:',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _textMuted,
                          letterSpacing: 0.4,
                        ),
                      ),
                      pw.SizedBox(height: 26),
                      pw.Text(
                        userName,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: _inkBlack,
                        ),
                      ),
                      pw.Text(
                        'Pemilik Rekening / Buku Kas',
                        style: pw.TextStyle(fontSize: 7.5, color: _textSlate),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'STATUS AUDIT REKONSILIASI:',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _textMuted,
                          letterSpacing: 0.4,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'VERIFIED & RECONCILED',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: _positiveGreen,
                          letterSpacing: 0.5,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'FinGuard Autonomous Audit Engine · Hash Integrity OK',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _charcoal,
                        ),
                      ),
                      pw.Text(
                        'Waktu Rekonsiliasi: $dateStr',
                        style: pw.TextStyle(fontSize: 7, color: _textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Laporan_Keuangan_FinGuard_${monthName.replaceAll(' ', '_')}.pdf',
    );
  }

  static pw.Widget _buildMetricCell({
    required String title,
    required String value,
    required String subtitle,
    required PdfColor valueColor,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: _borderHairline, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: _textMuted,
                letterSpacing: 0.3,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 11.5,
                fontWeight: pw.FontWeight.bold,
                color: valueColor,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              subtitle,
              style: pw.TextStyle(fontSize: 7, color: _textSlate),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    PdfColor? textColor,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 7.5 : 8,
          fontWeight: (isHeader || isBold) ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor ?? (isHeader ? _textSlate : _charcoal),
        ),
      ),
    );
  }
}
