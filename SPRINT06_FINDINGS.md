# Sprint 06 — Bathymetry sungai dan aktor fisik berjalan–merendam–berenang

**Tanggal:** 2 November 2026. **Status:** Prototipe Godot 4.7.2; karakter `CharacterBody3D` nyata berjalan, masuk air dangkal, dan mengapung di alur dalam. Aset karakter masih dummy lab.

## Landasan dan pembatasan

Prototipe ini **bukan implementasi reverse-engineered kode ACNH**. Penataan pulau edit-tile, kontur sungai, dan tiga mode gerak dipakai sebagai inspirasi desain yang dapat diuji secara independen. Seluruh nilai ukuran, bentuk dasar sungai, dan rumus flotasi adalah rancangan game Nusantara kita, belum pengukuran atau hukum fisika ACNH. Godot `CharacterBody3D`, `move_and_slide()`, `SurfaceTool`, dan `ConcavePolygonShape3D` adalah komponen engine yang kita pakai.

Dokumentasi primer: [Godot CharacterBody3D](https://docs.godotengine.org/en/4.7/classes/class_characterbody3d.html), [Godot SurfaceTool](https://docs.godotengine.org/en/4.7/classes/class_surfacetool.html), [Godot Collision shapes](https://docs.godotengine.org/en/4.7/tutorials/physics/collision_shapes_3d.html).

## A. Model bathymetry yang konsisten dengan field air

Rumus depresi dasar sungai diturunkan dari coverage air kontinyu `F(x,z)` dari Sprint 04:

`depresi = 0,36 * smoothstep(0,27, 0,78, F) + 0,48 * smoothstep(0,68, 0,98, F)`

Permukaan air diletakkan `0,08` unit di bawah elevasi dataran acuan, sehingga kedalaman air pusat (coverage=1) menjadi sekitar **0,76 unit**. Kedalaman semakin tipis dekat garis shore.

`RiverBathymetry` digunakan di dua jalur:

- `TerrainBuilder`: permukaan tanah kini dibentuk melalui **6 lapis segitiga radial per tile**, bukan satu triangle fan besar. Mesh itulah yang menghasilkan collider fisik tanah.
- `WaterRules`: menghitung tinggi dasar dan kedalaman untuk mengklasifikasi **dangkal** (kedalaman sampai 0,39 unit) versus **alur dalam** (lebih dari 0,39 unit). Pita luar **TEPI** masih berdasarkan jarak 0,23 unit dari kontur.

Kedalaman analitik dan mesh fisik cocok tepat pada vertex, namun selisih kecil di antaravertex mungkin terjadi akibat interpolasi segitiga. Ini **profil sungai desain**, bukan hidrologi/erosi atau pengukuran sungai nyata.

## B. Perpindahan berdasarkan CharacterBody3D

`RiverCharacter` berisi bentuk collision kapsul, model debug sederhana, dan `_physics_process()` yang menjalankan:

1. Dapatkan posisi kaki dan zona basah dari `WaterRules.sample()`.
2. Validasi segmen horizontal dalam interval maksimal 0,095 unit.
3. Jika mode **jalan**, larang posisi basah; jika **rendam**, larang alur dalam; jika **renang**, boleh melewati alur dalam pada tingkat peta sama.
4. Mode darat/rendam memakai gravitasi `16 unit/s²` dan `move_and_slide()`. Angka ini parameter gameplay, bukan konstanta dunia nyata.
5. Saat `RENANG` di kedalaman setidaknya `0,34` unit, kecepatan vertikal diarahkan perlahan menuju pusat badan setinggi `water_surface + 0,18` sebagai **pengapungan artifisial**. Tubuh debug sedikit condong.
6. Setelah `move_and_slide()`, sampling diulang; jika sliding mendorong badan ke zona terlarang, posisi sebelum langkah dipulihkan.

Tombol `C` menyalakan/mematikan aktor fisik sehingga marker probe Sprint 05 dapat dipakai untuk inspeksi terpisah. Aktor fisik adalah mode default saat F5.

## C. Perbaikan pengeditan air

Ketika dasar sungai lebih dalam, raycast biasa dapat jatuh pada lokasi tanah yang jauh di belakang piksel air yang dipilih. Shift+klik sekarang mencari perpotongan pertama ray terhadap permukaan air pada level relevan **sebelum** fallback ke collision tanah. Ini memperbaiki regresi pengeditan water tile setelah bathymetry ditambah. Percobaan ulang `test_editor_input.gd` kembali PASS.

## Validasi aktual

| Uji | Hasil | Bukti |
| --- | --- | --- |
| `test_bathymetry.gd` | **PASS** | Depth pusat ~0,76; collider tanah hasil raycast sama dengan lantai analitik pada toleransi 0,045 |
| `test_river_character.gd` | **PASS** | Aktor jatuh ke tanah, jalan berhenti di bank, rendam masuk dangkal tanpa menembus alur dalam, renang melintas dan mengapung |
| `test_island.gd` | **PASS** | Topologi sungai, mesh, normal, dan penyimpanan |
| `test_physics.gd` | **PASS** | Collider tanah/tebing |
| `test_character.gd` | **PASS** | Kapsul dasar tidak melewati tebing |
| `test_composer.gd` | **PASS** | Brush dan serialisasi |
| `test_editor_input.gd` | **PASS** | Klik layar dan rekonstruksi collision/air setelah bathymetry |
| `test_bank_collision.gd` | **PASS** | Collider bank dan flow |
| `test_water_rules.gd` | **PASS** | Zona dan aturan path |
| `test_water_validator.gd` | **PASS** | Audit jaringan sungai |
| `test_probe_ui.gd` | **PASS** | Toggle heatmap/probe dan HUD Sprint 06 |

Dalam pengujian gerak panjang pada fixture, sumbu X aktor bergerak **25,25 → 24,86 → 21,58** unit antara akhir fase jalan, rendam, renang. Ini bukan ukuran kecepatan nyata; angka hanya memvalidasi perpindahan melintasi batas zona. Pada fase mengapung, badan mendekati `water_y + 0,18` dan tidak terjatuh ke dasar.

## Capture

- `terrain_preview_sprint05.png`: sebelum profil dalam/aktor fisika.
- `terrain_preview.png`: tampilan keseluruhan World Lab 06 dengan aktor debug pada darat.
- `water_zones_preview.png`: heatmap memakai kedalaman analitik.
- `physics_swim_closeup.png`: aktor fisik mengapung di alur sekitar 0,76 unit.
- `physics_modes.gif`: 19 frame 960×540 yang memperlihatkan perubahan zona dan status gravitasi/pengapungan. Ini bukan animasi skeleton yang sudah di-rig.

## Prioritas berikut

1. **Controller animasi dan model rig**: ganti mannequin dengan karakter Nusantara yang benar, state machine jalan → wading → swimming, blend locomotion dan transisi keluar sungai.
2. **Integrasi arus**: gunakan `RiverContour.flow_at()` untuk memberi drift pada badan dengan gaya yang terkendali; uji ketika karakter berhenti dan melawan arus.
3. **Kolam, pantai, dan muara**: perlu profil bathymetry dan gelombang yang berbeda, terutama mangrove dan permukiman pesisir.
4. **Perbaikan cliff-waterfall**: mesh bawah air, rongga tebing, buih/semprotan lokal, dan sambungan yang tidak terlihat kotak.
5. **Skalabilitas**: submesh/collider terpartisi serta cache jarak ke shoreline agar editor pulau besar tetap responsif.

## Kesimpulan

Sprint 06 menghubungkan **kontur → kedalaman dasar → zona gameplay → gerakan CharacterBody3D** dengan hasil tes nyata. Fondasi ini dapat dikembangkan menjadi mekanik Nusantara orisinal, tetapi kualitas rig, animasi, dan efek air masih jauh dari game komersial dan bukan reproduksi internal ACNH.
