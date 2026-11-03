# Nusantara World Lab — review berkelanjutan Sprint 19–21

## Prinsip sumber

ACNH adalah **benchmark observasi visual dan perilaku pemain**, bukan sumber untuk menyalin aset, cerita, shader, atau parameter privat. Pilihan angka dalam dokumen ini adalah parameter perancangan orisinal Nusantara. Data RE yang telah ditinjau pada Sprint sebelumnya tetap dipisahkan dari hipotesis visual.

## Siklus review → perbaikan → verifikasi

| Area | Kondisi Sprint 18 | Perbaikan 19–21 | Kekurangan yang masih terlihat |
| --- | --- | --- | --- |
| Aliran sungai | Lapisan noise bergerak, hampir tidak menunjukkan arus; garis diagonal kuat sudah dihilangkan | `COLOR.rg` menyampaikan vektor arus ke shader dengan drift terbatas, riak pendek melengkung dan tersebar | Arus belum membentuk pusaran di belokan berdasarkan kedalaman atau kontak tepi |
| Bibir sungai | Pita tanah berwarna tunggal; buih terpisah menjadi segmen statis | Wet-to-dry color ramp dari `TerrainBuilder._ground_color()`, foam world-space yang bergerak dan memudar ke tengah | Beberapa persambungan mesh dan wujud tepi di sudut kecil masih kasar |
| Pulau/pantai | Seluruh tanah level 0 pasir terang; pulau terlihat seperti bidang datar | Level 0 berumput di tengah, hanya border pantai yang bercampur pasir; shader rumput multi-skala | Outline pulau masih persegi karena grid selalu mengisi seluruh luas map |
| Tebing | Dinding polos, sedikit tonjolan | Warna ochre atas → batu gelap bawah, delapan strip vertikal, faset dan shader noise world-space | Terlalu teratur pada relief tertentu, belum ada lumut/erosion lokal dan tepi grass yang kaya |
| Air terjun | Bukaan sempit, tirai datar, buih dasar hampir tak terlihat | Lebar hasil pengujian `0.078125..0.6875` dalam parameter tepi satu tile; alpha feather, lip matching, bercak buih animasi | Masih terlihat sebagai satu lembar 2D tanpa ketebalan/mist volumetrik; koneksi ke cliff side perlu transisi khusus |
| Samudra | Hanya background kosong di luar peta | Mesh laut melingkari peta, warna dasar dan gelombang pecah dekat pantai; outlet sungai level 0 disambung sampai border | Ocean hanyalah tampilan, bukan ruang renang; coast belum sculptable dan laut/sungai belum berbagi bidang dinamika |

## Perubahan teknis penting

1. **Hidrologi satu sumber:** `RiverContour.field_at()` tetap menjadi sumber untuk air, tepi, bathymetry dan `WaterRules`. Ekstensi occupancy saat mencapai tepi peta hanya berlaku pada sungai level 0 yang bersambung ke laut.
2. **Visual terpisah dari gameplay:** vektor arus dipakai untuk mengorientasikan wavelet, tetapi animasi shader tidak mengubah kecepatan atau arah gerak kapsul. `CoastBuilder` tidak menambahkan collider palsu yang memungkinkan pemain berenang melampaui tepi map.
3. **Tebing dan collider tetap setara:** faset tebing dibentuk pada vertex geometri yang sama untuk render dan `create_trimesh_shape()`. Kaki/karakter tidak menabrak displacement shader yang tak ada di physics.
4. **Buih terfragmentasi:** wavelet pendek dan foam menggunakan koordinat dunia serta mask yang berubah dalam waktu; tidak ada RNG per tile pada batas kontur air.
5. **Editor tetap data-driven:** tiga layout, height 0–5, dua layer visual, pengeditan tile, bridge/ramp, validasi akses, penyimpanan schema v5 tetap mempertahankan pipeline Sprint 18.

## Pemeriksaan kualitas

- `tests/test_art_direction.gd` menuntut perbedaan sinyal warna rumput/pasir, gradien bank/alpha foam, keberadaan wavelet berorientasi arus, rentang warna cliff, bukaan curtain, foam dan ocean ring nonfisik.
- Seluruh **29/29 `tests/test_*.gd` lulus** di Godot 4.7.2 headless setelah perubahan Sprint 21. Uji fisika mencakup kapsul menyebrangi jembatan/ramp, arus hilir, IK kaki, animasi, save schema v5, dan audit akses pulau.
- Kamera tetap untuk `s21_wave_frame_a.png` hingga `s21_wave_frame_d.png` pada sekitar 0, 1, 3 dan 6 detik animasi. Frame tersebut menguji evolusi, bukan hanya satu render statis.
- `s20_waterfall_overview.png`, `s20_waterfall_closeup.png`, dan `s20_waterfall_later.png` memperlihatkan jembatan air atas → curtain → buih bawah, sehingga cacat sambungan dapat diinspeksi.

## Review kritis: yang masih menghalangi kelas visual ACNH

**P0 — topology pesisir:** saat ini setiap peta merupakan persegi penuh; sandbar, teluk, tanjung dan outlet ke lautan harus menjadi data denah yang bisa diedit, lalu mesh/marching contour serta collision terbangun bersama. `CoastBuilder` hanya frame visual. Juga belum ada pesisir yang dapat diinjak atau air laut yang dapat direnangi.

**P0 — air terjun volumetrik:** perlu top-water overspill kontinu, side-flow menempel rock face, ketebalan tirai dengan lapisan normal dan busa pinggir, spray di kaki yang mengikuti titik benturan air, dan kamera A/B. Nilai bukaan 0.078..0.6875 adalah keputusan prototipe fixture, tidak boleh dianggap ukuran game referensi.

**P1 — aliran kontur:** untuk belokan, arus harus diturunkan dari medan kecepatan kontinu dengan boundary no-penetration; adveksi shader dan feedback swim mesti menggunakan medan yang sama dengan skala waktu terkontrol.

**P1 — material dan cahaya:** grass clumps, rona tanah yang sesuai biome, detail erosi tebing/lumut, normal maps artisanal, AO, shadow color, serta refleksi/fresnel air. Shader sekarang hanya melapiskan noise world-space di atas vertex color.

**P2 — tool desain pulau:** preview sebelum edit, undo/redo beberapa objek, kontrol manual radius kelokan dan panjang sungai, dan penyimpanan shape coastline yang mendukung tiga denah tanpa mengubah generator.

## Target kualitas berikutnya

1. Tiga screenshot benchmark Nusantara yang identik framing-nya dengan tiga referensi visual (air sungai, cliff, waterfall), disertai anotasi jarak bentuk—bukan klaim pixel-perfect tanpa data.
2. Coast mask baru yang dapat diedit dari denah 2D dan digunakan bersama render, navigasi, collision, serta save/load; tes tiga peta dengan pantai unik.
3. Waterfall pass geometri 3D dan foam sheet berlapis, diikuti seri frame 0–6 detik dan inspeksi di sisi tebing.
4. Profil performance pada map kecil dan 112×96 dengan regenerasi parsial sehingga editor tetap responsif.
