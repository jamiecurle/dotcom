
export default {
  mounted() {
    this.handler = (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key === "s") {
        e.preventDefault()
        // the Save button sits outside the form now, so submit the form itself
        this.el.requestSubmit()
      }

      if ((e.metaKey || e.ctrlKey) && e.key === "b") {
        e.preventDefault()
        wrapSelection(document.getElementById("post_markdown"), "**")
      }

      if ((e.metaKey || e.ctrlKey) && e.key === "i") {
        e.preventDefault()
        wrapSelection(document.getElementById("post_markdown"), "*")
      }
    }
    window.addEventListener("keydown", this.handler)
  },
  destroyed() {
    window.removeEventListener("keydown", this.handler)
  }
}

function wrapSelection(textarea, marker) {
  if (!textarea) return
  const { selectionStart: start, selectionEnd: end, value } = textarea
  const selected = value.slice(start, end)
  textarea.value = value.slice(0, start) + marker + selected + marker + value.slice(end)
  const newStart = start + marker.length
  textarea.setSelectionRange(newStart, newStart + selected.length)
  textarea.dispatchEvent(new Event("input", { bubbles: true }))
}