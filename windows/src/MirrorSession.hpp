#pragma once

#include "WindowCatalog.hpp"
#include "FuwaCore.hpp"

#include <dwmapi.h>

#include <string>

namespace fuwa::windows {

class MirrorSession final {
public:
    MirrorSession() = default;
    MirrorSession(const MirrorSession&) = delete;
    MirrorSession& operator=(const MirrorSession&) = delete;
    ~MirrorSession();

    [[nodiscard]] bool start(
        const WindowCandidate& source,
        DWORD ownProcessId,
        std::wstring& error
    );

    [[nodiscard]] bool refresh(
        DWORD ownProcessId,
        std::wstring& error
    );

    void stop() noexcept;

    [[nodiscard]] bool active() const noexcept;
    [[nodiscard]] const WindowCandidate& source() const noexcept;

private:
    static constexpr wchar_t mirrorWindowClassName[] =
        L"FuwaWindowsMirrorWindow";

    [[nodiscard]] static bool registerWindowClass(std::wstring& error);
    [[nodiscard]] static LRESULT CALLBACK windowProcedure(
        HWND window,
        UINT message,
        WPARAM wParam,
        LPARAM lParam
    );

    HWND mirrorWindow_ = nullptr;
    HTHUMBNAIL thumbnail_ = nullptr;
    WindowCandidate source_{};
    core::SessionStateMachine state_{};
};

} // namespace fuwa::windows
