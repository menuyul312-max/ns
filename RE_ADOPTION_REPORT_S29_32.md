# Nusantara World Lab — Sprint 29–32: RE-grounded terrain & coast

Tanggal laporan: 3 November 2026 (WIB)  
Proyek awal: Nusantara World Lab Sprint 28 (Godot 4.7+)  
Referensi: [`menuyul312-max/acnh-re-results`](https://github.com/menuyul312-max/acnh-re-results), `main` pada tree SHA **`5309d6f2a7659c85a4bce1bee6561f0f136f46e0`**  
Basis binary yang dinyatakan repository: **ACNH 1.0.0**, SHA-256 ELF `5bf707c3dc5dac0ad9635af7d336ec580f81c3f7876d0f55400d1900e3415d74`.

> Penggunaan: riset struktur dan kontrak perilaku, tidak mengimpor kode decompile, asset game, ROM, atau data mentah Nintendo. Semua modul Godot ditulis sendiri. Repository ini merupakan laporan RE; status uji native adalah **klaim dan artefak verifikasi dari repository**, bukan berarti kami menjalankan binary Nintendo di sesi ini.

## 1. Ledger bukti versus penerapan

| Topik | Bukti repository (konteks yang benar-benar diuji/didata) | Implementasi Godot | Batas / tidak boleh diklaim |
|---|---|---|---|
| Koordinat terrain | `0x52b5a0`: `s32*5 + 2.5` untuk XZ. `0x52b280`: truncation dan koreksi negatif; `-10 -> -3`. 562+452 kasus di konteks terbatas | `NativeTerrainReference.cell_center()`, `native_index()` | **5 bukan meter Godot**; ukuran tile Nusantara 2.1 tetap milik kita. Input NaN/infinite/extreme belum dibuktikan. |
| Lookup atribut | `0x18adf0`: record 52 byte, empat atribut pada offset 48..51; empat **sektor segitiga**, dibelah diagonal. 2.494 kasus | `sector()`, `attribute_at()` memakai **buffer uji ringkas 4 byte/sel**, bukan rekonstruksi ABI 52 byte | 48 byte lain, konversi preset 14-byte ke runtime 52-byte dan seluruh geometri mesh asli belum selesai. |
| Overlay | `0x181cd0`: empat byte override, sentinel 7 = inherit; 576 kasus | `attribute_at()` membaca override parsial dengan fallback base | Data `land_mask` kita bukan format overlay Nintendo dan tidak dilabeli sebagai itu. |
| Sampler ground | `0x162dc0`: N,W,S,E dengan offset 1.25 dari pusat; `0x187420` all WaterCheck, `0x1874f0` any PlayerNoEntry, `0x187610` exactly two WaterCheck; konteks native direkonstruksi | `four_points()`, `sample_four()`, tiga aggregator boolean; `NusantaraGroundQuery` memakai **empat titik pada tile Nusantara** | Atribut WaterCheck/PlayerNoEntry asli belum dipasang ke seluruh tabel 63 baris; contoh Godot memproyeksikan **mask dan river field Nusantara**, bukan reproduksi setiap predicate ACNH. |
| Kebijakan collision | Fragment `0xda9a60..0xda9b30`: selector 2 mempertahankan mode table, flag bit6 override, raw mask 0/0x80/0x201; 62.702 kasus terkait | `NativeCollisionPolicyReference.resolve()` sebagai **laboratorium raw flags saja** | **Jangan** menyamakan 0x201 dengan layer Godot atau menafsirkan artinya sebagai solid/ghost; solver geometris, friksi, unit waktu masih unknown. |
| Terraforming | `FieldLandMakingActionParam` terdiri dari 17 row; ada 1×1, 3×3, layer, `MeshEdgeDirType`, `PlaneChangeType`, `FallActionType` | Editor `T` + `U` untuk brush **1×1/3×3**, `set_land_area()` dengan seluruh operasi pada clone dulu (commit atomik) | Urutan aksi, sistem undo, mesh clip/marching-squares, aturan semua 17 action **belum terbukti** dari tabel saja. Transaksi atomik adalah keputusan desain Nusantara. |
| Pantai dan ombak | Repository terutama memetakan *terrain attribute dan policy*, **bukan shader, mesh shoreline, foam, atau dinamika gelombang** yang telah diuji native | Perbaikan deformer bibir pantai, radius corner, shader dual breaker dan broken foam **orisinal** | Ini _visual research_, bukan hasil pengukuran RE ACNH. Kontur masih grid, screenshot 3D baru belum tersedia. |

### Sumber langsung

1. [TERRAIN_RUNTIME.md](https://github.com/menuyul312-max/acnh-re-results/blob/main/acnh-re/docs/TERRAIN_RUNTIME.md) — native index, 52-byte grid, overlay, empat sampel, aggregator dan limit.
2. [FOCUS7_MECHANICS.md](https://github.com/menuyul312-max/acnh-re-results/blob/main/acnh-re/docs/FOCUS7_MECHANICS.md) — pembagian triangular sektor, 63-row ground, parameter pemain dan catatan open problem.
3. [terrain_collision_parameters.json](https://github.com/menuyul312-max/acnh-re-results/blob/main/acnh-re/output/mechanics/terrain_collision_parameters.json) — field name/hash dan 17 row landmaking.
4. [COLLISION_RESPONSE.md](https://github.com/menuyul312-max/acnh-re-results/blob/main/acnh-re/docs/COLLISION_RESPONSE.md) — mode, mask raw, scalar step, verifikasi bersyarat.
5. [PROXIMITY_GROUND.md](https://github.com/menuyul312-max/acnh-re-results/blob/main/acnh-re/docs/PROXIMITY_GROUND.md) — radius XZ, batas tinggi serta konsumen mask.
6. [DATA_CONTRACT.md](https://github.com/menuyul312-max/acnh-re-results/blob/main/acnh-re/docs/DATA_CONTRACT.md) — tipe, status ketidakpastian hash, sumber BCSV/BYML.
7. [continuation_frontier.json](https://github.com/menuyul312-max/acnh-re-results/blob/main/acnh-re/output/mechanics/continuation_frontier.json) — daftar terbuka untuk terrain/collision/nav dan batas claim.
8. [NATIVE_STAGE_WEATHER.md](https://github.com/menuyul312-max/acnh-re-results/blob/main/acnh-re/docs/NATIVE_STAGE_WEATHER.md) — identitas build ACNH 1.0.0 dan provenance ELF.

## 2. Sprint yang dikerjakan

### Sprint 29 — Evidence-first RE integration

- Meninjau root README, kontrak data, mekanik, terrain runtime, collision response dan frontier dari repo milik pengguna. Mengikat referensi ke tree SHA, bukan mengambil asumsi ACNHRecomp atau Animal Crossing: New Leaf.
- Menetapkan **verified / mapped-table / adapted / unknown** pada setiap perubahan. Metadata 63 ColGroundAttributeParam, 17 FieldLandMakingActionParam, 12 FieldLandMakingError **bukan** bukti semua aturan permainan sudah direkonstruksi.

### Sprint 30 — Native ground laboratory

- Modul baru `scripts/native_terrain_reference.gd`: native index negatif, tile center, empat sector triangular, overlay sentinel 7, empat titik, tiga boolean aggregator.
- Modul `scripts/nusantara_ground_query.gd`: transform rasio ke tile Nusantara yang tetap 2.1 unit; sampel actual `RiverContour.field_at` dan `CoastContour.on_island` di arah N/W/S/E.
- Tombol **Y** menampilkan flag four-point pemain/probe secara langsung di HUD. Ini *adaptasi* dan bukan konsumsi BCSV asli.
- Modul `scripts/native_collision_policy_reference.gd` mempertahankan angka mask raw tanpa menyuntikkannya ke collision Godot.
- `docs/re_native_four_sector.svg`: diagram siap audit.

### Sprint 31 — Landmaking transaction

- Tombol **T** masih mengaktifkan mode edit pantai. Tombol **U** memilih radius 0 / radius 1 (1×1 atau 3×3). Klik kiri menggali laut, kanan mengisi darat.
- `set_land_area()` menggunakan salinan island, mengecek seluruh 9 tile, link, dan connectivity; hanya setelah semuanya lolos, commit diterapkan sekaligus. Penolakan tidak meninggalkan terrain sebagian berubah.
- Mode 1×1 lama dipertahankan. Format save **tetap v7**, jadi kompatibel dengan sisa checkpoint.

### Sprint 32 — Visual coast pass

- Bibir corner mask diperlebar (radius 0.65 ke 0.82 unit Nusantara), domain warp samping sedikit diperbesar dan dibuat dua-frekuensi.
- `CoastBuilder.OCEAN_SHADER` diberi dua breaker, patahan world-space, coast normal dari gradien SDF, backwash dan parameter `breaker_strength` / `wave_temporal_scale`.
- **Belum dinyatakan lolos review visual 3D**; transisi tetap perlu dievaluasi di GPU/desktop. **Tidak ada klaim bahwa rumus shader ini dari Nintendo.**

## 3. QA / status yang jujur

- Tes Godot baru tersedia pada `tests/test_re_ground_contract.gd` dan `tests/test_atomic_land_brush.gd`.
- **7/7** tes Python kontrak matematis/struktur **lulus** memakai `python3 -m unittest discover -s tests -p test_re_offline.py -v`. Tes ini tidak menjalankan GDScript dan bukan pengganti render/test integrasi Godot.
- **Godot executable tidak tersedia pada kontainer kerja sesi ini**. Karena itu kami **belum menjalankan** suite Godot baru dan tidak mengklaim 35/35 lulus.
- Baseline Sprint 28 sebelumnya memiliki 33/33 tes Godot lulus **pada sesi terdahulu**, bukan verifikasi ulang code Sprint 32.
- Diagram `.svg` adalah ilustrasi matematis berdasarkan bukti sektor, **bukan capture viewport Godot**.

## 4. Backlog RE berikutnya (urutan tegas)

1. **Konstruksi mesh kontur:** pemodelan smooth clip/marching-squares level 0, collider berkoordinat sama, dukungan concave corner. Kita belum memiliki bukti native mesh dari repo; harus dinilai sebagai inovasi grafis sendiri.
2. **Terrain flags:** petakan semua atribut dari 63 row `ColGroundAttributeParam` untuk *proyek simulasi* yang memvalidasi pengaruh tiap flag. Jangan langsung menamai hash unknown.
3. **Terraforming actions:** audit 17 row `FieldLandMakingActionParam` dan 12 row `FieldLandMakingError` versus fungsi consumer terkait; migrasi tiap aksi ke aturan Nusantara setelah caller cukup jelas.
4. **Coast physics:** swim entry, surf force, kedalaman, buoyancy dan collision response asli masih perlu bukti tambahan; hingga saat itu gunakan model fisika Nusantara yang ditandai orisinal.
5. **Art QA:** jalankan proyek di Godot 4.7+, ambil screenshot A/B dari kamera identik, periksa wave foam, waterfall side seam, corner mesh, dan framerate dengan GPU.

**Kriteria sukses:** perilaku spesifik yang berasal dari RE diberi tautan dan uji pembanding; algoritme orisinal terpisah; editor tidak korup pada pembatalan; tidak ada klaim ACNH 1:1 sebelum validasi visual dan runtime.
