## Sync 2026-03-17 14:51 UTC — 44 commits from upstream

- 8d8fadbb Add hidden CLI command for live terminal debugging (#1599)
- e1582582 fix: restore Sparkle automatic update checks (#1597)
- d8a968c6 Address SSH follow-up PR review comments
- de138fa5 Fix remote daemon build script using relative output path after cd (#1595)
- dfcbaa32 Fix SSH remote CLI and loopback proxy follow-ups
- 96bd2463 Add regression tests for SSH remote CLI follow-ups
- 1fc4bcba Add macOS 26 (Tahoe) compat tests, skip zig build via stub (#1590)
- 66174ceb Fix release browser portal compile
- a561a272 Migrate CI/CD to WarpBuild, consolidate test jobs (#1501)
- bbdb626e Fix nightly remote daemon and SSH relay wiring
- 8cd36775 Add remote CLI relay regressions
- b0d994c9 Fix UI test helper closure captures
- 60aab29e Make remote proxy close idempotent
- 832426af Stabilize SSH remote flow after merging main
- 95ef1c8c Keep portal sync responsive during live resize
- 8d1d4722 Defer terminal portal sync past layout churn
- 94f7529a Add regression test for deferred terminal portal sync
- 3fbfd74a Fix socket focus and startup env regressions
- 60137e0f Add regressions for v1 panel focus preservation
- ca4f4b7c Fix browser move and zsh bootstrap regressions
- 902ee030 Fix SSH transport dedupe and loopback review issues
- 5e7458b9 Fix SSH workspace priming and restore state
- 29d046c5 Fix ghostty deferred-init regression harness
- 85e6a5aa Fix ssh stack review regressions
- 1b95c25e Add ssh stack regression tests
- 815ed87e Avoid sourcing profile in ssh bootstrap
- 6dd0f158 Add ssh profile-noise regression
- 2c9464c0 Proxy remote browser favicon fetches
- 50b5969d Add remote favicon proxy regression
- b0bfabdb Optimize remote daemon builds and TCP latency
- 4fffe3be Address ssh stack review follow-ups
- 2e6856ff Fix ssh stack review regressions
- 19b59cae Reapply "Merge pull request #239 from manaflow-ai/issue-151-ssh-remote-port-proxying"

## Sync 2026-03-17 07:01 UTC — 17 commits from upstream

- dc6bcb25 fix: address browser import review feedback
- 150600d0 Fix #1574: remove top update banner in sidebar (#1575)
- 9bf6ad94 Avoid blocking browser PR metadata updates (#1564)
- 92cb4226 feat: add browser profile mapping import flow
- 7f220dc8 Fix sidebar PR badges for restored workspaces (#1570)
- 1480171e Support folder drops on dock icon (#1571)
- 975a8509 Update bonsplit for split transparency
- 08854f14 Update bonsplit for split transparency
- 971b2b4e fix: show sidebar update banner from background checks (#1543)
- e4e53a96 Mention extensions not yet supported in import note
- 3bce4195 Use single-window browser import wizard with close button
- c1ffc178 Make browser import a 2-step choice flow
- e70ebe6d Tone down empty browser import overlay
- 9dd66980 Add browser import flow with installed-browser detection

