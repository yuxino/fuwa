#pragma once

#include <cstdint>

namespace fuwa::core {

// A native window handle is meaningful only together with the process and
// thread that owned it when Fuwa selected it. Process creation time prevents a
// recycled PID from silently restoring an older identity.
struct WindowIdentity final {
    std::uintptr_t handle = 0U;
    std::uint32_t processId = 0U;
    std::uint32_t threadId = 0U;
    std::uint64_t processCreationTime = 0U;

    [[nodiscard]] constexpr bool isValid() const noexcept {
        return handle != 0U && processId != 0U && threadId != 0U
            && processCreationTime != 0U;
    }

    friend constexpr bool operator==(
        const WindowIdentity&,
        const WindowIdentity&
    ) noexcept = default;
};

[[nodiscard]] bool MatchesWindowIdentity(
    const WindowIdentity& expected,
    const WindowIdentity& current
) noexcept;

// These facts are collected by the Win32 adapter, then evaluated here without
// calling Win32 or DWM. WS_EX_APPWINDOW is represented separately because it
// intentionally overrides the usual owned/tool-window exclusion.
struct WindowEligibilityFacts final {
    WindowIdentity identity{};
    std::uint32_t width = 0U;
    std::uint32_t height = 0U;
    bool isTopLevel = false;
    bool isVisible = false;
    bool isMinimized = false;
    bool isCloaked = false;
    bool isToolWindow = false;
    bool hasOwner = false;
    bool isAppWindow = false;
    bool isShellSurface = false;
    bool hasUsefulTitle = false;
};

struct WindowEligibilityPolicy final {
    std::uint32_t ownProcessId = 0U;
    std::uint32_t minimumWidth = 80U;
    std::uint32_t minimumHeight = 50U;
};

enum class WindowEligibility : std::uint8_t {
    eligible,
    invalidIdentity,
    ownProcess,
    notTopLevel,
    notVisible,
    minimized,
    cloaked,
    shellSurface,
    toolWindow,
    ownedAuxiliary,
    missingTitle,
    emptyBounds,
    belowMinimumSize
};

[[nodiscard]] WindowEligibility EvaluateWindowEligibility(
    const WindowEligibilityFacts& facts,
    const WindowEligibilityPolicy& policy = {}
) noexcept;

[[nodiscard]] bool IsOrdinaryWindowEligible(
    const WindowEligibilityFacts& facts,
    const WindowEligibilityPolicy& policy = {}
) noexcept;

struct PixelSize final {
    std::uint32_t width = 0U;
    std::uint32_t height = 0U;
};

// Client-coordinate destination rectangle. Width and height are kept separate
// from x/y so conversion to a Win32 RECT remains explicit at the API boundary.
struct PixelRect final {
    std::uint32_t x = 0U;
    std::uint32_t y = 0U;
    std::uint32_t width = 0U;
    std::uint32_t height = 0U;

    friend constexpr bool operator==(
        const PixelRect&,
        const PixelRect&
    ) noexcept = default;
};

// Fits sourceSize inside destinationSize, centered and without cropping. A
// non-empty input always retains at least one pixel on each axis, including at
// extreme aspect ratios. Any zero input dimension returns an empty rectangle.
[[nodiscard]] PixelRect CalculateAspectFitRect(
    PixelSize sourceSize,
    PixelSize destinationSize
) noexcept;

} // namespace fuwa::core
