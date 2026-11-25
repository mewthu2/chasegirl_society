import { Controller } from "@hotwired/stimulus"

// Copia o texto do alvo "source" e mostra "Copiado!" no botão por alguns segundos.
export default class extends Controller {
  static targets = ["source", "button"]

  async copy() {
    const text = this.sourceTarget.textContent.trim()
    try {
      await navigator.clipboard.writeText(text)
    } catch {
      const range = document.createRange()
      range.selectNodeContents(this.sourceTarget)
      const sel = window.getSelection()
      sel.removeAllRanges()
      sel.addRange(range)
      document.execCommand("copy")
      sel.removeAllRanges()
    }
    const label = this.buttonTarget.querySelector("span")
    const original = label.textContent
    label.textContent = "Copiado!"
    clearTimeout(this.timer)
    this.timer = setTimeout(() => { label.textContent = original }, 2000)
  }

  disconnect() { clearTimeout(this.timer) }
}
