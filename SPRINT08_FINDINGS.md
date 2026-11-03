# Sprint 08 — AnimationTree dan riak kontak air

**Tanggal:** 2 November 2026. **Engine:** Godot 4.7.2. **Status:** prototipe orisinal, tes dan capture terotomasi.

## Sasaran

Mengurangi ketergantungan pada pose yang ditulis langsung di fungsi fisika dan membangun jalur animasi yang nanti bisa dihubungkan ke karakter orisinal Nusantara. Interaksi air juga harus memberi umpan balik visual ketika aktor memasuki sungai atau berenang.

## Eksperimen 1 — clip dan state machine engine

Tambahan `scripts/mannequin_animation_bridge.gd` mengandung `AnimationPlayer` dengan empat clip ber-keyframe (`idle`, `walk`, `wade`, `swim`) dan sebuah `AnimationTree` dengan `AnimationNodeStateMachine` serta *crossfade* **0,18 detik**.

- Kunci rotasi lengan/kaki mengikuti gerak periodik pada lima waktu (0,00; 0,25; 0,50; 0,75; 1,00 detik); kepala punya track bob sendiri.
- `RiverCharacter.MotionState` tetap memilih state dengan aturan gameplay; jembatan mengubah label Indonesia (`DIAM`, `JALAN`, `RENDAM`, `RENANG`) menjadi nama clip.
- Kemiringan dan orientasi badan terhadap arah gerak/air masih diberikan controller. Jika jembatan gagal inisialisasi, pose prosedural lama merupakan *fallback*.
- Ini **memvalidasi API dan penyaluran state**, bukan animasi rig final. GLB, `Skeleton3D`, skin weights, *retargeting*, dan set animasi karakter Nusantara asli masih pekerjaan terpisah.

**Pengujian:** `test_animation_tree.gd` mengecek tree aktif, keempat clip tersedia, transisi idle → walk → swim terjadi, serta nilai rotasi sendi berubah mengikuti keyframe; bukan hanya nama state yang berubah.

## Eksperimen 2 — riak saat kontak air

Tambahan `scripts/water_ripple_fx.gd` menggambar cincin bersegmen transparan secara lokal dari mesh segitiga. Event dipicu oleh kondisi `WaterRules.sample()` setelah pemindahan fisika.

| Pemicu | Respons |
| --- | --- |
| Peralihan darat ke air | Satu lingkaran lebih besar (strength 1,35) |
| Bergerak saat tetap di air | Satu lingkaran tiap ±0,24 detik; ukuran lebih kecil untuk dangkal |
| Berhenti/meninggalkan air | Tidak mengeluarkan lingkaran baru |
| Umur riak mencapai 0,95 detik | Mesh dihapus dari scene |
| Ada 12 lingkaran aktif | Riak tertua dikeluarkan sebelum menambah baru |

Pusat riak memakai koordinat permukaan air dari `sample.surface_y`, bukan tinggi kaki. Karena sistem ini hanya geometri visual datar, **tidak memodelkan tekanan, gelombang, atau debit sungai**. Tes `test_water_ripples.gd` memverifikasi tidak muncul di darat, muncul ketika masuk air dan berenang, memiliki geometri/material, serta dihapus setelah masa hidup.

## Verifikasi

**15 dari 15 pengujian `tests/test_*.gd` lulus** pada Godot headless 4.7.2, termasuk regresi editor, tebing, jaringan sungai, air terjun, pemeriksaan lintasan, dorongan arus, dan state animasi lama.

Capture `animation_wade_preview.png`, `animation_fx_preview.png`, `animation_fx_closeup.png`, dan `animation_fx_motion.gif` memperlihatkan manekin laboratorium, bukan cuplikan ACNH. HUD menampilkan nama clip yang sedang aktif dan jumlah riak. `terrain_preview_sprint07.png` serta GIF `current_motion.gif` menjadi arsip Sprint 07, sedangkan `terrain_preview.png` menampilkan World Lab 08.

## Penemuan dan batas interpretasi

1. **Kontrol gameplay dan playback animasi terpisah.** `RiverCharacter` menentukan kapan berenang, sedangkan `AnimationTree` mengatur perpindahan gerak; ini memudahkan perubahan desain karakter tanpa mengubah aturan sungai.
2. **Zona gameplay bukan otomatis pose.** Mode berenang dapat menghasilkan `WALK` di tepi dangkal karena `floating` hanya benar pada alur cukup dalam. UI sengaja membedakan *mode aksi* dan *state aktual*.
3. **Kontak air perlu titik sampel stabil.** Efek muncul di `surface_y` pada posisi aktor yang telah lolos validasi fisika. Perubahan elevasi tebing/air harus terus diuji agar ring tidak melayang di atas tepi.
4. **Gerakan estetis belum akurat untuk produksi.** Animasi ini keyframe sederhana pada pivot; belum ada invers kinematika, fase langkah sesuai kecepatan, waterline torso yang natural, atau rig GLB yang bisa mengganti node manekin.
5. **Riset ACNH dibatasi ke pembelajaran konsep yang bisa diamati.** Tidak ada aset, kode, parameter internal, dekompilasi, maupun klaim bahwa angka dan fisika proyek ini sama dengan ACNH.

## Sprint 09 yang direkomendasikan

- Definisikan kontrak karakter Nusantara berbasis `Skeleton3D`/GLB, daftar bone utama, dan pemetaan clip gameplay; impor satu model orisinal lalu buktikan transisi idle/walk/wade/swim.
- Tambahkan sambungan tinggi aktor dan *waterline* tubuh saat transisi kedalaman; bandingkan clipping visual pada batas bank.
- Bangun test scene untuk muara bercabang, kolam, dan air terjun, lalu pisahkan physics float, visual splash, dan aturan penataan pulau.

Referensi engine primer: [Godot AnimationTree](https://docs.godotengine.org/en/4.7/classes/class_animationtree.html), [AnimationNodeStateMachine](https://docs.godotengine.org/en/4.7/classes/class_animationnodestatemachine.html), [AnimationPlayer](https://docs.godotengine.org/en/4.7/classes/class_animationplayer.html).
