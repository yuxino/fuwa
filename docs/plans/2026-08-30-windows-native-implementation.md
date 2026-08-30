# Windows Native Mirror Implementation Plan

**Goal:** Add a dependency-free native Windows version of Fuwa that selects an ordinary application window and displays a topmost local live mirror without changing macOS behavior.

**Architecture:** Preserve the current Swift/macOS targets and add a sibling C++20 Win32 target. Enumerate ordinary candidates with a composite HWND/process/thread/lifetime/class identity, render the selected source through a DWM live thumbnail into a Fuwa-owned topmost window, and expose selection plus lifecycle controls through a normal taskbar window, a notification-area icon, and `Ctrl+Alt+P`.

**Tech Stack:** C++20, Win32, Desktop Window Manager, CMake/CTest, CPack/Inno Setup, GitHub Actions Windows x64 and ARM64 runners.

---

### Task 1: Add testable Windows core policy

**Files:**
- Create: `windows/src/FuwaCore.hpp`
- Create: `windows/src/FuwaCore.cpp`
- Create: `windows/tests/FuwaCoreTests.cpp`
- Create: `windows/CMakeLists.txt`

**Step 1: Write failing tests**

Cover ordinary-window eligibility, composite native identity matching,
aspect-fit rectangles, zero dimensions, and idempotent pin-session transitions.

**Step 2: Build and verify failure**

Run on Windows: `cmake -S windows -B build/windows -A ARM64 && cmake --build build/windows --config Release`

Expected: test target fails until the policy functions exist.

**Step 3: Implement the minimal policy**

Keep this code independent of DWM side effects so it can be exhaustively tested.

**Step 4: Run tests**

Run: `ctest --test-dir build/windows -C Release --output-on-failure`

Expected: all Windows core tests pass.

### Task 2: Implement the native Windows application

**Files:**
- Create: `windows/src/FuwaWindows.cpp`
- Create: `windows/src/WindowCatalog.hpp`
- Create: `windows/src/WindowCatalog.cpp`
- Create: `windows/src/MirrorSession.hpp`
- Create: `windows/src/MirrorSession.cpp`
- Create: `windows/resources/FuwaWindows.rc`
- Create: `windows/resources/Fuwa.ico`
- Create: `windows/resources/app.manifest`

**Step 1: Implement safe window enumeration**

Use public Win32/DWM APIs, filter non-ordinary and minimized surfaces, and
preserve the composite native identity across selection and pin creation.

**Step 2: Implement the mirror lifecycle**

Create a Fuwa-owned click-through tool window, register/update/unregister one DWM
thumbnail, track geometry, and tear down synchronously on invalid source, lock,
suspend, unpin, or exit.

**Step 3: Implement native controls**

Provide a bilingual native control window, refresh and pin actions, tray menu,
`Ctrl+Alt+P`, clear errors, and standard-user lifecycle behavior.

**Step 4: Compile with strict warnings**

Run: `cmake --build build/windows --config Release --parallel`

Expected: `/W4 /WX /permissive-` build succeeds without third-party runtime
dependencies.

### Task 3: Package and verify both Windows architectures

**Files:**
- Create: `windows/scripts/verify-artifact.ps1`
- Modify: `windows/CMakeLists.txt`
- Modify: `.github/workflows/ci.yml`

**Step 1: Configure a per-user Inno Setup installer**

Install under the signed-in user's local application data, create a Start-menu
entry and a standard uninstaller, request no elevation, and carry version
`0.1.1.2` from the macOS marketing/build versions.

**Step 2: Add x64 and ARM64 CI jobs**

Build, test, package, verify PE architecture/imports/version, and upload workflow
artifacts without creating a tag or Release.

**Step 3: Run hosted builds**

Expected: exact x64 and ARM64 installer artifacts plus checksums are retained by
the CI run; the existing macOS job remains green.

### Task 4: Align product documentation without changing its structure

**Files:**
- Modify: `README.md`
- Modify: `README_EN.md`
- Modify: `PRIVACY.md`
- Modify: `CHANGELOG.md`

**Step 1: Update only user-visible platform facts**

Document the Windows selection/hotkey/tray flow, no-capture-permission DWM model,
unsigned installer status, and Quick Look as macOS-only.

**Step 2: Verify bilingual parity and links**

Run local link checks, version checks, `git diff --check`, and compare the two
README structures.

### Task 5: Prepare the isolated native-acceptance handoff

**Files:**
- Create: `windows/lab/acceptance.ps1`
- Create: `windows/lab/README.md`

**Step 1: Stage the exact ARM64 installer and scripts**

Copy only task-owned artifacts into a Fuwa-specific directory under the assigned
shared run and record SHA-256 plus source commit.

**Step 2: Stop at the VM slot boundary**

Do not start, stop, click, install, or launch in UTM while another project owns
the slot. Report `ready-for-native-slot` with exact paths.

**Step 3: Run native acceptance when the slot is handed over**

Install, launch, select safe Notepad and Explorer windows, prove live changes and
topmost behavior, inspect taskbar/tray, exercise invalid-source handling, quit,
uninstall, and retain safe screenshots plus machine-readable evidence.
