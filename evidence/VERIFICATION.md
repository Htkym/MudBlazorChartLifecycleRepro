# Chart lifecycle PR verification

Checked locally on 2026-10-16. This folder is supporting evidence, not files to
commit to MudBlazor. The proposed upstream change is exactly two files:
`mudHelpers.js` and `mudHelpers.test.ts`.

## Submission status

Draft PR: [MudBlazor/MudBlazor#14045](https://github.com/MudBlazor/MudBlazor/pull/14045).

Target: `MudBlazor/MudBlazor`, base `dev`; fix branch:
`fix/chart-resize-observer-lifecycle`.

Base and rechecked remote `dev`:
`326bf8c8dcd9f1765d4301e468fcad36d398a16c`.

The two-file change is committed and pushed to
[Htkym/MudBlazor](https://github.com/Htkym/MudBlazor/tree/fix/chart-resize-observer-lifecycle)
at [d7cc80f](https://github.com/Htkym/MudBlazor/commit/d7cc80fe053606c2c6b7c832ab51f8b3eec3854d).
The committed source bytes match the verified candidate. The public
reproduction/evidence destination is
[Htkym/MudBlazorChartLifecycleRepro](https://github.com/Htkym/MudBlazorChartLifecycleRepro).
The Draft PR is open against `dev` with the source commit above as its head.
The reproduction repository contains supporting material, not additional
upstream changes. Upstream CI is separate from the local checks recorded
below; consult the PR checks for its current state. No separate Issue was
created.

The technical preparation is complete, but author-recorded visual proof has
not been supplied. The current AutoTriage policy excludes automated recordings
from normal PR video proof and exempts disposal/teardown errors. This bug
concerns a delayed callback after chart disposal, so the exemption may apply;
it is not a reason to present the existing automated clips as qualifying proof.
The Draft PR explains the disposal/teardown scope and retains these
clips as supplementary diagnostics. A manual before/after recording can be
provided if maintainers require it; acceptance of the exemption is not assumed.

## Design decision

The initial local candidate observed each containing root with `subtree: true`.
At 50 charts, 200 batches in an unrelated subtree produced 10,000 callbacks and
210,000 mutation records. Median total time was 23.9ms in Edge and 114ms in
Firefox. See the two `root-subtree-*-performance.json` files.

The final patch instead observes only direct child-list changes along the
ancestor chain, crossing shadow roots through their hosts. A connected
reparenting event refreshes that chain. This catches hidden ancestor removal
without copying every unrelated descendant mutation to every chart observer.
No global registry, service, public API, or dependency was added.

The seventh regression and a native closed-shadow scenario specifically check
that moving a connected hidden chart into another tree does not lose cleanup
coverage. The final full frontend pipeline passed after this change.

`IResizeObserver` consolidation is intentionally deferred. Its explicit
unsubscription, event-based C# contract, trailing debounce, and
`BoundingClientRect` differ from the chart helper's leading/trailing delivery,
timestamp, content dimensions, and automatic cleanup. A service migration is
not a drop-in substitution for this bounded fix.

Maintainer context:

- [Reuse preference, 2025-03-18](https://github.com/MudBlazor/MudBlazor/pull/11041#issuecomment-2732970508).
- [Automatic cleanup/provider direction](https://github.com/MudBlazor/MudBlazor/pull/11041#issuecomment-2734684070).
- #11041 subsequently received approval and merged with the separate helper.
  That history supports requesting focused Draft-PR feedback; it does not imply
  approval of the present patch.
- Targeted searches found no matching ongoing chart-helper migration or fix.
  This is a scoped negative search, not proof that no related work exists.

## Environment and isolation

Windows 11 x64; .NET SDK 10.0.401; runtime/client packages 10.0.12;
repository-pinned Bun 1.4.2 (`744846f84`).

Edge 155.0.4283.45 ran through Playwright. Installed Firefox 158.0 ran through
Selenium with GeckoDriver 0.37.1, not Playwright's separate patched Firefox.
Fresh disposable contexts/profiles were used.

Original hosts were built in an isolated, clean detached worktree at the base
SHA, using the exact prepared public reproduction archive. The real fix branch
was never overwritten to produce a baseline. The temporary copied regression
test was removed after checking the original implementation.

Both browsers fetched and hashed each host's actual loaded MudBlazor script:

| Variant | SHA-256 of `MudBlazor.min.js` |
| --- | --- |
| Original pinned `dev` | `DDDEBA483BE257587CE0356D095BC26980733E4F4D0A204F9F81DCB4AB62264D` |
| Final ancestor-chain fix | `1BB894C5105908E59CE83A9B8778E17DB80DE0D3682909454E83689A097D3AE9` |

The Docs run used the same final JS hash.

## Ordinary app navigation

| Browser | Mode | Original target-error trials / attempted | Final target-error trials / attempted |
| --- | --- | ---: | ---: |
| Edge | Server | 1 / 1 | 0 / 20 |
| Edge | WebAssembly | 1 / 2 | 0 / 20 |
| Firefox | Server | 1 / 2 | 0 / 20 |
| Firefox | WebAssembly | 1 / 1 | 0 / 20 |

Only ordinary app buttons and links were used. The parent width actually
reached 360px before navigation, with a 300ms observation window afterward.
Original runs stopped at the first target error. Each run retained a working
0-to-1 counter, hidden Blazor error UI, and unchanged document timeOrigin.
Small baseline samples do not estimate error frequency or establish a circuit
crash. Firefox error collection covers the observed trial window, not all
browser startup diagnostics.

Sources: `edge-navigation.json`, `firefox-baseline-navigation.json`,
`firefox-candidate-navigation.json`. Edge logs a separate favicon 404 per app
context; this has not been hidden or counted as a chart error.

## Native observers, Docs, and reconnect

`edge-native-observers.json` and `firefox-native-observers.json` each contain six
passing native-browser checks: normal resize, visible/hidden ancestor removal,
nested closed-shadow removal, connected reparenting into a closed shadow tree,
and resize after a controlled rejected callback. These use real browser
observers and a Promise-returning fake .NET reference, not a full app.

`docs-charts.json` contains actual Release Docs Server examples:

| Page | Observed charts by the pre-navigation snapshot | Resize check | Old active observers after navigation |
| --- | ---: | --- | ---: |
| Bar | 3 | `MatchBoundsToSize` enabled; viewport resize; actual SVG/viewBox agreement | 0 |
| Pie | 1 | Original Add button; test-only paper width 260px; SVG 300.8 to 228px | 0 |
| HeatMap | 6 | Viewport resize; native size delivery | 0 |
| Sankey | 3 | Original Chart width slider; example width 1000 to 999px | 0 |

A forwarding native ResizeObserver wrapper recorded delivery and disconnects.
One selected chart per page was hidden/revealed through test-only CSS while
remaining connected. No Blazor-managed DOM nodes were manually removed. The
visible original home link then performed interactive navigation. All 13 old
chart observations disconnected, with no page reload or chart callback error.
Every recorded Docs console error was an HTTP-local-image CSP diagnostic;
the console was not empty.

`server-reconnect.json` records an actual interrupted WebSocket, blocked
reconnect transports, and successful `Blazor.reconnect()` with a second socket.
Offline, the attached SVG rendered at 468px while its viewBox stayed at 720.
After reconnect, the same SVG updated to 360 with unchanged document timeOrigin.
There were no page errors. Deliberately blocked transport diagnostics and the
favicon failure remain recorded; transient connection IDs are redacted.
This run did not log a chart-helper callback warning. Controlled Promise
rejection and actual reconnect are separate checks.

## Performance and limits

Five interleaved original/final rounds for each of 1/10/50 SVG helper fixtures,
with four settling frames, 20 warmup batches, then 200 measured batches.
Each batch adds 20 spans in an unrelated subtree, removes them, and yields to
the mutation microtask checkpoint. The .NET reference returns a resolved
Promise; native observer wrappers count callbacks and active subscriptions.
No builds or competing browser benchmarks ran during these measurements.

Median total milliseconds for 200 measured batches:

| Fixtures | Edge original | Edge final | Firefox original | Firefox final |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 1.7 | 1.7 | 10 | 8 |
| 10 | 1.6 | 1.9 | 7 | 7 |
| 50 | 1.5 | 3.0 | 8 | 12 |

Final mutation callbacks/records for the unrelated subtree were zero, as in
the original. After ancestor removal, final active ResizeObserver and
MutationObserver counts were both zero at every count in every round. The
original retained one of each per chart.

See `edge-performance.json` and `firefox-performance.json` for all rounds,
per-batch p95 values, and exact counts. Coarse timers and instrumentation make
small timing differences noisy; some Firefox p95 values quantize to zero.
Registration, shared-ancestor mutation cost, long-running memory behavior,
real .NET callback cost, and full Blazor app throughput were not benchmarked.
These results are not a zero-overhead claim or a production capacity limit.

The main residual cost is direct child-list changes on an observed shared
ancestor. Adding/removing siblings under a shared dashboard/grid container
causes every affected chart to disconnect and rebuild its ancestor observations,
even if none of those charts moved. The benchmark deliberately mutates below an
unrelated child, so it does not quantify this shared-container churn. This is an
open performance-review point, not a measured performance non-issue.

## Build, test, and formatting checks

- Original helper with the seven regressions: **1 pass, 6 fail**, as expected.
- Final helper: **7 pass, 0 fail**. No arbitrary test sleeps; native happy-dom
  mutation delivery, controlled resize delivery, and fake timers are used.
- Full existing frontend pipeline: ESLint, TypeScript, complete Bun tests, JS
  bundle, and Sass passed.
- Final normal Server/Wasm builds: four projects each, zero errors/warnings.
- Final Release Docs Server build: seven projects, zero errors/warnings.
- Relevant Release chart fixtures: **510 pass, 0 fail, 0 skipped**.
- CI-form changed-file `dotnet format src --no-restore --verify-no-changes
  --include ...`, final scoped whitespace formatting, LF verification, and
  `git diff --check` passed.

The test command was run from the upstream root so `global.json` selects
Microsoft.Testing.Platform. RTK's filtered invocation reported zero tests; the
unchanged command using the skill's documented `-Raw` recovery ran all 510.
The zero-test attempt is not counted as a pass:

```powershell
dotnet test --project src\MudBlazor.UnitTests\MudBlazor.UnitTests.csproj `
  -c Release --no-restore -- `
  --filter "FullyQualifiedName~MudBlazor.UnitTests.Charts|FullyQualifiedName~MudBlazor.UnitTests.Components.ChartTests" `
  --output Normal --no-ansi --hangdump --hangdump-timeout 60s
```

Full upstream CI, unrelated analyzer/docs test suites, and the Docs WasmHost
build were not run in this preparation. No C# or public API changed. Raw local
build/test logs are retained in the working folder but omitted from the
shareable archive because they contain local filesystem paths.

## Media and archive contents

`baseline-chart.png`, `baseline-after.png`, `candidate-chart.png`, and
`candidate-after.png` are actual app screenshots. The two WebAssembly workflow
recordings are 1280x900 WebM: baseline 3.52s; candidate 12.04s. Native browser
decoding checked a frame and metadata from each; see `media-validation.json`.
They show the app, not DevTools, and must be read alongside exported errors.
They were captured by Playwright and are supplementary debugging evidence,
not author-recorded media satisfying the
[current visual-proof policy](https://github.com/MudBlazor/MudBlazor/blob/326bf8c8dcd9f1765d4301e468fcad36d398a16c/.github/AutoTriage.prompt#L117-L125).

### Recommended author recording

One before/after pair in WebAssembly is a focused demonstration; the exported
test results separately cover both hosts and browsers.

1. Start the already-built unmodified and patched hosts separately; do not
   overwrite the fix branch to obtain the original. Use the normal browser
   window with DevTools Console docked and Preserve log enabled.
2. Use an ordinary screen recorder, such as Windows Snipping Tool, to record
   the browser and console. In the unmodified app, manually click Resize chart,
   then Navigate away. Repeat through Back to chart until the disposed-reference
   exception appears. Stop the baseline recording.
3. Clear the console, switch to the patched app, and record the same manual
   sequence for several attempts, including the working counter afterward.
   Do not script the clicks or manufacture an error. Keep unrelated windows,
   account details, and secrets out of the captured region.
4. Drag both video files into the PR body and ensure GitHub plays them inline.
   A ZIP attachment or download-only link does not satisfy the video format
   requirement. Label the host and original/patched versions clearly.

No author-operated recording or human acceptance is claimed here. If relying
on the disposal/teardown exemption instead, explain that scope and leave the
final interpretation to the maintainers.

The public repository's `evidence` directory includes this report, review,
patch, selected JSON, screenshots, videos, and a file-hash manifest. It excludes
the PR body, raw CLI logs, local browser profiles, virtual environments, and
upstream worktrees. The local evidence ZIP also includes the submitted English
PR body; the public evidence directory does not duplicate it. The separate local
`MudBlazorChartLifecycleRepro-public.zip` remains the original baseline-only
source archive.

All task-owned app hosts and browser sessions were stopped after verification.
Already-in-flight callbacks remain outside the protection of connectivity
guards; a connected element is not proof that its .NET reference is valid.

An independent rubber-duck review found no blocking implementation or evidence
issue. Its two nonblocking observations and their disposition are recorded in
`REVIEW.md`; this is an AI review, not human maintainer approval.
