import { Controller } from "@hotwired/stimulus"

// Reduz as fotos no próprio celular antes de enviar (prints de stories chegam com 3–8 MB)
// e mostra miniaturas. Vídeos passam sem alteração.
const MAX_SIDE = 1600
const QUALITY = 0.82

export default class extends Controller {
  static targets = ["input", "previews", "zone", "submit"]

  over(e) { e.preventDefault(); this.zoneTarget.classList.add("is-over") }
  leave() { this.zoneTarget.classList.remove("is-over") }

  async changed() {
    this.leave()
    const files = Array.from(this.inputTarget.files)
    if (!files.length) { this.previewsTarget.innerHTML = ""; return }

    this.element.classList.add("is-uploading")
    if (this.hasSubmitTarget) this.submitTarget.disabled = true
    try {
      const processed = await Promise.all(files.map((f) => this.compress(f)))
      const dt = new DataTransfer()
      processed.forEach((f) => dt.items.add(f))
      this.inputTarget.files = dt.files
      this.render(processed)
    } catch (err) {
      console.warn("Falha ao comprimir, enviando originais", err)
      this.render(files)
    } finally {
      this.element.classList.remove("is-uploading")
      if (this.hasSubmitTarget) this.submitTarget.disabled = false
    }
  }

  render(files) {
    this.previewsTarget.innerHTML = ""
    files.forEach((file) => {
      const box = document.createElement("div")
      box.className = "pv"
      const url = URL.createObjectURL(file)
      const media = document.createElement(file.type.startsWith("video/") ? "video" : "img")
      media.src = url
      if (media.tagName === "VIDEO") { media.muted = true; media.playsInline = true }
      const size = document.createElement("span")
      size.textContent = `${(file.size / 1024 / 1024).toFixed(1)} MB`
      box.append(media, size)
      this.previewsTarget.append(box)
    })
  }

  async compress(file) {
    if (!file.type.startsWith("image/") || file.type === "image/gif") return file
    const bitmap = await createImageBitmap(file)
    const scale = Math.min(1, MAX_SIDE / Math.max(bitmap.width, bitmap.height))
    if (scale === 1 && file.size < 900 * 1024) return file
    const canvas = document.createElement("canvas")
    canvas.width = Math.round(bitmap.width * scale)
    canvas.height = Math.round(bitmap.height * scale)
    canvas.getContext("2d").drawImage(bitmap, 0, 0, canvas.width, canvas.height)
    const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/jpeg", QUALITY))
    if (!blob || blob.size >= file.size) return file
    const name = file.name.replace(/\.[^.]+$/, "") + ".jpg"
    return new File([blob], name, { type: "image/jpeg", lastModified: Date.now() })
  }
}
