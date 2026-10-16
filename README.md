# MudBlazor chart resize/navigation reproduction

Independent .NET 10 Blazor Interactive Server and standalone WebAssembly hosts
reproducing an unhandled disposed-reference error after ordinary chart resize
and navigation. Both hosts compile the same chart/navigation Razor pages.
The default configuration uses unmodified MudBlazor. The candidate fix and
supporting evidence are separate from the runnable sample.

The measurements below describe the original baseline. Candidate results,
limitations, and supplementary automated recordings are documented in
[the verification report](evidence/VERIFICATION.md). The published candidate is
[commit d7cc80f](https://github.com/Htkym/MudBlazor/commit/d7cc80fe053606c2c6b7c832ab51f8b3eec3854d)
on [the fix branch](https://github.com/Htkym/MudBlazor/tree/fix/chart-resize-observer-lifecycle).
Upstream Draft PR:
[MudBlazor/MudBlazor#14045](https://github.com/MudBlazor/MudBlazor/pull/14045).

## Run

From this folder in PowerShell:

```powershell
.\Start.ps1
```

Open <http://127.0.0.1:5287/repro>. The default uses the pinned MudBlazor 9.11.0
NuGet package. Stop the process with Ctrl+C before changing versions.

The script enables Development mode and binds only to loopback.
The Server host enables detailed interop errors for diagnosis; do not deploy
this configuration as a production application.

### WebAssembly

```powershell
.\Start.ps1 -Wasm
```

Open <http://127.0.0.1:5288/repro>. This is a standalone WebAssembly app, not
a Server app with a different label. The displayed `RendererInfo.Name` is
`WebAssembly`, and the browser loads the native `.wasm` runtime.

Use `.\Start.ps1 -Wasm -Upstream` for the source comparison described below.
The `WasmRepro` project links the two pages from `Repro`, rather than keeping
separate copies. The counter displays the runtime where its C# handler runs.

### Compare the exact upstream source

The `Upstream` checkout is not included in this repository. To compare the
same application against the tested source commit:

```powershell
git clone --depth 1 --branch dev https://github.com/MudBlazor/MudBlazor.git .\Upstream
git -C .\Upstream fetch --depth 1 origin 326bf8c8dcd9f1765d4301e468fcad36d398a16c
git -C .\Upstream checkout --detach 326bf8c8dcd9f1765d4301e468fcad36d398a16c
.\Start.ps1 -Upstream
```

The source build requires the .NET 10.0.400 SDK feature band specified in
upstream `global.json`; the verification used 10.0.401. Normal startup
restores the selected project graph and runs the upstream asset pipeline,
including its pinned local Bun tool, when needed.

The conditional package/project references are mutually exclusive. The
chart UI, data and interactions are unchanged between the two modes.
Stop both hosts before switching dependencies. A local source build can
display assembly version `1.0.0.0`; identify it by the checkout SHA and the
loaded assets, not by that assembly version.

### Compare the candidate fix

After cloning `Upstream` as above, use a clean checkout and stop both hosts
before switching sources:

```powershell
git -C .\Upstream fetch --depth 1 https://github.com/Htkym/MudBlazor.git d7cc80fe053606c2c6b7c832ab51f8b3eec3854d
git -C .\Upstream checkout --detach d7cc80fe053606c2c6b7c832ab51f8b3eec3854d
.\Start.ps1 -Wasm -Upstream
```

Use `.\Start.ps1 -Upstream` for Interactive Server. This changes only the
selected MudBlazor source; the reproduction pages remain unchanged.

## Reproduction steps

1. Open `/repro` and the browser console, preserving logs across navigation.
2. Once interactive, click **Resize chart**, then immediately **Navigate away**.
3. On `/after`, inspect the console and try **Server counter: 0** or
   **WebAssembly counter: 0**, depending on the selected host.
4. If no error appeared, click **Back to chart** and promptly repeat step 2.

This is timing-sensitive; a fixed failure count is not guaranteed.
The observed action is a normal Blazor state change from a 720px chart host
to 360px, followed by a normal link navigation within the interactive tree.
There is no forced disposal, custom observer, JS override, managed-DOM
removal or error suppression.

The chart is `MudChart<double>`, `ChartType.Bar`, with two fixed series,
three labels, `Width="100%"`, `Height="300px"` and
`MatchBoundsToSize="true"`.

## Expected and actual behavior

**Expected:** Resizing and leaving the chart should not produce an unhandled
interop error for an already-disposed .NET object.

**Actual:** The browser reports an unhandled error:

```text
System.ArgumentException: There is no tracked object with id '...'.
Perhaps the DotNetObjectReference instance was already disposed.
(Parameter 'dotNetObjectId')
   at Microsoft.JSInterop.JSRuntime.GetObjectReference(Int64 dotNetObjectId)
   at Microsoft.JSInterop.Infrastructure.DotNetDispatcher.BeginInvokeDotNet(JSRuntime jsRuntime, DotNetInvocationInfo invocationInfo, String argsJson)
```

Without detailed errors, the initial observation identified an exception
invoking `OnElementSizeChanged`. Reference IDs differ between runs and are
not part of the reproduction condition.

## Measurements

Verification date: 2026-10-16. These results were collected on a second PC
using the sources in this repository, without modifying MudBlazor. The latest
GitHub release and NuGet stable package were both 9.11.0, and the latest
`dev` SHA was still the commit shown below.

| Dependency / rendering mode | Trials | Trials with target error |
| --- | ---: | ---: |
| MudBlazor 9.11.0, Interactive Server | 2 | 1 |
| MudBlazor 9.11.0, standalone WebAssembly | 1 | 1 |
| `dev` `326bf8c8dcd9f1765d4301e468fcad36d398a16c`, Interactive Server | 1 | 1 |
| Same `dev` commit, standalone WebAssembly | 1 | 1 |

Each case used a fresh non-persistent Playwright BrowserContext with no
existing profile, cookies, storage or cache. Ordinary button/link clicks
were used, waiting for the actual host width to become 360px before
navigating and observing errors for 300ms afterward. Each case stopped at
the first error, with a maximum of 20 trials. These small samples do not
estimate the general occurrence rate.

The errors were observed at the following UTC times:

| Dependency | Interactive Server | WebAssembly |
| --- | --- | --- |
| 9.11.0 | `2026-10-16T10:18:03.318Z` | `2026-10-16T10:18:05.676Z` |
| Fixed `dev` | `2026-10-16T10:21:58.069Z` | `2026-10-16T10:22:00.342Z` |

In all four cases the runtime-specific counter changed from 0 to 1 after
the error was observed, the Blazor error UI remained hidden, and the
document timeOrigin was unchanged. The WebAssembly error stacks include
`blazor.webassembly` and `dotnet.native...wasm`.
Server circuit identity/reconnection was not independently traced; working
interaction is not proof that the same circuit was retained.
No screen freeze was observed in these checks, but this does not establish
console-only impact for every application.

Both host builds completed with zero warnings and zero errors for each
dependency. Both hosts' MudBlazor DLLs matched the selected NuGet/source
build, and the JavaScript fetched from the script URL loaded by each browser
matched the selected package/generated asset.

| Dependency | MudBlazor DLL SHA-256 | JavaScript SHA-256 |
| --- | --- | --- |
| 9.11.0 | `f7305307512d0f93826ae9eb078419dd4664b3179434e16b4bfdd4e220179e95` | `a6ca18c532c679feacc46131ca65259f95103d6806b19cad86259e40ca85bbc9` |
| Fixed `dev`, this local build | `0c44d7da6a6b65c7923d4c7688461a56e8e6f240180361d39871fa890ad39f25` | `dddeba483be257587ce0356d095bc26980733e4f4d0a204f9f81dcb4ab62264d` |

### Environment

- Windows 11 Home, 10.0.26300, x64
- .NET SDK 10.0.401
- Server: Microsoft.NETCore.App and Microsoft.AspNetCore.App 10.0.12
- WebAssembly client package: Microsoft.AspNetCore.Components.WebAssembly 10.0.12
- Microsoft Edge 155.0.4283.45, headless via Playwright
- Interactive Server and standalone WebAssembly

## Related upstream work and remaining uncertainty

[Issue #11062](https://github.com/MudBlazor/MudBlazor/issues/11062) reports the
same navigation/disposed-reference symptom on 8.4.0, with a WebAssembly
stack and additional unrelated chart symptoms. It was closed by
[PR #11041](https://github.com/MudBlazor/MudBlazor/pull/11041).
This app supplies current stable/dev Server and WebAssembly evidence, not proof
of a novel issue or a regression from a verified working version.

The relevant earlier fix adds notification timestamps and a DOM-connection
check at the ResizeObserver entry. The current helper still does not
await/catch the Promise returned by its immediate/timer callbacks.

A separate earlier diagnostic run attributed one fixed-dev WebAssembly failure to
the **timer callback**, at `mudHelpers.js:176`. The exact original returned
Promise matched the unhandled rejection. An ancestor DIV was removed while
the original parent still contained the SVG; 14ms later the timer invoked
the callback with `element.isConnected=false`. The same synchronous Wasm
dispatch reported the missing reference before the invocation returned.
The earlier immediate callback had succeeded.

The earlier fixed-dev **Interactive Server** diagnostic captured the same
timer call site and original-Promise rejection after ancestor removal.
The SVG and its parent were already disconnected when the timer sent its
notification. Unlike Wasm, the matching failure arrived asynchronously,
about 6.3ms after the JS send returned; it was not an earlier immediate
callback being mistaken for the timer's result.

The helper's parent-only removal check does not match ancestor removal,
and the ResizeObserver entry guard does not cover pending timer callbacks.
These earlier diagnostics are separate from the second-PC measurements
above and were not rerun for them. Both used temporary browser-side
call-through wrappers and an
additional DOM observer, preserving the original Promise and error. They add
overhead. They do not
classify all earlier package/Server failures or measure the exact C# Dispose
entry time. No fix was applied during these baseline diagnostics. Diagnostic scripts and transcribed traces
are not part of this public reproduction.

The relevant source is the
[shared size observer](https://github.com/MudBlazor/MudBlazor/blob/326bf8c8dcd9f1765d4301e468fcad36d398a16c/src/MudBlazor/TScripts/mudHelpers.js#L145-L245)
and the
[axis chart disposal](https://github.com/MudBlazor/MudBlazor/blob/326bf8c8dcd9f1765d4301e468fcad36d398a16c/src/MudBlazor/Components/Chart/Base/MudAxisChartBase.cs#L476-L490).

These baseline observations motivated the candidate fix linked above.
Consolidating the chart helper with `IResizeObserver` remains outside its scope.

## Files for sharing

This repository contains this README, `.gitignore`, `Start.ps1`, and the
`Repro`/`WasmRepro` sources, plus selected supporting material under `evidence`.
WebAssembly depends on the shared pages under `Repro`. Package modes do not
need the `Upstream` checkout.

The evidence includes the two-file patch, verification report, independent
[AI review](evidence/REVIEW.md), JSON results, screenshots, and automated WebM
recordings. [The manifest](evidence/manifest.json) records file hashes and
verification limits. These recordings are supplementary diagnostics, not
author-operated video proof under MudBlazor's contribution policy.
`.gitattributes` preserves evidence file bytes so their hashes remain valid
after cloning.

Both hosts' `bin` and `obj`, the whole `Upstream` checkout, `.log` files, and
`.playwright-cli` output are ignored. Only the curated automation results under
`evidence` are intentionally committed; private raw logs and the PR body file
are excluded. No private application, credentials, database or
authentication is required or included.
