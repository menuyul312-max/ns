# Nusantara World Lab — Catatan teknis Sprint 16

## Tujuan

Menyempurnakan sambungan buatan dari Sprint 15 agar penataan pulau lebih aman dan penampilan jembatan/ramp lebih terbaca pada kamera isometrik. Riset ACNH digunakan sebagai inspirasi pembagian tugas sistem (terrain, jalur, collision, placement); **tidak ada parameter yang diklaim hasil ekstraksi biner game Nintendo**.

## Aturan ruang bebas

| Kasus | Keputusan | Kode ketika ditolak |
| --- | --- | --- |
| Jembatan tepat satu tile air, dua bank kering sejajar, kosong | Diterima | — |
| Pohon/rumah/konektor lain di bank jembatan | Ditolak | `BANK_BLOCKED` |
| Tinggi bank berbeda dari ketinggian tile air | Ditolak | `BANK_LEVEL` |
| Tidak ada dua bank kering pada orientasi E-W atau N-S | Ditolak | `NO_BANK_PAIR` |
| Ramp pada tile rendah, tetangga kering lebih tinggi tepat satu level, kosong | Diterima | — |
| Rumah/pohon/konektor lain pada landasan atas ramp | Ditolak | `RAMP_LANDING_BLOCKED` |
| Tidak ada tebing +1 level | Ditolak | `NO_CLIFF_STEP` |
| Pohon/rumah ditambahkan ke endpoint konektor aktif | Ditolak | `LINK_LANDING` |
| Konektor baru memakai endpoint konektor lama sehingga ilegal | Ditolak | `LINK_CONFLICT` |

Aturan ini belum memodelkan ruang bebas multi-tile, jembatan diagonal, ramp dua tile, pondasi bergeser, dan akses kursi roda; semua memerlukan desain data serta pengujian tersendiri.

## Detailing geometris

- `IslandLinkBuilder`: dek dasarnya tetap 12 irisan triangulasi kontinu dengan `ConcavePolygonShape3D` pada collision layer 32.
- **Jembatan bambu Nusantara**: papan variasi warna halus, dua balok pinggir segmental, dua pasang tiang penyangga di air, dan empat penanda ujung.
- **Ramp kayu**: papan mengikuti tangen kemiringan permukaan tiap irisan; dua balok sisi mempertegas bibir lintasan.
- Papan, balok, dan penyangga adalah visual-only, tidak menambah collider tajam. Satu permukaan tetap bertanggung jawab untuk berjalan, raycast kaki, dan deteksi zona daratan.
- `TerrainBuilder` dari Sprint 15 mempertahankan dinding tebing di kanan-kiri ramp dan membuka bagian selebar jalur. Saat ini tepian masih bisa ditingkatkan dengan batu/rumput penutup sambungan yang mengikuti kurva alih-alih balok datar.

## Verifikasi

- `tests/test_link_clearance.gd`: aturan baru, pencegahan invalidasi, dan pemeriksaan node visual.
- `tests/test_link_physics.gd`: **kapsul CharacterBody3D** benar-benar menyeberangi dek dan mencapai elevasi tinggi. Pengujian menggunakan collider Godot aktual, bukan sekadar graf BFS.
- Tes Sprint 15 tetap digunakan untuk validasi migrasi data v1–v4 ke v5, air/sungai, collider tebing, akses graph, animasi dan HUD.
- Capture Godot sesungguhnya: `s16_validation_rejected.png`, `s16_island_after.png`, `s16_bridge_detail.png`, `s16_ramp_detail.png`.

## Batasan hasil reverse engineering

Parameter tile, radius, sudut, permukaan arched bridge, material bambu, aturan clearance dan panjang sambungan **merupakan pilihan desain prototipe**, bukan angka dari executable ACNH. Untuk menyamakan lebih dekat dengan ACNH diperlukan bukti terpisah tentang ukuran, bentuk blueprint konstruksi, constraint tebing/sungai, cara character controller memilih lantai, dan edge clipping. Setiap klaim sebaiknya diberi status `terverifikasi sumber`, `teramati video`, atau `hipotesis Nusantara` sebelum dijadikan aturan permanen.

## Arah Sprint 17

1. Profil tepian bank organik dan sambungan yang mengikuti kontur sungai (bukan potongan lurus).
2. Metadata footprint multi-tile agar jembatan panjang dan ramp berlapis dapat didefinisikan tanpa enumerasi jenis baru tiap ukuran.
3. Tes otomatis untuk seam visual, minimum clearance tubuh, simetri arah, kombinasi tebing-rumah-jembatan, serta biaya rebuild mesh per edit.
