# Catatan teknis — Nusantara World Lab Sprint 17

## Fokus

Mengatasi batas panjang jembatan Sprint 16 dan menambah pertemuan visual dek dengan pasir tepian. Prototipe memakai pengamatan umum bentuk pulau ala ACNH sebagai riset desain, **bukan port kode atau klaim parameter native Nintendo**.

## Model data dan validasi

| Entitas | Model Sprint 17 | Keterbatasan |
| --- | --- | --- |
| Satu jembatan | Rentang 1–3 tile air secara E/W (`kind=5`) atau N/S (`kind=6`) | Tidak diagonal atau melewati 4+ tile |
| Ujung jembatan | Dua bank kering dengan level sama, bebas pohon/rumah/konektor | Tidak ada fondasi bertingkat atau penyesuaian jarak bebas multi-tile |
| Simpanan | Skema v5 yang sama; tiap sel air diberi marker sumbu yang sama | Integritas lintasan bergantung pada validasi seluruh span |
| Editor | Pasang dan lepas seluruh span dalam satu tindakan | Belum punya pilihan arah eksplisit saat dua sumbu valid |
| Akses | Graf 4-arah mencakup semua sel dek dan menolak edit `ACCESS_SPLIT` | Belum memodelkan lebar, NPC crowd, atau arus lalu-lintas |
| Walk physics | Satu collider triangulasi dengan lengkungan rendah kontinu | Tidak memodelkan deformasi papan atau gesekan khas material |

### Alur edit

1. Menelusuri rangkaian air lurus ke kedua bank, berhenti jika melebihi tiga tile.
2. Memvalidasi level semua tile air, bank bebas objek, dan tidak ada marker konektor lain.
3. Menyalin data pulau, memberi marker semua sel bridge, lalu menguji integritas tetangga dan keterhubungan.
4. Menerapkan seluruh perubahan ke data sekaligus; membangun ulang satu dek panjang pada redraw berikutnya.
5. Penghapusan mengikuti prosedur simetris. Saat mode `K` aktif, bridge yang merupakan satu-satunya penghubung tidak boleh dihapus.

## Geometri sambungan tepian

- `IslandLinkBuilder` mengukur bentang total sebagai `(jumlah tile + 0.28) × TILE_SIZE`, untuk menyediakan bibir pendek yang masuk ke daratan di setiap ujung. Jumlah irisan meningkat menjadi `12 × jumlah tile`.
- Mesh tampak dan `ConcavePolygonShape3D` tetap satu kesatuan, dengan puncak busur prototipe +0.225 unit relatif dasar.
- Setiap ujung mendapat `BankApronA/B`: sapuan warna tanah dengan *alpha fade* dari tepi dek ke tanah, dihitung dari sebaran non-linier pada lebar apron. Batu kecil memecah garis pertemuan lurus di sisi luar jembatan.
- Apron dan bebatuan sengaja **tanpa collider** agar tidak membuat lompatan kecil pada roda physics karakter. Geometri kontur sungai global belum diganti; apron hanyalah penutup transisi lokal.

## Pengujian

- `test_bridge_spans.gd`: stamping tiga tile, satu mesh/36 bilah visual, apron, graf akses, jalan kaki menurut aturan, simpan/muat v5, invalidasi bank, penolakan `K`, penghapusan atomik, limit panjang.
- `test_bridge_span_physics.gd`: aktor `CharacterBody3D` benar-benar menyeberangi jembatan tiga tile dan telapak melewati puncak busur.
- Pengujian Sprint 15–16 tetap berjalan untuk jembatan satu tile, ramp, ketinggian tebing, water/depth, animasi, IK, dan migrasi data.
- Screenshot: `s17_before_wide_river.png`, `s17_after_wide_bridge.png`, `s17_actor_midspan.png`, `s17_bank_apron_detail.png`.

## Batasan klaim dan roadmap

Data ini harus dianggap **hipotesis dan desain orisinal** sampai tersedia bukti reverse engineering yang menghubungkan rumus, ukuran, dan toleransi ke fungsi atau parameter ACNH yang spesifik. Selanjutnya perlu: bank contour benar-benar melengkung sebagai bagian dari mesh terrain dan water, high/low landing bertingkat, jembatan panjang yang mengikuti kelokan, tes kualitas siluet dan seam visual, serta profiler rebuild mesh pada peta besar.
