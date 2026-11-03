# Nusantara World Lab — Sprint 23–25

Tanggal: 3 November 2026 (WIB)  
Engine: Godot 4.7.2 (GL Compatibility)  
Dasar: proyek Sprint 22 yang dipulihkan sebagai checkpoint; perubahan dilakukan dalam copy Sprint 25.

> Ini proyek orisinal untuk menguji mekanik dan bahasa visual pulau dengan Animal Crossing: New Horizons sebagai **referensi observasi**, bukan dekompilasi ataupun penggunaan kode, tekstur, atau data proprietary Nintendo. Parameter numeriknya adalah rancangan Nusantara World Lab, **bukan** parameter terverifikasi ACNH.

## Sprint 23 — Foam mengikuti bentuk pantai

**Akar masalah:** shader ombak Sprint 22 mengukur jarak dari empat garis persegi, meskipun batas mesh/collider darat telah dibengkokkan. Akibatnya busa kadang tampak terpisah dari bibir pantai.

**Perubahan:**

- `CoastContour.boundary_at()` menjadi fungsi sumber tunggal untuk empat garis pantai.
- `CoastBuilder.make_shoreline_texture()` membuat tekstur profil RGBA float dengan 512 sampel, memuat batas barat/timur/utara/selatan.
- Shader laut menggunakan jarak bertanda terhadap profil tersebut (`water_distance`) agar gerak ombak membelok bersama teluk; foam diputus dengan noise teradveksi.
- Tetap memisahkan *visual ocean* dari logika berenang; laut luar belum menjadi area gameplay.

**Acceptance:** test membandingkan nilai profil yang masuk ke material dengan posisi kontur collision secara numerik, untuk keempat sisi pada beberapa sampel.

## Sprint 24 — Coast sculpt dan penyimpanan denah v6

- `IslandDefinition` menyimpan empat `shore_profiles` sebagai data denah, diinterpolasi antar node di sepanjang tepi pulau.
- Editor: tekan **O** untuk berpindah ke mode ukir pantai. Saat aktif, klik kiri di area dekat tepi menggeser garis pantai masuk (membentuk cekungan); klik kanan mengembalikannya. Tiap klik mengubah 0,20 satuan dunia; nilai maksimal 1,10. Node di empat sudut dikunci agar sambungan tetap stabil.
- Sculpt otomatis diredam pada bukaan sungai basah agar muara tidak tersumbat oleh perubahan profil pantai.
- Rendering ground dan collision menggunakan transformasi pesisir yang sama; aturan gerak di tepi diperbarui secara otomatis.
- Save/load menulis `schema_version: 6`. Denah v1–v5 tetap diterima dan mendapat profil pantai netral.
- Data tidak menghapus tile atau menambah laut simulasional: ini **penggeseran siluet garis luar**, belum alat menggambar pulau bebas / pulau terpisah.

**Acceptance:** pengeditan, sambungan antartile, batas gerak, serialisasi v6, migrasi v5 dan kehadiran collider.

## Sprint 25 — Peralihan bibir air terjun

- Lembaran air mendapatkan *wet crest shoulder* yang sedikit masuk ke permukaan sungai atas, mengurangi garis sambungan gelap.
- Noise aliran jatuh memiliki dua skala rivulet/serat; alpha tidak seragam untuk melembutkan bidang.
- Apron foam ditessellasi dalam band yang lebih rapat, dengan variasi jarak, opacity dan gradasi ke tepian. Versi pertama menghasilkan motif kotak-kotak dan langsung direvisi berdasarkan screenshot.
- Semuanya masih render berbasis mesh/shader dengan biaya relatif murah; bukan solver fluid 3D.

## Capture QA

| File | Pemeriksaan |
| --- | --- |
| `s25_coast_before.png` | Fixture garis pantai lama; sudut dan framing identik dengan `after`. |
| `s25_coast_after.png` | Profil yang dipahat, busa mengikuti bentuk baru dan muara tetap terbuka. |
| `s25_shore_editor_closeup.png` | Kontinuitas pantai skala dekat, batas warna pasir/rumput. |
| `s25_river_mouth.png` | Transisi air sungai ke laut. |
| `s25_waterfall_detail.png` | Lidah air jatuh, sambungan atas, busa dasar. |

Gambar dirender dalam Godot 4.7.2 menggunakan viewport 1280×720 (OpenGL compatibility / llvmpipe), bukan ilustrasi buatan image model.

## Tes dan keterbatasan yang terverifikasi

- `tests/test_shore_profile.gd` memeriksa profil, transisi visual/collider, dan serialisasi. `tests/test_probe_ui.gd` memeriksa tombol `O` dan label editor.
- Semua regression test `tests/test_*.gd` harus dijalankan setelah update; visual selalu dilihat ulang karena test numerik tidak bisa memastikan kualitas estetika.
- Celah terbesar terhadap referensi ACNH: pulau masih punya logika grid rectangular; belum ada mask polygon topologis, sistem pantai berlapis batu/karang, animasi ombak khusus sudut tanjung, karakter berenang ke laut terbuka, siklus musim, vegetasi dan partikel air terjun skala lanjut.
- Fixture ini memakai bahan warna/prosedur ilustratif. Efek hanya **mendekati bahasa visual** game referensi, tidak dapat disebut setara pixel-by-pixel atau mekanik 1:1.

## Menjalankan

1. Buka `project.godot` dengan Godot 4.7.x; jalankan adegan utama.
2. Pilih denah dengan angka `1`–`3`; kamera ortografik otomatis menyesuaikan.
3. Tekan `O` lalu klik dekat bibir pulau untuk mengukir/revisi profil. Tekan `O` lagi untuk kembali ke editor tanah/air standar.
4. Simpan dengan `Ctrl+S`, muat dengan `L`.
5. Screenshot QA dapat diregenerasi: `godot --rendering-method gl_compatibility --path . --script res://tests/capture_sprint25.gd` pada display grafis (bukan mode headless).
6. Tes numerik: `godot --headless --path . --script res://tests/test_shore_profile.gd`, kemudian ulangi untuk tiap `tests/test_*.gd`.

### Rekomendasi teknis sprint berikutnya

Sprint 26: coastal mask berbasis tile untuk benar-benar menghapus/menambah daratan dan menata bentuk pulau nonpersegi, disertai transisi collider/ray-picking. Sprint 27: sungai yang otomatis tersambung ke coastal mask, dermaga, pasir, dan foam khusus muara. Sprint 28: waterfall spray dalam local flow-space dengan partikel tipis dan QA performa. Jangan menyamakan satu tahap ini dengan reproduksi akurat ACNH sampai ada pengukuran gameplay referensi yang sah.
