#include "FuwaCore.hpp"

#include <cstdint>

namespace fuwa::core {
bool MatchesWindowIdentity(
    const WindowIdentity& expected,
    const WindowIdentity& current
) noexcept {
    return expected.isValid() && current.isValid() && expected == current;
}

WindowEligibility EvaluateWindowEligibility(
    const WindowEligibilityFacts& facts,
    const WindowEligibilityPolicy& policy
) noexcept {
    if (!facts.identity.isValid()) {
        return WindowEligibility::invalidIdentity;
    }
    if (policy.ownProcessId != 0U
        && facts.identity.processId == policy.ownProcessId) {
        return WindowEligibility::ownProcess;
    }
    if (!facts.isTopLevel) {
        return WindowEligibility::notTopLevel;
    }
    if (!facts.isVisible) {
        return WindowEligibility::notVisible;
    }
    if (facts.isMinimized) {
        return WindowEligibility::minimized;
    }
    if (facts.isCloaked) {
        return WindowEligibility::cloaked;
    }
    if (facts.isShellSurface) {
        return WindowEligibility::shellSurface;
    }
    if (facts.isToolWindow && !facts.isAppWindow) {
        return WindowEligibility::toolWindow;
    }
    if (facts.hasOwner && !facts.isAppWindow) {
        return WindowEligibility::ownedAuxiliary;
    }
    if (!facts.hasUsefulTitle) {
        return WindowEligibility::missingTitle;
    }
    if (facts.width == 0U || facts.height == 0U) {
        return WindowEligibility::emptyBounds;
    }
    if (facts.width < policy.minimumWidth
        || facts.height < policy.minimumHeight) {
        return WindowEligibility::belowMinimumSize;
    }
    return WindowEligibility::eligible;
}

bool IsOrdinaryWindowEligible(
    const WindowEligibilityFacts& facts,
    const WindowEligibilityPolicy& policy
) noexcept {
    return EvaluateWindowEligibility(facts, policy)
        == WindowEligibility::eligible;
}

PixelRect CalculateAspectFitRect(
    PixelSize sourceSize,
    PixelSize destinationSize
) noexcept {
    if (sourceSize.width == 0U || sourceSize.height == 0U
        || destinationSize.width == 0U || destinationSize.height == 0U) {
        return {};
    }

    const std::uint64_t sourceWidthAtDestinationHeight =
        static_cast<std::uint64_t>(sourceSize.width)
        * destinationSize.height;
    const std::uint64_t destinationWidthAtSourceHeight =
        static_cast<std::uint64_t>(destinationSize.width)
        * sourceSize.height;

    std::uint32_t fittedWidth = 0U;
    std::uint32_t fittedHeight = 0U;

    if (sourceWidthAtDestinationHeight
        >= destinationWidthAtSourceHeight) {
        fittedWidth = destinationSize.width;
        const std::uint64_t scaledHeight =
            static_cast<std::uint64_t>(sourceSize.height)
            * destinationSize.width
            / sourceSize.width;
        fittedHeight = scaledHeight == 0U
            ? 1U
            : static_cast<std::uint32_t>(scaledHeight);
    } else {
        fittedHeight = destinationSize.height;
        const std::uint64_t scaledWidth =
            static_cast<std::uint64_t>(sourceSize.width)
            * destinationSize.height
            / sourceSize.height;
        fittedWidth = scaledWidth == 0U
            ? 1U
            : static_cast<std::uint32_t>(scaledWidth);
    }

    return PixelRect{
        (destinationSize.width - fittedWidth) / 2U,
        (destinationSize.height - fittedHeight) / 2U,
        fittedWidth,
        fittedHeight
    };
}

} // namespace fuwa::core
