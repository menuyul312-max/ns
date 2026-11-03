# Nusantara World Lab 12 — audit RE ACNH 1.0.0 dan perbaikan terrain

**Tanggal:** 2 November 2026. **Engine:** Godot 4.7.2. **Dasar:** arsip pengguna `acnh-re-results-main.zip` (lima ZIP anak dengan checksum SHA-256 cocok dengan `downloads/SHA256SUMS.txt`). **Sifat proyek:** implementasi desain Nusantara orisinal; tidak menyalin data preset, model, tekstur, disassembly, atau kode Nintendo ke build.

## 1. Sumber dan tingkat bukti

Yang diperiksa:

- `acnh-re/LAPORAN_AKHIR.md`: ringkasan kemajuan, batas data sumber, dan RE yang belum selesai.
- `acnh-re/docs/DATA_CONTRACT.md`: deklarasi struktur record terrain dan perbedaan parsing dari pemahaman semantik.
- `acnh-re/output/relations/terrain_native.json` di `ACNH_RE_bagian_05_dari_05.zip`: layout record, batas variasi, hitungan semua sel, dan hubungan model.
- `acnh-re/output/world/FieldPresetA00_LandMaking.json`: contoh nyata grid, array `cells`, serta himpunan nilai rotasi/variasi/height.

Arsip tersebut menyatakan seluruh subset B_data yang disuplai terpetakan secara struktural, **bukan 100% mekanik game**. Hasil validasi struct native lebih kuat daripada asumsi model fisik/collision/gameplay. Semua konversi yang dibuat pada Sprint 12 diberi batas bukti berikut.

## 2. Temuan berkeyakinan tinggi

| Temuan | Bukti arsip | Konsekuensi desain |
|---|---|---|
| 96 preset terrain × 10.752 sel | `terrain_native.json`: `records=1032192`; seluruh preset A/B/C | Editor Nusantara tidak boleh menyatukan level, motif, dan penempatan menjadi satu enum |
| Grid preset contoh = 112×96, urutan row-major | `FieldPresetA00_LandMaking.json`: `grid` dan `order` | `IslandDefinition` mendukung ukuran variabel termasuk 112×96, demo tetap 14×10 |
| Satu record memiliki 7 nilai bermakna: `(unit0, variation0, rotation0, unit1, variation1, rotation1, height)` | `cell_fields`, `DATA_CONTRACT.md`, dan bukti native | Dibuat API `terrain_record_at()` serta dua layer independen |
| Tinggi 0–5 diterima. Input 6+ dibaca sebagai 4, bukan clamp ke 4 untuk nilai 5 | `terrain_native.json`: `height_valid_range` + `height_invalid_fallback` | `normalize_reference_height()` menjaga kasus batas untuk audit data eksternal |
| Variasi aktual datang dari indeks dalam sel; nilai `Variation` pada katalog unit ialah batas maksimal | `terrain_native.json`: `variation_note` dan `legacy_layer0_model_disagreements=54820` | Renderer memakai indeks variasi dari sel, fallback 0 jika melebihi batas palet Nusantara |
| Rotasi contoh memakai nilai 0–3 | `FieldPresetA00_LandMaking.json`: nilai unik rotasi | Motif dekor bisa diputar tiap 90° dengan kontrol editor |
| Kedua layer tersimpan, tetapi layer kedua seluruhnya unit 0 pada data preset yang tersedia | `terrain_native.json`: `layer_counts[1]` seluruh 1.032.192 unit 0 | Layer kedua di Nusantara menjadi ekstensi kosmetik **orisinal**, bukan reproduksi fungsi yang telah terbukti di ACNH |

**Catatan penting:** ukuran tile yang terlihat di Godot (`TILE_SIZE=2.1`) dan beda elevasi (`HEIGHT_STEP=1.55`) adalah parameter *prototype Nusantara*. Tidak boleh dikutip sebagai skala ACNH; data RE belum membuktikan transformasi fisiknya. Pemetaan ID unit sumber ke model Godot juga belum tersedia—ID material baru 0–3 di sini merupakan indeks palet orisinal, bukan unit ID Nintendo.

## 3. Perubahan kode yang diuji

1. `IslandDefinition` kini menyimpan metadata terpisah: `surface_units/variations/rotations` dan `detail_units/variations/rotations`. Tiap tile tetap memiliki `levels` dan `water` untuk gameplay; **dua layer material tidak mengubah collider**.
2. Format penyimpanan menjadi **schema v3** dengan `terrain_layers[0/1]`; loader tetap membaca v1 (tanpa water) dan v2 (water sudah ada). Editor menolak ukuran, nilai unit, variasi, rotasi, dan array yang malformed.
3. `IslandComposer.cycle_terrain_layer()` mendukung siklus unit, variasi dan orientasi per layer. Variasi desain kita memakai batas `[0,3,2,1]` untuk empat ID palet; nilai lebih besar dari batas jenis dianggap varian 0, tidak diartikan sebagai varian terakhir.
4. `TerrainBuilder` mewarnai layer pertama sebagai tanah merah, lumut, atau kerikil; warna memakai *radial blending* pada world coordinate agar tile yang bersebelahan membentuk jalur menyatu. Renderer layer kedua menambahkan ornamen kecil tanpa collider sebagai `GroundDecorLayer`. Model, bentuk, dan warna dibuat orisinal.
5. Input gameplay: `Alt+klik kiri` mengganti material permukaan; `Ctrl+klik kiri` mengganti dekor; klik kanan dengan modifier memutar; tambahkan Shift+klik kiri untuk siklus variasi. Input lama klik kiri/kanan elevasi, Shift+klik kiri air, `1/2/3` denah, `Ctrl+S` simpan, `L` muat, dan kontrol karakter tetap berfungsi.
6. Fixture sungai menambahkan jalur tanah dan ornamen contoh. Ini bukan denah dari sumber RE; seluruh geometri dan warna tetap milik Nusantara.

## 4. Pengujian dan capture

- `tests/test_re_terrain_layers.gd` memverifikasi tinggi 0–5 dan fallback, dukungan array 112×96, dua layer, variasi/rotasi, warna yang benar-benar berubah, lapisan dekor, collider utama tetap ada, migrasi v1/v2/v3, round-trip JSON, dan penolakan nilai di luar rentang.
- `tests/test_editor_input.gd` memverifikasi lukisan dua layer via input mouse tanpa merusak raycast collider dan brush sungai.
- **20/20 tes** `tests/test_*.gd` lulus setelah revisi, termasuk tes animasi GLB, IK, shovel, water mode, water validator, bank collision dan serialization.
- `tests/capture_re_terrain.gd` membuat tiga frame asli dari renderer Godot: `terrain_re_before.png` (fixture awal), `terrain_re_after.png` (penambahan jalur dan ornamen), `terrain_re_overview.png` (overview + HUD baru).

## 5. Apa yang tidak dapat diklaim dari ZIP ini

| Topik | Status |
|---|---|
| Aturan lengkap grid pulau dan semua batas bangunan | Belum dibuktikan penuh; preset tidak otomatis berarti aturan edit/gameplay |
| Skala dunia/tile, bentukan bibir tebing, pertemuan mesh, collision exact | Perlu audit model/mesh, caller physics, dan pembandingan visual terukur |
| Gameplay shovel mengubah tanah | Bukti record terrain saja tidak membuktikan seluruh aksi, validasi alat, atau UI |
| Physics pemain: kecepatan, gravitasi, friction, fall damage | **Tidak** diubah menjadi konstanta ACNH; tidak ada bukti native memadai di paket yang diperiksa |
| Fungsi layer kedua di ACNH | Tidak diketahui dari preset yang tersedia; seluruh field layer kedua bernilai default |
| Aturan gelombang air dan air terjun | Belum diperbaiki pada sprint ini; data terrain bukan algoritma render air |

## 6. Prioritas riset lanjutan

1. Pilih beberapa preset terenkripsi/non-proprietary statistik untuk melihat **distribusi kombinasi unit/varian** dan arah rotasi, tanpa menyalin peta ACNH ke aset produksi.
2. Identifikasi hubungan setiap ID unit dengan **kategori fungsi tanah** secara terverifikasi dan batas kompatibilitas tetangga; jangan menafsirkan nama model sebagai aturan gameplay.
3. Audit `FieldLandMakingError` bersama call site native untuk izin perubahan tanah/tebing; hasil pembacaan kolom s8 saja belum menjelaskan kondisi invalid seluruh brush.
4. Pisahkan pipeline komposisi denah, constraints, dan render agar pulau besar bisa di-stream dalam chunk. Benchmark 112×96 sebelum mengklaim layak runtime.
5. Untuk physics/animasi, cari fungsi native yang memvalidasi collision dan movement state; sampai saat itu gunakan pengukuran Godot sendiri dengan parameter yang dapat dituning.
