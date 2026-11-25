import { Controller } from "@hotwired/stimulus"

// Mostra o que cada canal exige: Feed = link; Stories = print; TikTok = link e print.
export default class extends Controller {
  static targets = ["linkField", "linkInput", "photoField", "photoInput", "photoMark"]
  static values = { link: Array, photo: Array, new: Boolean }

  connect() { this.update() }

  update() {
    const kind = this.element.querySelector("input[name='proof[kind]']:checked")?.value
    const needsLink = this.linkValue.includes(kind)
    const needsPhoto = this.photoValue.includes(kind)

    this.linkFieldTarget.hidden = !needsLink
    this.linkInputTarget.required = needsLink
    this.linkInputTarget.disabled = !needsLink
    this.photoInputTarget.required = needsPhoto && this.newValue
    if (this.hasPhotoMarkTarget) this.photoMarkTarget.hidden = !needsPhoto
  }
}
