<div align="center">

# 🛡️ FinGuard.ai
### Institutional-Grade AI Personal Finance & Wealth Intelligence Platform

[![Flutter](https://img.shields.io/badge/Flutter-3.38%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10%2B-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Database%20%26%20Edge%20Functions-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Google Gemini](https://img.shields.io/badge/Google%20Gemini-AI%20Intelligence-8E75B2?logo=googlegemini&logoColor=white)](https://ai.google.dev/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

FinGuard.ai adalah platform mobile manajemen finansial pribadi cerdas berbasis AI yang menggabungkan pencatatan otomatis, budgeting deterministik (50/30/20), simulasi target tabungan berbasis prioritas, pemindai nota transaksi (OCR), hingga intelijen bursa saham mendalam & bandarmologi.

</div>

---

## ✨ Fitur Unggulan

### 1. 🤖 AI Financial Coach
- Chat interaktif berbasis konteks database finansial riil pengguna secara realtime.
- Tiga mode persona yang dapat disesuaikan:
  - **Suportif & Ramah**: Memotivasi dan memberi bimbingan positif.
  - **Profesional & Tegas**: Standar perencana keuangan bersertifikat (CFP).
  - **Mode Roast Tongkrongan**: Bahasa santai, blak-blakan, dan menyadarkan saat belanja boros.
- Pengenalan transaksi otomatis via NLP untuk pencatatan instan.

### 2. 📐 Peta Keuangan Cerdas (Smart 1-Click Blueprint)
- Perhitungan pembagian gaji otomatis mengikuti prinsip **50/30/20**:
  - **50% Kebutuhan Pokok** (Makan, Transportasi, Tagihan).
  - **30% Keinginan & Gaya Hidup** (Hiburan, Belanja).
  - **20% Tabungan & Investasi** (Dana Darurat, Portofolio).
- Sinkronisasi instan ke seluruh batas (*limit*) jatah belanja per kategori.

### 3. 📈 Intelijen Bursa & Analisis Bandarmologi
- **Multi-Engine Edge Function**: Mengorkestrasi data Yahoo Finance, kalkulasi teknikal RSI(14), SMA(50), dan VWAP.
- **Analisis Order Book**: Evaluasi ketebalan Bid vs Offer, rasio HAKA vs HAKI, serta fraksi harga resmi BEI.
- **Top 3 Broker Akumulasi vs Distribusi**: Memetakan broker pembeli dan penjual dominan beserta estimasi lot dan harga rata-rata.
- **Simulasi Penjatahan e-IPO**: Menghitung estimasi alokasi ritel pooling berdasarkan target emisi dan batas tier permodalan.
- **Kalkulator Kapasitas Saldo**: Menghitung kemampuan beli lot saham riil berdasarkan uang dingin tanpa mengorbankan dana darurat.

### 4. 🧾 Pemindai Nota & Struk Belanja (Receipt Scanner)
- Ekstraksi gambar struk/nota belanja secara cerdas menggunakan Google Gemini Multi-Modal Vision.
- Otomatis membaca nama merchant, tanggal transaksi, total nominal, dan memetakan ke kategori anggaran yang sesuai.

### 5. ⚖️ Konsultasi Belanja ("Boleh Beli Gak?")
- Algoritma penilaian deterministik sebelum membeli barang impian.
- Mempertimbangkan rasio sisa uang dingin, beban cicilan aktif, serta dampak pengeluaran terhadap target tabungan.

### 6. 🧮 Kalkulator Finansial Deterministik
- **Kalkulator Dana Darurat**: Rekomendasi kebutuhan kas darurat berdasarkan profil tanggungan dan stabilitas pekerjaan.
- **Kalkulator Bunga Majemuk**: Proyeksi pertumbuhan investasi jangka panjang dengan simulasi setoran berkala.
- **Debt Service Ratio (DSR)**: Indikator kesehatan beban utang bulanan.

---

## 🏗️ Arsitektur Proyek (Feature-First Clean Architecture)

FinGuard dibangun dengan struktur modular berbasis fitur untuk memastikan skalabilitas, kemudahan pengujian, dan keterbacaan kode yang optimal:

```text
lib/
├── app/                  # Inisialisasi aplikasi, Dependency Injection (GetIt), Routing (GoRouter), Desain Sistem
├── bootstrap.dart        # Bootstrap konfigurasi awal & locale IDR
├── main.dart             # Application entrypoint
├── core/                 # Shared widgets, konfigurasi, utilitas kalkulator, formatters, dan Error Handling
└── features/
    ├── auth/             # Autentikasi Supabase & session guard
    ├── budgets/          # Manajemen batas pos belanja & pemantauan realisasi
    ├── calculators/      # Kalkulator finansial deterministik
    ├── coach/            # Chat interface AI Coach & pemindai nota
    ├── consultation/     # Evaluasi kelayakan belanja pra-checkout
    ├── dashboard/        # Beranda utama, navigasi tab melayang, dan metrik kas
    ├── goals/            # Target tabungan celengan & dana darurat dengan prioritas
    ├── monthly_review/   # Laporan evaluasi arus kas bulanan
    ├── profile/          # Pengaturan preferensi, profil, dan peta keuangan
    ├── stock_signals/    # Radar sinyal saham & Deep Stock Analysis
    └── transactions/     # Riwayat dan pencatatan transaksi masuk/keluar
```

Backend Supabase:
```text
supabase/
├── migrations/           # Skema database PostgreSQL, indexing, triggers, dan Row-Level Security (RLS)
└── functions/            # Supabase Edge Functions (Deno / TypeScript)
    ├── _shared/          # Helper auth, CORS, dan Google Gemini API Client
    ├── coach-chat/       # NLP conversational AI & ekstraksi transaksi
    ├── analyze-stock/    # Multi-engine analisis bursa & bandarmologi
    ├── purchase-consultation/
    └── monthly-review/
```

---

## 🚀 Panduan Memulai (Quick Start)

### 1. Prasyarat
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (versi 3.38.x atau lebih baru)
- [Dart SDK](https://dart.dev/get-started) (versi 3.10.x atau lebih baru)
- Akun [Supabase](https://supabase.com) & [Google AI Studio](https://aistudio.google.com) (Gemini API)

### 2. Kloning Repositori
```bash
git clone https://github.com/JojooLearn/Finguard.ai.git
cd Finguard.ai
```

### 3. Instalasi Dependensi
```bash
flutter pub get
```

### 4. Konfigurasi Environment
Salin template konfigurasi `.env.example`:
```bash
cp .env.example .env
```
Isi konfigurasi pada file `.env` dengan kredensial Supabase dan API Key Gemini Anda.

### 5. Menjalankan Pengujian & Analisis Kode
```bash
# Static analysis (Harus 0 issues)
flutter analyze

# Menjalankan seluruh test suite
flutter test
```

### 6. Menjalankan Aplikasi
```bash
# Jalankan pada emulator atau perangkat Android / iOS yang terhubung
flutter run
```

---

## 🤝 Berkontribusi

Kontribusi dari komunitas sangat diapresiasi! Silakan baca panduan lengkap pada [CONTRIBUTING.md](CONTRIBUTING.md) untuk detail alur pengajuan Pull Request, standar kode, dan prosedur pengujian.

---

## 📄 Lisensi

Proyek ini didistribusikan di bawah lisensi **MIT License**. Lihat file [LICENSE](LICENSE) untuk informasi lebih lanjut.

---

<div align="center">
Crafted with ❤️ by <b>johdev</b> (@JojooLearn)
</div>
