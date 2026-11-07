# Changelog

Semua perubahan pada proyek FinGuard dicatat dalam dokumen ini.

## [1.0.0] - 2026-10-20
### Ditambahkan
- **Inisialisasi Proyek**: Setup Flutter project dengan clean feature-first architecture (`app`, `core`, `features`).
- **Sistem Desain & Tema Visual**: Implementasi warna gradient sage green, kartu 2x2 grid (lime & dark green), tipografi Inter modern, dan floating bottom navigation bar sesuai acuan visual [Referensi.png](file:///c:/dev/FinGuard/Referensi.png) dan spesifikasi Stitch.
- **Database & Migrasi Supabase**: 9 file migrasi PostgreSQL lengkap (`profiles`, `financial_profiles`, `accounts`, `categories`, `transactions`, `budgets`, `financial_goals`, `goal_contributions`, `chat_conversations`, `chat_messages`, `ai_requests`, `monthly_reviews`), indeks performa, pemicu otomatis profil, dan aturan RLS menyeluruh.
- **Supabase Edge Functions**: Template fungsi Deno/TypeScript berotentikasi untuk `coach-chat`, `purchase-consultation`, dan `monthly-review` dengan integrasi Gemini API server-side.
- **Domain Mesin Finansial**: `FinancialCalculator` dengan logika matematis deterministik untuk arus kas, alokasi budget, estimasi dana darurat, bunga majemuk, dan rasio utang.
- **Layar & Fitur Lengkap**:
  - `HomePage`: Dasbor utama dengan kartu metrik ringkasan arus kas, insight card, dan daftar transaksi terbaru.
  - `CoachPage`: Antarmuka percakapan pelatih keuangan cerdas dengan saran cepat.
  - `BudgetPage`: Tampilan realisasi vs batas pagu anggaran per kategori dengan status chip.
  - `GoalsPage`: Pelacakan tabungan target dana darurat dan aset masa depan.
  - `ProfilePage`: Pengaturan akun, slider level ketegasan AI coach (1–5), dan navigasi ke alat finansial.
  - `TransactionListPage`: Filter transaksi berdasarkan status pemasukan/pengeluaran.
  - `PurchaseConsultationPage`: Uji kelayakan belanja sebelum transaksi nyata dilakukan.
  - `CalculatorsPage`: Kalkulator interaktif dana darurat, pertumbuhan majemuk, dan rasio utang.
  - `MonthlyReviewPage`: Snapshot performa keuangan bulanan dan evaluasi AI.
- **Rangkaian Pengujian Otomatis**: Unit test untuk formula finansial & formatter serta widget test untuk dasbor utama (semua lulus 100%).
