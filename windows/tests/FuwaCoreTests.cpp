#include "FuwaCore.hpp"

#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <string_view>

namespace {

using fuwa::core::PixelRect;
using fuwa::core::PixelSize;
using fuwa::core::WindowEligibility;
using fuwa::core::WindowEligibilityFacts;
using fuwa::core::WindowEligibilityPolicy;
using fuwa::core::WindowIdentity;

int failureCount = 0;

void expect(bool condition, std::string_view message) {
    if (condition) {
        return;
    }

    ++failureCount;
    std::cerr << "FAIL: " << message << '\n';
}

WindowEligibilityFacts ordinaryWindow() {
    WindowEligibilityFacts facts{};
    facts.identity = WindowIdentity{0x1234U, 42U, 77U, 123456U};
    facts.width = 640U;
    facts.height = 480U;
    facts.isTopLevel = true;
    facts.isVisible = true;
    facts.hasUsefulTitle = true;
    return facts;
}

void expectEligibility(
    const WindowEligibilityFacts& facts,
    WindowEligibility expected,
    std::string_view message
) {
    const WindowEligibilityPolicy policy{7U, 80U, 50U};
    expect(
        fuwa::core::EvaluateWindowEligibility(facts, policy) == expected,
        message
    );
}

void runWindowEligibilityTests() {
    const WindowEligibilityFacts eligible = ordinaryWindow();
    expectEligibility(
        eligible,
        WindowEligibility::eligible,
        "an ordinary visible application window is eligible"
    );
    expect(
        fuwa::core::IsOrdinaryWindowEligible(
            eligible,
            WindowEligibilityPolicy{7U, 80U, 50U}
        ),
        "the convenience eligibility predicate agrees with the reason"
    );

    auto facts = eligible;
    facts.identity.handle = 0U;
    expectEligibility(
        facts,
        WindowEligibility::invalidIdentity,
        "a null native handle is rejected"
    );

    facts = eligible;
    facts.identity.processId = 0U;
    expectEligibility(
        facts,
        WindowEligibility::invalidIdentity,
        "a zero process ID is rejected"
    );

    facts = eligible;
    facts.identity.threadId = 0U;
    expectEligibility(
        facts,
        WindowEligibility::invalidIdentity,
        "a zero window-thread ID is rejected"
    );

    facts = eligible;
    facts.identity.processCreationTime = 0U;
    expectEligibility(
        facts,
        WindowEligibility::invalidIdentity,
        "an unavailable process creation time is rejected"
    );

    facts = eligible;
    facts.identity.processId = 7U;
    expectEligibility(
        facts,
        WindowEligibility::ownProcess,
        "Fuwa windows are rejected by process identity"
    );

    facts = eligible;
    facts.isTopLevel = false;
    expectEligibility(
        facts,
        WindowEligibility::notTopLevel,
        "child windows are rejected"
    );

    facts = eligible;
    facts.isVisible = false;
    expectEligibility(
        facts,
        WindowEligibility::notVisible,
        "hidden windows are rejected"
    );

    facts = eligible;
    facts.isMinimized = true;
    expectEligibility(
        facts,
        WindowEligibility::minimized,
        "minimized windows are rejected because DWM may stop live updates"
    );

    facts = eligible;
    facts.isCloaked = true;
    expectEligibility(
        facts,
        WindowEligibility::cloaked,
        "DWM-cloaked windows are rejected"
    );

    facts = eligible;
    facts.isShellSurface = true;
    expectEligibility(
        facts,
        WindowEligibility::shellSurface,
        "shell surfaces are rejected"
    );

    facts = eligible;
    facts.isToolWindow = true;
    expectEligibility(
        facts,
        WindowEligibility::toolWindow,
        "unlisted tool windows are rejected"
    );

    facts = eligible;
    facts.hasOwner = true;
    expectEligibility(
        facts,
        WindowEligibility::ownedAuxiliary,
        "owned auxiliary windows are rejected"
    );

    facts = eligible;
    facts.hasOwner = true;
    facts.isAppWindow = true;
    expectEligibility(
        facts,
        WindowEligibility::eligible,
        "an explicit app window remains eligible even when owned"
    );

    facts = eligible;
    facts.isToolWindow = true;
    facts.isAppWindow = true;
    expectEligibility(
        facts,
        WindowEligibility::eligible,
        "WS_EX_APPWINDOW overrides the auxiliary tool-window classification"
    );

    facts = eligible;
    facts.hasUsefulTitle = false;
    expectEligibility(
        facts,
        WindowEligibility::missingTitle,
        "untitled surfaces are rejected"
    );

    facts = eligible;
    facts.width = 0U;
    expectEligibility(
        facts,
        WindowEligibility::emptyBounds,
        "zero-width windows are rejected"
    );

    facts = eligible;
    facts.height = 0U;
    expectEligibility(
        facts,
        WindowEligibility::emptyBounds,
        "zero-height windows are rejected"
    );

    facts = eligible;
    facts.width = 79U;
    expectEligibility(
        facts,
        WindowEligibility::belowMinimumSize,
        "windows narrower than policy are rejected"
    );

    facts = eligible;
    facts.height = 49U;
    expectEligibility(
        facts,
        WindowEligibility::belowMinimumSize,
        "windows shorter than policy are rejected"
    );

    facts = eligible;
    facts.width = 80U;
    facts.height = 50U;
    expectEligibility(
        facts,
        WindowEligibility::eligible,
        "the minimum useful size is inclusive"
    );
}

void runWindowIdentityTests() {
    const WindowIdentity selected{0x1234U, 42U, 77U, 123456U};
    expect(
        fuwa::core::MatchesWindowIdentity(selected, selected),
        "the exact handle and process ID match"
    );
    expect(
        !fuwa::core::MatchesWindowIdentity(
            selected,
            WindowIdentity{0x5678U, 42U, 77U, 123456U}
        ),
        "a different handle does not match"
    );
    expect(
        !fuwa::core::MatchesWindowIdentity(
            selected,
            WindowIdentity{0x1234U, 99U, 77U, 123456U}
        ),
        "a reused handle with a different process ID does not match"
    );
    expect(
        !fuwa::core::MatchesWindowIdentity(
            selected,
            WindowIdentity{0x1234U, 42U, 88U, 123456U}
        ),
        "a reused handle on a different thread does not match"
    );
    expect(
        !fuwa::core::MatchesWindowIdentity(
            selected,
            WindowIdentity{0x1234U, 42U, 77U, 654321U}
        ),
        "a reused PID from a different process lifetime does not match"
    );
    expect(
        !fuwa::core::MatchesWindowIdentity(
            WindowIdentity{},
            WindowIdentity{}
        ),
        "two invalid identities never match"
    );

    const auto largestHandle = (std::numeric_limits<std::uintptr_t>::max)();
    expect(
        fuwa::core::MatchesWindowIdentity(
            WindowIdentity{largestHandle, 1U, 2U, 3U},
            WindowIdentity{largestHandle, 1U, 2U, 3U}
        ),
        "native handle identity preserves the full uintptr_t width"
    );
}

void runAspectFitTests() {
    expect(
        fuwa::core::CalculateAspectFitRect(
            PixelSize{16U, 9U},
            PixelSize{100U, 100U}
        ) == PixelRect{0U, 22U, 100U, 56U},
        "a wide source is centered vertically"
    );
    expect(
        fuwa::core::CalculateAspectFitRect(
            PixelSize{9U, 16U},
            PixelSize{100U, 100U}
        ) == PixelRect{22U, 0U, 56U, 100U},
        "a tall source is centered horizontally"
    );
    expect(
        fuwa::core::CalculateAspectFitRect(
            PixelSize{4U, 3U},
            PixelSize{1920U, 1080U}
        ) == PixelRect{240U, 0U, 1440U, 1080U},
        "aspect fit letterboxes without exceeding the destination"
    );
    expect(
        fuwa::core::CalculateAspectFitRect(
            PixelSize{1U, 1U},
            PixelSize{64U, 64U}
        ) == PixelRect{0U, 0U, 64U, 64U},
        "equal aspect ratios fill the destination"
    );

    constexpr PixelRect empty{};
    expect(
        fuwa::core::CalculateAspectFitRect(
            PixelSize{0U, 9U},
            PixelSize{100U, 100U}
        ) == empty,
        "a zero source width produces an empty rectangle"
    );
    expect(
        fuwa::core::CalculateAspectFitRect(
            PixelSize{16U, 0U},
            PixelSize{100U, 100U}
        ) == empty,
        "a zero source height produces an empty rectangle"
    );
    expect(
        fuwa::core::CalculateAspectFitRect(
            PixelSize{16U, 9U},
            PixelSize{0U, 100U}
        ) == empty,
        "a zero destination width produces an empty rectangle"
    );
    expect(
        fuwa::core::CalculateAspectFitRect(
            PixelSize{16U, 9U},
            PixelSize{100U, 0U}
        ) == empty,
        "a zero destination height produces an empty rectangle"
    );

    const auto maximum = (std::numeric_limits<std::uint32_t>::max)();
    expect(
        fuwa::core::CalculateAspectFitRect(
            PixelSize{maximum, 1U},
            PixelSize{100U, 100U}
        ) == PixelRect{0U, 49U, 100U, 1U},
        "an extreme wide ratio retains one visible pixel of height"
    );
    expect(
        fuwa::core::CalculateAspectFitRect(
            PixelSize{1U, maximum},
            PixelSize{100U, 100U}
        ) == PixelRect{49U, 0U, 1U, 100U},
        "an extreme tall ratio retains one visible pixel of width"
    );
    expect(
        fuwa::core::CalculateAspectFitRect(
            PixelSize{maximum, maximum},
            PixelSize{maximum, maximum}
        ) == PixelRect{0U, 0U, maximum, maximum},
        "maximum 32-bit dimensions do not overflow ratio comparison"
    );
}

} // namespace

int main() {
    runWindowEligibilityTests();
    runWindowIdentityTests();
    runAspectFitTests();

    if (failureCount != 0) {
        std::cerr << failureCount << " FuwaCore test(s) failed\n";
        return EXIT_FAILURE;
    }

    std::cout << "All FuwaCore tests passed\n";
    return EXIT_SUCCESS;
}
