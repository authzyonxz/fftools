# NOTICE — copyright and third-party provenance

FFPatch is distributed under **GNU GPL v3.0** (see [LICENSE](LICENSE)).
This file satisfies the GPL attribution requirements for the code that was
derived from other projects. It is not promotion.

## Direct base

- **3106** — author QuinnTang74, GPL-3.0.
  <https://github.com/QuinnTang74/3106>
  The following were copied or ported from this repository into
  `Sources/Vendor/` and `Sources/`:
  - `exploit/bad_query.c`, `exploit/bad_query.h`
  - `exploit/worse_query.m`, `exploit/worse_query.h`
  - `exploit/mcm_bridge.m`, `exploit/mcm_bridge.h`
  - `exploit/kexploit_opa334.m/.h`, `krw.m/.h`, `kutils.m/.h`,
    `offsets.m/.h`, `machine_info.h`, `vnode.m/.h`, `xpaci.h`,
    `sandbox_escape.m/.h`
  - `helpers/SupportPolicy.swift` → ported to `Sources/FFSandbox.m`
    (version/build routing for kernel, bad_query, worse_query)
  - `helpers/SandboxAccess.swift`, `helpers/KernelExploit.swift` → ported to
    `Sources/FFSandbox.m`
  - `helpers/PatchTransaction.swift` → ported to `Sources/FFPatchEngine.m`
    (apply/restore journal, backup digests, atomic write, rollback), changed
    from `.3105` patch packages to raw container-mirrored payloads

- **3105** — author YangJiii, GPL-3.0.
  <https://github.com/YangJiiii/3105>
  3106 is based on the 3105 2.0 tree, so the container-access lineage above
  also carries 3105 copyright. The patch-package and recovery flow that
  `PatchTransaction.swift` grew from originates here.

## Upstream research this code depends on

- **worse_query** — Taj C (forcequitOS), GPL-3.0-or-later.
  <https://github.com/forcequitOS/worse_query>
- **WQ Files** — Christoph Kolbicz, GPL-3.0-or-later.
  <https://github.com/kolbicz/WQFiles>
  Product-level safety helpers in `worse_query.m` (Caches swap recovery,
  grant cache, path↔identifier map) are adapted from it.
- **Dopamine / kexploit lineage** — opa334 and contributors.
  <https://github.com/opa334/Dopamine>
  The iOS 17/18 kernel chain (`kexploit_opa334.m`, `sandbox_escape.m`,
  `offsets.m`, `krw.m`, `kutils.m`) descends from this work.
- **FilzaSlop** — 0xjohnnydev and contributors.
  <https://github.com/0xjohnnydev/FilzaSlop>
  MobileHouseArrest / MCM container identity research behind `mcm_bridge.m`.
- **CrazyMind90** — FilzaSlop sandbox-escape research basis.
- **Pocket Poster / Nugget** — LeminLimez and contributors, GPL-3.0.
  PosterBoard paths and the MHA-C2 container workflow lineage.

## Build-time authentication library

- **Logos API Authentication v6.2.0** — author Bao Nguyen (`baontq23`), supplied
  as `Sources/Vendor/LogosAPI/APIClient.h` and `Sources/Vendor/LogosAPI/libAPIClient.a`.
  The files are copied byte-for-byte from the full upstream `API/` directory at
  [`v6.2.0`](https://github.com/baontq23/Logos-API-Authentication/releases/tag/v6.2.0)
  and the archive is linked statically into `ffpatch.dylib`; the `.a` is not
  included as a separate file in the IPA. The upstream `API (Lite Secure)`
  variant is not used. The inspected upstream repository has no `LICENSE` file
  and its README does not state a license. **Redistribution permission and
  applicable terms therefore remain unresolved and should be confirmed with
  the rights holder.**

## Artwork

- Free Fire Normal logo: supplied by the project owner at
  <https://drive.google.com/file/d/1bQAPinz5iYpR7armWRE6O7-PcxG4UykC/view?usp=drivesdk>.
- Free Fire MAX logo: supplied by the project owner at
  <https://drive.google.com/file/d/15XLELuCjCOW66YqGompjmzjkPrD0HToO/view?usp=drivesdk>.
- FFPatch app logo: supplied by the project owner at
  <https://drive.google.com/file/d/1Gf7gV623_HoX3ERDXhWz77NvC9J5ntJ6/view?usp=drivesdk>.
  The game logos are used only to identify the supported games inside the app;
  the supplied artwork and Garena trademarks are **not** covered by the GPL.

## What FFPatch adds

- Objective-C/C reimplementation of the app: no Swift, no SwiftUI.
- Dylib-first app shell (`launcher/main.c` + `FFAppMain`) so the app binary is
  the dylib with a 60-line `MH_EXECUTE` stub.
- Raw-container payload model (`Payloads/<function>/<game>/<container path>`)
  replacing the `.3105` package format, with manifest-driven function IDs.
- New UIKit UI (FUNÇÕES / PERFIL) built to the supplied design reference,
  with native system alerts that omit internal function IDs from the screen.
- Restore-all, per-game receipts, container fingerprint checks, diagnostic
  export, and the license/profile surface.

If you modify and redistribute this project you must keep `LICENSE` and this
`NOTICE.md`, and state what you changed — that is the GPL-3.0 requirement and
the requirement of this project.
