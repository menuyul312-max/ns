# Kontrak GLB untuk Nusantara World Lab 09

**Dokumentasi mutakhir:** [`Nusa Character Base Kit v1`](../NUSA_CHARACTER_KIT_V1.md) menjelaskan profil rig modular, ekspresi wajah, soket, katalog animasi 16 klip, dan audit/transfer skin. Bagian Sprint 09 di bawah merupakan catatan historis.

`character_nusantara.glb` adalah salinan **model karakter milik pengguna** `Chibi_Gray_T_Pose_Clay_Model_s3.glb` yang sebelumnya diunggah dalam proyek mekanik karakter. Ini bukan aset Animal Crossing ataupun model Nintendo. Sebelum mendistribusikan game ke publik, pastikan lisensi dan hak atas semua model, tekstur, serta animasinya.

Godot mengimpor file ini sebagai `PackedScene`. `CharacterRigVisual` mencari `Skeleton3D` secara rekursif, lalu memetakan peran berikut:

| Peran logika | Nama tulang pada model pengguna |
| --- | --- |
| Root | `Hips` |
| Spine | `Spine` |
| Head | `Head` |
| Arm_L | `LeftUpperArm` |
| Arm_R | `RightUpperArm` |
| Leg_L | `LeftUpperLeg` |
| Leg_R | `RightUpperLeg` |

Audit file glTF/GLB: **satu mesh, satu skin, 23 joint, dua animasi (`Idle`, `FaceTest`)**. Sprint 09 menggunakan empat klip gameplay baru pada tulang, bukan mengklaim dua animasi bawaan sudah lengkap.

## Memasang karakter lain

1. Ekspor karakter Blender ke **GLB/glTF 2.0**, dengan satu `Skeleton3D` yang mengandung bahu dan panggul terpisah untuk kiri/kanan.
2. Simpan dengan nama `character_nusantara.glb` di folder ini, menggantikan file model lama **hanya jika kamu memang ingin mengganti model**.
3. Periksa nama bone terhadap `CharacterRigVisual.ALIASES` di `scripts/character_rig_visual.gd`. Tambahkan alias dengan sengaja jika penamaannya berbeda; jangan mengganti skeleton tanpa menguji karakter.
4. Buka project pada Godot 4.7+ untuk impor ulang, jalankan `test_skeleton_rig.gd`, lalu F5 dan tombol `R` untuk membandingkan terhadap manekin.
5. Cocokkan skala dan titik pijak. Untuk model pengguna ini adapter memakai skala 1,20 dan posisi visual Y = −0,61 (relatif kapsul aktor); model lain mungkin membutuhkan offset berbeda.

Jika GLB tidak tersedia atau pemetaan tujuh peran gagal, proyek akan menampilkan rig pengujian prosedural, bukan berpura-pura bahwa aset berhasil diimpor. Tes `test_skeleton_rig.gd` pada paket Sprint 09 sengaja mewajibkan *GLB asli* untuk memastikan jalur impor tidak diam-diam gagal.

## Keterbatasan

- Rotasi bahu dari T-pose diturunkan lewat offset statis. Kulit dan orientasi tulang yang berbeda membutuhkan kalibrasi rest pose per model.
- Katalog telah diperluas menjadi 16 klip prosedural dan foot IK untuk posisi berdiri; klip tersebut belum setara animasi produksi, bukan gait berbasis jarak tempuh atau root motion penuh, dan belum mendukung deformasi kain.
- Skinned mesh sudah dipakai, tetapi ini bukan bukti retopologi, skin weighting, ataupun animasi produksi sudah layak.
