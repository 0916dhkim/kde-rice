import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
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
];

test("all 4 Plasma 6 plasmoids have valid metadata.json and QML entrypoint", () => {
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
  assert.match(defaults, /widgetStyle=Klassy/);
  assert.match(defaults, /ColorScheme=NordicMinimal/);
  assert.match(defaults, /name=nordic-glass/);
  assert.match(defaults, /Image=NordicMist/);
  assert.match(defaults, /library=org\.kde\.klassy/);
  assert.match(defaults, /theme=Klassy/);

  assert.ok(existsSync(join(lnfDir, "contents/previews/preview.png")));
  assert.ok(existsSync(join(lnfDir, "contents/previews/fullscreenpreview.jpg")));

  const layoutDefaults = readFileSync(join(lnfDir, "contents/layouts/defaults"), "utf8");
  assert.match(layoutDefaults, /ButtonsOnRight=IAX/);
  assert.match(layoutDefaults, /BorderlessMaximizedWindows=false/);

  const wallMeta = JSON.parse(readFileSync(join(ROOT, "wallpapers/NordicMist/metadata.json"), "utf8"));
  assert.equal(wallMeta.KPlugin?.Id, "NordicMist");
  assert.ok(existsSync(join(ROOT, "wallpapers/NordicMist/contents/images/3000x2000.png")));
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
      "org.kde.plasma.kickoff",
      "dev.danny.nordic.workspaces",
      "dev.danny.nordic.windowtitle",
      "org.kde.plasma.panelspacer",
      "dev.danny.nordic.clock",
      "org.kde.plasma.panelspacer",
      "dev.danny.nordic.sysstat",
      "org.kde.plasma.systemtray",
    ]
  );
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
  assert.equal(dock.height, 54);
  assert.equal(dock.floating, true);
  assert.equal(dock.alignment, "center");
  assert.equal(dock.lengthMode, "fit");
  assert.equal(dock.hiding, "autohide");
  assert.equal(dock.opacity, "translucent");
  assert.deepEqual(dock._widgets.map((w) => w.type), ["org.kde.plasma.icontasks"]);
  assert.equal(dock._widgets[0]._cfg["General:fill"], false);
  assert.equal(dock._widgets[0]._cfg["General:launchers"], preservedList);

  const res2 = runLayoutWithInitialPanels([]);
  assert.ok(Array.isArray(res2.created[1]._widgets[0]._cfg["General:launchers"]));
});

test("Klassy system-wide XDG klassyrc defaults are valid", () => {
  const rc = readFileSync(join(ROOT, "klassy/klassyrc"), "utf8");
  for (const group of [
    "[Windeco]",
    "[ButtonSizing]",
    "[ButtonColors]",
    "[ButtonBehaviour]",
    "[TitleBarSpacing]",
    "[TitleBarOpacity]",
    "[WindowOutlineStyle]",
    "[ShadowStyle]",
  ]) {
    assert.ok(rc.includes(group), `klassy/klassyrc missing ${group}`);
  }
  assert.match(rc, /^WindowCornerRadius=10$/m);
  assert.match(rc, /^WindowOutlineStyleActive=WindowOutlineAccentColor$/m);
  assert.match(rc, /^WindowOutlineThickness=1$/m);
  assert.match(rc, /^BlurTransparentTitleBars=true$/m);
});

test("PKGBUILD and .SRCINFO are valid and consistent", () => {
  const pkgbuild = readFileSync(join(ROOT, "PKGBUILD"), "utf8");
  const srcinfo = readFileSync(join(ROOT, ".SRCINFO"), "utf8");
  execFileSync("bash", ["-n", join(ROOT, "PKGBUILD")], { stdio: "pipe" });

  assert.match(pkgbuild, /^pkgname=kde-rice-git$/m);
  assert.match(pkgbuild, /'klassy'/);
  assert.match(pkgbuild, /git\+https:\/\/github\.com\/0916dhkim\/kde-rice\.git/);
  assert.match(srcinfo, /^pkgbase = kde-rice-git$/m);
  assert.match(srcinfo, /^pkgname = kde-rice-git$/m);
  assert.match(srcinfo, /\tdepends = klassy$/m);
  assert.match(srcinfo, /source = kde-rice::git\+https:\/\/github\.com\/0916dhkim\/kde-rice\.git/);
});

console.log(`\nAll ${passed} verification checks passed.`);
