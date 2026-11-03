# Catatan riset teknis — Nusantara World Lab Sprint 18

## Tujuan

Mengurangi dua gap yang terlihat jelas pada capture Sprint 17: garis tepi sungai yang nyaris lurus pada bentangan panjang dan tekstur air berupa satu jalur diagonal berpola pekat. Fokus hanya kontur dan visual air; fitur jembatan/ramp, save v5, animasi, IK, dan collider tetap dipertahankan.

## Scalar field bersama

Pada tiap query `RiverContour.field_at(source, world_x, world_z, level)`, koordinat dunia digeser oleh dua profil sinus rendah dan tinggi. Nilai terwarping dipakai untuk interpolasi bilinear/smoothstep terhadap occupancy grid. Karena deformasi berasal dari posisi dunia dan seed pulau yang tetap, tiap tile memiliki kontur bersama tanpa diskontinuitas berulang.

| Lapisan | Mekanik | Dampak |
| --- | --- | --- |
| Meander transversal | `0.155*sin(z*0.47 + phase) + 0.061*sin(z*1.31 - ...)` | Kedua sisi alur vertikal meliuk sepanjang sungai |
| Meander longitudinal | `0.137*sin(x*0.49 - ...) + 0.054*sin(x*1.39 + ...)` | Alur horizontal dan sudut danau juga tidak berpola kotak |
| Variation residual | `0.034*sin(warped_x*1.27 + ...) + 0.025*sin(warped_z*1.51 - ...)` | Detail lembut mengikuti field yang sama |
| Bank material | `RiverContour.append_mesh` dari threshold yang sama | Tidak ada penghalang fisika baru yang terpisah dari garis air |

Angka-angka tersebut adalah **pilihan artistik prototipe Nusantara**, bukan temuan angka dari executable ACNH. Tingkat akurasi perlu dibandingkan memakai hasil observasi gambar referensi yang terkontrol.

## Permukaan air

Masalah lama: offset UV berbasis interpolasi vektor flow setiap vertex menimbulkan garis perubahan fase besar ketika arah flow berubah di antara tile; tampak sebagai pita diagonal pada sungai lebar.

Perbaikan: nilai UV berdasar posisi dunia, drift seragam kecil dan lapisan `fbm` multi-skala. Detail ripple berbasis sel lokal dengan pusat acak deterministik, diberi radial attenuation sebelum sel berakhir. Hasilnya tidak mengejar gelombang fisik spektral; ia memprioritaskan pergerakan lembut tanpa pola paralel panjang. `WaterRules`, dorongan arus, dan kalkulasi depth gameplay **tidak mengandalkan** shader tersebut.

## Verifikasi

- `tests/test_water_meander.gd`: sampel numerik sepanjang bank, cek kontinuitas melintasi tepi tile, klasifikasi wet/dry pada interior dan build `WaterSurface/RiverBanks/RiverBankCollision`.
- Tes regresi lama menguji beach, air dangkal/dalam, jalur anti-tunnel, air terjun, bank collider, simpan/muat, bridge 1–3 tile, dan kapsul `CharacterBody3D`.
- Capture `s18_wave_frame_a.png` dan `s18_wave_frame_b.png` memuat sudut kamera sama dengan waktu simulasi berbeda untuk melihat evolusi visual.

## Status pembuktian

Tidak ada klaim bahwa rumus ini merupakan pipeline render Nintendo. Ini **implementasi independen** yang memanfaatkan observasi visual untuk membuat pondasi mekanik orisinal. Langkah lanjut yang berharga: capture video loop air pendek, parameter kelokan sungai yang bisa dikendalikan editor, analisis difusi buih, integrasi variasi river depth, dan visual fisika arus terkontrol.
