# Sprint 09 — Integrasi GLB milik pengguna, rig Skeleton3D, dan waterline

**Tanggal:** 2 November 2026. **Godot:** 4.7.2. **Status:** riset dan prototipe yang dapat dijalankan. Tidak mengandung kode maupun aset Nintendo.

## Masalah yang ditangani

Sebelumnya prototipe memiliki aturan pulau, collider, aliran sungai, renang, efek riak, serta `AnimationTree`, tetapi karakter masih berbentuk manekin. Sprint ini menguji apakah animasi gameplay dapat dipasang pada **karakter dengan tulang dan skin sungguhan**, lalu membuat perbedaan visual saat kedalaman air berubah.

## Audit model input

Model ditemukan dalam file pengguna `Chibi_Gray_T_Pose_Clay_Model_s3.glb`, diintegrasikan secara lokal pada `assets/character_nusantara.glb`.

| Sifat yang diperiksa | Hasil audit |
| --- | --- |
| Format | glTF binary 2.0 (`.glb`) |
| Mesh | 1 |
| Skin | 1 |
| Tulang pada skin | 23, termasuk `Hips`, `Spine`, `Head`, `LeftUpperArm`, `RightUpperArm`, `LeftUpperLeg`, `RightUpperLeg` |
| Animasi bawaan | `Idle`, `FaceTest` |
| Rentang mesh dari aksesori pertama | kira-kira 0–1 unit secara vertikal pada metadata aksesornya |
| Hasil impor Godot | `PackedScene` berisi `Skeleton3D`; tujuh peran animasi wajib berhasil dipetakan |

Sistem baru tidak menyatakan bahwa animasi bawaan mencakup berjalan atau berenang. Empat animasi permainan yang digunakan dibuat oleh kita dan perlu diperhalus untuk produksi.

## Implementasi

1. `CharacterRigVisual` memuat GLB bila tersedia, menelusuri `Skeleton3D`, dan menggunakan alias bone untuk peran `Root`, `Spine`, `Head`, `Arm_L/R`, `Leg_L/R`. Jika gagal, fallback rig dengan `Skeleton3D` tujuh tulang dan `BoneAttachment3D` bisa dipakai untuk debugging.
2. `SkeletonAnimationBridge` membangun `AnimationPlayer` dengan keyframe **rotation 3D** yang menarget tulang GLB (bukan sekadar pivot manekin). `AnimationTree` menangani transisi `idle/walk/wade/swim` dengan crossfade 0,18 detik.
3. GLB yang diunggah berasal dari T-pose. Pada clip gameplay, lengan diturunkan dengan offset rotasi bahu sebelum ayunan/kayuhan diaplikasikan. Ini baru *basic pose correction*, bukan solusi IK atau retargeting universal.
4. `CharacterRigVisual.set_waterline()` mengubah offset Y visual secara halus, maksimum −0,14 unit berdasarkan kedalaman `WaterRules`; **tinggi kapsul collision dan aturan traversal tidak ikut berubah**.
5. Tombol `R` membandingkan tampilan GLB dengan manekin lama dalam scene dan aturan fisika yang sama. Tidak perlu membuat dua controller karakter.

## Validasi

**16/16 tes `tests/test_*.gd` lulus**. Tes `test_skeleton_rig.gd` menuntut impor GLB asli berhasil, jumlah tulang sedikitnya 20, semua peran terpetakan, keempat clip tersedia, `AnimationTree` benar-benar berpindah state, rotasi bone tangan berubah antar frame, posisi visual tubuh turun saat berenang di alur dalam, dan tombol A/B visual bekerja. Tes lama dari Sprint 01–08 tetap lulus.

Capture baru:

- `rig_walk_preview.png` — GLB bergerak di teras tanah.
- `rig_wade_preview.png` — GLB merendam di tepian.
- `rig_swim_preview.png` / `rig_swim_closeup.png` — GLB di alur dalam dengan riak kontak air.
- `rig_motion.gif` — 36 frame fase berjalan → merendam → berenang.
- `terrain_preview.png` — denah overview World Lab 09.

## Batas visual dan fisika yang masih terlihat

- Proporsi/model 3D berasal dari unggahan, namun **pose langkah dan kayuhan masih kasar**: belum ada bahu/siku dinamis multi-axis, kaki menyentuh tanah secara IK, atau sinkronisasi langkah dengan kecepatan aktual. Satu klip berulang 1 detik belum mewakili variasi gerak yang halus.
- Saat masuk sungai, posisi visual Y menurun tetapi *perpindahan waterline* belum ditentukan oleh tubuh/skinned mesh yang sebenarnya (tidak ada deformasi busa dan percikan khusus di area tangan dan lutut).
- Skala 1,20 dan offset −0,61 disetel untuk GLB pengguna ini, belum metadata basis karakter yang umum.
- `AnimationTree` bone track menjembatani animasi kita ke skeleton yang benar, **bukan** pipeline retargeting produksi dari berbagai nomenklatur/arah tulang. Dua animasi bawaan (`Idle`, `FaceTest`) belum dicampur dengan clip gerak.
- Tidak ada analisis mekanik internal ACNH dari kode dekompilasi. Parameter dan algoritma dunia ini bersifat orisinal serta dapat berubah untuk pengalaman game Nusantara.

## Sprint 10 yang disarankan

1. Tambahkan **pose calibration** untuk upper arm, forearm, thigh, foot, neck; simpan profil per model alih-alih sudut global dalam kode. Uji tangan kanan/kiri dan telapak secara terpisah.
2. Pisahkan **locomotion blendspace** (idle/walk/run) dari **action layer** (sekop, tepuk tangan, memancing), agar kegiatan tidak mematikan gerak atau fisika.
3. Implementasikan **foot IK/ground contact** pada terrain bertingkat dan *waterline* berdasarkan pose pinggul/kaki, lalu ambil GIF A/B dengan toleransi visual.
4. Audit rigging model pengguna di Blender/rig tool untuk skin weights, jempol, pergelangan kaki, dan tumit sebelum animasi produksi.

Referensi engine primer: [Godot Skeleton3D](https://docs.godotengine.org/en/4.7/classes/class_skeleton3d.html), [Godot AnimationTree](https://docs.godotengine.org/en/4.7/classes/class_animationtree.html), [3D Animation Track Types](https://docs.godotengine.org/en/4.7/tutorials/animation/animation_track_types.html).
