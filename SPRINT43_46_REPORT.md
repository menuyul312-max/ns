# Nusantara World Lab — Sprint 43–46: Global Coast Rings + Island Preview

Tanggal: 2026-11-03 (Asia/Jakarta). Status: implementasi prototype. **Belum menjalankan Godot atau menghasilkan capture frame renderer Godot dalam sesi ini.**

## 1. Capture pulau terkini: keterbatasan dan solusi

Godot dan Blender tidak ditemukan pada lingkungan kerja. Supaya keadaan pulau bisa direview, saya menambah alat CPU `tools/cpu_island_preview.py` yang mereplikasi secara independen **denah `IslandDefinition.fixture_coast_mask()`**, lalu menghasilkan:

- `s46_island_cpu_preview.png`: visualisasi isometrik diagnostik + peta 2D yang mendekati penempatan darat, laut, tebing, dan sungai berdasarkan data tile; **tidak menjalankan renderer Godot**, shader, animasi, collision atau efek air.
- `s46_global_contour_audit.png`: pemeriksaan outline denah global dari mask daratan, dengan cincin luar berwarna krem dan lubang air berwarna merah muda; ini **diagram mask, bukan siluet mesh yang sudah di-warp**.

Pada keadaan terkoreksi fixture memiliki **20×14 tile**, **159 tile darat**, **121 tile laut**, **24 tile tebing tinggi**, dan **18 tile sungai**.

Untuk menghasilkan capture Godot asli kemudian, jalankan dengan Godot 4.7+ dan GPU/display atau display virtual yang mendukung renderer:

```
godot --path . --script res://tests/capture_sprint46.gd
```

Skrip baru ini menghasilkan empat gambar nyata *bila berhasil dijalankan*:

1. `s46_godot_island_overview.png`
2. `s46_godot_eastern_cove.png`
3. `s46_godot_southern_outlet.png`
4. `s46_godot_contour_debug.png` (outline topologis mask yang **bukan** persis garis mesh)

**Empat file itu belum dibuat** dalam sesi ini, jadi tidak disertakan sebagai hasil render yang sudah ada.

## 2. Sprint 43: kontur global pulau

Modul baru `scripts/island_coast_loops.gd` mengekstrak graf tepi terarah dengan land di satu sisi, kemudian menelusuri cincin tertutup menggunakan prioritas belok kanan pada simpul yang mempunyai lebih dari satu edge keluar. Hasilnya berupa daftar `PackedVector2Array` world-space dan metadata:

- `islands`: jumlah cincin luar (termasuk pulau-pulau terpisah)
- `holes`: lubang air internal (cincin dengan area bertanda sebaliknya)
- `broken_chains`: rantai yang gagal ditutup
- `boundary_edges`, `signed_area_world`, `perimeter_world`, per-ring `area_tiles` dan `vertex_count`.

Ambiguitas sentuhan diagonal ditangani agar dua islet yang hanya bersentuhan di ujung sudut tetap **dua** pulau, bukan satu komponen besar yang keliru.

**Penting:** garis ini masih mengikuti perimeter tile *raw mask*; ini belum mesh kontur bebas dan **bukan pengganti** collider yang dipakai mekanik jalan/renang. TerrainBuilder tetap authoritative sampai ada triangulasi, collision, dan uji Godot yang menyeluruh.

## 3. Sprint 44: audit menemukan bug denah nyata

Denah contoh Sprint 26 selama ini berkomentar *detached sandbar*, namun audit membuktikan gosong tenggara tersambung ke pulau utama melalui satu jalur pada `x=16,z=10`. Sebelum koreksi, mask berisi **160 darat/120 laut** dan hanya **satu** komponen pulau meskipun ada gosong yang tampak terpisah sebagian.

Di `IslandDefinition.fixture_coast_mask()`, sel `x==16` pada baris `z>=9` sekarang menjadi kanal laut permanen dalam fixture, sehingga gosong tidak tersambung. Setelah koreksi, ring audit menunjukkan **2 pulau**, **0 lubang**, **0 rantai terbuka**, **84/84 edge tercakup**, dan konservasi luas bertanda **159 tile**.

Koreksi tersebut hanya mengubah **fixture demo**, bukan menyunting denah yang telah disimpan pengguna melalui `user://`.

## 4. Sprint 45: integrasi dan regresi

- `scripts/main.gd`: menyimpan `coast_audit` setelah setiap `_refresh_terrain()`; HUD kini memberi jumlah cincin pulau/cekungan sehingga editor topologi dapat mendeteksi pemisahan gugusan.
- `tests/test_s46_coast_loops.gd`: rectangle, hole internal, dua islet diagonal, fixture pesisir asli, konservasi luas tiap kasus.
- `tests/test_s46_offline.py`: 5 tes offline tambahan, termasuk **270 mask acak** untuk menguji seluruh edge tertutup dan jumlah area tiap mask; hasilnya juga menjadi dasar diagram kontur 2D.

## 5. Sprint 46: rute capture engine dan pengemasan

`tests/capture_sprint46.gd` mengambil kamera tetap untuk overview, teluk timur, muara selatan dan overlay kontur audit. Script dibuat agar verifikasi visual dapat dilakukan di mesin dengan engine tanpa mendesain ulang capture manual.

Nama project dan HUD disinkronkan ke `WORLD LAB 46`, test ekspektasi HUD diperbarui.

### Tes yang benar-benar dijalankan

```
python3 -m unittest discover -s tests -p 'test*offline.py' -v
```

**24/24 tes Python offline PASS** (19 checkpoint Sprint 42 dan 5 sprint baru). Uji kode GDScript berjumlah **39 skrip `tests/test_*.gd`, belum dijalankan** karena Godot CLI/runtime tidak tersedia. Tidak ada pengukuran FPS/physics nyata.

## 6. Referensi hasil RE dan apa yang belum dapat disimpulkan

Sumber penelitian tetap [`menuyul312-max/acnh-re-results`](https://github.com/menuyul312-max/acnh-re-results), dengan dokumentasi terrain runtime pada [`acnh-re/docs/TERRAIN_RUNTIME.md`](https://github.com/menuyul312-max/acnh-re-results/blob/main/acnh-re/docs/TERRAIN_RUNTIME.md). Kontrak koordinat native, tile ground, overlay, dan landmaking tercatat dalam `RE_ADOPTION_REPORT_S29_32.md`.

**Kontur ring, definisi kanal, algoritme penelusuran edge, dan preview 3D dalam paket ini adalah rancangan orisinal untuk Nusantara, bukan port atau bukti algoritme tersembunyi ACNH.**

## 7. Prioritas sprint berikut

1. **Contour-to-mesh:** smoothed ring dengan *clearance constraint* terhadap pulau/lubang lain, triangulasi watertight, dan collision yang memakai triangulasi sama.
2. **In-game terraforming:** validator brush memperbarui local contour dan menolak perubahan yang menciptakan tepi/collision tidak valid.
3. **Real capture + regression:** jalankan 39 tes GDScript dan empat screenshot Godot pada GPU. Audit gap visual: tebing, pasir, busa ombak, air terjun, river mouth.
4. **Benchmark:** profil cache/pengukuran edit untuk 20×14, 112×96, dan 3×3 brush; optimasi dirty regions.
