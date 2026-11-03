# Sprint 10 — Aksi sekop di atas locomotion dan target kaki untuk IK

**Tanggal:** 2 November 2026. **Engine:** Godot 4.7.2. **Status:** prototipe interaksi pertama yang dapat dipicu pemain pada GLB Nusantara; 18 tes terotomasi lulus.

## Tujuan

Menguji aksi sekop (shovel) pada model `Chibi_Gray_T_Pose_Clay_Model_s3.glb` dengan `Skeleton3D` sungguhan, tanpa menghentikan state gerak kaki. Bersamaan, siapkan pengukuran dua titik kaki dan permukaan terrain sebagai input bagi solver IK yang akan datang.

## Sistem aksi

`SkeletonAnimationBridge` sekarang menggunakan `AnimationNodeBlendTree`:

- Input dasar `locomotion` berisi state machine empat clip `idle/walk/wade/swim` yang sebelumnya sudah teruji.
- Input aksi `shovel` memakai satu clip 1,30 detik, **tidak berulang**. Keyframe pada detik `0,00 / 0,14 / 0,34 / 0,54 / 0,76 / 1,06 / 1,30` menciptakan tahap persiapan, ayunan, kontak, dan pemulihan.
- `AnimationNodeOneShot` mencampur aksi hanya pada `Arm_L`, `Arm_R`, `Spine`, dan `Head`. **Filter bone ini diperlukan**: tes awal menunjukkan gerak kaki sempat berhenti tanpa filter; tes setelah perbaikan memverifikasi rotasi tulang paha tetap berubah ketika karakter berjalan sekaligus menggunakan sekop.
- Tombol **`E`** memulai aksi hanya jika `WaterRules` mengizinkan zona darat/tepi, mode jalan aktif, `CharacterBody3D.is_on_floor()` benar, dan aksi sebelumnya telah selesai. Permintaan berulang saat clip aktif ditolak.

`ShovelTool` membuat prop sederhana berupa poros kayu dan mata sekop metal serta memasangnya pada `RightHand` memakai `BoneAttachment3D`. Visual hanya tampil selama OneShot. Ini bukan model final; orientasi gagang perlu dikalibrasi untuk tiap karakter dan pose jari.

Pada detik sekitar **0,57** animasi, `RiverCharacter` raycast ke tanah di depan aktor dan memicu tepat satu `DigImpactFX` jika titiknya sesuai zona darat/tepi. Mesh bekas gali berumur **3 detik**, lalu diproses untuk dihapus. Efek ini **tidak** membuat lubang fisik, mengurangi elevasi, atau menghasilkan item.

## Target kaki dan temuan kalibrasi

`FootGroundProbe` membuat sumber `BoneAttachment3D` untuk `LeftFoot` dan `RightFoot` dari GLB pengguna. Setiap tick di darat:

1. Mengambil koordinat global bone kaki.
2. Melakukan raycast sejauh 0,56 unit ke atas dan 0,94 unit ke bawah dari tulang, dengan mask collider terrain.
3. Menyimpan `foot_hits[side]` yang berisi `valid`, `gap`, posisi tulang `world`, dan titik collider `ground`.
4. Dengan tombol **`G`**, target kiri diberi warna merah muda dan kanan sian. Marker hilang saat aktor mengapung.

Pada fixture daratan rata, `LeftFoot` terukur sekitar **0,6935 unit lebih tinggi** daripada titik collider. Ini merupakan jarak tulang-terrain pada impor GLB ini, **bukan nilai penetrasi kaki atau tinggi jangkauan IK**. Hasilnya mengingatkan bahwa posisi origin bone, skinning, skala rig, serta visual mesh belum dikalibrasi. Belum ada solver dua tulang yang mengoreksi posisi sendi atau menempelkan telapak ke kontur tanah; marker hanyalah target eksperimen.

## Hasil pengujian

**18/18 skrip `tests/test_*.gd` lulus** setelah perubahan. Pengujian baru:

| Skrip | Pembuktian |
| --- | --- |
| `test_shovel_action.gd` | Sekop hanya di darat dengan grounded actor; OneShot aktif; input berulang ditolak; clip locomotion dan gerak paha tetap berjalan; tepat satu bekas gali; pemulihan melepas prop; berenang melarang sekop; bekas lama terhapus |
| `test_foot_ground_probe.gd` | Kedua nama tulang GLB dikenali; raycast mengenai tanah; koordinat/gap finite; marker visual aktif per kaki dan disembunyikan saat mengapung |
| `test_probe_ui.gd` | HUD World Lab 10 dan toggle overlay, mode, current, rig tetap bekerja |

Tes dari Sprint 01–09 untuk serialisasi denah, editor, cliff collider, bathymetry, penyeberangan sungai, gerak arus, dan seluruh state animasi tetap berjalan.

## Capture

- `shovel_action_preview.png`: fase OneShot saat sekop terlihat di tangan.
- `shovel_impact_preview.png`: bekas gali muncul pada tanah.
- `shovel_walk_preview.png`: clip `WALK` dan aksi `SEKOP` berjalan bersama.
- `foot_targets_preview.png`: target kaki kiri/kanan pada ground terrain.
- `shovel_motion.gif`: 36 frame demonstrasi, direkam dengan `Engine.time_scale=0,35` agar gerak mudah diamati. Durasi di game pada waktu normal tetap 1,30 detik.
- `terrain_preview.png`: overview Sprint 10.

## Keterbatasan yang harus diperbaiki

1. Gerakan sekop masih keyframe prosedural sederhana, belum halus untuk produk akhir. Khususnya jangkauan tangan ke gagang, orientasi pergelangan, kontak bilah dengan tanah, dan sinkronisasi seluruh tubuh belum diatur oleh IK atau authored animation kualitas tinggi.
2. Bekas gali tidak terintegrasi ke `IslandDefinition`, tidak memengaruhi pathing/collider, dan belum menyimpan perubahan dalam denah.
3. Aksi dapat dilakukan sambil berjalan untuk membuktikan upper-body layering. Desain game akhir mungkin perlu membatasi kecepatan atau menghentikan aktor selama impact.
4. Raycast kaki belum melakukan IK; gap raw bone-to-ground sekitar 0,69 unit pada fixture menunjukkan perlunya kalibrasi rest pose / scale dan analisis skin mesh.
5. Tidak ada kode, animasi, nilai fisika, maupun asset Nintendo yang digunakan. Implementasi ini orisinal dengan ACNH hanya sebagai studi konsep gerak yang dapat diamati.

## Prioritas Sprint 11

- Buat **kalibrasi foot target + solver dua tulang** dengan visualisasi sebelum/sesudah, lalu uji berdiri dan berjalan pada lereng/tebing yang berubah.
- Rapikan **grip sekop dan fase kontak** memakai keyframe yang mengekalkan posisi mata sekop relatif tanah, dengan input yang memilih sudut dan posisi target.
- Pisahkan gameplay `DigAction` dari visual: validasi tile, perubahan data `IslandDefinition`, persistensi, larangan dekat tebing/air, dan item hasil gali—hanya sesudah kontrak desain dipilih.

Rujukan primer engine: [AnimationNodeOneShot](https://docs.godotengine.org/en/4.7/classes/class_animationnodeoneshot.html), [AnimationNodeBlendTree](https://docs.godotengine.org/en/4.7/classes/class_animationnodeblendtree.html), [BoneAttachment3D](https://docs.godotengine.org/en/4.7/classes/class_boneattachment3d.html), [Ray-casting](https://docs.godotengine.org/en/4.7/tutorials/physics/ray-casting.html).
