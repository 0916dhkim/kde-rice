import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, lstatSync, readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");

let passed = 0;
function test(name, fn) {
  fn();
  passed += 1;
  console.log(`  ✓ ${name}`);
}

function extractSvgIds(svgText) {
  const ids = new Set();
  for (const m of svgText.matchAll(/\bid="([^"]+)"/g)) {
    ids.add(m[1]);
  }
  return ids;
}

console.log("Running kde-rice verification suite...");

const EXPECTED_PLASMOIDS = [
  "dev.danny.nordic.workspaces",
  "dev.danny.nordic.windowtitle",
  "dev.danny.nordic.clock",
  "dev.danny.nordic.sysstat",
  "dev.danny.nordic.dock",
  "dev.danny.nordic.launcher",
];

test("all 6 Plasma 6 plasmoids have valid metadata.json and QML entrypoint", () => {
  for (const id of EXPECTED_PLASMOIDS) {
    const dir = join(ROOT, "plasmoids", id);
    const metaPath = join(dir, "metadata.json");
    const qmlPath = join(dir, "contents/ui/main.qml");
    assert.ok(existsSync(metaPath), `missing ${metaPath}`);
    assert.ok(existsSync(qmlPath), `missing ${qmlPath}`);

    const meta = JSON.parse(readFileSync(metaPath, "utf8"));
    assert.equal(meta.KPackageStructure, "Plasma/Applet", `${id}: KPackageStructure`);
    assert.equal(meta["X-Plasma-API-Minimum-Version"], "6.0", `${id}: Plasma 6 API min version`);
    assert.equal(meta.KPlugin?.Id, id, `${id}: KPlugin.Id matches directory`);

    const qml = readFileSync(qmlPath, "utf8");
    assert.match(qml, /\bPlasmoidItem\s*\{/, `${id}: uses Plasma 6 PlasmoidItem root`);
    assert.doesNotMatch(qml, /import\s+org\.kde\.plasma\.core\s+\d/, `${id}: unversioned Qt6 imports`);
    assert.doesNotMatch(qml, /font\.pixelSize\s*:\s*\d+\.\d+/, `${id}: font.pixelSize must be integer`);
    assert.doesNotMatch(qml, /QQC2\.ToolTip\b/, `${id}: use PlasmaCore.ToolTipArea instead of in-window QQC2.ToolTip`);
    assert.doesNotMatch(qml, /(PlasmaComponents|QQC2)\.Menu\b/, `${id}: use PlasmaExtras.Menu instead of in-window QQC2/PlasmaComponents.Menu`);
  }
});

test("nordic-glass desktop theme metadata, plasmarc, and colors are valid", () => {
  const themeDir = join(ROOT, "themes/nordic-glass");
  const meta = JSON.parse(readFileSync(join(themeDir, "metadata.json"), "utf8"));
  assert.equal(meta.KPlugin?.Id, "nordic-glass");

  const plasmarc = readFileSync(join(themeDir, "plasmarc"), "utf8");
  assert.match(plasmarc, /FallbackTheme=breeze-dark/);
  assert.match(plasmarc, /\[BlurBehindEffect\][\s\S]*enabled=true/);

  const colors = readFileSync(join(themeDir, "colors"), "utf8");
  assert.match(colors, /\[Colors:Window\]/);
  assert.match(colors, /DecorationFocus=136,192,208/);
});

test("Global Theme (look-and-feel) and Wallpaper KPackages are valid", () => {
  const lnfDir = join(ROOT, "look-and-feel/dev.danny.nordic");
  const lnfMeta = JSON.parse(readFileSync(join(lnfDir, "metadata.json"), "utf8"));
  assert.equal(lnfMeta.KPackageStructure, "Plasma/LookAndFeel");
  assert.equal(lnfMeta.KPlugin?.Id, "dev.danny.nordic");

  const defaults = readFileSync(join(lnfDir, "contents/defaults"), "utf8");
  assert.match(defaults, /widgetStyle=Breeze/);
  assert.match(defaults, /ColorScheme=NordicMinimal/);
  assert.match(defaults, /font=Manrope,/);
  assert.match(defaults, /activeFont=Manrope,/);
  assert.match(defaults, /Theme=nordic-icons/);
  assert.match(defaults, /name=nordic-glass/);
  assert.match(defaults, /Image=NordicMist/);
  assert.match(defaults, /library=org\.kde\.breeze/);
  assert.match(defaults, /theme=Breeze/);

  assert.ok(existsSync(join(lnfDir, "contents/previews/preview.png")));
  assert.ok(existsSync(join(lnfDir, "contents/previews/fullscreenpreview.jpg")));

  const layoutDefaults = readFileSync(join(lnfDir, "contents/layouts/defaults"), "utf8");
  assert.match(layoutDefaults, /BorderlessMaximizedWindows=true/);

  const wallMeta = JSON.parse(readFileSync(join(ROOT, "wallpapers/NordicMist/metadata.json"), "utf8"));
  assert.equal(wallMeta.KPlugin?.Id, "NordicMist");
  assert.ok(existsSync(join(ROOT, "wallpapers/NordicMist/contents/images/3840x2160.png")));
});

test("panel-background and dialog SVGs contain required 9-slice, mask, shadow, and floating IDs", () => {
  const nineParts = [
    "topleft", "top", "topright",
    "left", "center", "right",
    "bottomleft", "bottom", "bottomright",
  ];
  const baseRequired = [
    ...nineParts,
    ...nineParts.map((p) => `mask-${p}`),
    ...nineParts.map((p) => `shadow-${p}`),
    "hint-top-margin", "hint-bottom-margin", "hint-left-margin", "hint-right-margin",
    "shadow-hint-top-margin", "shadow-hint-bottom-margin", "shadow-hint-left-margin", "shadow-hint-right-margin",
    "shadow-hint-top-inset", "shadow-hint-bottom-inset", "shadow-hint-left-inset", "shadow-hint-right-inset",
    "hint-stretch-borders",
  ];
  const floatingRequired = [
    "floating-center",
    "floating-hint-top-margin",
    "floating-hint-bottom-margin",
    "floating-hint-left-margin",
    "floating-hint-right-margin",
  ];

  const panelSvgs = [
    "themes/nordic-glass/widgets/panel-background.svg",
    "themes/nordic-glass/translucent/widgets/panel-background.svg",
  ];
  for (const rel of panelSvgs) {
    const ids = extractSvgIds(readFileSync(join(ROOT, rel), "utf8"));
    for (const req of [...baseRequired, ...floatingRequired]) {
      assert.ok(ids.has(req), `${rel} missing SVG element id="${req}"`);
    }
  }

  const dialogSvgs = [
    "themes/nordic-glass/dialogs/background.svg",
    "themes/nordic-glass/translucent/dialogs/background.svg",
  ];
  for (const rel of dialogSvgs) {
    const ids = extractSvgIds(readFileSync(join(ROOT, rel), "utf8"));
    for (const req of baseRequired) {
      assert.ok(ids.has(req), `${rel} missing SVG element id="${req}"`);
    }
  }
});

test("tasks.svg contains base and south dock task states", () => {
  const ids = extractSvgIds(
    readFileSync(join(ROOT, "themes/nordic-glass/widgets/tasks.svg"), "utf8")
  );
  for (const state of ["normal", "focus", "hover", "attention", "minimized"]) {
    for (const prefix of [state, `south-${state}`]) {
      for (const part of ["topleft", "top", "topright", "left", "center", "right", "bottomleft", "bottom", "bottomright"]) {
        assert.ok(ids.has(`${prefix}-${part}`), `tasks.svg missing ${prefix}-${part}`);
      }
    }
  }
  assert.ok(ids.has("hint-stretch-borders"));
});

test("Global Theme desktop-layout.js builds top floating bar + bottom autohide floating dock", () => {
  const scriptSrc = readFileSync(
    join(ROOT, "look-and-feel/dev.danny.nordic/contents/layouts/org.kde.plasma.desktop-layout.js"),
    "utf8"
  );

  function runLayoutWithInitialPanels(initialPanels) {
    const created = [];
    const removed = [];
    const desktops = [{ wallpaperPlugin: "" }];

    class MockWidget {
      constructor(type, initialCfg = {}) {
        this.type = type;
        this.currentConfigGroup = [];
        this._cfg = { ...initialCfg };
      }
      readConfig(key, fallback) {
        const k = `${this.currentConfigGroup.join("/")}:${key}`;
        return k in this._cfg ? this._cfg[k] : fallback;
      }
      writeConfig(key, val) {
        const k = `${this.currentConfigGroup.join("/")}:${key}`;
        this._cfg[k] = val;
      }
    }

    class MockPanel {
      constructor() {
        this.location = "";
        this.height = 0;
        this.floating = false;
        this.alignment = "";
        this.lengthMode = "";
        this.hiding = "";
        this.opacity = "adaptive";
        this._widgets = [];
        created.push(this);
      }
      addWidget(type) {
        const w = new MockWidget(type);
        this._widgets.push(w);
        return w;
      }
      widgets() {
        return this._widgets;
      }
      remove() {
        removed.push(this);
      }
    }

    const oldPanels = initialPanels.map((p) => ({
      widgets: () => p.widgets.map((w) => new MockWidget(w.type, w.cfg)),
      remove() {
        removed.push(p.name);
      },
    }));

    const sandbox = {
      Panel: MockPanel,
      panels: () => oldPanels,
      currentActivity: () => "act-1",
      desktopsForActivity: () => desktops,
    };
    vm.runInNewContext(scriptSrc, sandbox);
    return { created, removed, desktops };
  }

  const preservedList = "applications:custom-term.desktop,applications:obsidian.desktop";
  const res1 = runLayoutWithInitialPanels([
    {
      name: "old-default",
      widgets: [
        { type: "org.kde.plasma.icontasks", cfg: { "General:launchers": preservedList } },
      ],
    },
  ]);

  assert.deepEqual(res1.removed, ["old-default"]);
  assert.equal(res1.created.length, 2);
  assert.equal(res1.desktops[0].wallpaperPlugin, "org.kde.image");

  const [topBar, dock] = res1.created;
  assert.equal(topBar.location, "top");
  assert.equal(topBar.height, 34);
  assert.equal(topBar.floating, true);
  assert.equal(topBar.lengthMode, "fill");
  assert.equal(topBar.hiding, "none");
  assert.equal(topBar.opacity, "translucent");
  assert.deepEqual(
    topBar._widgets.map((w) => w.type),
    [
      "dev.danny.nordic.launcher",
      "dev.danny.nordic.workspaces",
      "dev.danny.nordic.windowtitle",
      "org.kde.plasma.panelspacer",
      "dev.danny.nordic.clock",
      "org.kde.plasma.panelspacer",
      "dev.danny.nordic.sysstat",
      "org.kde.plasma.systemtray",
    ]
  );
  assert.equal(topBar._widgets[0].globalShortcut, "Alt+F1");
  assert.equal(
    topBar._widgets[0]._cfg["General:icon"],
    "/usr/share/plasma/desktoptheme/nordic-glass/icons/nordic-launcher.svg"
  );
  assert.ok(!topBar._widgets.some((w) => w.type.includes("media")));

  for (const w of topBar._widgets) {
    if (w.type.startsWith("dev.danny.")) {
      assert.ok(EXPECTED_PLASMOIDS.includes(w.type), `unknown custom plasmoid ${w.type}`);
    }
  }

  assert.equal(dock.location, "bottom");
  assert.equal(dock.height, 58);
  assert.equal(dock.floating, true);
  assert.equal(dock.alignment, "center");
  assert.equal(dock.lengthMode, "fit");
  assert.equal(dock.hiding, "autohide");
  assert.equal(dock.opacity, "translucent");
  assert.deepEqual(dock._widgets.map((w) => w.type), ["dev.danny.nordic.dock"]);
  assert.equal(dock._widgets[0]._cfg["General:launchers"], preservedList);

  const res2 = runLayoutWithInitialPanels([]);
  assert.ok(Array.isArray(res2.created[1]._widgets[0]._cfg["General:launchers"]));
});

test("KWin 6 nordic-notitlebar script and /etc/xdg/kwinrc rounded-corner defaults are valid", () => {
  const kwinDir = join(ROOT, "kwin/scripts/nordic-notitlebar");
  const meta = JSON.parse(readFileSync(join(kwinDir, "metadata.json"), "utf8"));
  assert.equal(meta.KPackageStructure, "KWin/Script");
  assert.equal(meta.KPlugin?.Id, "nordic-notitlebar");
  assert.equal(meta.KPlugin?.EnabledByDefault, true);
  assert.equal(meta["X-Plasma-API"], "javascript");

  const src = readFileSync(join(kwinDir, "contents/code/main.js"), "utf8");
  let addedHandler = null;
  const makeWin = (props) => ({
    noBorder: false,
    fullScreen: false,
    fullScreenChanged: { connect: () => {} },
    ...props,
  });
  const normal = makeWin({ normalWindow: true });
  const dialog = makeWin({ dialog: true });
  const dock = makeWin({ dock: true, normalWindow: false });
  const addedNormal = makeWin({ normalWindow: true });

  vm.runInNewContext(src, {
    workspace: {
      windowAdded: { connect: (fn) => { addedHandler = fn; } },
      windowList: () => [normal, dialog, dock],
    },
  });
  assert.equal(normal.noBorder, true);
  assert.equal(dialog.noBorder, true);
  assert.equal(dock.noBorder, false);
  addedHandler(addedNormal);
  assert.equal(addedNormal.noBorder, true);

  const kwinrc = readFileSync(join(ROOT, "kwin/kwinrc"), "utf8");
  assert.match(kwinrc, /^\[Plugins\]/m);
  assert.match(kwinrc, /^kwin4_effect_shapecornersEnabled=true$/m);
  assert.match(kwinrc, /^nordic-notitlebarEnabled=true$/m);
  assert.match(kwinrc, /^\[Round-Corners\]/m);
  assert.match(kwinrc, /^AnimationDuration=200$/m);
  assert.match(kwinrc, /^Size=12$/m);
  assert.match(kwinrc, /^OutlineColor=163,190,140$/m);
  assert.match(kwinrc, /^ActiveOutlineAlpha=235$/m);
  assert.match(kwinrc, /^InactiveOutlineColor=136,192,208$/m);
  assert.match(kwinrc, /^InactiveOutlineAlpha=108$/m);
  assert.match(kwinrc, /^UseNativeDecorationShadows=false$/m);
});

test("nordic-icons overlay theme has valid index.theme, SVGs, and zero broken symlinks", () => {
  const iconRoot = join(ROOT, "icons/nordic-icons");
  const idx = readFileSync(join(iconRoot, "index.theme"), "utf8");
  assert.match(idx, /^Name=Nordic Icons$/m);
  assert.match(idx, /^Inherits=breeze-dark$/m);
  assert.match(idx, /^FollowsColorScheme=true$/m);

  let files = 0;
  let links = 0;
  function walk(dir) {
    for (const entry of readdirSync(dir)) {
      const full = join(dir, entry);
      const lst = lstatSync(full);
      if (lst.isSymbolicLink()) {
        assert.ok(existsSync(full), `broken symlink: ${full}`);
        assert.ok(statSync(full).isFile(), `symlink target not file: ${full}`);
        links += 1;
      } else if (lst.isDirectory()) {
        walk(full);
      } else if (entry.endsWith(".svg")) {
        const text = readFileSync(full, "utf8");
        assert.match(text, /ColorScheme-Text/, `missing KDE ColorScheme-Text class in ${full}`);
        files += 1;
      }
    }
  }
  walk(iconRoot);
  assert.match(idx, /places\/22/);
  assert.match(idx, /categories\/22/);
  for (const required of [
    "apps/22/ktip.svg",
    "apps/22/kup.svg",
    "apps/22/lighttable.svg",
    "apps/22/kwalletmanager.svg",
    "preferences/22/preferences-desktop-theme-global.svg",
    "preferences/22/preferences-desktop-wallpaper.svg",
    "preferences/22/preferences-desktop-user-password.svg",
    "places/22/user-home.svg",
    "places/22/folder-documents.svg",
    "devices/22/drive-harddisk.svg",
  ]) {
    assert.ok(existsSync(join(iconRoot, required)), `missing ${required}`);
  }
  assert.ok(files >= 75, `expected >= 75 canonical SVGs, got ${files}`);
  assert.ok(links >= 250, `expected >= 250 alias symlinks, got ${links}`);
});

test("launcher fuzzy/acronym/frecency matcher ranks and highlights accurately", () => {
  const src = readFileSync(
    join(ROOT, "plasmoids/dev.danny.nordic.launcher/contents/code/fuzzy.js"),
    "utf8"
  ).replace(/^\.pragma library\s*/m, "");
  const sandbox = {};
  vm.runInNewContext(src, sandbox);

  const items = [
    { id: "app:ghostty", name: "Ghostty", icon: "ghostty", keywords: "terminal", kind: "app", appRow: 0, defaultRank: 18 },
    { id: "app:settings", name: "System Settings", icon: "settings", keywords: "config", kind: "app", appRow: 1, defaultRank: 10 },
    { id: "app:obsidian", name: "Obsidian", icon: "obsidian", keywords: "notes", kind: "app", appRow: 2, defaultRank: 16 },
    { id: "app:libreoffice", name: "LibreOffice", icon: "lo", keywords: "office", kind: "app", appRow: 3, defaultRank: 0 },
    { id: "action:lock", name: "Lock Screen", icon: "system-lock-screen", keywords: "lockscreen", kind: "session", actionId: "lock", defaultRank: 5, prefixBoost: 120 },
    { id: "app:xss", name: "A & B <Test>", icon: "test", keywords: "", kind: "app", appRow: 4, defaultRank: 0 },
  ];

  const acronym = sandbox.rankItems(items, "ss", {}, 8);
  assert.equal(acronym[0].id, "app:settings");
  assert.match(acronym[0].displayHtml, /#88c0d0/);

  const lockFirst = sandbox.rankItems(items, "l", { "app:libreoffice": 10 }, 8);
  assert.equal(lockFirst[0].id, "action:lock");

  const sNotLock = sandbox.rankItems(items, "s", {}, 8);
  assert.equal(sNotLock[0].id, "app:settings");

  const fuzzy = sandbox.rankItems(items, "gst", {}, 8);
  assert.equal(fuzzy[0].id, "app:ghostty");

  const emptyFrecency = sandbox.rankItems(items, "", { "app:obsidian": 5 }, 8);
  assert.equal(emptyFrecency[0].id, "app:obsidian");

  const escaped = sandbox.rankItems(items, "test", {}, 8);
  assert.equal(escaped[0].id, "app:xss");
  assert.ok(!escaped[0].displayHtml.includes("<Test>"), "must HTML-escape app names");
  assert.match(escaped[0].displayHtml, /&amp;.*&lt;/);

  assert.equal(
    sandbox.normalizeDesktopId("applications:com.mitchellh.ghostty.desktop"),
    "com.mitchellh.ghostty"
  );
  assert.equal(
    sandbox.normalizeDesktopId("file:///usr/share/applications/google-chrome.desktop?iconData=abc"),
    "google-chrome"
  );
  assert.equal(sandbox.normalizeDesktopId("org.kde.dolphin"), "org.kde.dolphin");
});

test("bundled Manrope static fonts and SIL OFL 1.1 license are present", () => {
  const fontDir = join(ROOT, "fonts/manrope");
  for (const f of [
    "Manrope-Regular.ttf",
    "Manrope-Medium.ttf",
    "Manrope-SemiBold.ttf",
    "Manrope-Bold.ttf",
    "OFL.txt",
  ]) {
    assert.ok(existsSync(join(fontDir, f)), `missing ${f}`);
  }
  const ofl = readFileSync(join(fontDir, "OFL.txt"), "utf8");
  assert.match(ofl, /SIL OPEN FONT LICENSE Version 1\.1/);
});

test("PKGBUILD and .SRCINFO are valid and consistent", () => {
  const pkgbuild = readFileSync(join(ROOT, "PKGBUILD"), "utf8");
  const srcinfo = readFileSync(join(ROOT, ".SRCINFO"), "utf8");
  execFileSync("bash", ["-n", join(ROOT, "PKGBUILD")], { stdio: "pipe" });

  assert.match(pkgbuild, /^pkgname=kde-rice-git$/m);
  assert.match(pkgbuild, /OFL-1\.1/);
  assert.match(pkgbuild, /'kwin-effect-rounded-corners-git'/);
  assert.match(pkgbuild, /git\+https:\/\/github\.com\/0916dhkim\/kde-rice\.git/);
  assert.match(srcinfo, /^pkgbase = kde-rice-git$/m);
  assert.match(srcinfo, /^pkgname = kde-rice-git$/m);
  assert.match(srcinfo, /\tlicense = OFL-1\.1$/m);
  assert.match(srcinfo, /\tdepends = kwin-effect-rounded-corners-git$/m);
  assert.match(srcinfo, /source = kde-rice::git\+https:\/\/github\.com\/0916dhkim\/kde-rice\.git/);
});

console.log(`\nAll ${passed} verification checks passed.`);
