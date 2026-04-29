import { Controller } from "@hotwired/stimulus"

// Handles updating the upload dropzone UI when a file is selected
export default class extends Controller {
  static targets = ["input", "filename"]

  connect() {
    this.updateDisplay()
  }

  fileSelected() {
    this.updateDisplay()
  }

  updateDisplay() {
    const file = this.inputTarget.files?.[0]

    if (file) {
      this.filenameTarget.textContent = `Selected: ${file.name}`
      this.element.classList.add("upload-dropzone--ready")
    } else {
      this.filenameTarget.textContent = ""
      this.element.classList.remove("upload-dropzone--ready")
    }
  }
}
