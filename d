ganti bagian simpanKomik di scraper.js, khusus bagian chapters, jadi pakai insert biasa dengan hapus dulu:
jsasync function simpanKomik(komik) {
  const { chapters, ...komikData } = komik

  const { error: errKomik } = await supabase
    .from("komik")
    .upsert(komikData, { onConflict: "slug" })

  if (errKomik) {
    console.log(`❌ Gagal simpan komik ${komik.title}:`, errKomik.message)
    return
  }

  if (chapters.length > 0) {
    // Hapus chapters lama dulu baru insert baru
    await supabase.from("chapters").delete().eq("komik_slug", komik.slug)

    const chapterRows = chapters.map(ch => ({
      ...ch,
      komik_slug: komik.slug
    }))

    const { error: errCh } = await supabase
      .from("chapters")
      .insert(chapterRows)

    if (errCh) console.log(`❌ Gagal simpan chapters:`, errCh.message)
  }

  console.log(`✅ ${komik.title} — ${chapters.length} chapters disimpan`)
}

Buat lebih banyak komik (scrape beberapa halaman)
Ganti fungsi ambilListKomik jadi:
jsasync function ambilListKomik() {
  console.log("⏳ Mengambil list komik...")
  const results = []

  for (let page = 1; page <= 5; page++) {
    const url = page === 1 ? `${BASE_URL}/komik/` : `${BASE_URL}/komik/page/${page}/`
    const { data } = await axios.get(url, { headers: HEADERS })
    const $ = cheerio.load(data)

    $(".listupd .bs").each((i, el) => {
      const title = $(el).find(".tt").text().trim()
      const url = $(el).find("a").attr("href")
      const thumb = getImg($(el).find("img"), $)
      if (url) results.push({ title, url, slug: extractSlug(url), thumb })
    })

    console.log(`📄 Halaman ${page} — total ${results.length} komik`)
    await new Promise(r => setTimeout(r, 1000))
  }

  return results
}
Ini akan scrape 5 halaman sekaligus, bisa dapat 100+ komik. Kalau mau lebih banyak tinggal ganti <= 5 jadi angka lebih besar.
Jalankan lagi setelah TRUNCATE:
