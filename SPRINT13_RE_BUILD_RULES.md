# Sprint 13 — Audit RE terhadap aturan konstruksi pulau

Tanggal: 2 November 2026. Input pengguna: `acnh-re-results-main.zip` (hasil riset RE ACNH versi 1.0.0). Output: implementasi **orisinal** Godot 4.7.2 untuk eksperimen game Nusantara.

## 1. Yang didukung data RE

| Asal data | Fakta pada dump | Belum bisa disimpulkan |
| --- | --- | --- |
| `output/tables_resolved/FieldLandMakingError.json` | **12 kategori error** bernama, di antaranya `CliffCreateExistNearTree`, `CliffBreakExistNearWater`, `CliffCreateExistStructure`, `CliffBreakExistStructure`, `RiverExistNearTree`, `RiverExistBackFaceFall`, `CliffCreateExistFrontFall`, `RiverExistStructure`, dan `SystemError`. | Kondisi boolean lengkap, jarak spasial, prioritas error, dan perilaku saat edge-case. |
| `output/tables_resolved/FieldLandMakingActionParam.json` | **17 baris konfigurasi** dengan kolom `ActionRange`, `Layer`, `SuccessResult`, `PlaneChangeType`, `FallActionType`, `UpdateParts`, `FallToRiver`, `MainType`, `ActionLockRange`. `ActionRange` memuat nilai `1x1` dan `3x3`. | Apakah `3x3` adalah area query/lock/collision, preview, atau brush yang mengubah 9 sel. |
| Struktur terrain dari Sprint 12 | Elevasi dan dua lapisan metadata visual adalah bagian dari catatan grid yang dapat dipelajari. | Geometri rounded cliff, detail penumbra, angka meter asli ACNH, atau aturan penempatan pulau yang lengkap. |

Nama label error merupakan **petunjuk kategori**; belum cukup untuk mengklaim identitas native predicate. Dua belas label keseluruhannya: `CliffExistOnItem`, `SystemError`, `CliffCreateExistStructure`, `CliffCreateExistNearTree`, `CliffBreakExistNearWater`, `CliffBreakExistNearTree`, `RiverExistNearTree`, `CliffBreakExistStructure`, `CliffBreakExistNearOnCliff`, `RiverExistBackFaceFall`, `CliffCreateExistFrontFall`, `RiverExistStructure`.

## 2. Implementasi eksperimen Nusantara

| Keputusan desain kita | Status | Cara menguji |
| --- | --- | --- |
| Validasi `B` OFF secara default (perilaku lama) | Implementasi orisinal | Naikkan tile dekat pohon sebelum `B` ON. |
| Context radius 1 cell = **3×3**, hanya **1 tile** diubah | Hipotesis eksplisit | Taruh pohon di (3,3), edit (4,4) ditolak, edit (5,5) diterima. |
| `OCCUPIED_TILE`, `TREE_NEAR_EDIT`, `BUILDING_NEAR_EDIT` | Predikat prototipe; diinspirasi label error | `Shift+klik kanan` untuk menaruh fitur, lalu `B` ON. |
| `CLIFF_NEAR_WATER` saat menurunkan elevasi dekat air | Predikat prototipe | Buat jalur air dan coba turunkan tile tetangga. |
| `WATERFALL_NEAR_EDIT` saat edit dekat dua air berbeda elevasi | Predikat prototipe | Coba menaikkan tile dekat air terjun. |
| `water_remove` tetap bisa dilakukan saat validasi ON | Kebijakan pemulihan desain | Hapus air untuk memperbaiki layout. |
| Raycast editor mask 1; prop collision layer 16; karakter mask 17 | Perilaku Godot lokal | Klik terrain di dekat prop; aktor menabrak prop. |
| Pohon dan rumah panggung modular dari primitive mesh | Aset orisinal sementara | Lihat capture after/overview. |

Jangan mengartikan nama `CLIFF_NEAR_WATER` dlsb sebagai identifier dalam kode ACNH: itu **identifier buatan proyek** untuk memudahkan QA. Penanda tile merah menunjukkan hasil pemeriksaan, bukan efek dari game Nintendo.

## 3. Data, persistensi, dan integritas

`IslandDefinition` memiliki array `levels`, `water`, `occupants`, dan field `unit/variation/rotation` untuk dua lapisan terrain. `occupants` mengkodekan `0=kosong`, `1=pohon`, `2=rumah panggung`. Serialisasi `schema_version=4`; v1–v3 dapat dimuat dengan occupancy kosong. Parser menolak ukuran array yang berbeda, nilai occupancy bukan integer 0..2, dan penghuni yang bertabrakan dengan water tile.

## 4. Yang belum dikerjakan / tingkat keyakinan

1. **Prioritas riset berikutnya:** telusuri *native callers* dan function references dari `FieldLandMakingActionParam`/`FieldLandMakingError` sebelum merinci kapan `3x3` dipakai, batas cliff adjacency, front/back waterfall, dan keluasan river operation. **Data yang ada belum memverifikasi semua keputusan Sprint 13.**
2. Validasi global river continuity, radius bangunan multi-tile, akses pintu rumah, inventory/biaya penataan, tanaman tumbuh, area terlarang permanen, dan pengukuran gaya gerak perlu desain lebih lanjut.
3. Collision prop saat ini proxy sederhana; belum memakai navmesh obstacle atau spatial indexing. Atap rumah limas dan kanopi pohon masih *placeholder* berbentuk primitif.
4. Angka `TILE_SIZE=2.1`, `HEIGHT_STEP=1.55`, kecepatan, gaya arus, dan offset kolisi **bukan** parameter resmi ACNH.

## 5. Reproduksi

Jalankan `tests/test_build_rules.gd` untuk pemeriksaan aturan. Jalankan semua berkas `tests/test_*.gd` untuk regresi. Jalankan `tests/capture_sprint13.gd` dengan renderer Godot yang aktif untuk menghasilkan `build_rules_before.png`, `build_rules_after.png`, dan `build_rules_overview.png` di root proyek.

Kode dan mesh ini dibuat secara mandiri untuk Nusantara; tidak menyertakan sumber, tekstur, model, atau paket Nintendo.
