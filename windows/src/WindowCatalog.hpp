#pragma once

#include <windows.h>

#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace fuwa::windows {

struct WindowCandidate {
    HWND handle = nullptr;
    DWORD processId = 0;
    DWORD threadId = 0;
    std::uint64_t processCreationTime = 0U;
    RECT bounds{};
    std::wstring title;
    std::wstring applicationName;
    std::wstring className;
};

class WindowCatalog final {
public:
    [[nodiscard]] static std::vector<WindowCandidate> snapshot(
        DWORD ownProcessId
    );

    [[nodiscard]] static std::optional<WindowCandidate> foreground(
        DWORD ownProcessId
    );

    [[nodiscard]] static bool revalidate(
        const WindowCandidate& candidate,
        DWORD ownProcessId
    );

    [[nodiscard]] static bool sameIdentity(
        const WindowCandidate& expected,
        const WindowCandidate& current
    ) noexcept;

private:
    [[nodiscard]] static std::optional<WindowCandidate> inspect(
        HWND window,
        DWORD ownProcessId
    );
};

} // namespace fuwa::windows
