// Unstick the fixed primary nav once the footer reaches it, so the nav
// doesn't overlap the footer content.
const header = document.querySelector("body > header")
const footer = document.querySelector("body > footer")

if (header && footer) {
  let ticking = false

  const update = () => {
    ticking = false
    const headerHeight = header.offsetHeight
    const footerTop = footer.getBoundingClientRect().top + window.scrollY
    const unstickAt = footerTop - headerHeight

    if (window.scrollY >= unstickAt) {
      header.style.position = "absolute"
      header.style.top = unstickAt + "px"
    } else {
      header.style.position = ""
      header.style.top = ""
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
  window.addEventListener("phx:page-loading-stop", onScroll)
  update()
}
