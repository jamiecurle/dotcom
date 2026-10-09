import topbar from "../../vendor/topbar";

export default {
  mounted() {
    this.pendingFiles = new Map();

    this.handler = (e) => {
      const { name, type, file } = e.detail;
      this.pendingFiles.set(name, file);
      this.pushEvent("sign-image-url", { name, type });
    };
    window.addEventListener("sign-image-url", this.handler);

    this.handleEvent("set-markdown", ({ markdown }) => this.setMarkdown(markdown));

    this.handleEvent("page-loading-stop", ({ name, url, public_url }) => {
      const file = this.pendingFiles.get(name);
      this.pendingFiles.delete(name);

      if (!file) {
        topbar.hide();
        return;
      }

      fetch(url, {
        method: "PUT",
        headers: { "Content-Type": file.type || "application/octet-stream" },
        body: file,
      })
        .then((res) => {
          if (!res.ok) throw new Error(`upload failed: ${res.status}`);
          this.swapPlaceholder(name, `![${name}](${public_url})`);
        })
        .catch((err) => {
          console.error(err);
          this.swapPlaceholder(name, `![upload failed: ${name}]()`);
        })
        .finally(() => topbar.hide());
    });
  },

  // The server merged a change made elsewhere (e.g. an accepted suggestion)
  // into the draft. LiveView won't patch a focused textarea, so set it here.
  setMarkdown(markdown) {
    if (this.el.value === markdown) return;

    const old = this.el.value;
    const caret = this.el.selectionEnd;
    const scrollTop = this.el.scrollTop;

    // Find where the old and new text start to differ. A caret before that
    // point stays put; one after it keeps its distance from the end, which
    // holds still when the change landed above where you're typing.
    let same = 0;
    while (same < old.length && old[same] === markdown[same]) same++;

    const pos = caret <= same ? caret : Math.max(0, markdown.length - (old.length - caret));

    this.el.value = markdown;
    this.el.setSelectionRange(pos, pos);
    this.el.scrollTop = scrollTop;
  },

  swapPlaceholder(name, replacement) {
    const placeholder = `![Uploading ${name}…]()`;
    const idx = this.el.value.indexOf(placeholder);
    if (idx === -1) return;

    const start = this.el.selectionStart;
    const end = this.el.selectionEnd;
    this.el.value =
      this.el.value.slice(0, idx) +
      replacement +
      this.el.value.slice(idx + placeholder.length);

    // Keep the caret roughly where it was; if it sat after the placeholder,
    // shift it by the length delta so typing position is preserved.
    const delta = replacement.length - placeholder.length;
    const adjust = (pos) => (pos > idx ? pos + delta : pos);
    this.el.setSelectionRange(adjust(start), adjust(end));

    this.el.dispatchEvent(new Event("input", { bubbles: true }));
  },

  destroyed() {
    window.removeEventListener("sign-image-url", this.handler);
  },
};
