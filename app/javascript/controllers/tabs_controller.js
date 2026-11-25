import { Controller } from "@hotwired/stimulus"

// Abas do login: "Sou influencer" / "Sou da equipe".
export default class extends Controller {
  static targets = ["tab", "panel"]

  select(event) {
    const name = event.currentTarget.dataset.tab
    this.tabTargets.forEach((t) => t.setAttribute("aria-selected", t.dataset.tab === name))
    this.panelTargets.forEach((p) => {
      p.hidden = p.dataset.tab !== name
      if (!p.hidden) p.querySelector("input:not([type=hidden])")?.focus()
    })
  }
}
