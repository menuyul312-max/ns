# Sprint 07 — Pose prosedural dan dorongan arus pada aktor sungai

**Tanggal:** 2 November 2026. **Status:** Godot 4.7.2, bukti fisika teruji; manekin masih artefak lab.

## Tujuan

Mengubah aktor Sprint 06 yang hanya mengapung dan berpindah menjadi prototipe dengan **pergantian pose yang kontinu** dan interaksi **arus sungai** yang dapat diamati, tanpa menyalin sistem proprietary ACNH.

Referensi kemampuan engine: [Godot CharacterBody3D](https://docs.godotengine.org/en/4.7/classes/class_characterbody3d.html), [Godot AnimationTree](https://docs.godotengine.org/en/4.7/classes/class_animationtree.html) sebagai arah integrasi untuk rig produksi di masa depan. Kode sekarang menggunakan state machine prosedural di GDScript, **belum** `AnimationTree`.

## Implementasi A — empat state animasi

`RiverCharacter.MotionState`: `IDLE`, `WALK`, `WADE`, `SWIM`.

| State | Pemicu gameplay | Prosedural yang diamati |
| --- | --- | --- |
| `IDLE` | Darat tanpa input gerak | Tubuh kembali tegak, bob dan ayunan mengecil |
| `WALK` | Gerak darat yang tidak terhalang | Tangan/kaki berayun berlawanan dengan phase gait |
| `WADE` | Mode merendam di kedalaman dangkal | Ayunan lebih pelan, lengan sedikit terbuka |
| `SWIM` | Mode berenang dan cukup dalam untuk mengapung | Badan condong, tangan/kaki berganti kayuhan, kepala bob kecil |

Setiap state memiliki bobot `walk_blend`, `wade_blend`, `swim_blend` yang bergerak dengan faktor `min(1, delta*6)`. Pivot bahu dan panggul merupakan node transform prosedural, **bukan rig tulang yang sudah dipaint weight**. Ini layak sebagai tes gerak, bukan animasi karakter produksi.

## Implementasi B — dorongan arus

Ketika `mode=SWIM` dan aktor sedang mengapung, `WaterRules.sample()` mengembalikan arah `RiverContour.flow_at()`. Dorongan horizontal:

`velocity_horizontal = input_player * speed_mode + flow_direction * 0.55`

Nilai `0,55` adalah **unit dunia per detik** pada prototipe ini. Bukan kecepatan arus sungai asli atau parameter ACNH. Dorongan hanya diterapkan jika posisi percobaan masih berada pada air, dan perpindahan total melewati `WaterRules.can_traverse_path()` serta post-physics validation. Tombol `F` mengaktifkan/menonaktifkan dorongan untuk uji A/B tanpa mengubah shader air.

**Keterbatasan flow:** graph hanya mengenal satu outlet terendah dan arah topologis, belum memperhitungkan geometri cross-section, kecepatan lokal, volume, tekanan, atau pusaran fisik. Arus dapat mengantar aktor menuju zona dangkal; controller akan kembali ke gravitasi ketika tidak mengapung.

## Implementasi C — penampil arah aliran

`WaterFlowOverlay` menambahkan panah datar di pusat petak basah. Panah dikalkulasi dari vektor interpolasi `RiverContour.flow_at()`, disatukan dengan heatmap kedalaman ketika `V` aktif. Karena panah dibuat per pusat petak, visualnya **alat audit jaringan**, bukan streamline kontinu hidrodinamika.

## Tes dan observasi

| Uji baru | Hasil | Bukti |
| --- | --- | --- |
| `test_current_drift.gd` | **PASS** | Perenang idle terdorong ke hilir; saat arus OFF posisi stabil; saat berenang melawan arus bisa bergerak ke hulu |
| `test_animation_states.gd` | **PASS** | State idle → walk → wade → swim → idle, bobot blend dan joint prosedural terpasang |
| `test_probe_ui.gd` (diperluas) | **PASS** | Panah arus dibangun pada heatmap; tombol `F` mengubah drift aktor dan HUD |
| `test_river_character.gd` baseline | **PASS** | Jalan/rendam/renang tetap sesuai aturan ketika arus sengaja dimatikan agar hasil dapat dibandingkan |

Hasil uji `test_current_drift`: posisi hanyut **+0,54 unit** searah flow, arus OFF **0,00 unit**, dan saat input ke hulu **−1,13 unit** (proyeksi sumbu flow). Angka ini hasil simulasi fixture, bukan spesifikasi fisika ACNH.

Tes lain dari Sprint 01–06 tetap dijalankan untuk regresi, mencakup mesh, collider, editor, kontur, bathymetry, validasi jaringan, dan serialisasi.

## Capture

- `terrain_preview_sprint06.png`: baseline visual Sprint 06.
- `terrain_preview.png`: World Lab 07 dengan HUD state/arus.
- `water_zones_preview.png`: heatmap plus panah arah arus pada seluruh denah.
- `physics_swim_closeup.png`: closeup aktor dan panah arus.
- `current_debug_preview.png`: close-up manekin dengan kontrol arus ON.
- `current_motion.gif`: 24 frame berurutan: arus OFF, hanyut tanpa input, lalu bergerak melawan arus sambil animasi tangan/kaki terus berjalan.

## Pekerjaan berikutnya

1. Masukkan model karakter Nusantara hasil pipeline 3D terpisah (GLB rigged) dan ganti pivot prosedural dengan `AnimationTree` / blend poses.
2. Baurkan transisi masuk/keluar air dengan posisi bahu, kaki, dan kepala yang mengikuti waterline; tambahkan animasi pergerakan lebih halus.
3. Hubungkan flow ke aksi lain seperti perahu, benda terapung, jembatan, dan ketahanan saat berenang.
4. Perbaiki water flow map untuk percabangan, kolam, muara, pasang-surut, dan arus air terjun.
5. Tingkatkan art quality tebing, foam, dan shader air. Saat ini gap visual terhadap game referensi masih jelas.

Semua aset, rumus, dan parameter tetap **orisinil**, dengan ACNH hanya sebagai referensi pengalaman desain yang bisa diamati.
