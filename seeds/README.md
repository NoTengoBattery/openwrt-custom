# Seeds

`build_me.pl <target> <subtarget>` regenerates `.config` from scratch on every run
by concatenating the files here. `.config` is disposable; **these files are the
source of truth.** To make a package selection persist, add it to the right seed.

Kernel options are separate: `kernel-*.seed` is appended to
`target/linux/<target>/…/config-<ver>`, not to `.config`.

## Two axes: scope and level

Every line has two independent decisions behind it.

**Scope** is which file the symbol lives in. `build_me.pl` concatenates in a fixed
order and kconfig reads the result top to bottom, so for a symbol assigned more
than once **the last write wins**. Scope *is* precedence:

| # | File | Scope |
|---|------|-------|
| 1 | `config-common.seed` | build identity, toolchain, rootfs policy, the three umbrella meta-packages |
| 2 | `config-features.seed` | cross-target capability — `=y` only |
| 3 | `config-available.seed` | cross-target capability — `=m` only |
| 4 | `kernel.seed` | kernel build identity |
| 5 | `target-<family>.seed` | SoC-family identity, optimization, multi-profile, family-wide capability |
| 6 | `target-<family>-<subtarget>.seed` | subtarget capability and device selection |
| 7 | `packages-<slim\|full>.seed` | storage/size tier, chosen with `PKGS=` (default `slim`) |

**Level** is the value, and it answers a different question — *does the image need
this at boot?*

- `=y` — **baked into the image.**
- `=m` — **built and published to the package repository** for post-install. This
  is a promise that the repo will carry it. It is *not* a way to shrink an image:
  never demote something to `=m` for size reasons.
- `=n` — **explicit opt-out**, overriding a broader scope or a target's own
  `DEFAULT_PACKAGES`. Stays inline wherever the exception belongs.

Two buckets sit outside the stack and outrank everything, because
`DEPENDS:=+pkg` becomes a kconfig `select`:

- `DEVICE_PACKAGES` in `target/linux/<t>/image/*.mk` — single-device packages.
- `DEPENDS` in the custom feed at `../feed` — functional requirements of custom code.

## Rules

1. **Declare at the highest scope whose entire population needs it**, and express
   exceptions as an explicit `=n` one scope down. The wireless stack lives in the
   family seeds, not repeated per subtarget.
2. **Pick the level from boot necessity, not size.** The btrfs stack must be `=y`
   because a tool cannot mount a filesystem whose module is not in the image.
3. **If custom code calls it, it belongs in a `../feed` DEPENDS and in no seed.**
   A seed line for something a DEPENDS already forces is a no-op that implies a
   gate which does not exist.
4. **Annotate promotions.** `=m` at a broad scope plus `=y` at a narrow one is a
   legitimate pattern, but the effective value is not visible from either line
   alone, so comment the narrow end.

## Known promotions

| Package | Broad scope | Promoted to | Where |
|---|---|---|---|
| `luci-app-samba4` | `config-available.seed` `=m` | `=y` | `target-x86.seed`, annotated |
| `minidlna` | `config-available.seed` `=m` | `=y` *implicitly* | `target-x86.seed` selects `luci-app-minidlna=y`, whose `+minidlna` dependency becomes a `select`. Deliberately left implicit — there is no seed line for it. |

## Gotchas

- **Device symbols depend on multi-profile mode.** With
  `CONFIG_TARGET_MULTI_PROFILE=y`, devices are selected as
  `CONFIG_TARGET_DEVICE_<target>_<subtarget>_DEVICE_<name>=y`, and per-device
  package strings as `CONFIG_TARGET_DEVICE_PACKAGES_<target>_<subtarget>_DEVICE_<name>`.
  The shorter `CONFIG_TARGET_<target>_<subtarget>_DEVICE_<name>` form is a member
  of the same kconfig *choice* as `TARGET_MULTI_PROFILE`, so writing it in a
  subtarget seed silently switches multi-profile back off — and takes
  `TARGET_PER_DEVICE_ROOTFS` with it.
- **`CONFIG_TARGET_PER_DEVICE_ROOTFS` only exists under multi-profile**, so
  `config-common.seed`'s assignment is inert on x86-64, which builds
  single-profile.
- **`CONFIG_shadow-all=n`** in `config-common.seed` is correct despite the missing
  `PACKAGE_` prefix — `shadow-all` is a real kconfig symbol declared inside
  `Package/shadow-utils/config`. It opts out of the whole PLD suite so only the
  `shadow-*` applets named in `notengobattery-defaults` DEPENDS get built.
- **Adding a device means two edits**: the seed, and the board→hostname table at
  `../feed/system/notengobattery-defaults/files/board_hostname.script`.
