# Panduan Kontribusi FinGuard.ai 🛡️

Terima kasih atas ketertarikan Anda untuk berkontribusi pada pengembangan **FinGuard.ai**! Kami sangat menyambut baik kontribusi berupa perbaikan bug, optimasi performa, penambahan fitur finansial baru, maupun penyempurnaan dokumentasi.

---

## 🎯 Prinsip & Standar Pengembangan

1. **Clean Architecture (Feature-First)**: Setiap fitur di dalam `lib/features/` dibagi menjadi tiga lapisan: `data`, `domain`, dan `presentation`.
2. **State Management**: Menggunakan `Bloc` / `Cubit` (`flutter_bloc`). Hindari state mutasi langsung tanpa event/cubit.
3. **Zero-Slop UI & Design System**: Mengikuti palet warna FinGuard (`AppColors`), tipografi (`AppTypography`), serta spacing konsisten (`AppSpacing`). Hindari layout berantakan, bayangan bertumpuk tajam, atau emoji berlebihan.
4. **Keamanan & Privasi Kredensial**: **JANGAN PERNAH** melakukan commit API Key rahasia, Service Role Key, file `.env`, file `.keystore`, atau kredensial pribadi ke dalam repositori.

---

## 🛠️ Alur Kontribusi (Git Workflow)

Sebagai proyek open-source, seluruh perubahan kode harus melalui mekanisme **Pull Request (PR)**:

```mermaid
gitGraph
   commit id: "Initial Commit"
   branch contributor-fork
   checkout contributor-fork
   commit id: "Fork & Branch"
   commit id: "Implement Feature / Fix"
   commit id: "Pass Tests & Analyzer"
   checkout master
   merge contributor-fork id: "Reviewed & Approved by Maintainer"
```

### Langkah-langkah:

1. **Fork Repositori**:
   Klik tombol **Fork** di pojok kanan atas halaman GitHub [Finguard.ai](https://github.com/JojooLearn/Finguard.ai) ke akun GitHub pribadi Anda.

2. **Clone Fork Anda**:
   ```bash
   git clone https://github.com/USERNAME-ANDA/Finguard.ai.git
   cd Finguard.ai
   ```

3. **Buat Branch Fitur Baru**:
   Gunakan nama branch yang deskriptif:
   ```bash
   git checkout -b feature/nama-fitur-baru
   # atau untuk perbaikan bug:
   git checkout -b fix/deskripsi-bug
   ```

4. **Konfigurasi Environment Lokal**:
   - Salin file `.env.example` menjadi `.env`:
     ```bash
     cp .env.example .env
     ```
   - Isi kredensial Supabase dan Gemini API lokal Anda. File `.env` sudah otomatis diabaikan oleh `.gitignore` sehingga aman.

5. **Lakukan Perubahan Kode & Verifikasi**:
   Pastikan kode Anda lolos static analysis dan unit test:
   ```bash
   # Pastikan tidak ada warning atau error (0 issues)
   flutter analyze

   # Pastikan seluruh unit & widget test lulus
   flutter test
   ```

6. **Commit & Push**:
   Tulis pesan commit yang jelas dan terstruktur:
   ```bash
   git add .
   git commit -m "feat(stock): add VWAP calculation on edge function"
   git push origin feature/nama-fitur-baru
   ```

7. **Buka Pull Request (PR)**:
   - Masuk ke repositori GitHub dan klik **Compare & pull request**.
   - Jelaskan secara ringkas perubahan yang Anda buat, alasan di baliknya, dan screenshot (jika ada perubahan UI).

---

## 🔍 Kebijakan Review & Penggabungan (Merge)

- Setiap Pull Request akan ditinjau oleh Maintainer utama (**@JojooLearn / johdev**).
- Tidak ada kontributor luar yang dapat langsung menggabungkan kode ke branch utama (`master`) tanpa persetujuan eksplisit dari Maintainer.
- Jika ada penyesuaian yang diperlukan, Maintainer akan memberikan komentar dan saran perbaikan langsung pada halaman Pull Request.
