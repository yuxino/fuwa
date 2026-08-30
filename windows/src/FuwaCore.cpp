#include "FuwaCore.hpp"

#include <cstdint>

namespace fuwa::core {
namespace {

SessionTransition acceptedTransition(
    SessionState from,
    SessionEvent event,
    SessionState to
) noexcept {
    return SessionTransition{from, event, to, true};
}

SessionTransition rejectedTransition(
    SessionState state,
    SessionEvent event
) noexcept {
    return SessionTransition{state, event, state, false};
}

} // namespace

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

SessionTransition TransitionSession(
    SessionState state,
    SessionEvent event
) noexcept {
    switch (state) {
    case SessionState::idle:
        switch (event) {
        case SessionEvent::startRequested:
            return acceptedTransition(
                state,
                event,
                SessionState::starting
            );
        case SessionEvent::startFailed:
        case SessionEvent::stopRequested:
        case SessionEvent::stopCompleted:
        case SessionEvent::sourceLost:
            return acceptedTransition(state, event, state);
        case SessionEvent::startSucceeded:
            return rejectedTransition(state, event);
        default:
            return rejectedTransition(state, event);
        }

    case SessionState::starting:
        switch (event) {
        case SessionEvent::startRequested:
            return acceptedTransition(state, event, state);
        case SessionEvent::startSucceeded:
            return acceptedTransition(state, event, SessionState::live);
        case SessionEvent::startFailed:
            return acceptedTransition(state, event, SessionState::idle);
        case SessionEvent::stopRequested:
        case SessionEvent::sourceLost:
            return acceptedTransition(
                state,
                event,
                SessionState::stopping
            );
        case SessionEvent::stopCompleted:
            return rejectedTransition(state, event);
        default:
            return rejectedTransition(state, event);
        }

    case SessionState::live:
        switch (event) {
        case SessionEvent::startSucceeded:
            return acceptedTransition(state, event, state);
        case SessionEvent::stopRequested:
        case SessionEvent::sourceLost:
            return acceptedTransition(
                state,
                event,
                SessionState::stopping
            );
        case SessionEvent::startRequested:
        case SessionEvent::startFailed:
        case SessionEvent::stopCompleted:
            return rejectedTransition(state, event);
        default:
            return rejectedTransition(state, event);
        }

    case SessionState::stopping:
        switch (event) {
        case SessionEvent::stopCompleted:
            return acceptedTransition(state, event, SessionState::idle);
        case SessionEvent::startSucceeded:
        case SessionEvent::startFailed:
        case SessionEvent::stopRequested:
        case SessionEvent::sourceLost:
            return acceptedTransition(state, event, state);
        case SessionEvent::startRequested:
            return rejectedTransition(state, event);
        default:
            return rejectedTransition(state, event);
        }
    default:
        return rejectedTransition(state, event);
    }
}

SessionStateMachine::SessionStateMachine(SessionState initialState) noexcept
    : state_(initialState) {}

SessionState SessionStateMachine::state() const noexcept {
    return state_;
}

SessionTransition SessionStateMachine::apply(SessionEvent event) noexcept {
    const SessionTransition transition = TransitionSession(state_, event);
    state_ = transition.to;
    return transition;
}

} // namespace fuwa::core
