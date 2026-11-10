# Nusantara World Lab — Sprint 54 (Stratified Cliffs and Chamfered Lips)

**Nusa Character Base Kit v2:** lihat [`NUSA_CHARACTER_KIT_V2.md`](NUSA_CHARACTER_KIT_V2.md). Wajah diperluas menjadi atlas mata/mulut yang independen pada kepala, retarget *pose* skeleton lintas profil, profil collision tubuh/sensor interaksi, serta kontrak skeleton quadruped terpisah. V2 tetap prototipe dan bukan replika persis struktur/animasi ACNH.

**Nusa Character Base Kit v1:** dokumentasi kontrak skeleton biped/hewan/spirit, 23-bone GLB contoh pengguna, 78 target ekspresi, 16 klip animasi prototipe, socket modul, pemeriksa GLB, dan alat Blender untuk transfer skin terbatas ada di [`NUSA_CHARACTER_KIT_V1.md`](NUSA_CHARACTER_KIT_V1.md). Sumber karakter pengguna dan semua aset Nintendo **tidak disertakan dalam repo**.

**Sprints 53–54:** [`SPRINT53_54_REPORT.md`](SPRINT53_54_REPORT.md) documents layered cliff-wall relief, twelve vertical mesh rows, a slightly more chamfered corner profile and wider gently varied grass lips. `s54_cliff_profile_cpu.png` shows the mathematical before/after cross section, **not** a Godot image. Per user request, the experimental CI workflow from Sprint 52 has now been **removed**; only direct commits to `main` are used.

**Sprints 49–52 (historical):** [`SPRINT49_52_REPORT.md`](SPRINT49_52_REPORT.md) describes a fix for outward-warped beach membership, two propagating coastal foam fronts, and revision-based SDF texture caching. The report also records a CI experiment **since discontinued and removed from the repository**. The `s50_surf_train_cpu_frames.png` diagram is not an engine capture.

**Sprint 48:** [`SPRINT48_RE_OVERLAY_REPORT.md`](SPRINT48_RE_OVERLAY_REPORT.md) documents a read-only RE-inspired region diagnostic panel, **J** to toggle and **H** to compare base/overlay modes. Two CPU previews (`s48_region_cpu_mode0.png`, `s48_region_cpu_mode1.png`) visualize the same fixture; they are *not* Godot renderer captures. Live screenshot script: `tests/capture_sprint48.gd`. Existing gameplay terrain editing and collision rules are unchanged.

**Sprint 47:** [`SPRINT47_RE_REGION_REPORT.md`](SPRINT47_RE_REGION_REPORT.md) documents a new bounded reference model of the RE region-height checker, bit2/bit6 rectangle mutation, and navigation-byte decoder. It includes a Godot test (`tests/test_re_terrain_region.gd`) but does **not** change gameplay collision or placement permissions. The test still requires a Godot 4.7+ runtime for execution.

**Sprint 43–46:** lihat [`SPRINT43_46_REPORT.md`](SPRINT43_46_REPORT.md). Sistem `IslandCoastLoops.trace()` membentuk cincin kontur global dari `land_mask`, membedakan pulau terpisah, lubang air, dan pertemuan diagonal tanpa menyambungkan komponen yang berbeda. Audit menemukan gosong tenggara pada denah contoh ternyata masih memiliki jembatan satu tile: kini diperbaiki. HUD menampilkan hitungan pulau/lubang. `tests/capture_sprint46.gd` disediakan untuk mengambil **empat screenshot 3D sesungguhnya** saat Godot tersedia. Karena lingkungan saat ini tidak memiliki Godot, disertakan [`s46_island_cpu_preview.png`](s46_island_cpu_preview.png) (preview 3D CPU sederhana) dan [`s46_global_contour_audit.png`](s46_global_contour_audit.png) (diagram kontur 2D); keduanya **bukan screenshot game**. **24/24 tes offline lulus**, **39 tes GDScript belum dapat dijalankan**. Cincin mask saat ini masih *non-authoritative diagnostic*, sedangkan mesh + collision tetap dibangun oleh TerrainBuilder lama.

**Checkpoint Sprint 39–42:** lihat [`SPRINT39_42_REPORT.md`](SPRINT39_42_REPORT.md). Bentuk shoreline di sepanjang tepi yang masih menyambung kini menggunakan gelombang spasial lintas-tile yang *C0/C1-like* pada titik sambung, dan berhenti dengan aman di ujung terputus. Di area pecah ombak, tekstur SDF laut 256×256 diperhalus menggunakan distance-to-segment geometry yang juga memberi warna pasir; di laut jauh tetap pakai EDT yang lebih efisien. Diagram sebelum/sesudah: [`s42_coherent_coastline_diagnostic.png`](s42_coherent_coastline_diagnostic.png), **bukan capture Godot 3D**. **19/19 tes Python offline lulus**; **38 skrip tes Godot belum dijalankan** karena runtime tidak ada. Belum ada klaim mencapai visual ACNH; ini kode dan visual Nusantara orisinal.

**Checkpoint terbaru Sprint 36–38:** baca [`SPRINT36_38_REPORT.md`](SPRINT36_38_REPORT.md). Pasir di teluk kini menggunakan jarak ke geometri pantai yang benar-benar digambar (tepi melengkung, skirt yang dipangkas, dan fillet cekung), bukan jarak ke persegi `land_mask`. Cache segmen pantai menggunakan bin spasial dua tile dan invalidasi otomatis ketika topology/height/water/sculpt berubah. Diagram: [`s38_sandband_curve_diagnostic.png`](s38_sandband_curve_diagnostic.png), **simulasi 2D ilustratif, bukan tangkapan Godot 3D**. Total **37 skrip regresi Godot belum bisa dijalankan** dalam lingkungan ini; **15 tes Python offline lulus**. RE ACNH tetap menjadi rujukan untuk kontrak ground; heuristik visual pesisir di sini adalah orisinal.

**Checkpoint baru Sprint 33–35:** lihat [`SPRINT33_35_REPORT.md`](SPRINT33_35_REPORT.md). Pantai di lekukan teluk sekarang menggunakan geometri *concave fillet* kecil yang ikut masuk mesh tanah **dan** collision, bukan sekadar shader. Pemeriksaan darat/laut memakai footprint segitiga yang sama; river mouth dilindungi dari tambalan melintang. Shoreline distance field kini menggunakan transformasi jarak Euklides terpisah (X/Z), sehingga sabuk ombak lebih konsisten di lengkung/diagonal. Diagram topologi: [`s35_fillet_topdown_schematic.png`](s35_fillet_topdown_schematic.png) — **diagram CPU, bukan capture Godot**. Total **36 skrip uji Godot** masih perlu dijalankan ketika runtime tersedia; **11 pengujian Python offline lulus**. Ini tetap desain orisinal; belum setara ACNH secara visual.

**Checkpoint terbaru Sprint 29–32:** baca [`RE_ADOPTION_REPORT_S29_32.md`](RE_ADOPTION_REPORT_S29_32.md). Repository RE pengguna [`menuyul312-max/acnh-re-results`](https://github.com/menuyul312-max/acnh-re-results) sekarang menjadi rujukan bukti untuk koordinat native, empat sektor segitiga, overlay 7, dan konfigurasi landmaking. Ini **bukan** klaim port atau salinan algoritme/asset game. Implementasi independen baru: `NativeTerrainReference`, `NusantaraGroundQuery`, `NativeCollisionPolicyReference`, brush pesisir 1×1/3×3 **atomik**, serta shader ombak dual-breaker. Tekan **T** untuk mode topologi, **U** untuk ukuran brush, **Y** untuk inspeksi empat titik ground. Dua test baru: `tests/test_re_ground_contract.gd` dan `tests/test_atomic_land_brush.gd`; tes terbaru **belum dijalankan** di sesi ini karena runner Godot tidak tersedia.

Proyek **Godot 4.7+** orisinal untuk riset terrain, collision, sungai, air terjun, dan penataan pulau dalam game Nusantara. **Sprint 26–28** menghadirkan `land_mask` agar pulau dapat ditata dengan teluk dan daratan terpisah, shader laut yang memakai distance field, dan mist di sisi air terjun. Fitur sebelumnya tetap meliputi jembatan 1–3 tile, ramp, graf akses, dua layer terrain, animasi, dan karakter GLB. **Ini desain Nusantara, bukan kode hasil dekompilasi ACNH.**

**Mulai dari [SPRINT26_28_REPORT.md](SPRINT26_28_REPORT.md)** untuk audit terbaru. Rujukan sebelumnya: [SPRINT23_25_REPORT.md](SPRINT23_25_REPORT.md), [SPRINT22_COASTLINE_BENCHMARK.md](SPRINT22_COASTLINE_BENCHMARK.md), [SPRINT19_21_CONTINUOUS_REVIEW.md](SPRINT19_21_CONTINUOUS_REVIEW.md), [SPRINT18_WATER_CONTOUR_WAVES.md](SPRINT18_WATER_CONTOUR_WAVES.md). Ukuran tile/physics Godot tetap prototipe, **bukan angka resmi ACNH**.

## Menjalankan

1. Buka `project.godot` menggunakan Godot 4.7+.
2. Tekan F5 untuk menjalankan demo.
3. Coba kontrol:

| Input | Fungsi |
| --- | --- |
| Klik kiri | Naikkan elevasi satu tingkat |
| Klik kanan | Turunkan elevasi satu tingkat |
| **Shift + klik kiri** | Tambahkan/hapus air pada tile |
| `1` | Denah teras |
| `2` | Denah tebing belokan |
| `3` | Denah sungai 14×10, 20 tile air, satu air terjun |
| **`4`** | Denah pulau nonpersegi dengan teluk, sungai, dan gosong terpisah |
| `Ctrl+S` | Simpan denah ke `user://nusantara_island_layout.json` |
| `L` | Muat denah tersimpan |
| **`O`** | Mode edit pesisir. Selagi aktif, klik **kiri** di dekat tepi pulau untuk membentuk cekungan, **kanan** untuk menguranginya. Titik sudut tetap terkunci. |
| **`T`** | Mode edit topologi. Klik **kiri** untuk menghapus daratan menjadi laut, klik **kanan** untuk mengembalikannya. Kedua mode `O` dan `T` tidak aktif bersamaan. |
| `W`, `A`, `S`, `D` atau panah | Gerakkan aktor fisika (atau probe debug) |
| `M` | Ganti mode: **Jalan → Rendam → Renang** |
| `C` | Aktif/nonaktif mode aktor `CharacterBody3D`; saat nonaktif, gunakan probe lama |
| `P` | Tampilkan/sembunyikan probe debug saat aktor fisika nonaktif |
| `V` | Tampilkan/sembunyikan zona kedalaman dan **panah arah arus** |
| `F` | Aktif/nonaktif dorongan arus pada karakter (untuk A/B perbandingan) |
| `R` | Bandingkan visual **GLB Nusantara** dengan manekin lama; aturan fisika tetap sama |
| **`E`** | **Ayunkan sekop** ketika berada di darat/tepi dan menyentuh tanah. Tidak bisa diulang sampai fase pemulihan selesai. |
| **`G`** | Tampilkan/sembunyikan titik tanah hasil raycast di bawah kaki kiri dan kanan. |
| **`I`** | Aktif/nonaktif **TwoBoneIK3D** kaki saat karakter berdiri di darat untuk membandingkan hasilnya. IK otomatis dilepas saat berjalan dan berenang. |
| **`Alt + klik kiri`** | Siklus material tanah pada layer pertama: natural, tanah merah, lumut, kerikil |
| **`Ctrl + klik kiri`** | Siklus ornamen orisinal pada layer kedua |
| **`Alt/Ctrl + klik kanan`** | Putar material/dekor layer terkait sebesar 90° |
| **`Alt/Ctrl + Shift + klik kiri`** | Siklus indeks variasi unit untuk layer terkait |
| **`B`** | Aktif/nonaktif aturan penataan pulau eksperimental (default OFF). HUD menampilkan alasan edit ditolak. |
| **`Shift + klik kanan`** | Siklus isi tile kering: kosong → pohon → rumah panggung → kosong. |
| **`N`** | Tampilkan/sembunyikan overlay berwarna tiap komponen jalan kaki (default OFF). |
| **`K`** | Perlindungan konektivitas pulau ON/OFF (default OFF); menolak edit yang memutus jalur yang sebelumnya terhubung. |
| **`Ctrl + Shift + klik kanan`** | Pada tile kering yang menghadap tebing +1 level: pasang/hapus ramp. Pada tile air dengan 1–3 sel air berturut-turut di antara dua bank sejajar: pasang/hapus **seluruh bentangan** jembatan sekaligus. Lokasi lain ditolak dengan alasan. |

## Sprint 26–28 — mask topologi dan transisi air

- **Sprint 26:** model `land_mask` per tile, editor `T`, collision hanya pada daratan dan schema denah v7 dengan migrasi v1–v6. Denah contoh tombol `4` memperlihatkan pulau nonpersegi.
- **Sprint 27:** laut mengisi sel kosong dan menggunakan shore SDF 256×256. Mesh pasir/pantai, skirt berwarna, serta klasifikasi rumput mempertimbangkan mask; transisi muara menggunakan alpha yang berkurang menuju laut.
- **Sprint 28:** mist transparan beranimasi pada sisi air terjun, tanpa mengubah collider atau arus.
- Visual diagnostik: `s28_topdown_comparison.png` berasal dari *Image* Godot headless. Script `tests/capture_sprint28.gd` tersedia untuk menghasilkan screenshot 3D ketika display tersedia, tetapi belum dapat dieksekusi di lingkungan ini.
- Tes baru `tests/test_island_mask.gd` dan `tests/test_fall_mist.gd`: total **33 tes regresi** pada checkpoint ini.

**Batasan:** bentuk coastline masih mengikuti grid dan sedikit membulat, belum polygon bebas. Laut baru belum bisa direnangi. Efek mist Sprint 28 perlu diperiksa dalam rendering 3D sebelum dinyatakan bagus.

## Sprint 23–25 — ukir garis pantai, ombak dan air terjun

- **Sprint 23:** laut menggunakan profile texture 512 sampel yang dibangun dari `CoastContour.boundary_at()`; animasi ombak mengikuti batas *nyata* yang digunakan oleh mesh/collider.
- **Sprint 24:** editor bisa mengubah `shore_profiles` per-node dalam mode `O`, data disimpan sebagai `schema_version: 6`, dan denah v1–v5 dimigrasikan tanpa mengubah level/water/link lama. Di outlet sungai bentuk ukiran pesisir otomatis diredam.
- **Sprint 25:** crest shoulder air terjun melewati pertemuan sungai-tebing, rivulet ditambah, dan alpha buih dasar dipecah dengan gradasi agar tidak kotak-kotak.
- Lihat `s25_coast_before.png` versus `s25_coast_after.png` (kamera identik), `s25_shore_editor_closeup.png`, `s25_river_mouth.png`, dan `s25_waterfall_detail.png`. Tes baru `tests/test_shore_profile.gd`; total 31 tes regresi.

**Batasan:** profil sculpt adalah perpindahan tepian, bukan mask pulau bebas. Laut luar masih dekoratif dan bentuk waterfall belum setara referensi ACNH.

## Sprint 22 — garis pantai organik

- `CoastContour.warp_ground()` menggeser geometri perimeter level 0 dengan dua frekuensi sinus mulus di ruang dunia. Pada fixture 16×10, rentang deformasi garis pantai terukur **0,930 unit dunia**. Bagian tengah pulau tidak ikut berubah; muara air tawar mendapat pengurangan deformasi.
- `TerrainBuilder` memakai vertex yang sudah digeser untuk **render dan collision**, sementara `WaterRules.can_traverse_path()` menolak langkah melalui teluk tanpa tanah. Editor/denah tile lama tetap dapat dipakai; ini belum mask pulau bebas.
- `CoastBuilder` menambah jangkauan laut sedikit ke dalam batas map supaya lekukan pantai yang masuk tidak meninggalkan langit kosong.
- `RiverContour` memberi alpha rendah pada ujung sungai level 0 dan `WaterBuilder.WATER_SHADER` membaurkannya di atas laut, mengurangi garis blok biru di muara.
- `WaterBuilder` juga membangun **tiga lapis tirai air terjun** yang bertemu di bibir atas dan kaki bawah namun sedikit terpisah di tengah. Ini menambah volume geometri, tanpa mengklaim sudah menjadi simulasi fluida.
- Uji baru `tests/test_coast_contour.gd`, capture `s22_island_organic_coast.png`, `s22_coastline_closeup.png`, dan `s22_river_mouth.png`. Total **30 tes regresi**.

**Batasan:** ini deformer pesisir deterministik dalam perimeter persegi, bukan land-mask editable bebas. Tepi air laut belum collider yang dapat direnangi dan shader ombak belum mengetahui signed-distance contour tepat di sepanjang semua lekukan.

## Sprint 19–21 — review dan pengembangan bertahap

- **19 / river:** `WaterBuilder.WATER_SHADER` kembali membaca arah arus dari `COLOR.rg`, tetapi hanya untuk drift *beramplitudo kecil* serta riak lokal yang berbentuk lengkungan pendek, bukan garis paralel antar tile. `ShoreFoam` memakai noise animasi dan `RiverBanks` menggradasikan warna tepi basah ke tanah.
- **20 / cliffs + falls:** rumput tidak lagi mewarnai seluruh level nol dengan pasir; pantai ditentukan dari jarak ke batas peta. Tebing memakai gradasi vertikal, faset kontinu, dan shader batu world-space. Bukaan waterfall diperluas dengan irisan dari dua elevasi, sisi tirai transparan, dan buih kaki yang terpecah oleh noise kontinu.
- **21 / sea:** `CoastBuilder` membangun **cincin laut visual** tanpa collider gameplay. Riak pesisir berbentuk pecahan sesaat, bukan rentetan garis paralel. `RiverContour` memperpanjang sungai level nol hingga batas peta agar bertemu visual laut. Bentuk garis pantai masih berbasis peta persegi; belum merupakan topologi pulau bebas.
- Tes visual tambahan: `tests/test_art_direction.gd` memeriksa palet pantai/rumput, gelombang mengikuti arus, alpha foam, faset tebing, bukaan air terjun, dan ocean mesh visual. Total **29 tes regresi**.
- Capture aktual: `s21_island_overview.png`, `s21_water_closeup.png`, `s21_coastal_waves.png`, `s21_wave_frame_a/b/c/d.png` (sekitar 0/1/3/6 detik), `s20_waterfall_overview.png`, `s20_waterfall_closeup.png`, `s20_waterfall_later.png`.

**Kualitas saat ini:** visual lebih kohesif daripada Sprint 18 namun **belum setara ACNH**. Tepi pulau masih persegi, badan air terjun belum volumetrik, buih/spray masih shader prosedural, bentuk tumbuhan sederhana, dan analisis referensi frame-by-frame masih diperlukan. Seluruh pemilihan warna/parameter adalah eksperimen desain Nusantara, tidak diatribusikan ke engine Nintendo.

## Perubahan Sprint 17 → 18

- `RiverContour.field_at()` menerapkan **warp berlapis yang kontinu di koordinat dunia** sebelum interpolasi data water tile. Kedua tepi sungai melengkung secara konsisten; tidak ada `random()` atau jitter yang berbeda di perbatasan tile.
- Seluruh konsumen lama menggunakan scalar field yang sama: mesh air, dinding/ground, bathymetry, zona karakter, dan bank collision. Meander adalah visual/analitik shared sehingga hasil fisika dan gambar tidak mengambil model berbeda.
- `WaterBuilder.WATER_SHADER` menghapus offset UV yang dulu dihitung langsung dari `COLOR.rg` flow yang berubah per tile. Shader baru memakai **fractal brownian motion**, domain distortion, warna noise lembut, dan ripple lokal yang memudar sebelum tepi sel. Aliran sungai untuk gameplay tetap berasal dari `RiverContour.flow_at()`.
- Tes baru `test_water_meander.gd` mengukur variasi garis tepian, kontinuitas scalar field, klasifikasi wet/dry, keberadaan bank collider dan struktur shader. Total **28 tes** bila seluruh suite lulus.
- Capture Godot: `s18_river_overview.png`, `s18_water_closeup.png`, `s18_wave_frame_a.png`, `s18_wave_frame_b.png`, `s18_bridge_bank_closeup.png`.

**Batasan:** ini masih noise procedural sederhana. Kecepatan air visual tidak selalu sesuai `flow_at()` pada tikungan dan pusaran, dan belum ada pembiasan/refleksi screen-space. Penyamaan parameter dengan ACNH membutuhkan bukti RE terpisah.

## Perubahan Sprint 16 → 17

- `IslandLinkRules.bridge_span()` mencari rangkaian **1, 2, atau 3 tile air** pada sumbu E/W atau N/S. Seluruhnya harus setinggi sama dan memiliki dua bank kering, sejajar, tanpa penghuni maupun konektor lain. Situs lebih panjang ditolak `SPAN_TOO_LONG`.
- Format simpan tetap **schema v5**: setiap tile air dalam jembatan menyimpan `kind=5/6` yang sama. Setengah jembatan dengan marker yang putus dianggap tidak valid.
- `IslandComposer.cycle_connector()` memasang atau menghapus seluruh rangkaian marker **secara atomik**. Proteksi `K` memeriksa dampak perubahan seluruh bentangan sekaligus.
- `IslandLinkBuilder` membangun **satu `StaticBody3D` dan satu mesh collider melengkung** per bentangan, bukan tiga papan terpisah. Visual papan, balok tepi, dan tiang penyangga memanjang bersama span.
- `BankApronA/B` adalah transisi pasir transparan dengan batas tanah sedikit bergelombang, ditambah bebatuan kecil visual-only. Semua benar-benar mengikuti posisi kedua bank; permukaan collision dasar tidak berubah.
- Tambahan `tests/test_bridge_spans.gd` dan `tests/test_bridge_span_physics.gd`; total **27 tes** bila suite lulus. Tes fisika menggerakkan kapsul `CharacterBody3D` sepanjang sungai selebar tiga tile.
- Capture Godot: `s17_before_wide_river.png`, `s17_after_wide_bridge.png`, `s17_actor_midspan.png`, `s17_bank_apron_detail.png`.

**Batasan Sprint 17:** geometri hanya lurus, maksimal tiga tile air. Kontur sungai global masih menggunakan algoritme lama; apron hanya meningkatkan transisi lokal di titik jembatan. Ini masih prototipe visual Nusantara, **bukan rekonstruksi numerik geometri ACNH**.

## Perubahan Sprint 15 → 16

- `IslandLinkRules.is_valid()` sekarang memeriksa **clearance pada tepian kering** jembatan dan **landasan atas** ramp. Pohon, rumah panggung, atau konektor lain pada endpoint tidak lagi diterima.
- `placement_report()` memberi kode terperinci `BANK_BLOCKED`, `BANK_LEVEL`, `NO_BANK_PAIR`, `RAMP_LANDING_BLOCKED`, dan `NO_CLIFF_STEP`, sehingga editor tidak hanya menyebut lokasi tidak valid.
- `IslandComposer.cycle_occupant()` menolak penempatan objek di endpoint konektor aktif (`LINK_LANDING`). Penempatan konektor baru juga tidak boleh merusak konektor tetangga (`LINK_CONFLICT`).
- `IslandLinkBuilder` sekarang membuat **12 bilah melintang, dua balok sisi mengikuti kontur, serta empat tiang bambu visual pada jembatan**. Ramp memakai papan kayu yang mengikuti kemiringan. Semua detail tambahan **non-collider** agar tidak memunculkan tangga-tangga yang menjegal kapsul; jalur fisik tetap satu collider dek kontinu.
- Pengujian baru `tests/test_link_clearance.gd` mencakup bank terhalang, perubahan berbahaya pada konektor aktif, benturan antara konektor, dan node visual. Total **25 tes** jika seluruh suite lulus.
- Capture baru: `s16_validation_rejected.png`, `s16_island_after.png`, `s16_bridge_detail.png`, `s16_ramp_detail.png`.

**Batasan:** penataan saat ini mendukung jembatan satu tile air dan ramp beda satu elevasi; tipe konektor belum bisa dipilih manual per arah. Detailing masih material procedural sederhana, bukan asset final. Angka geometrinya dibuat untuk game Nusantara, tidak diambil dari binary ACNH.

## Perubahan Sprint 14 → 15

- `IslandDefinition.connectors` menyimpan **0 = kosong, 1–4 = ramp N/E/S/W, 5–6 = jembatan E/W atau N/S**. Format simpan **schema v5** memigrasikan v1–v4, dengan validator yang menolak konektor tanpa penyangga legal.
- `IslandLinkRules` memisahkan geometri syarat penempatan, graf akses 4-arah, dan area deck. Ramp hanya di tile rendah dengan tetangga darat +1 elevasi; jembatan prototipe membentang **tepat satu tile air** dan memiliki darat pada kedua ujung level sama.
- `IslandLinkBuilder` membentuk permukaan low-poly original dengan **StaticBody3D/ConcavePolygonShape3D** pada collision layer 32; aktor dan raycast kaki dapat menginjaknya. Raycast editor tetap memilih terrain layer 1.
- `TerrainBuilder` membuka sisi cliff di depan ramp. `WaterRules` mengenali deck jembatan sebagai darat dan mengizinkan lintasan transisi tinggi melalui konektor valid. Aktor `CharacterBody3D` benar-benar melewati keduanya dalam pengujian fisik.
- Audit akses `N/K` kini menghitung bridge/ramp sebagai *edge*; mencabut satu-satunya penghubung bisa ditolak `ACCESS_SPLIT` ketika `K` ON.
- Tambahan `test_island_links.gd` dan `test_link_physics.gd`; total **24 tes** (sebelumnya 22).
- `connectors_before.png`, `connectors_after_access.png`, `connectors_bridge_walk.png`, `connectors_ramp_walk.png` dibuat melalui capture Godot.

Semua ukuran konektor, radius deck dan kemiringan adalah **parameter prototipe Nusantara**, bukan angka terverifikasi dari game Nintendo.

Sprint sebelumnya dicatat di bawah untuk histori.

## Perubahan Sprint 13 → 14

- `IslandAccessAudit.analyze()` membangun grafik **4-arah, tile kering, elevasi sama** dengan BFS. Komponen yang telah terpisah tidak diasumsikan sebagai bug atau syarat blokir semua edit.
- `IslandAccessAudit.preview_change()` membuat simulasi salinan denah dan mengecek apakah **tile yang tidak diedit** kehilangan keterhubungan setelah satu perubahan. Ini mengizinkan pembuatan bukit terisolasi di tepi dan jalur alternatif, tetapi menolak pemotongan satu-satunya jembatan darat.
- `IslandAccessOverlay` menggambar warna berbeda untuk tiap komponen; **`N`** menampilkan peta, **`K`** mengaktifkan pemeriksaan saat editing. Tombol lama `B` tetap independen.
- Penambahan air di tile berpenghuni selalu ditolak untuk menjaga integritas save v4, bahkan jika kedua mode validasi sedang OFF.
- Penolakan `ACCESS_SPLIT` menampilkan alasan dan tile merah. Dua mode OFF secara default agar perbandingan dan perilaku historis bisa diuji.
- Tambahan `tests/test_access_audit.gd`: skenario jembatan sempit, terputus oleh tebing, jalur memutar, area yang sudah terpisah, dan grid 112×96. Total **22 tes** setelah penambahan ini.
- Capture `access_regions_before.png`, `access_edit_rejected.png`, `access_split_simulation.png`, dan `access_island_overview.png` dihasilkan Godot.

Sprint 13 dan sebelumnya dicatat di bawah untuk histori.

## Perubahan Sprint 12 → 13

- `IslandBuildRules` memeriksa **konteks 3×3** di sekitar satu tile sebelum mengubah tebing/air. **3×3 bukan perintah menggambar sembilan tile**. Ini desain uji; tabel RE belum membuktikan radius predikat aslinya.
- Ketika `B` aktif, dekat pohon/bangunan, penurunan tebing dekat air, dan edit dekat waterfall dapat ditolak. Pesan/kode muncul di HUD; **tile sasaran diberi penanda merah**. `B` mati mempertahankan perilaku editor sebelumnya.
- Pohon sederhana dan rumah panggung sintetis menggunakan primitive mesh Godot, disertai collider prop terpisah. Karakter menabrak prop, sementara raycast editor memilih terrain di belakangnya.
- **Schema v4** menambahkan array occupancy; loading schema v1/v2/v3 didukung. Data rusak (occupancy di air atau nilai di luar batas) ditolak.
- `test_build_rules.gd` menambah cakupan validasi, mutasi satu tile, fitur, collision, dan persistensi, di samping tes lama.
- `build_rules_before.png`, `build_rules_after.png`, `build_rules_overview.png` adalah capture Godot asli Sprint 13.

Sprint 12 di bawah tetap dicatat sebagai sejarah penelitian.

## Perubahan Sprint 11 → 12

- Setiap tile kini menyimpan **dua layer**, masing-masing `unit/variation/rotation`, di samping level dan air.
- Editor/save format menjadi **schema v3**, tetap kompatibel saat memuat schema v1/v2. Nilai yang tidak valid ditolak.
- Palet dan dekor berada pada layer visual; terrain collider, water flow, dan aturan jalan/rendam/renang tidak berubah.
- Jalur tanah mengalir halus antar sel melalui **radial blending**, sehingga tidak berupa sekumpulan kotak bercelah.
- Tambahan `test_re_terrain_layers.gd` dan input mouse baru; total **20 tes**.
- Capture Godot `terrain_re_before.png`, `terrain_re_after.png`, `terrain_re_overview.png` memperlihatkan perubahan.

Temuan RE dasar: **96 preset 112×96 sel**, record tujuh field (dua layer + height), elevasi 0–5, serta pemilihan indeks variasi aktual dari cell. Layer kedua ternyata kosong pada preset-preset yang tersedia: di proyek ini layer kedua **ekstensi orisinal** dan tidak diklaim sebagai fitur yang telah terbukti dalam ACNH.

## Perubahan Sprint 10 → 11

1. **Pose GLB mengikuti rotasi rest.** Semua clip procedural `Skeleton3D` menambah delta gerak pada quaternion rest tulang asli. Ini menghilangkan masalah kaki terbalik/terangkat akibat rotasi identitas. Pengukuran pergelangan-ke-tanah di daratan rata turun dari 0,694 menjadi **0,097 unit**.
2. **`FootIKController` memakai dua `TwoBoneIK3D` asli Godot 4.7**, masing-masing `UpperLeg → LowerLeg → Foot`, target raycast terkalibrasi, dan knee pole yang mengikuti arah karakter. Kontrol `I` untuk A/B. Aktif hanya pada idle di ground; target ditolak jika beda elevasi lebih besar dari 0,15 unit. Tebing 1,55 unit **tidak** mungkin dijembatani kaki sepanjang ~0,30 unit.
3. **Raycast kaki memakai mask 9** (terrain layer 1 dan kontak geometri rinci layer 8), sementara kapsul aktor tetap pada layer terrain 1. Pada uji patch +0,11 unit, kesalahan pergelangan turun dari **0,110** ke **kurang dari 0,000001 unit** setelah IK bekerja.
4. **Sekop menjadi prop tangan berukuran lebih kecil**. Posisi grip berasal dari `RightHand`, sedangkan child pivot meluruskan poros ke arah tanah tanpa tersesat oleh bone axis GLB. Masih visual/prototipe: belum ada IK tangan kedua, penguncian bilah saat kontak, atau deformasi tanah.
5. **Bukti visual baru:** `ik_before_preview.png`, `ik_after_preview.png`, dan `shovel_grip_preview.png`, masing-masing 960×540. Buat ulang dengan `tests/capture_sprint11.gd`.

Lihat `SPRINT11_FINDINGS.md` untuk audit batas solver, hasil uji, dan tindak lanjut.

## Perbedaan Sprint 09 → 10

| Komponen | Sprint 09 | Sprint 10 |
| --- | --- | --- |
| Animasi GLB | Hanya idle/walk/wade/swim | **Lapisan aksi sekop**: `AnimationNodeBlendTree` + `AnimationNodeOneShot` dengan filter tulang atas |
| Aksi pemain | Navigasi dan mode air | `E` untuk aksi sekop 1,30 detik; cooldown otomatis dan ditolak saat berenang |
| Peralatan | Tidak ada | **Model sekop original sementara** menempel pada `RightHand` (`BoneAttachment3D`) |
| Respons tanah | Brush editor dapat mengubah elevasi | Bekas gali visual sementara setelah kontak sekop; belum mengubah data terrain |
| Pemeriksaan kaki | Tidak ada target per kaki | `FootGroundProbe` raycast untuk bone `LeftFoot` dan `RightFoot`, target debug `G` |
| QA | 16 tes | **18 tes**, termasuk aksi sekop, keberlanjutan gerak kaki, efek kontak, cooldown, larangan renang, target kiri/kanan |

## Catatan riset

Pose sekop masih authored keyframe sederhana pada bahu/tulang belakang/kepala; bukan hasil motion capture. Pencangkokan OneShot ke atas locomotion sudah diverifikasi tidak menghentikan gerak kaki. Bekas gali hanyalah mesh visual yang memudar **3 detik**; fungsi menggali item atau mengubah pulau belum diimplementasikan.

Catatan historis: pada Sprint 10, probe target kaki **baru mengukur, belum IK** dan mendeteksi gap ~0,69 unit. Sprint 11 mengidentifikasi bahwa nilai tersebut terutama berasal dari rotasi bone animasi yang mengabaikan pose rest; kini dikoreksi, dan solver IK aktif secara terbatas saat berdiri.

## Arsip perubahan Sprint 08 → 09

| Komponen | Sprint 08 | Sprint 09 |
| --- | --- | --- |
| Aktor yang terlihat | Manekin geometri sederhana | **GLB chibi pengguna**, skinned mesh dengan 23 tulang dan dua animasi bawaan |
| Jalur animasi | `AnimationTree` pada pivot node manekin | `AnimationTree` kedua menggerakkan **bone rotation tracks** milik `Skeleton3D` yang diimpor |
| Mapping rig | Joint dengan nama buatan kode | Adapter `Root/Spine/Head/Arm_L/Arm_R/Leg_L/Leg_R` dengan alias GLB seperti `Hips`, `LeftUpperArm`, `LeftUpperLeg` |
| Waterline | Tinggi tubuh mengikuti kapsul fisika | **Penurunan visual halus** sampai 0,14 unit sesuai kedalaman air (tanpa mengubah collider) |
| Debug | Clip dan jumlah riak | Nama clip, jumlah riak, sumber **GLB**, jumlah tulang, toggle `R` untuk A/B |
| QA | 15 tes | **16 tes**, menambahkan tes impor model 23 tulang, keyframe rotation tulang, waterline, dan toggle rig |

GLB sumber: `assets/character_nusantara.glb`, berasal dari unggahan pengguna `Chibi_Gray_T_Pose_Clay_Model_s3.glb`, bukan hasil dekompilasi ACNH. Asset di dalam ZIP untuk penggunaan proyek pengguna ini; tidak untuk redistribusi publik tanpa pemeriksaan hak/izin.

Import GLB lain dapat dilakukan dengan mengganti file di jalur yang sama lalu membuka project di Godot untuk reimport. Detail nama tulang, skala, orientasi, dan langkah pengujian tersedia pada `assets/README.md` serta `SPRINT09_FINDINGS.md`.

## Arsip perubahan Sprint 07 → 08

| Komponen | Sprint 07 | Sprint 08 |
| --- | --- | --- |
| Gerak sendi | Rotasi sinus langsung dalam `RiverCharacter` | `AnimationPlayer` berisi empat clip ber-keyframe dan `AnimationTree` state machine dengan crossfade 0,18 detik |
| State karakter | `MotionState` dan bobot transisi | State tetap, tapi aktor meneruskan transisi ke `MannequinAnimationBridge.travel()`; pose kiri/kanan dari track rotasi |
| Efek air | Foam tepian statis dan shader permukaan | Cincin riak transparan yang membesar dan memudar saat masuk air / bergerak di alur |
| Debug HUD | Pose dan arus | Nama clip aktif, jumlah riak yang hidup, dan arus |
| QA | Tes pose prosedural dan drift | Tambahan tes aktivasi AnimationTree, gerak keyframe sesungguhnya, spawn/lifetime riak, dan regresi seluruh 15 tes |

## Struktur data dan renderer

- `IslandDefinition`: elevasi, air, dan dua layer gaya terrain tersimpan terpisah (`schema_version=3`). Data schema v1/v2 tetap dapat dibuka; layer gaya yang belum tersedia diisi kosong.
- `IslandComposer`: brush tanah dan air, switch fixture, ekspor/impor JSON.
- `TerrainBuilder`: tebing dan sudut hibrida; dasar sungai turun secara kontinu mengikuti field air.
- `RiverContour`: occupancy permukaan air diinterpolasi antar pusat tile pada level elevasi yang sama, lalu permukaan air/bank dibentuk dengan memotong segitiga grid pada ambang 0,5. Resolusi **12 sampel per tile**. Arah arus dihasilkan dari jarak graf menuju satu outlet.
- `WaterBuilder`: mesh air kontur global, collider bank, buih tepian yang jarang, tirai air terjun selebar bukaan, dan area pendeteksi air kasar.
- `RiverBathymetry`: profil depresi tanah berbasis scalar field, dipakai bersama oleh `TerrainBuilder` dan kueri gameplay. Dasar dekat shore hampir setinggi air lalu turun sampai ~0,76 unit di alur pusat.
- `WaterRules`: kueri kedalaman air, empat zona, jarak shoreline dari 16 sampling radial, dan pemeriksaan jalur agar gerakan cepat tidak melompati sungai.
- `RiverCharacter`: `CharacterBody3D` dengan kapsul fisika, gravitasi/float, arah input, dorongan arus `0,55 unit/detik` pada alur dalam, serta empat `MotionState`. Pemeriksaan zona dilakukan sebelum dan sesudah pergeseran fisika. Mengirim state ke bridge animasi dan kondisi basah ke efek riak.
- `MannequinAnimationBridge`: jalur animasi manekin Sprint 08 tetap tersedia untuk uji perbandingan A/B (`R`). Default Sprint 09 adalah adapter `Skeleton3D` untuk GLB pengguna.
- `CharacterRigVisual`: memuat `assets/character_nusantara.glb` sebagai `PackedScene`, mencari `Skeleton3D`, memetakan tujuh peran tulang; jatuh kembali ke rig pengujian jika model tidak cocok. Menyetel tinggi visual secara terpisah dari collider.
- `SkeletonAnimationBridge`: clip idle/walk/wade/swim dan `AnimationTree` untuk `Skeleton3D`, termasuk pose bahu yang menurunkan lengan dari T-pose GLB. Crossfade 0,18 detik; belum motion-captured atau clip produksi.
- `SkeletonAnimationBridge` Sprint 10: satu clip nonloop `shovel` pada bahu kiri/kanan, kepala dan tulang belakang; overlay OneShot dengan filter tulang atas saat kaki tetap memainkan locomotion.
- `ShovelTool`: peralatan sementara dari mesh buatan kita yang mengikuti bone tangan kanan GLB. Hanya terlihat selama aksi berlangsung.
- `DigImpactFX`: bekas gali sementara sebagai visual ring/soill patch, terikat validasi raycast darat.
- `FootGroundProbe`: raycast per `LeftFoot`/`RightFoot` ke collider terrain (layer 1) atau detail kontak kaki (layer 8), menyimpan posisi dan gap sendi pergelangan ke tanah; marker kiri/kanan via `G`.
- `FootIKController`: koreksi kaki yang terbatas untuk idle, memakai native `TwoBoneIK3D` kiri/kanan dan knee pole; mati otomatis ketika berjalan/berenang dan jika selisih elevasi melebihi jangkauan aman. Toggle `I`.
- `WaterRippleFX`: mesh cincin rata di permukaan air dengan transparansi yang menurun. Maksimal 12 riak aktif, lifetime 0,95 detik; riak ketika masuk air dan gerak berkelanjutan (jeda 0,24 detik). **Bukan solver fluida**.
- `IslandWaterValidator`: audit jaringan air menggunakan flood-fill/BFS serta peringatan elevasi waterfall yang melompat lebih dari satu level. Peringatan bersifat **informasi desain kita**, bukan aturan resmi ACNH.
- `WaterZoneOverlay`: warna kuning di batas sungai dan sian di bagian tengah berdasarkan `RiverBathymetry.depth_at`; hanya debug.
- `WaterFlowOverlay`: panah arah arus hasil interpolasi `RiverContour.flow_at()`; hanya ditampilkan jika `V` aktif.
- `main.gd`: editor, `CharacterBody3D` aktif secara default, mode navigasi, HUD dan tombol `C` untuk probe lama.

Aturan mode tetap: **Jalan** hanya darat/tepi; **Rendam** bisa masuk kedalaman sampai `0,39` unit; **Renang** boleh menyeberang alur dalam. Ketika berenang di air yang cukup dalam, kecepatan horizontal adalah **kontrol pemain + dorongan arah aliran**, diperiksa ulang oleh aturan lintasan sebelum dan sesudah `move_and_slide()`. Jika input dilepas, arus masih dapat menggeser karakter; tombol `F` untuk menahan drift. Arus tidak bekerja sebagai fluida bermassa/debit.

## Bukti visual

- `terrain_preview_sprint06.png`: baseline World Lab 06.
- `terrain_preview_sprint07.png`: capture baseline Sprint 07 untuk perbandingan (1280×720).
- `terrain_preview_sprint08.png`: overview final Sprint 08 dengan HUD animasi dan riak (1280×720).
- `water_zones_preview.png`: heatmap kedalaman serta panah arus (1280×720).
- `physics_swim_closeup.png`: close-up aktor di dalam air dengan panah arus (1280×720).
- `current_debug_preview.png`: satu frame closeup manekin dan panah aliran (960×540).
- `current_motion.gif`: **24 frame** demonstrasi arus OFF → hanyut tanpa input → berenang melawan arus, disertai pose prosedural.
- `animation_wade_preview.png`: close-up rendam/tepi pada Sprint 08 (960×540).
- `animation_fx_preview.png`: close-up renang dan riak pada Sprint 08 (960×540).
- `animation_fx_closeup.png`: frame lanjutan setelah gerak pada Sprint 08 (960×540).
- `animation_fx_motion.gif`: **36 frame**, urutan jalan → rendam → renang dengan `AnimationTree` dan riak air.
- `rig_walk_preview.png`: GLB **berjalan** di atas teras tanah Sprint 09.
- `rig_wade_preview.png`: GLB **merendam** di tepi alur Sprint 09.
- `rig_swim_preview.png` dan `rig_swim_closeup.png`: GLB **berenang** di alur dalam dengan cincin riak Sprint 09.
- `rig_motion.gif`: **36 frame** demonstrasi GLB jalan → rendam → berenang dengan state, waterline, dan riak.
- `shovel_action_preview.png`: close-up satu fase alat sekop di tangan GLB (Sprint 10).
- `shovel_impact_preview.png`: efek bekas gali pada tanah.
- `shovel_walk_preview.png`: berjalan sambil melakukan aksi sekop.
- `foot_targets_preview.png`: marker raycast tanah di bawah dua kaki.
- `shovel_motion.gif`: **36 frame** urutan aksi sekop → sekop sambil berjalan → titik kaki debug.
- `terrain_re_before.png`, `terrain_re_after.png`: A/B jalur tanah organik dan dekor pada grid yang sama (Sprint 12).
- `terrain_re_overview.png`: overview lengkap editor dua-layer dengan HUD Sprint 12.
- `build_rules_before.png`, `build_rules_after.png`: A/B mode aturan edit Sprint 13, termasuk pohon/rumah orisinal dan tanda tile ditolak.
- `build_rules_overview.png`: overview scene dengan context check 3×3 aktif.
- `access_regions_before.png`: wilayah yang bisa dilalui sebelum jembatan tanah dipotong (Sprint 14).
- `access_edit_rejected.png`: tile merah ketika mode perlindungan menolak pemotongan jalur.
- `access_split_simulation.png`: mode bebas memperlihatkan dua sisi dataran dengan warna wilayah berbeda.
- `access_island_overview.png`: pemetaan akses visual pada denah sungai Nusantara sebelumnya.
- `connectors_before.png` dan `connectors_after_access.png`: perbandingan graf sebelum/sesudah ramp-jembatan Sprint 15.
- `connectors_bridge_walk.png`: aktor berada di lintasan fisik jembatan.
- `connectors_ramp_walk.png`: aktor bergerak naik ke tingkat tebing yang lebih tinggi.
- `terrain_preview.png`: overview World Lab 11 (1280×720) dengan status IK pada HUD; `terrain_preview_sprint09.png` adalah baseline historis.
- `ik_before_preview.png` / `ik_after_preview.png`: A/B koreksi ankle terhadap blok kontak setinggi +11 cm; capture aktual Godot Sprint 11.
- `shovel_grip_preview.png`: pegangan tangan kanan dan mata sekop menghadap tanah setelah koreksi GLB Sprint 11.
- `physics_modes.gif` dan `traversal_modes.gif`: GIF sprint sebelumnya untuk perbandingan.

## Pengujian

```bash
godot --headless --path . --script res://tests/test_island.gd
godot --headless --path . --script res://tests/test_physics.gd
godot --headless --path . --script res://tests/test_character.gd
godot --headless --path . --script res://tests/test_composer.gd
godot --headless --path . --script res://tests/test_editor_input.gd
godot --headless --path . --script res://tests/test_bank_collision.gd
godot --headless --path . --script res://tests/test_water_rules.gd
godot --headless --path . --script res://tests/test_water_validator.gd
godot --headless --path . --script res://tests/test_probe_ui.gd
godot --headless --path . --script res://tests/test_bathymetry.gd
godot --headless --path . --script res://tests/test_river_character.gd
godot --headless --path . --script res://tests/test_current_drift.gd
godot --headless --path . --script res://tests/test_animation_states.gd
godot --headless --path . --script res://tests/test_animation_tree.gd
godot --headless --path . --script res://tests/test_water_ripples.gd
godot --headless --path . --script res://tests/test_skeleton_rig.gd
godot --headless --path . --script res://tests/test_shovel_action.gd
godot --headless --path . --script res://tests/test_foot_ground_probe.gd
godot --headless --path . --script res://tests/test_foot_ik.gd
godot --headless --path . --script res://tests/test_re_terrain_layers.gd
godot --headless --path . --script res://tests/test_build_rules.gd
godot --headless --path . --script res://tests/test_access_audit.gd
godot --headless --path . --script res://tests/test_island_links.gd
godot --headless --path . --script res://tests/test_link_physics.gd
```

Jika memiliki display virtual, jalankan **`tests/capture_sprint15.gd`** untuk empat capture jembatan/ramp, dengan karakter dan graf akses. Skrip capture Sprint 14/13/12/11 tetap tersedia. Frame sementara `*_frame_*.png` tidak disertakan dalam ZIP.

## Batas prototipe

- Kontur sudah lintas-tile, tetapi *bank mesh* masih menampakkan facet kecil pada close-up. Belum ada penyatuan normal/material matang.
- Flow graph memilih satu outlet sederhana; **bukan** hidrodinamika, kecepatan terkalibrasi, ataupun simulasi debit. Dorongan `0,55 unit/detik` hanyalah parameter game sementara; cabang terputus/multi-muara belum diatur.
- Aktor kini memakai `AnimationTree` dengan rotasi bone rest yang benar pada GLB dan overlay OneShot sekop. **IK dua tulang sudah ada untuk kaki saat diam**, tetapi belum ada gait foot-lock, penyelesaian posisi tumit/jari kaki, stabilisasi panggul, retargeting Humanoid umum, buoyancy bermassa, stamina, jembatan, atau perahu. Model GLB masih memerlukan animasi produksi dan skinning check.
- Bekas gali `DigImpactFX` bersifat kosmetik, tidak mengubah `IslandDefinition`, tidak menciptakan lubang ber-collider, dan tidak menghasilkan item/inventory. Pemeriksaan aksi baru mengizinkan darat/tepi; belum mengecek alat aktif, stamina, atau jenis tile.
- Dasar sungai berasal dari profil analitik dan mesh radial; interpolasi segitiga berarti tinggi collider di antara vertex dapat berbeda sedikit dari fungsi kedalaman. Tes pusat alur cocok pada toleransi 0,045 unit.
- Jarak shoreline masih diperkirakan melalui 16 arah sampling maksimum 1,56 unit, bukan signed-distance field yang di-cache.
- Air terjun masih tirai tipis sederhana. Cincin air mengikuti permukaan secara analitik, bukan buoyancy atau surface deformation; sistem partikel splash dan interaksi air terjun belum ada.
- Audit jaringan sungai tetap informatif. Validator opsional Sprint 13 menolak sejumlah kasus lokal, tetapi belum memvalidasi lebar sungai, multi-muara, batas ekonomi, air laut/pasang-surut, konektivitas global, atau performa pulau besar.
- Semua ukuran, shader, dan algoritma merupakan **rancangan orisinal**, bukan rekonstruksi kode atau pengukuran internal ACNH.

Riset dan hasil eksperimen tercatat dalam `SPRINT01_FINDINGS.md` hingga `SPRINT15_LINKS_PHYSICS.md`.
