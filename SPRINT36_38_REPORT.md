# Nusantara World Lab — Sprint 36–38: Shoreline-Aligned Beach Color

**Checkpoint:** 2026-11-03, Asia/Jakarta. **Prototipe terimplementasi; render Godot dan tes GDScript belum dijalankan di sesi ini.**

## Latar belakang dan bug visual

Sprint 35 mengubah beberapa sudut teluk menjadi *concave fillet* yang benar-benar menambah mesh tanah dan collision. Namun, batas warna pasir–rumput masih memanggil `CoastContour.distance_to_coast()` yang menghitung jarak ke **persegi hilangnya tile**. Akibatnya sudut pantai tampak melengkung, sementara warna masih cenderung kotak/bergaris grid. Itu bukan masalah shader ombak; itu inkonsistensi dua definisi shoreline.

## Yang dibangun

### Sprint 36 — satu sumber geometri untuk pasir

`CoastContour.prepare_shoreline_cache(island)` kini mengekstrak polyline dari komponen yang dipakai builder 3D:

1. Tepi lurus berlekuk milik `TerrainBuilder._edge_position`, setelah `CoastContour.warp_ground`.
2. Interval pemotongan pangkal/ujung yang **sama** dengan skirt pantai, dipusatkan pada `TerrainBuilder._shore_edge_bounds`.
3. Sudut cembung yang dibulatkan lewat `TerrainBuilder._corner_arc_position`.
4. Sudut cekung di sel laut lewat `TerrainBuilder._concave_arc_point` (hanya jika 3 penopang darat level 0 kering).

Pewarnaan vertex `_ground_color` masih menggunakan *smooth blend* rumput–pasir asli Nusantara; yang berubah hanyalah jarak geometris yang diberikan ke fungsi tersebut. Dengan demikian mesh level tinggi, sungai, tanaman, dan layer dekor tetap memakai sistem sebelumnya.

### Sprint 37 — cache spasial dan invalidasi editor

- Polyline diindeks per tile, setiap segmen didaftarkan ke *bin* yang bersinggungan ditambah halo ±2 tile.
- Untuk vertex tertentu, perhitungan jarak titik-ke-segmen hanya membaca satu bin lokal, bukan menelusuri tepi dari seluruh pulau.
- `IslandDefinition.coastline_revision` naik pada `set_land`, `set_height`, `set_water`, dan `set_coast_inset`, memicu rekonstruksi otomatis saat query berikutnya.
- `TerrainBuilder.build_world` memaksa rekonstruksi setiap pembentukan mesh, melindungi kasus JSON load/seed yang mengubah data langsung tanpa setter. Simpan denah lama tetap kompatibel karena revision hanya runtime state, tidak menambah field serialisasi.
- Pesisir terluar tetap memakai sampel `boundary_at` historis. Pada titik lebih dari lima unit dari batas pulau, tidak lagi diperlukan empat pemanggilan warp untuk setiap vertex.

### Sprint 38 — pengujian, diagnostik, integrasi

- Ditambah `tests/test_s38_shoreline_cache.gd`: jarak ke inlet, keselarasan skirt–warna, pemulihan sel laut ke darat, penghapusan fillet ketika sisi teluk menjadi sungai.
- Ditambah `tests/test_s38_offline.py`: jarak segmen, jangkauan halo dua tile untuk pita pantai 3,35 unit, integrasi fungsi bersama, dan invalidasi revisi.
- HUD, nama proyek, dan ekspektasi `tests/test_probe_ui.gd` dinaikkan ke `WORLD LAB 38`.
- Diagram ilustratif CPU baru: `s38_sandband_curve_diagnostic.png`.

## Hasil pengujian yang terverifikasi

```bash
python3 -m unittest discover -s tests -p 'test*offline.py' -v
```

**15/15 PASS** (7 kontrak RE, 4 Sprint 35, 4 Sprint 38). Diagram diperiksa secara visual dan arsip ZIP diperiksa integritasnya.

**37 skrip `test_*.gd` belum dijalankan.** Executable Godot tidak ada di lingkungan kerja, paket engine juga tidak ada di cache yang bisa ditemukan. Tidak ada klaim tes fisika Godot lulus, capture Godot baru, peningkatan FPS terukur, atau paritas visual ACNH. Jalankan pengujian minimum berikut pada mesin dengan Godot 4.7+:

```bash
godot --headless --path . --script res://tests/test_s38_shoreline_cache.gd
godot --headless --path . --script res://tests/test_concave_fillet.gd
godot --headless --path . --script res://tests/test_island_mask.gd
godot --headless --path . --script res://tests/test_probe_ui.gd
```

Lanjutkan dengan semua skrip `tests/test_*.gd`. Periksa capture kamera identik dari skenario *one-cell cove*, U-shaped inlet, muara sungai, mask edit 3×3, dan edge bevel sebelum/telah edit.

## Provenance penelitian RE ACNH

Rujukan tetap repository milik pengguna: <https://github.com/menuyul312-max/acnh-re-results>, terutama analisis ground runtime di <https://github.com/menuyul312-max/acnh-re-results/blob/main/acnh-re/docs/TERRAIN_RUNTIME.md>. Interpretasi koordinat native, empat sub-sektor dasar, dan aturan overlay dilacak pada `RE_ADOPTION_REPORT_S29_32.md`.

**Penting:** *beach-distance cache*, sampel lengkungan, dan parameter blend adalah teknik renderer orisinal Nusantara, **bukan** hasil dekompilasi algoritme visual Nintendo. Data RE yang tersedia belum membuktikan desain mesh pantai asli atau shader laut ACNH.

## Gap dan prioritas berikut

| Gap | Dampak | Rencana |
| --- | --- | --- |
| Siluet pantai masih didasarkan pada mask tile | Segmen lurus panjang tetap berpola grid | Ekstraksi kontur global multi-ring dan spline yang disinkronkan dengan collision |
| Inlet radius 0,72 konstan | Beberapa teluk terlalu simetris | Radius adaptif menurut kelengkungan/geometri sekitar, tanpa menutup kanal |
| SDF ombak berbeda representasi dari cache pasir | Ada potensi selisih sub-pixel antarmaterial | Bakar field pasir+laut dari polyline/SDF yang sama pada satu resolusi adaptif |
| Query cache dibuat ulang pada tiap edit penuh | Bisa mahal di pulau besar | Invalidasi *dirty rectangle* untuk brush 1×1 dan 3×3; benchmark waktu nyata |
| Tidak ada Godot runtime saat development | Tidak ada bukti collision/render final | Siapkan runner ber-Godot 4.7+, screenshot dan tes body physics end-to-end |

## Batasan diagram

`s38_sandband_curve_diagnostic.png` adalah ilustrasi diferensial matematika (simulasi bitmap, tanpa shader `warp_ground`), dibuat untuk menunjukkan masalah warna yang mengikuti kotak versus warna yang mengikuti lengkungan. Ini **bukan screenshot mesin Godot** dan tidak dapat digunakan untuk mengklaim pencapaian visual setara ACNH.
