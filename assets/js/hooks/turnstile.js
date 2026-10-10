// Cloudflare Turnstile, the bot check on the subscribe form.
//
// The widget script is fetched only when a page with the hook mounts, so
// nothing from Cloudflare loads anywhere else on the site. Rendered inside
// the form, the widget adds a hidden "cf-turnstile-response" input whose
// token is posted with everything else and checked on the server. A token
// is single-use, so the server asks for a reset after a failed submit.
const SCRIPT = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit"

let loading = null

// Cloudflare's API, once its script has run. Not just `window.turnstile`:
// browsers expose elements by id as globals, so the hook's own
// <div id="turnstile"> *is* window.turnstile until the script replaces it.
function api() {
  const turnstile = window.turnstile
  return turnstile && typeof turnstile.render === "function" ? turnstile : null
}

function loadTurnstile() {
  if (api()) return Promise.resolve(api())

  loading ||= new Promise((resolve, reject) => {
    const script = document.createElement("script")
    script.src = SCRIPT
    script.async = true
    script.onload = () => resolve(api())
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
      if (api() && this.widget !== undefined) api().reset(this.widget)
    })
  },

  destroyed() {
    if (api() && this.widget !== undefined) api().remove(this.widget)
  },
}
