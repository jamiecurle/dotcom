// The tag input on the post editor. The server decides what stays in the box
// after a tag is committed (nothing, or the half-typed word after the last
// comma), but LiveView won't overwrite a focused input, so it tells us here.
export default {
  mounted() {
    this.handleEvent("set-tag-input", ({ value }) => {
      this.el.value = value;
    });
  },
};
