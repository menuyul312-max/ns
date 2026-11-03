# Sprint 14 — Audit konektivitas terrain, tebing, dan sungai

Tanggal: 2 November 2026. Proyek orisinal Godot 4.7.2 untuk fondasi mekanik game Nusantara.

## A. Kaitan dengan hasil RE ACNH

Arsip reverse engineering yang dipelajari pada Sprint 12–13 memberi struktur grid terrain, dua lapisan metadata, nilai elevasi, dan kategori error terraforming (`FieldLandMakingError`, `FieldLandMakingActionParam`). Namun **belum ada bukti pada arsip bahwa algoritma asli ACNH memakai BFS komponen kering, atau menolak setiap edit yang memutus konektivitas**. Sprint 14 adalah **hipotesis desain Nusantara**, dibuat terpisah dan dapat dimatikan untuk evaluasi.

Tidak ada model, tekstur, aset proprietary, atau kode runtime Nintendo yang dimasukkan.

## B. Definisi graf prototipe

- **Node:** satu tile darat `water=false`.
- **Sisi graf:** dua tile dry yang bertetangga 4-arah (utara/timur/selatan/barat) dan `height`-nya sama.
- **Tidak berlaku:** gerak diagonal, lompatan, tangga, landai/ramp, jembatan khusus, berenang, perahu, pintu, dan jalur navmesh di dalam bangunan.
- **Pencarian:** BFS untuk memberikan `region_id`, ukuran region, jumlah dry tile, dan region terbesar; satu traversal peta.
- **Preview satu edit:** klon state, terapkan calon perubahan elevasi/air pada klon, lalu ulangi audit. Tile asli tidak dimutasi sampai diterima.

## C. Aturan akses `K` (default OFF)

Untuk tiap region awal, identifikasi tile yang **tidak diubah** dan masih darat setelah edit. Bila tile-tile ini terpecah menjadi dua atau lebih region baru, edit ditolak dengan kode `ACCESS_SPLIT`.

Definisi ini sengaja **tidak** mensyaratkan semua daratan berada pada satu region. Tebing terpisah atau pulau kecil yang sudah ada tidak menyebabkan penolakan otomatis. Membuat satu bukit baru di pinggir jalur juga bisa diterima jika tidak memutus akses antar lokasi lain. `K` tidak mengubah mode `B`; keduanya opsional dan independen.

Perbaikan integritas terpisah: editor sekarang selalu menolak penambahan air tepat di bawah pohon/rumah. Ini mempertahankan invariant serialisasi schema v4 walaupun `B` dan `K` sedang OFF.

| Skenario | Proteksi OFF | Proteksi ON |
| --- | --- | --- |
| Menambahkan air pada satu-satunya penghubung dua sisi | Berhasil, dua region terpisah | Ditolak `ACCESS_SPLIT` |
| Menaikkan tile tengah di koridor satu-sel | Berhasil, koridor terbelah | Ditolak `ACCESS_SPLIT` |
| Mengangkat tile tepi tanpa memutus hubungan tile lain | Berhasil | Berhasil |
| Memotong jalur utama dengan alternatif memutar tersedia | Berhasil | Berhasil |
| Mengedit plateau yang memang sudah terpisah | Berhasil | Berhasil selama tidak memutus tile lainnya |

Visual `N` menampilkan warna tiap region dari hasil `IslandAccessOverlay`. Warna bukan hasil RE, hanya lapisan debug. Bila `K` aktif dan edit ditolak, marker merah muncul pada tile sasaran, bersama kode dan pesan di HUD.

## D. Performa dan batasan

Untuk ukuran studi 112×96 (10.752 tile), audit BFS berjalan pada batas (O(W × H)) dalam bentuk graph dengan maksimal 4 tetangga/node. Preview melakukan dua audit dan membuat satu salinan seluruh state; pada pulau besar masih membutuhkan profiling agar tidak menimbulkan lag editing. Overlay dibangun ulang setelah perubahan terrain, tidak setiap frame.

Audit level tile tidak setara dengan `CharacterBody3D` sweep/raycast. Satu celah visual kecil, radius kapsul, pinggiran sungai melengkung, slope, atau prop blocker dapat membuat jalur graf berbeda dari jalur fisika sebenarnya. Hasil ini merupakan **filter desain kasar**, bukan jaminan navigasi aktor nyata.

## E. Verifikasi dan tangkapan layar

`tests/test_access_audit.gd` memverifikasi jembatan, tebing, alternatif, area isolasi awal, non-mutasi preview, overlay, dan grid 112×96. Semua `tests/test_*.gd` merupakan tes regresi termasuk fitur Sprint 13.

`tests/capture_sprint14.gd` menghasilkan empat gambar PNG: sebelum, penolakan, simulasi tanpa proteksi, dan overview pulau utama. Ini frame sungguhan dari Godot, bukan gambar ilustratif generatif.

## F. Urutan penelitian berikutnya

1. Audit keterjangkauan berbasis **navmesh/capsule** dan penyelarasan dengan `WaterRules.can_traverse_path`.
2. Tambahkan **ramp, jembatan, tangga, dan transportasi air** sebagai jenis edge graf terpisah, lalu uji apakah dua sisi benar-benar bisa dilintasi.
3. Rute dari spawn ke objek layanan (rumah, balai desa, dermaga), bukan hanya hubungan antar semua tile.
4. Untuk klaim kesetiaan terhadap ACNH, telusuri caller function native terhadap aturan terraforming dan edge case sebelum mengadopsi numerik/radius yang lebih spesifik.
