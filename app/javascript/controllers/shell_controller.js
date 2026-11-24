import { Controller } from "@hotwired/stimulus"

// Abre/fecha o menu lateral no celular.
export default class extends Controller {
  toggle() { document.body.classList.toggle("sidebar-open") }
  close() { document.body.classList.remove("sidebar-open") }
}
