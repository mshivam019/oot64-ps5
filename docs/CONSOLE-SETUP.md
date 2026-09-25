# Tested console setup

Verified on firmware **9.00** on 2026-09-26 from the console's autoload file,
process list, ShadowMount log, and the locally supplied payloads. These identify
the tested setup, not minimum versions for all consoles.

## Payloads and startup order

The normal jailbreak is run first. Payload Manager's `/data/pldmgr/autoload.txt`:

```text
a53_ppr_install_fast_15.09.elf
!5000
kstuff-1.12-dr-test8.elf
!45000
ShadowMountPlus_1.7alpha13fix1-13-g072c17.elf
```

The `!` entries are delays in milliseconds. The kstuff payload is stored under
Payload Manager's `kstuff-lite` folder. ShadowMount reports
`v1.7alpha13fix1-13-g072c17`, build `2026-09-14T23:01:13Z`.

The user obtained these builds from Drakmor's Discord. The supplied ShadowMount
README links [Drakmor's Discord](https://discord.gg/x2Ppvzwjhm),
[ShadowMountPlus](https://github.com/drakmor/ShadowMountPlus), and
[kstuff-lite](https://github.com/EchoStretch/kstuff-lite). Exact test builds may be
distributed there rather than as GitHub releases; payload binaries are not bundled
with this port.

| Additional tool | Tested version / endpoint |
| --- | --- |
| FTP server | `ftpsrv-ps5_v0.20.elf`, port 2121 |
| ELF loader | elfldr v0.23, port 9021 |
| PS5Upload helper | 5.30.0, port 9113 |
| Windows PS5Upload engine | HTTP `127.0.0.1:19113` |

FTP and the upload tools are started as needed. For the local engine, use
`PS5_ADDR=<console-ip>:9113` and `PS5UPLOAD_ENGINE_PORT=19113`.

## etaHEN and the install path

The tested title path is `/mnt/ext1/etaHEN/games/PPSA99620` on the M.2 SSD.
**The directory name does not mean etaHEN is running.** ShadowMount scans this
location and mounts the title for launch.

etaHEN 2.5B is present in the user's payload collection, and the console retains
etaHEN files and old logs. It is absent from the current autoload and no etaHEN
process was present during inspection. The documented working setup uses the
standalone payloads above; etaHEN is not a demonstrated requirement or a built-in
module of this game.

## kstuff lifecycle and performance

ShadowMount's current effective configuration enables game auto-toggle, with a
15-second direct-title pause delay. There is no SoH-specific override. Recent SoH
launch logs said kstuff was **already disabled** at the pause deadline, so they
do not establish that ShadowMount itself disabled it on those launches.

The existing `kstuff_delay=PPSA99611:5` rule applies to Mario Kart, not SoH.
Keep per-title rules distinct. A running `kstuff.elf` process does not by itself
mean its hooks are currently enabled.

## Display and frame rate

The validated graphics SDK profile is **1080p60**. An earlier 120 Hz profile failed
the console's output-support check on the connected TV/link and produced a blank
screen. Support for 1080p120 on another display has not been established here.

Use 60 FPS interpolation for normal play. The scheduler can discard expired
interpolation frames without proportionally slowing the game; this is not proof
that 120 Hz output, 120 unique frames per second, or every high-FPS scene works.
Higher-refresh work should first validate the display mode with a small test app,
then benchmark a separate build at the 8.33 ms/frame budget.
