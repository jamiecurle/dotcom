// Info toasts close themselves when their countdown circle runs out.
//
// The circle is a CSS animation (assets/css/app/toasts.css), so the timing,
// the pause on hover and the reduced-motion handling all live there. This
// only listens for the animation finishing, then closes the toast exactly as
// a click would - running the toast's own phx-click, which clears the flash on
// the server and plays the fade out.
export default {
  mounted() {
    this.onEnd = (e) => {
      if (e.animationName !== "toast-countdown") return
      this.liveSocket.execJS(this.el, this.el.getAttribute("phx-click"))
    }
    this.el.addEventListener("animationend", this.onEnd)
  },

  // A new message replaced the old one in place - start the countdown again.
  updated() {
    const countdown = this.el.querySelector(".toast-countdown")
    if (!countdown) return

    countdown.style.animation = "none"
    void countdown.offsetWidth // force a reflow so the animation restarts
    countdown.style.animation = ""
  },

  destroyed() {
    this.el.removeEventListener("animationend", this.onEnd)
  },
}
