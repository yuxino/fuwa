#include "MirrorSession.hpp"

#include <windowsx.h>

#include <format>

namespace fuwa::windows {
namespace {

std::wstring hresultMessage(const wchar_t* operation, HRESULT status) {
    return std::format(
        L"{} failed (0x{:08X}).",
        operation,
        static_cast<unsigned long>(status)
    );
}

RECT sourceFrame(HWND source) {
    RECT bounds{};
    if (FAILED(DwmGetWindowAttribute(
            source,
            DWMWA_EXTENDED_FRAME_BOUNDS,
            &bounds,
            sizeof(bounds)
        ))) {
        GetWindowRect(source, &bounds);
    }
    return bounds;
}

} // namespace

MirrorSession::~MirrorSession() {
    stop();
}

bool MirrorSession::registerWindowClass(std::wstring& error) {
    const HINSTANCE instance = GetModuleHandleW(nullptr);
    WNDCLASSEXW windowClass{
        .cbSize = sizeof(WNDCLASSEXW),
        .style = CS_HREDRAW | CS_VREDRAW,
        .lpfnWndProc = MirrorSession::windowProcedure,
        .hInstance = instance,
        .hCursor = LoadCursorW(nullptr, IDC_ARROW),
        .hbrBackground = static_cast<HBRUSH>(GetStockObject(BLACK_BRUSH)),
        .lpszClassName = mirrorWindowClassName
    };

    if (RegisterClassExW(&windowClass) != 0) {
        return true;
    }
    if (GetLastError() == ERROR_CLASS_ALREADY_EXISTS) {
        return true;
    }

    error = std::format(
        L"Could not register the mirror window ({:d}).",
        GetLastError()
    );
    return false;
}

bool MirrorSession::start(
    const WindowCandidate& source,
    DWORD ownProcessId,
    std::wstring& error
) {
    stop();
    if (!WindowCatalog::revalidate(source, ownProcessId)) {
        error = L"The selected window is no longer available.";
        return false;
    }
    if (!registerWindowClass(error)) {
        return false;
    }

    const RECT bounds = sourceFrame(source.handle);
    const LONG width = bounds.right - bounds.left;
    const LONG height = bounds.bottom - bounds.top;
    if (width <= 0 || height <= 0) {
        error = L"The selected window has no visible area.";
        return false;
    }

    mirrorWindow_ = CreateWindowExW(
        WS_EX_TOOLWINDOW
            | WS_EX_NOACTIVATE
            | WS_EX_TRANSPARENT
            | WS_EX_LAYERED
            | WS_EX_TOPMOST,
        mirrorWindowClassName,
        L"Fuwa mirror",
        WS_POPUP,
        bounds.left,
        bounds.top,
        width,
        height,
        nullptr,
        nullptr,
        GetModuleHandleW(nullptr),
        nullptr
    );
    if (mirrorWindow_ == nullptr) {
        error = std::format(
            L"Could not create the mirror window ({:d}).",
            GetLastError()
        );
        return false;
    }

    if (SetLayeredWindowAttributes(mirrorWindow_, 0, 255, LWA_ALPHA) == FALSE) {
        error = std::format(
            L"Could not configure the mirror window ({:d}).",
            GetLastError()
        );
        stop();
        return false;
    }

    // This only affects Fuwa's own window. Failure is not fatal because display
    // affinity is a privacy hardening layer, not a prerequisite for DWM output.
    SetWindowDisplayAffinity(mirrorWindow_, WDA_EXCLUDEFROMCAPTURE);

    const HRESULT registrationStatus = DwmRegisterThumbnail(
        mirrorWindow_,
        source.handle,
        &thumbnail_
    );
    if (FAILED(registrationStatus)) {
        error = hresultMessage(L"DWM mirror registration", registrationStatus);
        stop();
        return false;
    }

    source_ = source;
    if (!refresh(ownProcessId, error)) {
        stop();
        return false;
    }
    return true;
}

bool MirrorSession::refresh(DWORD ownProcessId, std::wstring& error) {
    if (!active()) {
        error = L"No mirror is active.";
        return false;
    }
    if (!WindowCatalog::revalidate(source_, ownProcessId)) {
        error = L"The source window closed or changed identity.";
        stop();
        return false;
    }

    const RECT bounds = sourceFrame(source_.handle);
    const LONG width = bounds.right - bounds.left;
    const LONG height = bounds.bottom - bounds.top;
    if (width <= 0 || height <= 0) {
        error = L"The source window no longer has a visible area.";
        stop();
        return false;
    }

    if (SetWindowPos(
            mirrorWindow_,
            nullptr,
            bounds.left,
            bounds.top,
            width,
            height,
            SWP_NOACTIVATE | SWP_NOZORDER | SWP_SHOWWINDOW
        ) == FALSE) {
        error = std::format(
            L"Could not position the mirror window ({:d}).",
            GetLastError()
        );
        stop();
        return false;
    }

    SIZE sourceSize{};
    const HRESULT sizeStatus = DwmQueryThumbnailSourceSize(
        thumbnail_,
        &sourceSize
    );
    if (FAILED(sizeStatus)) {
        error = hresultMessage(L"DWM source-size query", sizeStatus);
        stop();
        return false;
    }

    RECT clientBounds{};
    GetClientRect(mirrorWindow_, &clientBounds);
    const SIZE destinationSize{
        clientBounds.right - clientBounds.left,
        clientBounds.bottom - clientBounds.top
    };
    const core::PixelRect fitted = core::CalculateAspectFitRect(
        core::PixelSize{
            sourceSize.cx > 0 ? static_cast<std::uint32_t>(sourceSize.cx) : 0U,
            sourceSize.cy > 0 ? static_cast<std::uint32_t>(sourceSize.cy) : 0U
        },
        core::PixelSize{
            destinationSize.cx > 0
                ? static_cast<std::uint32_t>(destinationSize.cx)
                : 0U,
            destinationSize.cy > 0
                ? static_cast<std::uint32_t>(destinationSize.cy)
                : 0U
        }
    );
    DWM_THUMBNAIL_PROPERTIES properties{
        .dwFlags = DWM_TNP_RECTDESTINATION
            | DWM_TNP_VISIBLE
            | DWM_TNP_OPACITY
            | DWM_TNP_SOURCECLIENTAREAONLY,
        .rcDestination = RECT{
            static_cast<LONG>(fitted.x),
            static_cast<LONG>(fitted.y),
            static_cast<LONG>(fitted.x + fitted.width),
            static_cast<LONG>(fitted.y + fitted.height)
        },
        .opacity = 255,
        .fVisible = TRUE,
        .fSourceClientAreaOnly = FALSE
    };
    const HRESULT updateStatus = DwmUpdateThumbnailProperties(
        thumbnail_,
        &properties
    );
    if (FAILED(updateStatus)) {
        error = hresultMessage(L"DWM mirror update", updateStatus);
        stop();
        return false;
    }

    return true;
}

void MirrorSession::stop() noexcept {
    if (mirrorWindow_ != nullptr) {
        ShowWindow(mirrorWindow_, SW_HIDE);
    }
    if (thumbnail_ != nullptr) {
        DwmUnregisterThumbnail(thumbnail_);
        thumbnail_ = nullptr;
    }
    if (mirrorWindow_ != nullptr) {
        DestroyWindow(mirrorWindow_);
        mirrorWindow_ = nullptr;
    }
    source_ = {};
}

bool MirrorSession::active() const noexcept {
    return mirrorWindow_ != nullptr
        && thumbnail_ != nullptr;
}

const WindowCandidate& MirrorSession::source() const noexcept {
    return source_;
}

LRESULT CALLBACK MirrorSession::windowProcedure(
    HWND window,
    UINT message,
    WPARAM wParam,
    LPARAM lParam
) {
    switch (message) {
    case WM_MOUSEACTIVATE:
        return MA_NOACTIVATE;
    case WM_NCHITTEST:
        return HTTRANSPARENT;
    case WM_ERASEBKGND:
        return 1;
    case WM_PAINT: {
        PAINTSTRUCT paint{};
        HDC context = BeginPaint(window, &paint);
        FillRect(
            context,
            &paint.rcPaint,
            static_cast<HBRUSH>(GetStockObject(BLACK_BRUSH))
        );
        EndPaint(window, &paint);
        return 0;
    }
    default:
        return DefWindowProcW(window, message, wParam, lParam);
    }
}

} // namespace fuwa::windows
