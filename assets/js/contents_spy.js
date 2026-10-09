// Mark the section you're reading in the margin contents. The current
// section is the last heading that has scrolled above a line a third of the
// way down the window; its contents link gets aria-current, which the CSS
// highlights. Runs on plain pages and again after each LiveView navigation,
// since moving between posts swaps the contents without a page load.

let teardown = () => {}

const setup = () => {
  teardown()

  const links = [...document.querySelectorAll("aside.margin-nav ol.numbered a[href^='#']")]
  const sections = links
    .map(link => ({ link, heading: document.getElementById(decodeURIComponent(link.hash.slice(1))) }))
    .filter(({ heading }) => heading)

  if (sections.length === 0) return

  let ticking = false

  const update = () => {
    ticking = false
    const line = window.innerHeight / 3
    let current = null

    for (const section of sections) {
      if (section.heading.getBoundingClientRect().top <= line) current = section
    }

    for (const { link } of sections) {
      if (current && link === current.link) {
        link.setAttribute("aria-current", "location")
      } else {
        link.removeAttribute("aria-current")
      }
    }
  }

  const onScroll = () => {
    if (!ticking) {
      requestAnimationFrame(update)
      ticking = true
    }
  }

  window.addEventListener("scroll", onScroll, { passive: true })
  window.addEventListener("resize", onScroll)
  update()

  teardown = () => {
    window.removeEventListener("scroll", onScroll)
    window.removeEventListener("resize", onScroll)
  }
}

setup()
window.addEventListener("phx:page-loading-stop", setup)
