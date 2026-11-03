# Nusantara World Lab — Sprint 26–28

Tanggal: 3 November 2026 (WIB)  
Engine: Godot 4.7.2, GL Compatibility (tes non-grafis / `--headless`)  
Checkpoint: Sprint 25 diunduh dari penyimpanan proyek, lalu dilanjutkan dalam salinan `acnh_sprint28_island_topology`.

> **Referensi riset:** ACNH digunakan sebagai referensi observasi bahasa visual/penataan pulau. Semuanya tetap implementasi Nusantara yang mandiri. Angka dan shader di sini tidak diklaim berasal dari hasil decompile Nintendo ataupun sebagai pengukuran fisika ACNH.

## Sprint 26 — topologi pulau sesungguhnya

**Masalah terdahulu:** Sprint 25 hanya memindahkan tepi pulau persegi dengan `shore_profiles`. Tile secara logis tetap ada di semua posisi.

**Perbaikan:**

- Setiap tile kini mempunyai `land_mask`, penanda **ada/tidak ada daratan**. Tile hilang tidak membangun grass, tanah, dekorasi, penghuni, maupun collider darat.
- `IslandComposer.set_land_presence()` menambah atau menghapus tile melalui mode editor **T**: klik kiri menghapus daratan, klik kanan mengembalikannya. Memasang kembali daratan pada daerah kosong menggunakan persilangan sinar kamera dengan bidang laut, sehingga bisa memilih ruang yang sudah tidak memiliki collider.
- Penghapusan ditolak bila tile masih memuat air tawar, elevasi, pohon/bangunan, atau konektor aktif; juga ditolak bila akan menghilangkan daratan terakhir. Mode proteksi `K` mencegah edit yang memutus region jalan yang sebelumnya terhubung.
- `IslandLinkRules` dan `IslandAccessAudit` membedakan laut dari tanah datar, sehingga laut tidak berubah menjadi jalan kaki atau landasan jembatan semu.
- Format denah menjadi **schema v7** dengan `land_mask`. Denah versi 1–6 tetap dimigrasikan sebagai daratan utuh tanpa menimpa elevasi, alur air, maupun metadata konektor.
- Tambahan denah contoh **tombol 4**: pulau tak simetris, teluk di sisi timur, saluran di sisi selatan, gosong terpisah, serta satu sungai menuju pesisir. Ini layout orisinal untuk demonstrasi.

## Sprint 27 — pesisir dan air mengikuti topology mask

- `CoastBuilder` membuat **bidang laut tunggal** di bawah sel yang dihapus, bukan hanya cincin laut di luar peta. Mask darat mengungkapnya pada posisi yang dihapus.
- Jarak ombak sekarang dapat membaca tekstur **signed-distance field 256×256**, dibangun dari `CoastContour.on_island()` yang juga digunakan aturan gerak. Dua sapuan chamfer memproses jarak dengan biaya mendekati linear terhadap resolusi tekstur.
- Profil pesisir lama tetap menjadi fallback hemat untuk layout tanpa mask; nilai `use_coast_sdf` memilih mode berdasarkan apakah mask berisi laut.
- Mesh darat memundurkan garis tepi level nol secara lembut di dekat perbatasan darat–mask serta membulatkan beberapa pojok cembung. Lapisan `MaskedShoreSkirts` menutupi penampang tipis pantai sampai di bawah permukaan laut.
- Warna pasir level nol sekarang mempertimbangkan **batas mask** dan bukan hanya empat sisi pulau.
- `RiverContour` memberi occupancy parsial menuju laut yang menyentuh sungai level nol, menurunkan alpha air tawar mendekati outlet, dan tidak menggambar bank di luar daratan. Ini transisi render, belum hidrodinamika pasang-surut.

## Sprint 28 — waterfall edge blending

- `WaterBuilder` menambah mesh `FallMist`: sepasang veil transparan di sisi bukaan air terjun, memakai noise yang bergerak sesuai waktu. Alpha ditipiskan di sisi luar dan ujung atas/bawah supaya tidak menjadi kotak padat.
- Mist tetap **render-only**, tidak memodifikasi collision, zona berenang, atau gaya arus.
- Fixture sungai pada pulau mask kini mempunyai jalur berbelok, untuk menguji waterfall dan outlet dalam satu layout.

## QA dan batasan

### Gambar

- `s28_topdown_comparison.png`: diagnostik **top-down yang dibuat lewat kode Image Godot pada mode headless**, memakai land mask dan SDF yang juga dipakai renderer laut. Panel kiri = semua tile masih ada; kanan = mask topologi baru.
- `tests/capture_sprint28.gd`: script yang sudah disediakan untuk memotret lima view 3D (before/after, teluk, air terjun, muara). **Capture 3D tidak dapat diverifikasi dalam sesi ini karena virtual display ditolak lingkungan eksekusi.** Jangan menganggap peta diagnostik sebagai screenshot viewport.
- Regresi matematis dan integritas resource mesh dapat diperiksa lewat tes headless di folder `tests/`.

### Keterbatasan teknis dan visual

1. **Kontur masih berpangkal pada grid.** Pojok sudah sedikit dilunakkan, tetapi siluet teluk masih bertangga di beberapa sisi. Sprint selanjutnya membutuhkan polygon/dual-contour atau clip mesh berbasis SDF, dengan collision yang persis sama.
2. Bidang laut dalam mask masih visual. Karakter sengaja dicegah keluar dari gameplay grid, termasuk saat mode berenang.
3. Transisi river-to-sea masih berupa interpolasi occupancy/alpha, bukan percampuran fisik air tawar-laut.
4. Waterfall veil baru telah memiliki geometri/shader dan tes, namun kualitas artistiknya **belum lolos review screenshot 3D pada lingkungan ini**.
5. Tidak ada klaim tentang kesetaraan visual atau fisika 1:1 dengan ACNH.

## Menjalankan

1. Buka `project.godot` menggunakan Godot 4.7.x, lalu F5.
2. Tekan `4` untuk denah pulau baru. Tekan `T` untuk edit mask, klik **kiri** menghilangkan tanah dan **kanan** mengembalikan; tekan `T` untuk kembali ke mode terrain standar.
3. `O` tetap membuka sculpt profil tepi luar; kedua mode saling menonaktifkan otomatis.
4. `Ctrl+S` untuk simpan (schema v7), `L` untuk memuat. `K` mengaktifkan proteksi jalur.
5. Tes contoh: `godot --headless --path . --script res://tests/test_island_mask.gd` dan `res://tests/test_fall_mist.gd`.
6. Diagnostik tanpa GPU: `godot --headless --path . --script res://tests/capture_sprint28_topdown.gd`.
7. Ketika desktop/virtual display tersedia: `godot --rendering-method gl_compatibility --path . --script res://tests/capture_sprint28.gd` menghasilkan capture viewport 1280×720 untuk audit visual.

## Rencana kelanjutan

- **Sprint 29:** true smooth coastal topology (vertex clipping / marching squares dengan collider yang konsisten) dan editor brush sepanjang tepian, bukan sekadar potongan kotak.
- **Sprint 30:** laut yang bisa direnangi secara bertahap, validasi arus/surf pesisir, zona kedalaman baru, dan boat/shoreline interaksi.
- **Sprint 31:** waterfall side-rock join, spray nonuniform berbasis flow-space, temporal capture QA, pengujian performance pada beberapa resolusi.
