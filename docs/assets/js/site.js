/* CodexSatellites site — progressive enhancement only.
   No dependencies, no build step, no network calls. Every behaviour here is
   additive: with scripting disabled the page renders complete and readable. */

window.__siteReady = true;

(function () {
  "use strict";

  var root = document.documentElement;
  var reduced = window.matchMedia("(prefers-reduced-motion: reduce)");
  var finePointer = window.matchMedia("(hover: hover) and (pointer: fine)");

  /* ------------------------------------------------------------- reveal */

  var revealTargets = Array.prototype.slice.call(
    document.querySelectorAll("[data-reveal]")
  );

  function showAll() {
    revealTargets.forEach(function (el) {
      el.classList.add("is-visible");
    });
  }

  revealTargets.forEach(function (el) {
    var delay = el.getAttribute("data-delay");
    if (delay) el.style.setProperty("--reveal-delay", delay + "ms");
  });

  if (!("IntersectionObserver" in window) || reduced.matches) {
    showAll();
  } else {
    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        });
      },
      { rootMargin: "0px 0px -12% 0px", threshold: 0.12 }
    );
    revealTargets.forEach(function (el) {
      observer.observe(el);
    });
    // safety net: anything still hidden after a few seconds is revealed,
    // so an observer edge case can never leave content invisible
    window.setTimeout(function () {
      revealTargets.forEach(function (el) {
        var box = el.getBoundingClientRect();
        if (box.top < window.innerHeight) el.classList.add("is-visible");
      });
    }, 3000);
  }

  /* ------------------------------------------------------------- header */

  var header = document.querySelector(".site-header");
  var ticking = false;

  function syncHeader() {
    if (header) header.classList.toggle("is-scrolled", window.scrollY > 8);
    ticking = false;
  }

  window.addEventListener(
    "scroll",
    function () {
      if (ticking) return;
      ticking = true;
      window.requestAnimationFrame(syncHeader);
    },
    { passive: true }
  );

  syncHeader();

  /* ---------------------------------------------------------- spotlight */

  var spotlightVars = false;

  function setSpotlight(event) {
    if (spotlightVars) return;
    spotlightVars = true;
    window.requestAnimationFrame(function () {
      root.style.setProperty("--gx", event.clientX + "px");
      root.style.setProperty("--gy", event.clientY + "px");
      spotlightVars = false;
    });
  }

  if (finePointer.matches && !reduced.matches) {
    document.body.classList.add("has-pointer");
    window.addEventListener("pointermove", setSpotlight, { passive: true });
  }

  /* ------------------------------------------------- surface highlight */

  var surfaces = document.querySelectorAll(
    ".bento-cell, .spec, .feature-visual"
  );

  surfaces.forEach(function (surface) {
    surface.addEventListener(
      "pointermove",
      function (event) {
        var box = surface.getBoundingClientRect();
        surface.style.setProperty("--mx", event.clientX - box.left + "px");
        surface.style.setProperty("--my", event.clientY - box.top + "px");
      },
      { passive: true }
    );
  });

  /* ------------------------------------------------- CTA pointer feedback */

  /* Feedback only: the primary control leans a few pixels toward the cursor so
     the press target reads as live. Capped at 3px so it never fights layout. */
  if (finePointer.matches && !reduced.matches) {
    document.querySelectorAll(".btn-primary").forEach(function (button) {
      button.addEventListener(
        "pointermove",
        function (event) {
          var box = button.getBoundingClientRect();
          var dx = (event.clientX - (box.left + box.width / 2)) / (box.width / 2);
          var dy = (event.clientY - (box.top + box.height / 2)) / (box.height / 2);
          button.style.transform =
            "translate(" + (dx * 3).toFixed(2) + "px," + (dy * 3).toFixed(2) + "px)";
        },
        { passive: true }
      );
      button.addEventListener("pointerleave", function () {
        button.style.transform = "";
      });
    });
  }

  /* ----------------------------------------------------- notch demo ----- */

  var demo = document.querySelector("[data-demo]");
  if (demo) {
    var sats = Array.prototype.slice.call(demo.querySelectorAll(".sat"));
    var bar = demo.querySelector(".demo-bar");
    var idleTimer = 0;
    var IDLE_MS = 3000;

    function isOpen() {
      return document.body.classList.contains("demo-open");
    }

    function setExpanded(state) {
      sats.forEach(function (sat) {
        sat.setAttribute("aria-expanded", state ? "true" : "false");
      });
    }

    function open() {
      document.body.classList.add("demo-open");
      setExpanded(true);
      restartIdle();
    }

    function close() {
      if (!isOpen()) return;
      document.body.classList.remove("demo-open");
      setExpanded(false);
      window.clearTimeout(idleTimer);
      idleTimer = 0;
    }

    function restartIdle() {
      window.clearTimeout(idleTimer);
      idleTimer = window.setTimeout(close, IDLE_MS);
    }

    sats.forEach(function (sat) {
      sat.addEventListener("click", function (event) {
        event.stopPropagation();
        if (isOpen()) {
          close();
        } else {
          open();
        }
      });
    });

    // any activity inside the demo resets the inactivity window,
    // mirroring the app's three seconds of Settings-Bar inactivity
    ["pointermove", "keydown", "focusin"].forEach(function (type) {
      demo.addEventListener(
        type,
        function () {
          if (isOpen()) restartIdle();
        },
        { passive: true }
      );
    });

    document.addEventListener("pointerdown", function (event) {
      if (isOpen() && !demo.contains(event.target)) close();
    });

    document.addEventListener("keydown", function (event) {
      if (event.key === "Escape") close();
    });

    if (bar) {
      var launch = bar.querySelector("[data-launch]");
      if (launch) {
        launch.addEventListener("click", function () {
          var on = launch.getAttribute("aria-pressed") === "true";
          launch.setAttribute("aria-pressed", on ? "false" : "true");
          restartIdle();
        });
      }

      var frequency = bar.querySelector("[data-interval]");
      if (frequency) {
        var intervals = ["1m", "5m", "15m"];
        frequency.addEventListener("click", function () {
          var current = intervals.indexOf(frequency.textContent.trim());
          var value = intervals[(current + 1) % intervals.length];
          frequency.textContent = value;
          frequency.setAttribute("aria-valuetext", value);
          restartIdle();
        });
      }

      var quit = bar.querySelector("[data-quit]");
      if (quit) {
        quit.addEventListener("click", function () {
          close();
        });
      }
    }

    setExpanded(false);

    // One-time self-demonstration: expand the satellites briefly the first
    // time the demo is on screen, so the hover interaction is discoverable.
    if (finePointer.matches && !reduced.matches && "IntersectionObserver" in window) {
      var hinted = false;
      var hintTimer = 0;
      var endHint = function () {
        window.clearTimeout(hintTimer);
        demo.classList.remove("is-hinting");
      };
      var hintObserver = new IntersectionObserver(
        function (entries) {
          entries.forEach(function (entry) {
            if (!entry.isIntersecting || hinted) return;
            hinted = true;
            hintObserver.disconnect();
            demo.classList.add("is-hinting");
            hintTimer = window.setTimeout(endHint, 1600);
          });
        },
        { threshold: 0.7 }
      );
      hintObserver.observe(demo);
      demo.addEventListener("pointerenter", function () {
        hinted = true;
        endHint();
      });
      demo.addEventListener("focusin", function () {
        hinted = true;
        endHint();
      });
    }
  }

  /* -------------------------------------------------- widget size toggle */

  var sizes = Array.prototype.slice.call(
    document.querySelectorAll("[data-size]")
  );

  sizes.forEach(function (button) {
    button.addEventListener("click", function () {
      var target = button.getAttribute("data-size");
      sizes.forEach(function (other) {
        var selected = other === button;
        other.setAttribute("aria-selected", selected ? "true" : "false");
        other.tabIndex = selected ? 0 : -1;
        var panel = document.getElementById(
          other.getAttribute("aria-controls")
        );
        if (panel) panel.hidden = !selected;
      });
      var shown = document.getElementById(button.getAttribute("aria-controls"));
      if (shown) shown.classList.add("is-visible");
    });
  });

  sizes.forEach(function (button, index) {
    button.addEventListener("keydown", function (event) {
      var step =
        event.key === "ArrowRight" ? 1 : event.key === "ArrowLeft" ? -1 : 0;
      if (!step) return;
      event.preventDefault();
      var next = sizes[(index + step + sizes.length) % sizes.length];
      next.focus();
      next.click();
    });
  });
})();
