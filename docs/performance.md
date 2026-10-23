# Runtime efficiency

The app creates no overlay, render loop, audio player, or sprite textures at
startup. Custom reminders use one deadline for the earliest due reminder and
re-arm on store edits, wake, activation, and clock changes. There is no five-second
poll. With no pending custom reminders and Calendar disabled, there are no
scheduler timers or process activity assertions.

Calendar caches a day of upcoming events plus the largest alert offset. It
refreshes on EventKit changes, settings changes, wake/activation, clock changes,
and a coalescible 15-minute maintenance deadline. Known alerts have their own
exact deadline. In-flight queries are cancelled and generation-checked; dedup
preferences are written only when they change. The 90-second catch-up window
includes meetings that have just started.

Pending precise alerts use `userInitiatedAllowingIdleSystemSleep`, released when
the deadline fires or is cancelled. They never use `latencyCritical` or prevent
the Mac from sleeping. Wake notifications catch up custom reminders and refresh
calendar alerts.

During flight:

- The overlay uses a 360-point-high strip rather than the entire desktop. It
  expands for taller banners and is bounded by the display.
- Animation runs at 30 fps, or 20 fps in Low Power Mode. Movement uses elapsed
  time, so flight speed is unchanged.
- Cursor hit testing shares the render loop; there is no separate polling timer.
- The rope uses 16 segments and avoids redundant shape-path tessellation.
- Audio is decoded only when enabled and needed, and released after its fade.
- Finished overlays are hidden and paused immediately, then evicted after the
  audio fade. A replacement flight prevents eviction.

Sprite textures retain a 64x64 grid instead of the original 1088x1088 export:
16 KiB instead of approximately 4.5 MiB of uncompressed RGBA pixels per layer
(289 times fewer pixels). Image caches have size limits. Original PNGs remain
unchanged. Tests verify the artwork round trip; the original plane/blade exports
have a one-source-pixel mask seam off the native grid at the propeller edge.

Closing Settings releases its SwiftUI view tree and drawing surfaces. Selected
navigation and appearance category are persisted. Its banner preview is cached
and does not construct a GPU texture or shader.

## Local measurements

Short `top` samples on the development Mac, with the same saved appearance,
scale, speed, and audio preferences and two displays attached:

| State | Before | Optimized |
| --- | --- | --- |
| Idle memory | ~279 MiB, previously used app | ~14 MiB fresh; ~34 MiB after a flight |
| Active flight memory | ~351 MiB | ~75 MiB |
| Active flight CPU | Usually 8–10% | Usually 4–6% at 30 fps |
| Idle CPU | ~0% | ~0% |
| App prevents idle system sleep | Yes | No |

These are process snapshots, not battery-runtime measurements. The baseline
process had a longer lifetime; compilation, UI automation, and other work on the
Mac can affect individual samples. Framework caches can remain after a flight.

For a repeatable one-flight workload, quit the app and launch:

```sh
open ./JurassicAir.app --args --preview-flight
```

This starts one placeholder flight after three seconds. Profile using Instruments
or `top -l 38 -s 1 -pid PID -stats pid,command,cpu,mem,threads,idlew,power`.
Inspect sleep assertions with `pmset -g assertions`. Normal launches do not run
the profiling flight.

Apple references: [Minimize Timer Usage](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/Timers.html),
[Prioritize Work at the App Level](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/PrioritizeWorkAtTheAppLevel.html),
and [SKView](https://developer.apple.com/documentation/spritekit/skview).
