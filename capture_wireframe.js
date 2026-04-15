const { chromium, devices } = require('playwright');
const fs = require('fs');

(async () => {
  // 1. Setup Folders
  const outputDir = './Screenshots/Wireframes';
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  // 2. Setup Playwright with Android Emulation (Pixel 5)
  const pixel5 = devices['Pixel 5'];
  const browser = await chromium.launch({ headless: true });
  
  // Menggunakan resolusi & konteks mobile Android
  const context = await browser.newContext({
    ...pixel5,
    deviceScaleFactor: 2, // High resolution
  });
  
  const page = await context.newPage();

  console.log("🚀 Membuka aplikasi Flutter di localhost:8080...");
  try {
    // Pastikan Anda telah menjalankan `flutter run -d web-server --web-port=8080`
    await page.goto('http://localhost:8080');
  } catch(e) {
    console.log("❌ Gagal membuka localhost:8080. Pastikan Flutter server sudah jalan!");
    await browser.close();
    return;
  }

  console.log("⏳ Menunggu Flutter Web Canvas selesai render (10 detik)...");
  await page.waitForTimeout(10000);

  console.log("📸 Menyimpan screenshot login asli (sebelum wireframe)...");
  await page.screenshot({ path: `${outputDir}/1_Original.png` });

  // 3. Mengaktifkan Wireframe (Klik tombol kanan bawah)
  console.log("👆 Mengeklik tombol Wireframe secara buta (kordinat pojok)...");
  // Resolusi Pixel 5 = 393 x 851. Tombol melayang ada di kanan bawah.
  // Estimasi koordinat X: 350, Y: 800
  await page.mouse.click(350, 800);
  
  console.log("⏳ Menunggu animasi Wireframe aktif (3 detik)...");
  await page.waitForTimeout(3000);

  const rawWireframePath = `${outputDir}/2_Raw_Wireframe.png`;
  console.log("📸 Mengambil screenshot Wireframe mentah (full screen)...");
  await page.screenshot({ path: rawWireframePath });

  // 4. Membungkus hasil Screenshot ke dalam Frame HP Android (CSS)
  console.log("🎨 Membuat bingkai fisik (device frame) Android keren...");
  
  // Membaca file gambar sebagai Base64 agar bisa dimasukkan langsung ke Background HTML
  const imageBuf = fs.readFileSync(rawWireframePath);
  const base64Img = imageBuf.toString('base64');
  const imgDataUrl = `data:image/png;base64,${base64Img}`;

  // CSS sederhana menyerupai rangka/casing Android Modern
  const frameHtml = `
  <!DOCTYPE html>
  <html>
  <head>
    <style>
      body {
        margin: 0;
        padding: 60px;
        background-color: #eaeaea; /* Background luar abu-abu terang */
        display: flex;
        justify-content: center;
        align-items: center;
        min-height: 100vh;
      }
      .phone-frame {
        width: 393px;
        height: 851px;
        border: 18px solid #111; /* Bezel hitam */
        border-radius: 44px; /* Sudut HP melengkung */
        box-shadow: 0 20px 50px rgba(0,0,0,0.6), inset 0 0 0 2px #444; /* Efek kedalaman & pantulan */
        position: relative;
        background-color: #000;
        overflow: hidden;
      }
      /* Kamera depan (Punch Hole) */
      .phone-frame::before {
        content: '';
        position: absolute;
        top: 0;
        left: 50%;
        transform: translateX(-50%);
        width: 14px;
        height: 14px;
        background-color: #111;
        border-radius: 50%;
        z-index: 10;
        margin-top: 12px;
        box-shadow: inset 0 -2px 3px rgba(255,255,255,0.1);
      }
      .screen {
        width: 100%;
        height: 100%;
        background-image: url('${imgDataUrl}');
        background-size: cover;
        background-position: center;
      }
    </style>
  </head>
  <body>
    <div class="phone-frame">
      <div class="screen"></div>
    </div>
  </body>
  </html>
  `;

  // Buka halaman baru untuk merakit HTML Frame
  const framePage = await browser.newPage({
    viewport: { width: 800, height: 1100 } // Diperbesar muat untuk casing HP dan paddingnya
  });
  await framePage.setContent(frameHtml);
  
  await framePage.waitForTimeout(1000); // Tunggu render efek border & shadow
  
  console.log("📸 Menyimpan hasil akhir (Wireframe + Bingkai Android)...");
  await framePage.screenshot({ path: `${outputDir}/3_Wireframe_Android_Mockup.png` });

  await browser.close();
  console.log("✅ Selesai! Buka folder Screenshots/Wireframes untuk melihat hasilnya.");
})();
