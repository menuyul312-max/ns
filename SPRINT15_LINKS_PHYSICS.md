# Sprint 15 — Ramp, jembatan, dan fisika penghubung pulau

Tanggal: 2 November 2026. Prototipe Godot 4.7.2 untuk game Nusantara orisinal.

## A. Hubungan dengan studi ACNH

Studi RE Sprint 12/13 telah menemukan record grid terrain (termasuk height dan dua layer metadata) serta kategori error terraforming. **Belum tersedia bukti native yang memadai tentang format ramp/jembatan, ukuran, collision shape, navigasi aktor, atau aturan lokasi ACNH yang persis.** Semua data konektor dan geometri pada sprint ini adalah rancangan baru Nusantara; tidak menyalin model, tekstur atau algoritma proprietary Nintendo.

## B. Format konektor

`IslandDefinition` menyimpan `PackedByteArray connectors` berukuran `width*depth` dengan nilai 0..6:

| Nilai | Makna | Prasyarat |
| --- | --- | --- |
| 0 | Tidak ada konektor | — |
| 1..4 | Ramp N/E/S/W | Tile rendah harus kering, kosong dari fitur, bersebelahan arah yang dipilih dengan tile kering tepat **satu** level lebih tinggi |
| 5 | Jembatan arah timur-barat | Satu tile air dengan tepi barat dan timur kering pada level yang sama |
| 6 | Jembatan arah utara-selatan | Satu tile air dengan tepi utara dan selatan kering pada level yang sama |

**Schema v5** menambah field `connectors`. Layout v1–v4 dimigrasikan menjadi seluruh nilai nol. Saat loading, ukuran, tipe integer, rentang, dan syarat spasial setiap konektor diverifikasi sebelum layout baru menggantikan yang aktif. Pemilik konektor tidak bisa ditimpa pohon/bangunan, dan terrain/river edit ditolak jika membuat penyangga konektor tidak valid (`LINK_SUPPORT`).

## C. Render dan collision

- `IslandLinkBuilder` membentuk deck dari 12 segmen segitiga. Ramp setinggi `1.55` unit antarlevel sepanjang `2.1` unit—**angka prototipe**, bukan ukuran ACNH. Jembatan memiliki lengkung pendek dan bibir yang memasuki sedikit bagian tepi darat untuk transisi kaki halus.
- Collider menggunakan `StaticBody3D` dengan `ConcavePolygonShape3D` bertopeng layer **32**. Kapsul karakter mendeteksi terrain(1), fitur(16), serta connector(32), sehingga `collision_mask=49`. Raycast kaki memakai layer 1/8/32 (`mask=41`).
- Bagian tengah dinding tebing di ujung ramp dibuka sehingga kapsul bisa naik; dua pita dinding sempit tetap dibangun sebagai *side cheek* di kiri/kanan. Penyatuan material lip dan *side cheek* organik masih perlu penyempurnaan; geometri sekarang low-poly demonstrasi.
- Jembatan menandai jalur pusatnya sebagai zona darat dalam `WaterRules.sample`, sehingga aktor WALK tidak dipaksa berenang atau mengeluarkan riak. Area air di samping jalur tetap tidak bisa dilalui dengan mode WALK.

## D. Graf akses dan uji lintasan

`IslandAccessAudit` dari Sprint 14 kini memakai `IslandLinkRules.walk_edge`: selain perpindahan kering dengan tinggi sama, ia mengenali ramp antarlevel dan jembatan satu tile dengan arah yang cocok. **Mencabut konektor** dapat ditolak oleh `K` jika memisahkan tile lain yang sebelumnya terhubung.

`WaterRules.can_traverse_path` melakukan sampling berulang pada segmen gerak dan memeriksa transisi level/air dengan aturan konektor. Ini bukan navmesh umum: karakter harus mengikuti bagian deck, dan hanya empat arah grid yang diizinkan sebagai link baru.

Pengujian nyata `tests/test_link_physics.gd` menggerakkan `RiverCharacter` (`CharacterBody3D`) di dunia dengan terrain collider dan connector collider. Pada konfigurasi uji:

- Aktor melewati jembatan, dengan titik kaki di atas deck sekitar **0,25 unit**.
- Aktor mencapai atas tebing lewat ramp, dengan titik kaki akhir sekitar **1,57 unit**.
- Hasil ini membuktikan perilaku **skenario uji**, bukan kesetiaan fisika ACNH atau semua kondisi sudut/kecepatan.

Jalankan `tests/test_island_links.gd` untuk graf, aturan placement, izin WALK, persistensi, migrasi, dan penolakan layout rusak. Semua `tests/test_*.gd` untuk regresi lengkap.

## E. Batasan penting sebelum produksi

1. Jembatan hanya satu tile air; belum ada bentangan panjang, tiang yang menghindari objek bawah, kombinasi waterfall, atau jembatan diagonal.
2. Ramp hanya naik satu level dan menempati satu tile rendah. Sudut ramp relatif curam; lebar/jalur di game Nusantara akhir harus direvisi berdasarkan permainan dan toleransi kapsul.
3. Uji fisik masih lintasan lurus yang diatur; belum ada test robot otomatis untuk lintasan menanjak miring, pemantulan, tangga, replanning path saat editor bekerja, penempatan karakter di ujung jembatan, serta aksesibilitas kursi roda.
4. Graf tile masih aproksimasi terhadap collision mesh dan obstruksi fitur/objek; kelak perlu navmesh atau *voxelized clearance* untuk membuktikan jalur benar-benar bebas pada seluruh lebar badan.
5. Bagian sisi ramp, pertemuan tanah-bridge, pelengkung tepi rumput, railings, shadow contact, dan arus di bawah jembatan masih memerlukan pemolesan visual.

## F. Tindak lanjut yang disarankan

Sprint 16: koneksi bertingkat (tangga, ramp lebih lebar, jembatan banyak tile), pengukuran *capsule clearance* dan jalur spawn-ke-rumah/dermaga. Audit data RE native tetap dipisahkan agar klaim ACNH tidak tercampur desain orisinal.
