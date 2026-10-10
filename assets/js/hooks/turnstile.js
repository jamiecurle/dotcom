// Cloudflare Turnstile, the bot check on the subscribe form.
//
// The widget script is fetched only when a page with the hook mounts, so
// nothing from Cloudflare loads anywhere else on the site. Rendered inside
// the form, the widget adds a hidden "cf-turnstile-response" input whose
// token is posted with everything else and checked on the server. A token
// is single-use, so the server asks for a reset after a failed submit.
const SCRIPT = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit"

let loading = null

function loadTurnstile() {
  if (window.turnstile) return Promise.resolve(window.turnstile)

  loading ||= new Promise((resolve, reject) => {
    const script = document.createElement("script")
    script.src = SCRIPT
    script.async = true
    script.onload = () => resolve(window.turnstile)
    script.onerror = reject
    document.head.appendChild(script)
  })

  return loading
}

export default {
  mounted() {
    loadTurnstile().then((turnstile) => {
      this.widget = turnstile.render(this.el, {
        sitekey: this.el.dataset.sitekey,
        theme: "light",
        appearance: "interaction-only",
      })
    })

    this.handleEvent("turnstile:reset", () => {
      if (window.turnstile && this.widget !== undefined) window.turnstile.reset(this.widget)
    })
  },

  destroyed() {
    if (window.turnstile && this.widget !== undefined) window.turnstile.remove(this.widget)
  },
}
