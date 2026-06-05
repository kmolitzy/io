import { createClient } from "@supabase/supabase-js"
import axios from "axios"
import * as cheerio from "cheerio"

const SUPABASE_URL = "https://iwmxfxzlokvrabfdkplx.supabase.co"
const SUPABASE_KEY = "sb_publishable_9DBxgbZ0oHqRzlYB8yavJw_cJVwq3X3"

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY)

const BASE_URL = "https://komikmama.online"
const HEADERS = {
  "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36",
  "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
  "Accept-Language": "en-US,en;q=0.9,id;q=0.8",
  "Referer": BASE_URL
}

function extractSlug(url) {
  if (!url) return null
  const parts = url.replace(/\/$/, "").split("/")
  return parts[parts.length - 1]
}

function getImg(el, $) {
  const src = $(el).attr("data-src") ||
    $(el).attr("data-lazy-src") ||
    $(el).attr("data-bg") ||
    $(el).attr("src")
  if (!src && $(el).attr("style")) {
    const bgMatch = $(el).attr("style").match(/url\(["']?(.*?)["']?\)/)
    if (bgMatch) return bgMatch[1]
  }
  return src
}

async function ambilListKomik() {
  console.log("⏳ Mengambil list komik...")
  const { data } = await axios.get(BASE_URL, { headers: HEADERS })
  const $ = cheerio.load(data)
  const results = []

  $(".listupd .utao").each((i, el) => {
    const title = $(el).find(".uta .luf a.series h4").text().trim() || $(el).find(".uta .luf h4 a").text().trim()
    const url = $(el).find(".uta .luf a.series").attr("href")
    const thumb = getImg($(el).find(".uta .imgu img"), $)
    if (url) results.push({ title, url, slug: extractSlug(url), thumb })
  })

  console.log(`📦 Dapat ${results.length} komik`)
  return results
}

async function ambilDetail(url) {
  const { data } = await axios.get(url, { headers: HEADERS })
  const $ = cheerio.load(data)

  const title = $("h1.entry-title").text().trim()
  const thumb = getImg($(".thumb img"), $)
  const rating = $(".rating .num").text().trim()
  const synopsis = $(".entry-content p").text().trim()
  const genres = $(".seriestugenre a").map((i, el) => $(el).text().trim()).get().join(", ")

  const info = {}
  $(".infotable tr").each((i, el) => {
    const key = $(el).find("td:first-child").text().trim().replace(":", "")
    const val = $(el).find("td:last-child").text().trim()
    if (key) info[key.toLowerCase().replace(/\s+/g, "_")] = val
  })

  const chapters = []
  $("ul.clstyle li").each((i, el) => {
    const chUrl = $(el).find("a").attr("href")
    const name = $(el).find("span.chapternum").text().trim()
    const date = $(el).find("span.chapterdate").text().trim()
    if (chUrl) chapters.push({ name, url: chUrl, slug: extractSlug(chUrl), date })
  })

  return {
    title,
    url,
    slug: extractSlug(url),
    thumb,
    rating,
    synopsis,
    genres,
    status: info.status || "",
    chapters
  }
}

async function simpanKomik(komik) {
  const { chapters, ...komikData } = komik

  const { error: errKomik } = await supabase
    .from("komik")
    .upsert(komikData, { onConflict: "slug", ignoreDuplicates: true })

  if (errKomik) {
    console.log(`❌ Gagal simpan komik ${komik.title}:`, errKomik.message)
    return
  }

  if (chapters.length > 0) {
    const chapterRows = chapters.map(ch => ({
      ...ch,
      komik_slug: komik.slug
    }))

    const { error: errCh } = await supabase
      .from("chapters")
      .upsert(chapterRows, { onConflict: "slug", ignoreDuplicates: true })

    if (errCh) console.log(`❌ Gagal simpan chapters:`, errCh.message)
  }

  console.log(`✅ ${komik.title} — ${chapters.length} chapters disimpan`)
}

async function main() {
  console.log("🚀 Mulai scraping komikmama...\n")

  const listKomik = await ambilListKomik()

  for (const komik of listKomik) {
    try {
      console.log(`🔍 Scraping: ${komik.title}`)
      const detail = await ambilDetail(komik.url)
      await simpanKomik(detail)
      await new Promise(r => setTimeout(r, 1000))
    } catch (err) {
      console.log(`❌ Error ${komik.title}:`, err.message)
    }
  }

  console.log("\n🎉 Selesai!")
}

main()         
