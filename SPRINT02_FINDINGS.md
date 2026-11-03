# Sprint 02 — Tebing hibrida, physics probe, dan composer pulau

Tanggal: 2 November 2026. Status: **prototipe Godot telah diuji otomatis dan di-render**.

## Apa yang berubah

| Komponen | Sprint 01 | Sprint 02 |
| --- | --- | --- |
| Tepian teras | Segmen lurus, sudut 90° | Sudut convex menggunakan bevel yang dicampur arc halus |
| Top ground | Satu bidang per tile, warna sedikit berbeda | Poligon fan yang dipotong di sudut dan warna vertex kontinu berdasarkan koordinat dunia |
| Dinding | Segmen tebing berulang | Segmen tebing + surface sambungan sudut, offset kontinu |
| Physics | Dua collision shape dan raycast | Raycast serta kapsul `CharacterBody3D` berjalan menuju tebing |
| Penataan | Fixture statis | Brush klik kiri/kanan, switch denah, simpan/muat JSON |
| Bukti visual | `terrain_preview_sprint01.png` | `terrain_preview_soft_round.png` dan `terrain_preview.png` |

## Keputusan geometri

Corner hanya dibentuk kurva jika **dua sisi yang bertemu sama-sama exposed dan punya elevasi tetangga identik**. Jika dua tetangga berbeda tinggi, corner tetap tajam agar tidak muncul sambungan dinding yang tidak terdefinisi. Radius dan campuran arc-chamfer saat ini murni parameter gaya Nusantara; tidak mengklaim memakai model tebing asli ACNH.

Surface bibir rumput menutup jarak dari tanah di atas ke bagian muka dinding. Pembuatan normal sudah diuji agar tanah dan bibir menghadap atas serta dinding menghadap luar. Collision bawah mengikuti mesh aktual yang sama, termasuk kontur baru.

## Hasil uji Godot 4.7.2

| Tes | Hasil | Inti yang diuji |
| --- | --- | --- |
| `test_island.gd` | PASS | Denah, round-trip data, ujung arc, normal mesh, sambungan dinding, collider |
| `test_physics.gd` | PASS | Raycast ke beach, teras atas, dan dinding |
| `test_character.gd` | PASS | Kapsul bergerak ke dinding, terjadi slide collision, tidak menembus tebing |
| `test_composer.gd` | PASS | Brush menaikkan/menurunkan elevasi, switch denah, simpan dan muat JSON |
| `test_editor_input.gd` | PASS | Raycast koordinat layar memilih tile; collider dibangun ulang setelah edit |
| `capture_scene.gd` | PASS | PNG 1280×720 dirender menggunakan software OpenGL Mesa |

## Visual QA

- **Membaik:** bentuk dua tingkat lebih organik; sudut luar tidak berupa siku sempurna; tekstur petak warna hijau lebih merata; bibir tebing mengikuti sudut tanpa potongan persegi yang terlihat pada baseline.
- **Belum memuaskan:** dinding masih terlihat seragam/polygonal pada close-up; pemilihan topologi corner bertingkat belum lengkap; tanah dasar pasir terlalu datar; tidak ada shoreline dan air.
- **Aturan penting:** jangan mengubah radius sudut menjadi bulatan besar. Versi `terrain_preview_soft_round.png` menunjukkan efek terlalu membulat, sedangkan `terrain_preview.png` mencoba pendekatan chamfer 45° dengan lengkung ringan.

## Tahap berikutnya

1. Implementasikan sistem chunk terrain, undo/redo, dan model aturan penyusunan peta (area yang boleh dibangun, akses jalur, *slope*).
2. Verifikasi controller karakter dengan uji angka percepatan, belokan, stop, naik/turun dan collision edge.
3. Tambahkan **topologi sungai** dari data tile+tepi, bukan hanya mesh air datar; beri varian cekungan, aliran, dan air terjun yang disambung ke tebing.
4. Kumpulkan pengukuran ACNH yang sah untuk kalibrasi visual/perilaku. Terus pisahkan fakta reverse engineering dari interpretasi desain.

Riset PBC dan sumber primer tetap dicatat di `SPRINT01_FINDINGS.md`.
