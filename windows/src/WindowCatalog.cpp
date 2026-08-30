#include "WindowCatalog.hpp"
#include "FuwaCore.hpp"

#include <dwmapi.h>

#include <algorithm>
#include <array>
#include <cstdint>
#include <cwchar>
#include <filesystem>
#include <utility>

namespace fuwa::windows {
namespace {

constexpr std::size_t maximumTitleLength = 1024;

std::wstring windowClassName(HWND window) {
    std::array<wchar_t, 128> className{};
    const int length = GetClassNameW(
        window,
        className.data(),
        static_cast<int>(className.size())
    );
    if (length <= 0) {
        return {};
    }
    return std::wstring(className.data(), static_cast<std::size_t>(length));
}

bool isExcludedShellClass(const std::wstring& className) {
    constexpr std::array excludedClasses{
        L"Progman",
        L"WorkerW",
        L"Shell_TrayWnd",
        L"Shell_SecondaryTrayWnd",
        L"Windows.UI.Core.CoreWindow",
        L"XamlExplorerHostIslandWindow"
    };
    return std::ranges::any_of(excludedClasses, [&](const wchar_t* excluded) {
        return _wcsicmp(className.c_str(), excluded) == 0;
    });
}

std::uint64_t processCreationTime(DWORD processId) {
    HANDLE process = OpenProcess(
        PROCESS_QUERY_LIMITED_INFORMATION,
        FALSE,
        processId
    );
    if (process == nullptr) {
        return 0U;
    }

    FILETIME creation{};
    FILETIME exit{};
    FILETIME kernel{};
    FILETIME user{};
    const BOOL didRead = GetProcessTimes(
        process,
        &creation,
        &exit,
        &kernel,
        &user
    );
    CloseHandle(process);
    if (didRead == FALSE) {
        return 0U;
    }

    ULARGE_INTEGER value{};
    value.LowPart = creation.dwLowDateTime;
    value.HighPart = creation.dwHighDateTime;
    return value.QuadPart;
}

std::wstring windowTitle(HWND window) {
    const int reportedLength = GetWindowTextLengthW(window);
    if (reportedLength <= 0) {
        return {};
    }

    const auto capacity = static_cast<std::size_t>(
        std::min(reportedLength + 1, static_cast<int>(maximumTitleLength))
    );
    std::wstring title(capacity, L'\0');
    const int actualLength = GetWindowTextW(
        window,
        title.data(),
        static_cast<int>(title.size())
    );
    if (actualLength <= 0) {
        return {};
    }
    title.resize(static_cast<std::size_t>(actualLength));
    return title;
}

std::wstring applicationName(DWORD processId) {
    HANDLE process = OpenProcess(
        PROCESS_QUERY_LIMITED_INFORMATION,
        FALSE,
        processId
    );
    if (process == nullptr) {
        return L"Application";
    }

    std::array<wchar_t, 32768> executablePath{};
    DWORD pathLength = static_cast<DWORD>(executablePath.size());
    const BOOL didRead = QueryFullProcessImageNameW(
        process,
        0,
        executablePath.data(),
        &pathLength
    );
    CloseHandle(process);
    if (didRead == FALSE || pathLength == 0) {
        return L"Application";
    }

    const std::filesystem::path path(
        std::wstring_view(executablePath.data(), pathLength)
    );
    std::wstring name = path.stem().wstring();
    return name.empty() ? L"Application" : std::move(name);
}

bool extendedFrameBounds(HWND window, RECT& result) {
    const HRESULT status = DwmGetWindowAttribute(
        window,
        DWMWA_EXTENDED_FRAME_BOUNDS,
        &result,
        sizeof(result)
    );
    if (SUCCEEDED(status)) {
        return true;
    }
    return GetWindowRect(window, &result) != FALSE;
}

} // namespace

std::optional<WindowCandidate> WindowCatalog::inspect(
    HWND window,
    DWORD ownProcessId
) {
    if (window == nullptr || IsWindow(window) == FALSE) {
        return std::nullopt;
    }
    DWORD processId = 0;
    const DWORD threadId = GetWindowThreadProcessId(window, &processId);

    const LONG_PTR extendedStyle = GetWindowLongPtrW(window, GWL_EXSTYLE);

    BOOL cloaked = FALSE;
    const HRESULT cloakStatus = DwmGetWindowAttribute(
        window,
        DWMWA_CLOAKED,
        &cloaked,
        sizeof(cloaked)
    );
    RECT bounds{};
    if (!extendedFrameBounds(window, bounds)) {
        return std::nullopt;
    }
    const LONG width = bounds.right - bounds.left;
    const LONG height = bounds.bottom - bounds.top;
    std::wstring title = windowTitle(window);
    std::wstring className = windowClassName(window);
    const std::uint64_t creationTime = processCreationTime(processId);

    const core::WindowEligibilityFacts facts{
        .identity = core::WindowIdentity{
            reinterpret_cast<std::uintptr_t>(window),
            static_cast<std::uint32_t>(processId),
            static_cast<std::uint32_t>(threadId),
            creationTime
        },
        .width = width > 0 ? static_cast<std::uint32_t>(width) : 0U,
        .height = height > 0 ? static_cast<std::uint32_t>(height) : 0U,
        .isTopLevel = GetAncestor(window, GA_ROOT) == window,
        .isVisible = IsWindowVisible(window) != FALSE,
        .isMinimized = IsIconic(window) != FALSE,
        .isCloaked = SUCCEEDED(cloakStatus) && cloaked != FALSE,
        .isToolWindow = (extendedStyle & WS_EX_TOOLWINDOW) != 0,
        .hasOwner = GetWindow(window, GW_OWNER) != nullptr,
        .isAppWindow = (extendedStyle & WS_EX_APPWINDOW) != 0,
        .isShellSurface = window == GetShellWindow()
            || isExcludedShellClass(className),
        .hasUsefulTitle = !title.empty()
    };
    if (!core::IsOrdinaryWindowEligible(
            facts,
            core::WindowEligibilityPolicy{
                static_cast<std::uint32_t>(ownProcessId),
                80U,
                50U
            }
        )) {
        return std::nullopt;
    }

    return WindowCandidate{
        .handle = window,
        .processId = processId,
        .threadId = threadId,
        .processCreationTime = creationTime,
        .bounds = bounds,
        .title = std::move(title),
        .applicationName = applicationName(processId),
        .className = std::move(className)
    };
}

std::vector<WindowCandidate> WindowCatalog::snapshot(DWORD ownProcessId) {
    struct EnumerationContext {
        DWORD ownProcessId;
        std::vector<WindowCandidate>* candidates;
    } context{ownProcessId, nullptr};

    std::vector<WindowCandidate> candidates;
    context.candidates = &candidates;
    EnumWindows(
        [](HWND window, LPARAM rawContext) -> BOOL {
            auto* contextPointer = reinterpret_cast<EnumerationContext*>(
                rawContext
            );
            if (auto candidate = WindowCatalog::inspect(
                    window,
                    contextPointer->ownProcessId
                )) {
                contextPointer->candidates->push_back(std::move(*candidate));
            }
            return TRUE;
        },
        reinterpret_cast<LPARAM>(&context)
    );
    return candidates;
}

std::optional<WindowCandidate> WindowCatalog::foreground(DWORD ownProcessId) {
    return inspect(GetForegroundWindow(), ownProcessId);
}

bool WindowCatalog::revalidate(
    const WindowCandidate& candidate,
    DWORD ownProcessId
) {
    const auto current = inspect(candidate.handle, ownProcessId);
    if (!current) {
        return false;
    }
    return sameIdentity(candidate, *current);
}

bool WindowCatalog::sameIdentity(
    const WindowCandidate& expected,
    const WindowCandidate& current
) noexcept {
    return expected.className == current.className
        && core::MatchesWindowIdentity(
            core::WindowIdentity{
                reinterpret_cast<std::uintptr_t>(expected.handle),
                static_cast<std::uint32_t>(expected.processId),
                static_cast<std::uint32_t>(expected.threadId),
                expected.processCreationTime
            },
            core::WindowIdentity{
                reinterpret_cast<std::uintptr_t>(current.handle),
                static_cast<std::uint32_t>(current.processId),
                static_cast<std::uint32_t>(current.threadId),
                current.processCreationTime
            }
        );
}

} // namespace fuwa::windows
