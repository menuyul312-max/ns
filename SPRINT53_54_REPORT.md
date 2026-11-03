# Sprint 53–54 — Tebing Berlapis dan Bibir Rumput Lebih Alami

Status: implementasi source Godot + diagram CPU, **belum ada render engine Godot**.

## Sprint 53: relief tebing berlapis

- `TerrainBuilder._wall_offset()` kini menambahkan dua tonjolan batu (sekitar kedalaman relatif 0,31 dan 0,73) dengan satu ceruk strata di tengah.
- Profil memakai koordinat along-edge dunia yang sama dengan tile sebelah. Jarak tonjolan diubah secara perlahan sepanjang tebing, sehingga pola tidak diulang mentah setiap tile.
- Nilai relief tambahan dikalikan `sin(PI * depth_factor)` untuk menjamin **relief tambahan nol** tepat di bibir atas dan titik kaki bawah. Dinding atas tetap tersambung ke `lip_width()`, bagian bawah tetap ke posisi dasar.
- Dinding berada pada `TerrainBuilder` yang juga menghasilkan `WorldCollision`, bukan mesh dekorasi visual tanpa collision.

## Sprint 54: lip dan chamfer

- `WALL_ROWS` ditingkatkan dari 8 menjadi 12, memberi resolusi vertikal untuk strata baru.
- `CORNER_ARC_MIX` diturunkan dari 0,62 ke 0,54, menggeser sudut dari arc yang terlalu membulat ke arah chamfer/diagonal 45°.
- Profil bibir rumput diperlebar sedikit dan amplitudo variasi diperhalus. Nilai nominal 0,125 dengan dua harmonik 0,053 dan 0,024; minimum teoretis 0,048 dan maksimum 0,202 unit.
- `tests/test_s53_54_cliff.gd` memeriksa limit relief, sambungan atas/bawah, dan kesinambungan pada edge tile bersama. Tes matematis `tests/test_s53_54_cliff_offline.py` mencakup bentuk dan topologi nilai. Tes Godot belum dapat dijalankan di lingkungan ini.

Diagram `s54_cliff_profile_cpu.png` adalah potongan matematis asli Nusantara, **bukan** screenshot renderer Godot atau mesh dari ACNH. Ini menunjukkan arah perubahan geometrinya saja.

## Kebijakan repository

Sesuai arahan terbaru pengguna, workflow GitHub Actions dari Sprint 52 **dihapus**. Tidak ada CI/CD baru. Semua pembaruan dilakukan melalui commit langsung di `main`.

## Validasi dan risiko terbuka

- 37/37 tes Python offline lulus pada checkpoint ini; tes engine GDScript tetap pending.
- Belum ada verifikasi shader, shading normal, siluet sebenarnya, kaki aktor di tebing, atau collision seam dalam Godot.
- Perbedaan bentuk terhadap ACNH masih memerlukan tangkapan layar renderer/rujukan visual. Hasil RE di [`acnh-re-results`](https://github.com/menuyul312-max/acnh-re-results) dipakai untuk kontrak koordinat/terrain/mekanik yang terbukti; nilai radius, strata dan warna ini adalah desain orisinal Nusantara, bukan parameter native yang terungkap.

## Berikutnya

Lakukan review visual pada Godot 4.7+, terutama sambungan dinding dengan grass lip pada sudut chamfer, relief yang menonjol dan siluet ketika kamera rendah. Bila terlihat overlap/seam, koreksi profil pada titik bersama sebelum menaikkan amplitudo lagi.
