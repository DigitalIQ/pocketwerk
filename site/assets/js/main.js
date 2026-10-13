/* Pocketwerk site: small interactions, no dependencies. The 3D hero loads on first interaction. */
(function () {
  "use strict";
  var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
  var live = document.createElement("p");
  live.className = "sr-only";
  live.setAttribute("aria-live", "polite");
  document.body.appendChild(live);
  function say(text) { live.textContent = ""; setTimeout(function () { live.textContent = text; }, 30); }

  /* ---------- copy the Homebrew command ---------- */
  document.querySelectorAll("[data-copy]").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var code = document.getElementById(btn.getAttribute("data-copy"));
      var text = code.textContent.trim();
      var done = function () {
        var label = btn.querySelector("span");
        var icon = btn.querySelector("use");
        btn.classList.add("done");
        label.textContent = "Copied";
        icon.setAttribute("href", "#i-check");
        say("Homebrew command copied.");
        setTimeout(function () {
          btn.classList.remove("done");
          label.textContent = "Copy";
          icon.setAttribute("href", "#i-copy");
        }, 2000);
      };
      if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(text).then(done, function () { selectText(code); });
      } else {
        selectText(code);
      }
    });
  });
  function selectText(el) {
    var range = document.createRange();
    range.selectNodeContents(el);
    var sel = window.getSelection();
    sel.removeAllRanges();
    sel.addRange(range);
    say("Command selected. Press Command C to copy.");
  }

  /* ---------- the example pocket ---------- */
  var pocket = document.getElementById("pocket");
  var list = document.getElementById("items");
  var status = document.getElementById("demo-status");
  var searchOut = document.getElementById("pocket-search");
  var dockBtn = document.getElementById("dock-pocket");
  var items = Array.prototype.slice.call(list.querySelectorAll("li"));
  var query = "";
  var queryTimer;

  function nameOf(li) { return li.querySelector(".name").textContent; }
  function setStatus(text) { status.textContent = text; }
  function ping(li) {
    li.classList.add("ping");
    setTimeout(function () { li.classList.remove("ping"); }, 160);
  }
  function focusItem(li) {
    items.forEach(function (x) { x.tabIndex = -1; });
    li.tabIndex = 0;
    li.focus();
  }
  function selected() { return items.filter(function (li) { return li.getAttribute("aria-selected") === "true"; }); }
  function clearSelection() { items.forEach(function (li) { li.setAttribute("aria-selected", "false"); }); }
  function columns() {
    var v = pocket.getAttribute("data-view");
    return v === "grid" ? 3 : v === "tiles" ? 2 : 1;
  }
  function openItem(li) {
    var kind = li.getAttribute("data-kind");
    var n = nameOf(li);
    var verb = kind === "folder" ? "Opens the folder " + n + " inside the pocket." : "Opens " + n + ".";
    setStatus(verb);
    ping(li);
  }

  list.addEventListener("click", function (e) {
    var li = e.target.closest("li");
    if (!li) return;
    focusItem(li);
    if (e.metaKey || e.ctrlKey) {
      var on = li.getAttribute("aria-selected") !== "true";
      li.setAttribute("aria-selected", on ? "true" : "false");
      var count = selected().length;
      setStatus(count ? count + " selected. Return opens them together." : "Nothing selected.");
      return;
    }
    if (e.altKey) {
      if (li.getAttribute("data-kind") === "app") setStatus("Quits " + nameOf(li) + ".");
      else setStatus(nameOf(li) + " isn't an app, so there's nothing to quit.");
      ping(li);
      return;
    }
    clearSelection();
    openItem(li);
  });

  list.addEventListener("keydown", function (e) {
    var li = e.target.closest("li");
    if (!li) return;
    var visible = items.filter(function (x) { return !x.classList.contains("dim"); });
    var i = visible.indexOf(li);
    if (i < 0) { visible = items; i = items.indexOf(li); }
    var step = { ArrowRight: 1, ArrowLeft: -1, ArrowDown: columns(), ArrowUp: -columns() }[e.key];
    if (step) {
      e.preventDefault();
      var next = visible[Math.max(0, Math.min(visible.length - 1, i + step))];
      focusItem(next);
      return;
    }
    if (e.key === "Enter") {
      e.preventDefault();
      var sel = selected();
      if (sel.length > 1) { setStatus("Opens " + sel.map(nameOf).join(", ") + " together."); clearSelection(); }
      else openItem(li);
      return;
    }
    if (e.key === " ") {
      e.preventDefault();
      setStatus("Quick Look: " + nameOf(li) + ".");
      ping(li);
      return;
    }
    if (e.key === "Escape") { resetSearch(); return; }
    if (e.key === "Backspace") { query = query.slice(0, -1); applySearch(); return; }
    if (e.key.length === 1 && /\S/.test(e.key) && !e.metaKey && !e.ctrlKey && !e.altKey) {
      query += e.key.toLowerCase();
      applySearch();
    }
  });
  function applySearch() {
    clearTimeout(queryTimer);
    var first = null;
    items.forEach(function (li) {
      var hit = !query || nameOf(li).toLowerCase().indexOf(query) !== -1;
      li.classList.toggle("dim", !hit);
      if (hit && !first) first = li;
    });
    searchOut.textContent = query ? "Search: " + query : "";
    if (query && first) { focusItem(first); setStatus(first ? "Return opens " + nameOf(first) + "." : ""); }
    if (query && !first) setStatus("Nothing matches “" + query + "”.");
    queryTimer = setTimeout(resetSearch, 4000);
  }
  function resetSearch() {
    query = "";
    items.forEach(function (li) { li.classList.remove("dim"); });
    searchOut.textContent = "";
  }

  document.querySelectorAll("#pocket .views button").forEach(function (b) {
    b.addEventListener("click", function () {
      var v = b.getAttribute("data-view");
      pocket.setAttribute("data-view", v);
      document.querySelectorAll("#pocket .views button").forEach(function (x) { x.setAttribute("aria-pressed", x === b ? "true" : "false"); });
      setStatus({ grid: "Grid view.", list: "List view.", tiles: "Tiles view." }[v]);
    });
  });

  dockBtn.addEventListener("click", function () {
    var open = pocket.getAttribute("data-open") !== "true";
    pocket.setAttribute("data-open", open ? "true" : "false");
    dockBtn.setAttribute("aria-expanded", open ? "true" : "false");
    if (open) { pocket.removeAttribute("inert"); setStatus("The pocket opens right above its Dock icon."); }
    else { pocket.setAttribute("inert", ""); setStatus("A second click closes it."); }
  });

  /* ---------- design studio preview ---------- */
  var preview = document.getElementById("studio-pocket");
  var stageEl = document.getElementById("studio-stage");
  var clone = pocket.cloneNode(true);
  clone.querySelectorAll("[id]").forEach(function (el) { el.removeAttribute("id"); });
  clone.querySelectorAll("[tabindex]").forEach(function (el) { el.removeAttribute("tabindex"); });
  clone.querySelectorAll("[role]").forEach(function (el) { el.removeAttribute("role"); });
  clone.querySelectorAll("[aria-selected],[aria-labelledby],[aria-multiselectable],[aria-live]").forEach(function (el) {
    ["aria-selected", "aria-labelledby", "aria-multiselectable", "aria-live"].forEach(function (a) { el.removeAttribute(a); });
  });
  clone.querySelectorAll(".views button").forEach(function (b) { b.tabIndex = -1; });
  preview.innerHTML = clone.innerHTML;
  var looks = ["glass", "board", "signal", "night", "paper", "pointer"];
  document.querySelectorAll(".swatch").forEach(function (s) {
    s.addEventListener("click", function () {
      var look = s.getAttribute("data-look");
      looks.forEach(function (l) { preview.classList.remove("look-" + l); });
      preview.classList.add("look-" + look);
      document.querySelectorAll(".swatch").forEach(function (x) { x.setAttribute("aria-pressed", x === s ? "true" : "false"); });
    });
  });
  if (!reduceMotion.matches) {
    stageEl.addEventListener("pointermove", function (e) {
      var r = preview.getBoundingClientRect();
      preview.style.setProperty("--mx", ((e.clientX - r.left) / r.width * 100).toFixed(1) + "%");
      preview.style.setProperty("--my", ((e.clientY - r.top) / r.height * 100).toFixed(1) + "%");
    });
  }

  /* ---------- dock profiles ---------- */
  var row = document.getElementById("dock-row");
  var P = function (c, g) { return { c: c, g: g }; };
  var profiles = {
    work: [P("t-paper", "g-chat"), P("t-paper", "g-globe"), P("t-mint", "g-code"), P("t-ink", "g-term"), { spacer: "Projects" }, { pocket: ["t-mint", "t-paper", "t-ink", "t-yellow"] }, P("t-paper", "g-doc"), P("t-yellow", "g-cal")],
    studio: [P("t-yellow", "g-pen"), P("t-mint", "g-photo"), P("t-ink", "g-film"), { spacer: "Assets" }, { pocket: ["t-yellow", "t-orange", "t-mint", "t-paper"] }, P("t-green", "g-folder"), P("t-orange", "g-note")],
    evening: [P("t-orange", "g-note"), P("t-ink", "g-film"), P("t-paper", "g-chat"), P("t-yellow", "g-photo"), { pocket: ["t-orange", "t-ink", "t-yellow", "t-paper"] }]
  };
  function iconHTML(it) {
    if (it.spacer) return '<span><span class="spacer">' + it.spacer + "</span></span>";
    if (it.pocket) return '<span><span class="dock-icon mgi"><span class="mg">' + it.pocket.map(function (c) { return '<i class="' + c + '"></i>'; }).join("") + "</span></span></span>";
    return '<span><span class="dock-icon ' + it.c + '"><svg aria-hidden="true"><use href="#' + it.g + '"/></svg></span></span>';
  }
  function labelFor(name, data) {
    var n = data.filter(function (x) { return !x.spacer; }).length;
    return name.charAt(0).toUpperCase() + name.slice(1) + " profile: " + n + " Dock icons" + (data.some(function (x) { return x.spacer; }) ? " and a spacer." : ".");
  }
  function showProfile(name, animate) {
    var data = profiles[name];
    row.setAttribute("aria-label", labelFor(name, data));
    if (!animate || reduceMotion.matches) { row.innerHTML = data.map(iconHTML).join(""); return; }
    var old = row.querySelectorAll(":scope > span");
    old.forEach(function (li, i) { setTimeout(function () { li.classList.add("leave"); }, i * 25); });
    setTimeout(function () {
      row.innerHTML = data.map(iconHTML).join("");
      var fresh = row.querySelectorAll(":scope > span");
      fresh.forEach(function (li) { li.classList.add("enter"); });
      requestAnimationFrame(function () {
        fresh.forEach(function (li, i) { setTimeout(function () { li.classList.remove("enter"); }, 30 + i * 40); });
      });
    }, 200 + old.length * 25);
  }
  showProfile("work", false);
  var tabs = Array.prototype.slice.call(document.querySelectorAll(".profile-tabs [role=tab]"));
  function selectTab(t, focus) {
    tabs.forEach(function (x) {
      var on = x === t;
      x.setAttribute("aria-selected", on ? "true" : "false");
      x.tabIndex = on ? 0 : -1;
    });
    document.getElementById("dock-demo").setAttribute("aria-labelledby", t.id);
    if (focus) t.focus();
    showProfile(t.getAttribute("data-profile"), true);
  }
  tabs.forEach(function (t, i) {
    t.addEventListener("click", function () { if (t.getAttribute("aria-selected") !== "true") selectTab(t, false); });
    t.addEventListener("keydown", function (e) {
      var d = e.key === "ArrowRight" ? 1 : e.key === "ArrowLeft" ? -1 : 0;
      if (!d) return;
      e.preventDefault();
      selectTab(tabs[(i + d + tabs.length) % tabs.length], true);
    });
  });

  /* ---------- product video (shown once rendered) ---------- */
  var film = document.getElementById("film");
  if (film && film.getAttribute("data-video-ready") === "true") {
    var img = film.querySelector("img");
    var v = document.createElement("video");
    v.muted = true; v.playsInline = true; v.loop = true; v.preload = "none";
    v.poster = img.getAttribute("src");
    v.width = 1280; v.height = 800;
    v.setAttribute("aria-label", img.getAttribute("alt"));
    v.innerHTML = '<source src="' + film.getAttribute("data-webm") + '" type="video/webm"><source src="' + film.getAttribute("data-mp4") + '" type="video/mp4">';
    if (reduceMotion.matches) v.controls = true;
    else {
      v.autoplay = false;
      new IntersectionObserver(function (entries) {
        entries.forEach(function (en) { if (en.isIntersecting) v.play().catch(function () {}); else v.pause(); });
      }, { threshold: 0.4 }).observe(v);
    }
    img.replaceWith(v);
  }

  /* ---------- 3D hero, started lazily ---------- */
  var stage = document.getElementById("stage");
  function webgl() {
    try { var c = document.createElement("canvas"); return !!(c.getContext("webgl2") || c.getContext("webgl")); } catch (e) { return false; }
  }
  if (stage && !reduceMotion.matches && webgl() && !(navigator.connection && navigator.connection.saveData)) {
    var started = false;
    var evs = ["pointermove", "pointerdown", "touchstart", "scroll", "keydown", "wheel"];
    var start = function () {
      if (started) return;
      started = true;
      evs.forEach(function (ev) { window.removeEventListener(ev, start, { passive: true }); });
      import("./hero.js").then(function (m) { m.start(stage); }).catch(function () { /* poster stays */ });
    };
    evs.forEach(function (ev) { window.addEventListener(ev, start, { passive: true }); });
  }
})();
