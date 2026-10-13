/* Pocketwerk hero: a pegboard wall with a glass Dock. Pockets hang on pegs above their Dock icons,
   sway with the pointer and pop open. Loaded lazily by main.js; never under reduced motion. */
import * as THREE from "three";
import { RoundedBoxGeometry } from "three/addons/geometries/RoundedBoxGeometry.js";
import { RoomEnvironment } from "three/addons/environments/RoomEnvironment.js";

const HOLE_PX = 22; // must match --hole-size in site.css
const COL = {
  board: "#1b5546", hole: "#0c3a30", lit: "#24735f", orange: "#ff6b2c", orangeDeep: "#d9531a",
  ink: "#0f1b17", paper: "#f4f6f3", yellow: "#ffd15c", mint: "#9fdcc4", stitch: "#ffd6c2"
};
const GLYPHS = {
  code: "m12 10-6 6 6 6m8-12 6 6-6 6",
  globe: "M25 16a9 9 0 1 1-18 0 9 9 0 0 1 18 0ZM7 16h18M16 7c-3.5 4-3.5 14 0 18m0-18c3.5 4 3.5 14 0 18",
  term: "m8 11 5 5-5 5m8 0h8",
  pen: "m19.5 7.5 5 5L13 24H8v-5Zm-3 3 5 5",
  note: "M13 21V9l11-2v12M13 21a3 3 0 1 1-6 0 3 3 0 0 1 6 0Zm11-2a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z",
  folder: "M6 10.5a2 2 0 0 1 2-2h5l2.5 2.5H24a2 2 0 0 1 2 2V22a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2Z",
  doc: "M10 6h8l5 5v15H10Zm8 0v5h5M13.5 16h6m-6 4h6",
  link: "M14 18a4.5 4.5 0 0 0 6.4.4l3.3-3.3a4.5 4.5 0 0 0-6.4-6.4l-1.2 1.2M18 14a4.5 4.5 0 0 0-6.4-.4l-3.3 3.3a4.5 4.5 0 0 0 6.4 6.4l1.2-1.2",
  cal: "M9.5 8.5h13A2.5 2.5 0 0 1 25 11v11a2.5 2.5 0 0 1-2.5 2.5h-13A2.5 2.5 0 0 1 7 22V11a2.5 2.5 0 0 1 2.5-2.5ZM7 13.5h18M12 6v4m8-4v4",
  photo: "M8.5 8h15A2.5 2.5 0 0 1 26 10.5v11a2.5 2.5 0 0 1-2.5 2.5h-15A2.5 2.5 0 0 1 6 21.5v-11A2.5 2.5 0 0 1 8.5 8ZM6 21l6-6 5 5 3-3 6 6",
  chat: "M7 9.5a2.5 2.5 0 0 1 2.5-2.5h13A2.5 2.5 0 0 1 25 9.5v9a2.5 2.5 0 0 1-2.5 2.5H14l-5 4v-4H9.5A2.5 2.5 0 0 1 7 18.5Z",
  film: "M8.5 8h15A2.5 2.5 0 0 1 26 10.5v11a2.5 2.5 0 0 1-2.5 2.5h-15A2.5 2.5 0 0 1 6 21.5v-11A2.5 2.5 0 0 1 8.5 8ZM11 8v16m10-16v16M6 13h5m10 0h5M6 19h5m10 0h5"
};
const FG = { [COL.ink]: COL.paper, [COL.lit]: COL.paper };

function canvasTex(draw, size = 128) {
  const c = document.createElement("canvas");
  c.width = c.height = size;
  const g = c.getContext("2d");
  draw(g, size);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 4;
  return t;
}
function glyphTex(bg, glyph) {
  return canvasTex((g, s) => {
    g.fillStyle = bg; g.fillRect(0, 0, s, s);
    g.save(); g.translate(s * 0.18, s * 0.18); g.scale(s * 0.64 / 32, s * 0.64 / 32);
    g.strokeStyle = FG[bg] || COL.ink; g.lineWidth = 2.4; g.lineCap = "round"; g.lineJoin = "round";
    g.stroke(new Path2D(GLYPHS[glyph])); g.restore();
  });
}
function miniGridTex(colors) {
  return canvasTex((g, s) => {
    g.fillStyle = COL.lit; g.fillRect(0, 0, s, s);
    const m = s * 0.17, gap = s * 0.07, w = (s - 2 * m - gap) / 2;
    colors.forEach((c, i) => {
      g.fillStyle = c; g.beginPath();
      g.roundRect(m + (i % 2) * (w + gap), m + Math.floor(i / 2) * (w + gap), w, w, w * 0.24); g.fill();
    });
  });
}
function holeTex() {
  return canvasTex((g, s) => {
    g.fillStyle = COL.board; g.fillRect(0, 0, s, s);
    const r = s * 0.137, cx = s / 2, cy = s / 2;
    g.fillStyle = "rgba(255,255,255,0.07)"; g.beginPath(); g.arc(cx, cy + s * 0.03, r * 1.06, 0, Math.PI * 2); g.fill();
    g.fillStyle = COL.hole; g.beginPath(); g.arc(cx, cy, r, 0, Math.PI * 2); g.fill();
    g.fillStyle = "rgba(0,0,0,0.35)"; g.beginPath(); g.arc(cx, cy - s * 0.02, r * 0.86, Math.PI, 0); g.fill();
  }, 64);
}

export function start(stage, opts = {}) {
  const posterMode = !!opts.poster;
  const renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: "high-performance", preserveDrawingBuffer: posterMode });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.toneMapping = THREE.NoToneMapping;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFShadowMap;
  stage.appendChild(renderer.domElement);
  renderer.domElement.setAttribute("aria-hidden", "true");

  const scene = new THREE.Scene();
  const pmrem = new THREE.PMREMGenerator(renderer);
  scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
  scene.environmentIntensity = 0.55;

  const DIST = 22, FOV = 28;
  const camera = new THREE.PerspectiveCamera(FOV, 1, 0.1, 100);
  camera.position.set(0, 0, DIST);

  scene.add(new THREE.HemisphereLight(0xffffff, 0x2a6f5c, 1.0));
  const sun = new THREE.DirectionalLight(0xffffff, 1.55);
  sun.position.set(-6, 9, 12);
  sun.castShadow = true;
  sun.shadow.mapSize.set(1024, 1024);
  sun.shadow.radius = 5;
  sun.shadow.bias = -0.0008;
  scene.add(sun, sun.target);

  // board: exact brand colour (unlit) plus a shadow catcher in front of it
  const holes = holeTex();
  holes.wrapS = holes.wrapT = THREE.RepeatWrapping;
  const board = new THREE.Mesh(new THREE.PlaneGeometry(1, 1), new THREE.MeshBasicMaterial({ map: holes, toneMapped: false }));
  const catcher = new THREE.Mesh(new THREE.PlaneGeometry(1, 1), new THREE.ShadowMaterial({ opacity: 0.32 }));
  catcher.position.z = 0.01;
  catcher.receiveShadow = true;
  scene.add(board, catcher);

  // ---- materials and shared geometry
  const glass = new THREE.MeshPhysicalMaterial({ color: 0xe6f2ec, transmission: 1, thickness: 0.7, roughness: 0.22, ior: 1.42, metalness: 0, clearcoat: 1, clearcoatRoughness: 0.15, transparent: true, opacity: 1 });
  const panelGlass = new THREE.MeshPhysicalMaterial({ color: 0xf4f6f3, transmission: 0.55, thickness: 0.5, roughness: 0.5, ior: 1.3, clearcoat: 1, clearcoatRoughness: 0.25, transparent: true });
  const metal = new THREE.MeshStandardMaterial({ color: 0xdfe6e2, metalness: 0.85, roughness: 0.3 });
  const binCap = new THREE.MeshStandardMaterial({ color: COL.orange, roughness: 0.55, emissive: COL.orange, emissiveIntensity: 0.12 });
  const binSide = new THREE.MeshStandardMaterial({ color: COL.orangeDeep, roughness: 0.7 });
  const stitchMat = new THREE.MeshStandardMaterial({ color: COL.stitch, roughness: 0.8 });
  const sideMat = (c) => new THREE.MeshStandardMaterial({ color: c, roughness: 0.45 });

  const iconGeo = new RoundedBoxGeometry(1, 1, 0.26, 4, 0.2);
  const tileGeo = new RoundedBoxGeometry(0.7, 0.7, 0.12, 3, 0.15);
  const faceMats = (tex, edge) => { const s = sideMat(edge); const f = new THREE.MeshStandardMaterial({ map: tex, roughness: 0.42 }); return [s, s, s, s, f, s]; };

  // ---- the Dock
  const SLOT = 1.26;
  const dockItems = [
    { bg: COL.paper, g: "chat" }, { pocket: 0 }, { bg: COL.ink, g: "term" }, { pocket: 1 },
    { bg: COL.yellow, g: "photo" }, { pocket: 2 }, { bg: COL.mint, g: "film" }
  ];
  const dock = new THREE.Group();
  const shelfW = dockItems.length * SLOT + 0.34;
  const shelf = new THREE.Mesh(new RoundedBoxGeometry(shelfW, 1.32, 1.3, 6, 0.42), glass);
  shelf.position.set(0, 0, 0.62);
  shelf.receiveShadow = true;
  dock.add(shelf);
  scene.add(dock);

  const pocketDefs = [
    { tiles: [[COL.paper, "globe"], [COL.yellow, "pen"], [COL.mint, "code"], [COL.ink, "term"], [COL.paper, "doc"], [COL.orange, "note"]] },
    { tiles: [[COL.mint, "link"], [COL.yellow, "cal"], [COL.paper, "folder"], [COL.ink, "film"], [COL.orange, "photo"], [COL.paper, "chat"]] },
    { tiles: [[COL.yellow, "note"], [COL.paper, "photo"], [COL.mint, "film"], [COL.orange, "pen"], [COL.ink, "code"], [COL.paper, "doc"]] }
  ];
  const icons = [];
  dockItems.forEach((it, i) => {
    let mats;
    if (it.pocket !== undefined) {
      const cols = pocketDefs[it.pocket].tiles.slice(0, 4).map((t) => t[0]);
      mats = faceMats(miniGridTex(cols), COL.lit);
    } else {
      mats = faceMats(glyphTex(it.bg, it.g), it.bg);
    }
    const m = new THREE.Mesh(iconGeo, mats);
    m.position.set((i - (dockItems.length - 1) / 2) * SLOT, 0.04, 1.42);
    m.castShadow = true;
    m.userData.pocket = it.pocket;
    dock.add(m);
    icons.push(m);
  });

  // ---- pockets
  const binShape = new THREE.Shape();
  const TW = 0.86, BW = 0.72, BH = 1.2, R = 0.22;
  binShape.moveTo(-TW, 0); binShape.lineTo(TW, 0); binShape.lineTo(BW, -BH + R);
  binShape.quadraticCurveTo(BW - 0.02, -BH, BW - R, -BH); binShape.lineTo(-BW + R, -BH);
  binShape.quadraticCurveTo(-BW + 0.02, -BH, -BW, -BH + R); binShape.lineTo(-TW, 0);
  const binGeo = new THREE.ExtrudeGeometry(binShape, { depth: 0.56, bevelEnabled: true, bevelThickness: 0.05, bevelSize: 0.05, bevelSegments: 3, curveSegments: 10 });
  binGeo.translate(0, 0, -0.28);
  const pegGeo = new THREE.CylinderGeometry(0.075, 0.075, 0.5, 14);
  pegGeo.rotateX(Math.PI / 2);
  const wireGeo = new THREE.CylinderGeometry(0.028, 0.028, 1, 8);
  const panelGeo = new RoundedBoxGeometry(3.3, 2.4, 0.14, 4, 0.26);
  const stitchGeo = new THREE.BoxGeometry(0.11, 0.035, 0.02);

  const HANG = 0.95; // peg to bin rim
  const pockets = pocketDefs.map((def, pi) => {
    const pivot = new THREE.Group(); // at the peg
    const peg = new THREE.Mesh(pegGeo, metal);
    peg.position.z = 0.25; peg.castShadow = true;
    const swing = new THREE.Group();
    const bin = new THREE.Mesh(binGeo, [binCap, binSide]);
    bin.position.set(0, -HANG, 0.62);
    bin.castShadow = true;
    const rim = new THREE.Mesh(new THREE.BoxGeometry(1.72, 0.08, 0.05), binSide);
    rim.position.set(0, -0.08, 0.34); bin.add(rim);
    for (let k = 0; k < 11; k++) {
      const st = new THREE.Mesh(stitchGeo, stitchMat);
      st.position.set(-0.7 + k * 0.14, -0.27, 0.345); bin.add(st);
    }
    // wires from peg to the rim corners
    [-0.74, 0.74].forEach((x) => {
      const a = new THREE.Vector3(0, 0, 0.42), b = new THREE.Vector3(x, -HANG + 0.02, 0.62);
      const w = new THREE.Mesh(wireGeo, metal);
      w.position.copy(a).add(b).multiplyScalar(0.5);
      w.scale.y = a.distanceTo(b);
      w.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), b.clone().sub(a).normalize());
      w.castShadow = true;
      swing.add(w);
    });
    const panel = new THREE.Mesh(panelGeo, panelGlass);
    panel.position.set(0, 0.45, 1.05);
    panel.scale.setScalar(0.001);
    panel.castShadow = true;
    const tiles = def.tiles.map((t, ti) => {
      const m = new THREE.Mesh(tileGeo, faceMats(glyphTex(t[0], t[1]), t[0]));
      m.castShadow = true;
      // closed: three peek out of the bin, three wait inside
      const peek = ti < 3;
      const cx = (ti % 3 - 1) * 0.5;
      const closed = { x: cx * 0.92, y: peek ? -HANG + 0.1 + (ti === 1 ? 0.12 : 0) : -HANG - 0.7, z: 0.5 + ti * 0.004, r: peek ? (ti - 1) * -0.24 : 0 };
      const open = { x: (ti % 3 - 1) * 1.0, y: 0.45 + (ti < 3 ? 0.5 : -0.5), z: 1.2, r: 0 };
      m.userData = { closed, open };
      m.position.set(closed.x, closed.y, closed.z);
      m.rotation.z = closed.r;
      swing.add(m);
      return m;
    });
    swing.add(bin, panel);
    pivot.add(peg, swing);
    scene.add(pivot);
    return { pivot, swing, bin, panel, tiles, angle: 0, vel: 0, t: 0, target: 0, index: pi };
  });

  // ---- layout: icon size in px decides the scale, pegs snap to the board's holes
  let W = 1, H = 1, viewH = 1, viewW = 1, unit = 1, ox = 0, oy = 0;
  const hero = stage.closest(".hero") || stage;
  function pxToWorld(px, py) { return new THREE.Vector2((px / W - 0.5) * viewW, (0.5 - py / H) * viewH); }
  function layout() {
    W = Math.max(1, stage.clientWidth); H = Math.max(1, stage.clientHeight);
    renderer.setSize(W, H, false);
    camera.aspect = W / H; camera.updateProjectionMatrix();
    viewH = 2 * DIST * Math.tan(THREE.MathUtils.degToRad(FOV / 2));
    viewW = viewH * camera.aspect;
    board.scale.set(viewW, viewH, 1); catcher.scale.set(viewW, viewH, 1);
    const sr = stage.getBoundingClientRect(), hr = hero.getBoundingClientRect();
    ox = sr.left - hr.left; oy = sr.top - hr.top;
    const repX = W / HOLE_PX, repY = H / HOLE_PX;
    holes.repeat.set(repX, repY);
    holes.offset.set((ox / HOLE_PX) % 1, (-(repY + oy / HOLE_PX)) % 1);

    const wide = W >= 860 && W / H > 1.1;
    const iconPx = wide ? Math.min(84, Math.max(56, W * 0.05)) : Math.min(58, W / 11.2);
    unit = iconPx * viewH / H;
    const bottomPx = wide ? 56 + 62 + iconPx * 0.5 : 34 + 28 + iconPx * 0.5;
    const centerPx = wide ? W * 0.655 : W * 0.5;
    const c = pxToWorld(centerPx, H - bottomPx);
    dock.scale.setScalar(unit);
    dock.position.set(c.x, c.y, 0);
    const pegUp = 4.7;
    icons.forEach((m) => {
      if (m.userData.pocket === undefined) return;
      const p = pockets[m.userData.pocket];
      const wx = c.x + m.position.x * unit, wy = c.y + pegUp * unit;
      // snap to the hole grid (hole centres at 11 + 22k px from the hero's top-left)
      const gx = (wx / viewW + 0.5) * W + ox, gy = (0.5 - wy / viewH) * H + oy;
      const sx = Math.round((gx - HOLE_PX / 2) / HOLE_PX) * HOLE_PX + HOLE_PX / 2 - ox;
      const sy = Math.round((gy - HOLE_PX / 2) / HOLE_PX) * HOLE_PX + HOLE_PX / 2 - oy;
      const s = pxToWorld(sx, sy);
      p.pivot.position.set(s.x, s.y, 0);
      p.pivot.scale.setScalar(unit);
    });
    const span = Math.max(viewW, viewH);
    Object.assign(sun.shadow.camera, { left: -span, right: span, top: span, bottom: -span, near: 1, far: 60 });
    sun.shadow.camera.updateProjectionMatrix();
    sun.target.position.set(c.x, c.y, 0);
    sun.position.set(c.x - 6, c.y + 9, 12);
    wake();
  }

  // ---- interaction
  const ray = new THREE.Raycaster();
  const ndc = new THREE.Vector2(9, 9);
  let pinned = -1, hovered = -1, idleTimer = 0, lastX = null, lastT = 0;
  const hitParts = pockets.map((p) => [p.bin, p.panel, ...p.tiles]);
  function pocketAt(nx, ny) {
    ndc.set(nx, ny);
    ray.setFromCamera(ndc, camera);
    const hits = ray.intersectObjects([...icons, ...hitParts.flat()], false);
    for (const h of hits) {
      if (h.object.userData.pocket !== undefined) return h.object.userData.pocket;
      const pi = hitParts.findIndex((parts) => parts.includes(h.object));
      if (pi >= 0) return pi;
    }
    return -1;
  }
  function setOpen(i) { pockets.forEach((p, k) => { p.target = k === i ? 1 : 0; }); wake(); }
  function onMove(e) {
    const r = renderer.domElement.getBoundingClientRect();
    if (e.clientY < r.top || e.clientY > r.bottom) return;
    const nx = ((e.clientX - r.left) / r.width) * 2 - 1, ny = -((e.clientY - r.top) / r.height) * 2 + 1;
    const now = performance.now();
    if (lastX !== null) {
      const dx = (e.clientX - lastX) / Math.max(8, now - lastT);
      const wx = (nx * 0.5) * viewW;
      pockets.forEach((p) => {
        const d = Math.abs(p.pivot.position.x - wx) / (unit * 4);
        const near = Math.max(0, 1 - d);
        p.vel += -dx * 0.012 * near;
      });
    }
    lastX = e.clientX; lastT = now;
    hovered = pocketAt(nx, ny);
    if (hovered >= 0) setOpen(hovered);
    else if (pinned >= 0) setOpen(pinned);
    clearTimeout(idleTimer);
    idleTimer = setTimeout(() => { if (hovered < 0) setOpen(pinned >= 0 ? pinned : 1); }, 1600);
    wake();
  }
  function onClick(e) {
    const r = renderer.domElement.getBoundingClientRect();
    if (e.clientY < r.top || e.clientY > r.bottom || e.clientX < r.left || e.clientX > r.right) return;
    const i = pocketAt(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1);
    if (i < 0) return;
    if (pockets[i].target === 1 && pinned === i) { pinned = -2; setOpen(-1); } // a second click closes it
    else { pinned = i; setOpen(i); }
    pockets[i].vel += 0.04;
  }

  // ---- animation
  const ease = (t) => 1 - Math.pow(1 - t, 3);
  let running = false, sleepAt = 0, visible = true, last = performance.now();
  function step(dt) {
    let busy = false;
    pockets.forEach((p) => {
      // pendulum on the peg
      const acc = -26 * p.angle - 3.2 * p.vel;
      p.vel += acc * dt; p.angle += p.vel * dt;
      p.angle = THREE.MathUtils.clamp(p.angle, -0.5, 0.5);
      if (Math.abs(p.angle) > 0.0005 || Math.abs(p.vel) > 0.0005) busy = true;
      // pop: the product's own rise, about 200 ms
      const goal = p.target, dir = Math.sign(goal - p.t);
      if (dir !== 0) { p.t = THREE.MathUtils.clamp(p.t + dir * dt / 0.24, 0, 1); busy = true; }
      const k = ease(p.t);
      p.swing.rotation.z = p.angle * (1 - 0.65 * k);
      p.panel.scale.setScalar(Math.max(0.001, k));
      p.panel.position.y = 0.45 - (1 - k) * 0.3;
      p.tiles.forEach((m, ti) => {
        const a = m.userData.closed, b = m.userData.open;
        const kk = ease(THREE.MathUtils.clamp(p.t * 1.25 - ti * 0.04, 0, 1));
        m.position.set(a.x + (b.x - a.x) * kk, a.y + (b.y - a.y) * kk, a.z + (b.z - a.z) * kk);
        m.rotation.z = a.r * (1 - kk);
      });
    });
    return busy;
  }
  function frame(now) {
    if (!running) return;
    const dt = Math.min(0.033, (now - last) / 1000); last = now;
    const busy = step(dt);
    renderer.render(scene, camera);
    if (!stage.classList.contains("live")) {
      stage.classList.add("live");
      const poster = stage.querySelector(".hero-poster");
      if (poster) setTimeout(() => { poster.style.visibility = "hidden"; }, 700);
    }
    if (busy) sleepAt = now + 600;
    if (now > sleepAt || !visible) { running = false; return; }
    requestAnimationFrame(frame);
  }
  function wake() {
    if (posterMode || running || !visible) return;
    running = true; last = performance.now(); sleepAt = last + 600;
    requestAnimationFrame(frame);
  }

  layout();

  if (posterMode) {
    pockets.forEach((p, i) => { p.t = i === 1 ? 1 : 0; p.target = p.t; p.angle = [0.07, 0, -0.05][i]; p.vel = 0; });
    step(0);
    renderer.render(scene, camera);
    window.__posterReady = true;
    return;
  }

  new ResizeObserver(() => layout()).observe(stage);
  new IntersectionObserver((en) => { visible = en[0].isIntersecting; if (visible) wake(); }, { threshold: 0.01 }).observe(stage);
  document.addEventListener("visibilitychange", () => { visible = !document.hidden; if (visible) wake(); });
  window.addEventListener("pointermove", onMove, { passive: true });
  window.addEventListener("click", onClick);
  // greet: the middle pocket swings a little and opens
  pockets.forEach((p, i) => { p.vel = [0.35, -0.25, 0.3][i]; });
  setTimeout(() => setOpen(1), 350);
  wake();
}
