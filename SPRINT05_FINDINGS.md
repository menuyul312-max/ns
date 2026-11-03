# Sprint 05 — Aturan pergerakan di tepi air dan audit tata letak sungai

**Tanggal:** 2 November 2026. **Status:** Fungsional sebagai demonstrator aturan navigasi berbasis kontur; belum karakter final.

## Tujuan riset

Setelah kontur sungai Sprint 04, masalah terpenting ialah perbedaan antara **gambar air yang terlihat** dengan **keputusan gameplay apakah karakter boleh berjalan, merendam, atau berenang di lokasi tertentu**. Sistem tidak boleh bergantung hanya pada status tile, karena tepi sungai melengkung dan melewati tile.

Implementasi ini adalah **desain sistem orisinal**. ACNH hanya dipakai sebagai inspirasi observasi bahwa penataan sungai dan pergerakan karakter perlu terasa konsisten. Tidak ada pengukuran fisika maupun penggunaan source/asset Nintendo.

## Eksperimen 1 — klasifikasi spasial tanpa batas tile kaku

`WaterRules.sample(feet_position)` mengonversi elevasi kaki ke level air relevan, mengecek `RiverContour.field_at()`, lalu memperkirakan jarak terdekat menuju garis ambang air.

- Jarak shoreline dicari dalam **16 arah radial**, langkah **0,12 unit**, hingga **1,56 unit**, disempurnakan bisection enam iterasi setelah ditemukan perubahan sisi batas.
- **Darat:** di luar kontur dan di luar 0,23 unit dari tepi.
- **Tepi:** di luar kontur namun sejauh 0,23 unit atau kurang dari shore.
- **Dangkal:** di dalam kontur, sejauh 0,46 unit atau kurang dari shore.
- **Alur dalam:** di dalam kontur, lebih dari 0,46 unit dari shore.

Nama "alur dalam" adalah **konvensi gameplay berdasarkan jarak lateral**. Kedalaman dasar sungai sesungguhnya dan ketahanan berenang belum disimulasikan. Rentang ini didasarkan pada proporsi denah contoh dan perlu kalibrasi artistik untuk bioma Nusantara.

## Eksperimen 2 — lintasan aman

`WaterRules.can_traverse_path(origin, destination, mode)` memeriksa seluruh perpindahan dengan jarak sampel maksimum 0,095 unit dunia. Aturan sementara:

| Mode probe | Darat | Tepi | Dangkal | Alur dalam |
| --- | --- | --- | --- | --- |
| Jalan | boleh | boleh | blok | blok |
| Rendam | boleh | boleh | boleh | blok |
| Renang | boleh | boleh | boleh | boleh |

Perpindahan langsung antar level elevasi berbeda selalu diblokir, termasuk jika ada waterfall. Karakter belum otomatis memanjat tebing atau menggunakan jembatan/pole vault. Ini mencegah langkah panjang **melompati air sempit tanpa dicek**, dan memisahkan izin navigasi dari render mesh.

Probe UI pada `main.gd` ditunjukkan sebagai penanda laboratorium berwarna jingga, kuning, atau sian sesuai mode. Warna merah menandakan target gerak ditolak. `WASD`/panah bergerak, `M` ganti mode, `P` sembunyikan probe, `V` toggle heatmap; kontrol save berubah menjadi `Ctrl+S` supaya tidak bentrok dengan gerak `S`.

## Eksperimen 3 — audit denah non-destruktif

`IslandWaterValidator.audit(island)` menghitung:

- Jumlah tile air dan jumlah komponen jaringan air tersambung (BFS empat tetangga).
- Ukuran masing-masing komponen—sungai terpisah atau kolam terpisah tetap diperbolehkan.
- Jumlah petak air di batas peta sebagai indikator kontak pesisir potensial, **bukan validasi muara**.
- Jumlah tepi waterfall dan tepi yang melompat lebih dari satu tingkat elevasi.

Aturan validasi bersifat **peringatan**, tidak mengunci editor atau menyatakan aturan konstruksi Nintendo. Setelah semua air dilukis/diubah, HUD akan menampilkan notifikasi audit utama.

## Hasil pengujian

| Uji | Hasil | Hal yang diverifikasi |
| --- | --- | --- |
| `test_island.gd` | **PASS** | Baseline topologi dan mesh Sprint 04 |
| `test_physics.gd` | **PASS** | Raycast ground, tebing |
| `test_character.gd` | **PASS** | Probe kapsul tertahan tebing |
| `test_composer.gd` | **PASS** | Edit dan serialisasi layout |
| `test_editor_input.gd` | **PASS** | Mouse edit dan update hydrology |
| `test_bank_collision.gd` | **PASS** | Collider tepian, flow, dan kueri air |
| `test_water_rules.gd` | **PASS** | Keempat zona ditemukan, jalan/rendam/renang dibatasi, anti-tunneling sungai sempit, larangan menembus tebing |
| `test_water_validator.gd` | **PASS** | Jaringan utuh/terpisah, kontak border, waterfall melompat terlalu tinggi |
| `test_probe_ui.gd` | **PASS** | Pergantian zona overlay, mode, visibilitas probe, HUD |

Pemindaian 5.040 titik pada fixture 14×10 menemukan **4.501 darat, 74 tepi, 114 dangkal, dan 351 alur dalam**. Hitungan ini bergantung pada resolusi pencarian dan **bukan proporsi wilayah pulau secara fisik**.

## Capture dan pengamatan

- `terrain_preview_sprint04.png`: kondisi sebelum navigasi, sebagai acuan.
- `terrain_preview.png`: World Lab 05 dengan marker dan HUD.
- `water_zones_preview.png`: pita kuning di shoreline, bagian tengah alur berwarna sian. Overlay hanya debug dan tidak mengubah material air utama.
- `traversal_closeup.png`: mode berenang di tengah alur; HUD menampilkan zona dan jarak shore.
- `traversal_modes.gif`: 15 frame pada 960×540. Marker merah saat jalan/rendam tertahan dan sian saat mode berenang bisa memasuki alur. GIF ini merupakan gerak probe deterministik; bukan animasi karakter yang sudah di-rig.

## Kekurangan yang harus dikerjakan berikutnya

1. **Controller nyata:** transisi CharacterBody3D berjalan → wading → swimming dengan collision shape, gravitasi, buoyancy, posisi kaki, suara dan animasi yang benar.
2. **Bathymetry:** dasar sungai diprofil lebih detail sesuai kontur dan kedalaman, lalu samakan klasifikasi dangkal/dalam dengan kedalaman nyata. Saat ini zona berdasarkan jarak shore, bukan raycast dasar sungai.
3. **Performance:** untuk pulau besar, fungsi sampling radial dan raster overlay harus di-cache atau diganti query jarak ke poliline kontur yang sudah diproses.
4. **Editor terrain:** validasi perubahan sebelum commit, preview aturan sungai, undo/redo, brush kurva sungai yang artistik.
5. **Detail Nusantara:** pesisir pasang surut, mangrove, sungai berlumpur, tepi sawah, penyeberangan bambu, dan perahu, dengan sistem adaptif menurut bioma.

## Kesimpulan

Sprint ini membuktikan mekanik berbasis kontur bisa dipisahkan menjadi **data pulau → geometri → klasifikasi zona → aturan navigasi → HUD/test**. Hasilnya siap menjadi landasan gameplay orisinal, tetapi belum mereplikasi dimensi, animasi, atau perilaku fisik ACNH.
