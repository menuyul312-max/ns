# Sprint 11 — Pose rest GLB, IK dua tulang, dan orientasi grip sekop

**Tanggal:** 2 November 2026. **Engine:** Godot 4.7.2 stable. **Status:** prototipe koreksi kontak kaki saat diam telah dibuktikan pada runtime, bukan sistem gait IK final. **19 tes regresi** berhasil, termasuk tes IK baru.

## 1. Diagnosis mengapa kaki melayang pada Sprint 10

Audit `tests/inspect_rig_geometry.gd` menunjukkan bone `LeftUpperLeg → LeftLowerLeg → LeftFoot` memiliki local rest dan rotasi dengan sumbu hasil impor GLB. Track animasi lama menulis quaternion identitas secara absolut untuk hampir semua bone; ini **menimpa orientasi rest** GLB. Pada posisi idle, `LeftFoot` lama menjadi sekitar 0,693519 unit di atas collider, sementara paha justru melipat ke atas.

Perbaikan `scripts/skeleton_animation_bridge.gd`: clip idle, walk, wade, swim, dan shovel menggunakan **quaternion rest × delta pose** untuk bone impor. Bone kembali mengikuti hierarki yang benar. Pada tile datar yang sama:

| Metrik | Sebelum perbaikan | Setelah perbaikan |
| --- | ---: | ---: |
| Pergelangan (`LeftFoot`) di atas ground | 0,693519 unit | 0,097473 unit |
| Pergelangan (`RightFoot`) di atas ground | 0,693519 unit | 0,097473 unit |
| Jari kaki (`LeftToes`) di atas ground | bukan baseline yang sah | ±0,040913 unit |

Sisa jarak pergelangan **bukan bug penetrasi**: tulang `Foot` berada di atas kulit telapak; tulang `Toes` lebih dekat ke tanah. IK harus menargetkan titik ankle dengan clearance terkalibrasi, bukan memaksanya ke `ground.y`.

## 2. Implementasi IK yang betul-betul mengubah pose tulang

`scripts/foot_ik_controller.gd` membuat modifier Godot asli `TwoBoneIK3D` per kaki dan memasangkannya pada `Skeleton3D`. Setiap chain mempunyai root/middle/end bone, target ankle world-space dan pole lutut terpisah. `FootGroundProbe` memberikan posisi pergelangan, raycast ground, dan gap. Target Y ditentukan sebagai **elevasi ground + gap pergelangan netral** yang dikalibrasi setelah aktor settle pada tanah.

Solver aktif hanya bila aktor `is_on_floor`, visual GLB aktif, tidak mengapung, dan `motion_state == IDLE`. Tombol `I` melakukan perbandingan ON/OFF. Batas gerak vertikal kaki adalah ±0,15 unit per tick terhadap pose saat itu. Ini sengaja menolak jangkauan ekstrem pada batas cliff 1,55 unit, yang jauh melebihi panjang kaki GLB ~0,30 unit. Ketika berjalan atau berenang, modifier dinonaktifkan, sehingga locomotion asal tidak dibajak solver stasioner.

### Bukti uji terukur

`tests/test_foot_ik.gd` menaruh satu blok kontak kecil di bawah pergelangan kaki kanan, pada **contact query layer 8** (untuk detail halus), di atas terrain utama layer 1. Kapsul badan hanya bertabrakan dengan layer 1; raycast kaki menggunakan mask 9. Karena tinggi blok +0,110 unit, ankle tanpa IK meleset **0,110000** unit dari target. Setelah 15 tick IK:

- Selisih Y ankle-target menjadi sekitar **0,0000003 unit** (dalam toleransi presisi float).
- Bone `RightFoot` berpindah dari sekitar `y=1,647473` ke `y=1,757473`, dengan parent bone dan skin mesh ikut terdeformasi.
- Mode jalan dan berenang menonaktifkan correction; test juga menguji state renang `floating`.
- Dua modifier, dua target, kalibrasi kiri/kanan, dan shortcut UI diverifikasi.

Blok kuning pada `ik_before_preview.png` dan `ik_after_preview.png` adalah **fixture uji**, bukan fitur dekorasi permanen. Perbandingan memakai camera dan tempat yang sama. Uji tidak membuktikan dukungan slope yang mulus, foot locking saat berjalan, anti-penetrasi setiap jari kaki, atau seluruh tipe cliff di peta.

## 3. Orientasi sekop

Sprint 10 menggunakan prop sepanjang ~1 unit yang mewarisi rotasi `RightHand`; setelah koreksi rest, screenshot menunjukkan bilahnya malah berputar ke atas kepala. `scripts/shovel_tool.gd` kini membuat prop tangan kecil orisinal sepanjang kurang dari 0,4 unit, dengan child `WorldAlignedGrip`. Attachment mempertahankan **posisi** tulang tangan, sedangkan pivot menghitung inverse orientasi bone world agar sumbu poros tetap ke bawah dengan sedikit kemiringan mengikuti fase ayunan.

Pada capture `shovel_grip_preview.png`, telapak kanan dan trowel terlihat dalam frame sama; koordinat ujung bilah sekitar `y=1,608` ketika tanah `y=1,550`, sehingga bukan lagi di atas kepala. Tes aksi sekop juga menolak posisi ujung bilah yang terbalik. Ini **belum** jaminan bahwa tangan kiri menggenggam poros, bahwa bilah tepat menyentuh ground saat `DigImpactFX`, atau motion capture tangan sudah benar.

## 4. Pengujian dan reproduksi

**19/19 tes `tests/test_*.gd` lulus** di Godot headless; termasuk `test_foot_ik.gd`, `test_foot_ground_probe.gd`, `test_shovel_action.gd`, serta seluruh regresi dunia/air/editor/physics/animasi. `tests/inspect_ik_api.gd` dan `tests/inspect_rig_geometry.gd` adalah alat audit, **bukan tes pass/fail**. `tests/capture_sprint11.gd` menghasilkan tiga PNG melalui renderer Godot OpenGL Compatibility.

- `ik_before_preview.png`: kaki kanan di atas patch kuning +11 cm, IK mati.
- `ik_after_preview.png`: kaki kanan naik ke patch, IK aktif.
- `shovel_grip_preview.png`: tool pendek mengarah tanah saat OneShot.

Contoh eksekusi dari akar proyek:

```bash
godot --headless --path . --script res://tests/test_foot_ik.gd
godot --headless --path . --script res://tests/test_shovel_action.gd
godot --path . --script res://tests/capture_sprint11.gd
```

## 5. Rencana Sprint 12

1. **Gait dengan foot phase / planting:** pisahkan swing dan stance, foot lock selama fase tumpuan, target transition yang halus (hindari patah kaki saat masuk/keluar IK), serta root/pelvis compensation.
2. **Terrain lebih halus:** uji slope, batu, akar, ambang anak tangga, dan batas collider dekat tebing; bench side-by-side skin toe/heel penetration dan ankle error, termasuk kondisi kena air. Jangan menempatkan pengunci ankle di air dalam.
3. **Animasi sekop yang authored:** telusuri `RightHand`, `LeftHand`, target tanah, kontur sekop; buat target jangkauan saat hit, perbaiki two-hand grip, collision tanah dan sinkronisasi efek, alih-alih hanya durasi keyframe.
4. **DigAction data layer:** tentukan izin menggali, grid placement, perubahan terrain terlokalisasi, persistensi, undo/redo, dan sumber daya—desain orisinal Nusantara, tanpa mengambil asset/code Nintendo.

Dokumentasi engine primer: [TwoBoneIK3D Godot 4.7](https://docs.godotengine.org/en/4.7/classes/class_twoboneik3d.html), [SkeletonModifier3D](https://docs.godotengine.org/en/4.7/classes/class_skeletonmodifier3d.html), [BoneAttachment3D](https://docs.godotengine.org/en/4.7/classes/class_boneattachment3d.html).
