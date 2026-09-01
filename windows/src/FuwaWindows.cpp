#include "MirrorSession.hpp"
#include "WindowCatalog.hpp"
#include "../resources/resource.h"

#include <commctrl.h>
#include <shellapi.h>
#include <wtsapi32.h>

#include <algorithm>
#include <array>
#include <format>
#include <optional>
#include <string>
#include <vector>

namespace fuwa::windows {
namespace {

constexpr wchar_t mainWindowClassName[] = L"FuwaWindowsControlWindow";
constexpr wchar_t singleInstanceName[] = L"Local\\app.yuxino.fuwa.windows";
constexpr UINT trayIconIdentifier = 1;
constexpr UINT trayCallbackMessage = WM_APP + 1;
constexpr UINT mirrorTimerIdentifier = 1;
constexpr UINT globalHotKeyIdentifier = 1;
constexpr UINT mirrorRefreshMilliseconds = 250;

#define FUWA_WIDEN_VERSION_IMPL(value) L##value
#define FUWA_WIDEN_VERSION(value) FUWA_WIDEN_VERSION_IMPL(value)
constexpr wchar_t chineseAboutText[] =
    L"Fuwa " FUWA_WIDEN_VERSION(FUWA_MARKETING_VERSION)
    L"\n\nWindows 版本使用公开 DWM API 显示本地实时镜像，不读取、保存或上传窗口像素。"
    L"\n\nFinder Quick Look 在 Windows 不适用。";
constexpr wchar_t englishAboutText[] =
    L"Fuwa " FUWA_WIDEN_VERSION(FUWA_MARKETING_VERSION)
    L"\n\nThe Windows version uses the public DWM API for a local live mirror. "
    L"It does not read, save, or upload window pixels."
    L"\n\nFinder Quick Look is not applicable on Windows.";
#undef FUWA_WIDEN_VERSION
#undef FUWA_WIDEN_VERSION_IMPL

constexpr int controlList = 1001;
constexpr int controlRefresh = 1002;
constexpr int controlPin = 1003;
constexpr int controlReveal = 1004;
constexpr int controlUnpin = 1005;
constexpr int controlStatus = 1006;
constexpr int controlDescription = 1007;
constexpr int controlHeading = 1008;

constexpr UINT commandTrayOpen = 2001;
constexpr UINT commandTrayPinForeground = 2002;
constexpr UINT commandTrayUnpin = 2003;
constexpr UINT commandTrayAbout = 2004;
constexpr UINT commandTrayQuit = 2005;

struct UiCopy {
    const wchar_t* windowTitle;
    const wchar_t* heading;
    const wchar_t* description;
    const wchar_t* applicationColumn;
    const wchar_t* windowColumn;
    const wchar_t* refresh;
    const wchar_t* pinSelected;
    const wchar_t* showSource;
    const wchar_t* unpin;
    const wchar_t* trayOpen;
    const wchar_t* trayPinForeground;
    const wchar_t* trayAbout;
    const wchar_t* trayQuit;
    const wchar_t* ready;
    const wchar_t* emptySelection;
    const wchar_t* noForeground;
    const wchar_t* noMirror;
    const wchar_t* shortcutUnavailable;
    const wchar_t* trayUnavailable;
    const wchar_t* sessionNotificationsUnavailable;
    const wchar_t* timerUnavailable;
    const wchar_t* aboutText;
};

UiCopy makeCopy(bool chinese) {
    if (chinese) {
        return UiCopy{
            L"Fuwa - Windows 窗口镜像",
            L"选择一个普通应用窗口",
            L"Fuwa 会创建本地实时镜像并保持在普通窗口前方。也可在目标窗口位于前台时按 Ctrl+Alt+P。",
            L"应用",
            L"窗口",
            L"刷新",
            L"镜像所选窗口",
            L"显示源窗口",
            L"取消镜像",
            L"打开 Fuwa",
            L"镜像当前前台窗口",
            L"关于 Fuwa",
            L"退出",
            L"请选择窗口。Fuwa 不会修改源窗口的真实层级。",
            L"请先在列表中选择一个窗口。",
            L"当前前台没有可镜像的普通应用窗口。",
            L"当前没有镜像。",
            L"Ctrl+Alt+P 已被其他应用占用；列表与托盘仍可使用。",
            L"系统托盘图标不可用；关闭此窗口将退出 Fuwa。",
            L"Windows 会话通知不可用；为保护隐私，镜像功能已停用。请刷新后重试。",
            L"无法启动镜像安全监测；镜像已移除。",
            chineseAboutText
        };
    }

    return UiCopy{
        L"Fuwa - Windows window mirror",
        L"Choose an ordinary application window",
        L"Fuwa creates a local live mirror above ordinary windows. You can also press Ctrl+Alt+P while the target is in front.",
        L"Application",
        L"Window",
        L"Refresh",
        L"Mirror selected",
        L"Show source",
        L"Unpin",
        L"Open Fuwa",
        L"Mirror frontmost window",
        L"About Fuwa",
        L"Quit",
        L"Choose a window. Fuwa does not change the source window's real level.",
        L"Select a window from the list first.",
        L"The foreground window is not an ordinary capturable application window.",
        L"No mirror is active.",
        L"Ctrl+Alt+P is already used by another app. The list and tray still work.",
        L"The system-tray icon is unavailable. Closing this window will quit Fuwa.",
        L"Windows session notifications are unavailable, so mirroring is disabled for privacy. Refresh to retry.",
        L"Mirror safety monitoring could not start, so the mirror was removed.",
        englishAboutText
    };
}

bool usesSimplifiedChinese() {
    const LANGID language = GetUserDefaultUILanguage();
    return PRIMARYLANGID(language) == LANG_CHINESE;
}

HMENU controlMenuHandle(int identifier) noexcept {
    return reinterpret_cast<HMENU>(static_cast<INT_PTR>(identifier));
}

class Application final {
public:
    explicit Application(HINSTANCE instance)
        : instance_(instance),
          processId_(GetCurrentProcessId()),
          taskbarCreatedMessage_(RegisterWindowMessageW(L"TaskbarCreated")),
          copy_(makeCopy(usesSimplifiedChinese())) {}

    int run(int showCommand) {
        if (!registerMainWindowClass()) {
            return 1;
        }

        mainWindow_ = CreateWindowExW(
            0,
            mainWindowClassName,
            copy_.windowTitle,
            WS_OVERLAPPEDWINDOW,
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            820,
            560,
            nullptr,
            nullptr,
            instance_,
            this
        );
        if (mainWindow_ == nullptr) {
            return 1;
        }

        ShowWindow(mainWindow_, showCommand == SW_HIDE ? SW_SHOWNORMAL : showCommand);
        UpdateWindow(mainWindow_);

        MSG message{};
        BOOL messageResult = FALSE;
        while ((messageResult = GetMessageW(&message, nullptr, 0, 0)) > 0) {
            TranslateMessage(&message);
            DispatchMessageW(&message);
        }
        if (messageResult == -1) {
            return 1;
        }
        return static_cast<int>(message.wParam);
    }

private:
    bool registerMainWindowClass() {
        icon_ = static_cast<HICON>(LoadImageW(
            instance_,
            MAKEINTRESOURCEW(IDI_FUWA),
            IMAGE_ICON,
            0,
            0,
            LR_DEFAULTSIZE | LR_SHARED
        ));
        if (icon_ == nullptr) {
            icon_ = LoadIconW(nullptr, IDI_APPLICATION);
        }

        WNDCLASSEXW windowClass{
            .cbSize = sizeof(WNDCLASSEXW),
            .style = CS_HREDRAW | CS_VREDRAW,
            .lpfnWndProc = Application::windowProcedure,
            .hInstance = instance_,
            .hIcon = icon_,
            .hCursor = LoadCursorW(nullptr, IDC_ARROW),
            .hbrBackground = GetSysColorBrush(COLOR_WINDOW),
            .lpszClassName = mainWindowClassName,
            .hIconSm = icon_
        };
        return RegisterClassExW(&windowClass) != 0
            || GetLastError() == ERROR_CLASS_ALREADY_EXISTS;
    }

    static LRESULT CALLBACK windowProcedure(
        HWND window,
        UINT message,
        WPARAM wParam,
        LPARAM lParam
    ) {
        Application* application = reinterpret_cast<Application*>(
            GetWindowLongPtrW(window, GWLP_USERDATA)
        );
        if (message == WM_NCCREATE) {
            const auto* create = reinterpret_cast<CREATESTRUCTW*>(lParam);
            application = static_cast<Application*>(create->lpCreateParams);
            SetWindowLongPtrW(
                window,
                GWLP_USERDATA,
                reinterpret_cast<LONG_PTR>(application)
            );
        }
        if (application != nullptr) {
            return application->handleMessage(window, message, wParam, lParam);
        }
        return DefWindowProcW(window, message, wParam, lParam);
    }

    LRESULT handleMessage(
        HWND window,
        UINT message,
        WPARAM wParam,
        LPARAM lParam
    ) {
        if (taskbarCreatedMessage_ != 0
            && message == taskbarCreatedMessage_) {
            trayIconAdded_ = false;
            if (!addTrayIcon()) {
                ShowWindow(mainWindow_, SW_SHOWNORMAL);
                setStatus(copy_.trayUnavailable);
            }
            return 0;
        }

        switch (message) {
        case WM_CREATE:
            return onCreate(window) ? 0 : -1;
        case WM_SIZE:
            layoutControls(LOWORD(lParam), HIWORD(lParam));
            return 0;
        case WM_DPICHANGED: {
            const auto* suggested = reinterpret_cast<RECT*>(lParam);
            SetWindowPos(
                window,
                nullptr,
                suggested->left,
                suggested->top,
                suggested->right - suggested->left,
                suggested->bottom - suggested->top,
                SWP_NOACTIVATE | SWP_NOZORDER
            );
            return 0;
        }
        case WM_COMMAND:
            onCommand(LOWORD(wParam));
            return 0;
        case WM_NOTIFY:
            if (reinterpret_cast<NMHDR*>(lParam)->idFrom
                    == static_cast<UINT_PTR>(controlList)
                && reinterpret_cast<NMHDR*>(lParam)->code
                    == static_cast<UINT>(NM_DBLCLK)) {
                pinSelectedWindow();
            }
            return 0;
        case WM_HOTKEY:
            if (wParam == globalHotKeyIdentifier) {
                toggleForegroundWindow();
            }
            return 0;
        case WM_TIMER:
            if (wParam == mirrorTimerIdentifier) {
                refreshMirror();
            }
            return 0;
        case WM_WTSSESSION_CHANGE:
            if (wParam == static_cast<WPARAM>(WTS_SESSION_LOCK)
                || wParam == static_cast<WPARAM>(WTS_SESSION_LOGOFF)
                || wParam == static_cast<WPARAM>(WTS_CONSOLE_DISCONNECT)
                || wParam == static_cast<WPARAM>(WTS_REMOTE_DISCONNECT)) {
                stopMirror(copy_.noMirror);
            }
            return 0;
        case WM_POWERBROADCAST:
            if (wParam == static_cast<WPARAM>(PBT_APMSUSPEND)) {
                stopMirror(copy_.noMirror);
            }
            return TRUE;
        case trayCallbackMessage:
            onTrayEvent(LOWORD(lParam));
            return 0;
        case WM_QUERYENDSESSION:
            return TRUE;
        case WM_ENDSESSION:
            if (wParam != 0U) {
                shuttingDown_ = true;
                DestroyWindow(window);
            }
            return 0;
        case WM_CLOSE:
            if (shuttingDown_) {
                DestroyWindow(window);
            } else if (trayIconAdded_) {
                ShowWindow(window, SW_HIDE);
            } else {
                shuttingDown_ = true;
                DestroyWindow(window);
            }
            return 0;
        case WM_DESTROY:
            cleanup();
            PostQuitMessage(0);
            return 0;
        default:
            return DefWindowProcW(window, message, wParam, lParam);
        }
    }

    bool onCreate(HWND window) {
        mainWindow_ = window;
        heading_ = CreateWindowExW(
            0,
            L"STATIC",
            copy_.heading,
            WS_CHILD | WS_VISIBLE | SS_LEFT,
            0,
            0,
            0,
            0,
            window,
            controlMenuHandle(controlHeading),
            instance_,
            nullptr
        );
        description_ = CreateWindowExW(
            0,
            L"STATIC",
            copy_.description,
            WS_CHILD | WS_VISIBLE | SS_LEFT,
            0,
            0,
            0,
            0,
            window,
            controlMenuHandle(controlDescription),
            instance_,
            nullptr
        );
        list_ = CreateWindowExW(
            WS_EX_CLIENTEDGE,
            WC_LISTVIEWW,
            L"",
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | LVS_REPORT | LVS_SINGLESEL,
            0,
            0,
            0,
            0,
            window,
            controlMenuHandle(controlList),
            instance_,
            nullptr
        );
        refreshButton_ = createButton(copy_.refresh, controlRefresh);
        pinButton_ = createButton(copy_.pinSelected, controlPin);
        revealButton_ = createButton(copy_.showSource, controlReveal);
        unpinButton_ = createButton(copy_.unpin, controlUnpin);
        status_ = CreateWindowExW(
            0,
            L"STATIC",
            copy_.ready,
            WS_CHILD | WS_VISIBLE | SS_LEFT,
            0,
            0,
            0,
            0,
            window,
            controlMenuHandle(controlStatus),
            instance_,
            nullptr
        );
        if (heading_ == nullptr || description_ == nullptr || list_ == nullptr
            || refreshButton_ == nullptr || pinButton_ == nullptr
            || revealButton_ == nullptr || unpinButton_ == nullptr
            || status_ == nullptr) {
            return false;
        }

        createFonts();
        applyFonts();
        configureList();
        addTrayIcon();
        ensureSessionNotifications();
        hotKeyRegistered_ = RegisterHotKey(
            window,
            globalHotKeyIdentifier,
            MOD_CONTROL | MOD_ALT | MOD_NOREPEAT,
            'P'
        ) != FALSE;
        refreshWindowList();
        updateActions();
        if (!sessionNotificationRegistered_) {
            setStatus(copy_.sessionNotificationsUnavailable);
        } else if (!trayIconAdded_) {
            setStatus(copy_.trayUnavailable);
        } else if (!hotKeyRegistered_) {
            setStatus(copy_.shortcutUnavailable);
        }
        return true;
    }

    HWND createButton(const wchar_t* title, int identifier) const {
        return CreateWindowExW(
            0,
            L"BUTTON",
            title,
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
            0,
            0,
            0,
            0,
            mainWindow_,
            controlMenuHandle(identifier),
            instance_,
            nullptr
        );
    }

    void createFonts() {
        const UINT dpi = GetDpiForWindow(mainWindow_);
        const int bodyHeight = -MulDiv(10, static_cast<int>(dpi), 72);
        const int headingHeight = -MulDiv(16, static_cast<int>(dpi), 72);
        bodyFont_ = CreateFontW(
            bodyHeight,
            0,
            0,
            0,
            FW_NORMAL,
            FALSE,
            FALSE,
            FALSE,
            DEFAULT_CHARSET,
            OUT_DEFAULT_PRECIS,
            CLIP_DEFAULT_PRECIS,
            CLEARTYPE_QUALITY,
            DEFAULT_PITCH | FF_DONTCARE,
            L"Segoe UI"
        );
        headingFont_ = CreateFontW(
            headingHeight,
            0,
            0,
            0,
            FW_SEMIBOLD,
            FALSE,
            FALSE,
            FALSE,
            DEFAULT_CHARSET,
            OUT_DEFAULT_PRECIS,
            CLIP_DEFAULT_PRECIS,
            CLEARTYPE_QUALITY,
            DEFAULT_PITCH | FF_DONTCARE,
            L"Segoe UI"
        );
    }

    void applyFonts() const {
        const std::array bodyControls{
            description_,
            list_,
            refreshButton_,
            pinButton_,
            revealButton_,
            unpinButton_,
            status_
        };
        for (HWND control : bodyControls) {
            SendMessageW(
                control,
                WM_SETFONT,
                reinterpret_cast<WPARAM>(bodyFont_),
                TRUE
            );
        }
        SendMessageW(
            heading_,
            WM_SETFONT,
            reinterpret_cast<WPARAM>(headingFont_),
            TRUE
        );
    }

    void configureList() const {
        ListView_SetExtendedListViewStyle(
            list_,
            LVS_EX_FULLROWSELECT | LVS_EX_DOUBLEBUFFER | LVS_EX_LABELTIP
        );
        LVCOLUMNW applicationColumn{
            .mask = LVCF_TEXT | LVCF_WIDTH | LVCF_SUBITEM,
            .cx = 180,
            .pszText = const_cast<wchar_t*>(copy_.applicationColumn),
            .iSubItem = 0
        };
        ListView_InsertColumn(list_, 0, &applicationColumn);
        LVCOLUMNW windowColumn{
            .mask = LVCF_TEXT | LVCF_WIDTH | LVCF_SUBITEM,
            .cx = 540,
            .pszText = const_cast<wchar_t*>(copy_.windowColumn),
            .iSubItem = 1
        };
        ListView_InsertColumn(list_, 1, &windowColumn);
    }

    void layoutControls(int width, int height) const {
        if (heading_ == nullptr) {
            return;
        }
        const int margin = 24;
        const int contentWidth = std::max(0, width - (margin * 2));
        MoveWindow(heading_, margin, 20, contentWidth, 30, TRUE);
        MoveWindow(description_, margin, 54, contentWidth, 44, TRUE);

        const int buttonsTop = std::max(110, height - 92);
        const int statusTop = std::max(146, height - 42);
        const int listHeight = std::max(80, buttonsTop - 114);
        MoveWindow(list_, margin, 104, contentWidth, listHeight, TRUE);

        constexpr int buttonGap = 8;
        const int buttonWidth = std::max(
            100,
            (contentWidth - (buttonGap * 3)) / 4
        );
        int buttonLeft = margin;
        for (HWND button : std::array{
                 refreshButton_, pinButton_, revealButton_, unpinButton_}) {
            MoveWindow(button, buttonLeft, buttonsTop, buttonWidth, 32, TRUE);
            buttonLeft += buttonWidth + buttonGap;
        }
        MoveWindow(status_, margin, statusTop, contentWidth, 24, TRUE);

        ListView_SetColumnWidth(list_, 0, std::max(140, contentWidth / 3));
        ListView_SetColumnWidth(
            list_,
            1,
            std::max(220, contentWidth - std::max(140, contentWidth / 3) - 4)
        );
    }

    void refreshWindowList() {
        ensureSessionNotifications();
        candidates_ = WindowCatalog::snapshot(processId_);
        ListView_DeleteAllItems(list_);
        int row = 0;
        for (const auto& candidate : candidates_) {
            LVITEMW item{
                .mask = LVIF_TEXT,
                .iItem = row,
                .iSubItem = 0,
                .pszText = const_cast<wchar_t*>(candidate.applicationName.c_str())
            };
            ListView_InsertItem(list_, &item);

            ListView_SetItemText(
                list_,
                row,
                1,
                const_cast<wchar_t*>(candidate.title.c_str())
            );
            ++row;
        }
        if (!candidates_.empty()) {
            ListView_SetItemState(
                list_,
                0,
                LVIS_SELECTED | LVIS_FOCUSED,
                LVIS_SELECTED | LVIS_FOCUSED
            );
        }
        updateActions();
    }

    std::optional<WindowCandidate> selectedWindow() const {
        const int selected = ListView_GetNextItem(list_, -1, LVNI_SELECTED);
        if (selected < 0
            || static_cast<std::size_t>(selected) >= candidates_.size()) {
            return std::nullopt;
        }
        return candidates_[static_cast<std::size_t>(selected)];
    }

    void pinSelectedWindow() {
        const auto selected = selectedWindow();
        if (!selected) {
            setStatus(copy_.emptySelection);
            return;
        }
        startMirror(*selected);
    }

    void toggleForegroundWindow() {
        const auto foreground = WindowCatalog::foreground(processId_);
        if (!foreground) {
            setStatus(copy_.noForeground);
            return;
        }
        if (mirror_.active()
            && WindowCatalog::sameIdentity(mirror_.source(), *foreground)) {
            stopMirror(copy_.noMirror);
            return;
        }
        startMirror(*foreground);
    }

    void startMirror(const WindowCandidate& candidate) {
        KillTimer(mainWindow_, mirrorTimerIdentifier);
        if (!ensureSessionNotifications()) {
            mirror_.stop();
            setStatus(copy_.sessionNotificationsUnavailable);
            updateActions();
            return;
        }
        std::wstring error;
        if (!mirror_.start(candidate, processId_, error)) {
            setStatus(error);
            updateActions();
            return;
        }
        const UINT_PTR timer = SetTimer(
            mainWindow_,
            mirrorTimerIdentifier,
            mirrorRefreshMilliseconds,
            nullptr
        );
        if (timer == 0) {
            mirror_.stop();
            setStatus(copy_.timerUnavailable);
            updateActions();
            return;
        }
        setStatus(std::format(
            L"{} - {}",
            candidate.applicationName,
            candidate.title
        ));
        updateActions();
    }

    void refreshMirror() {
        std::wstring error;
        if (!mirror_.refresh(processId_, error)) {
            KillTimer(mainWindow_, mirrorTimerIdentifier);
            setStatus(error);
            updateActions();
        }
    }

    void stopMirror(const wchar_t* statusText) {
        KillTimer(mainWindow_, mirrorTimerIdentifier);
        mirror_.stop();
        setStatus(statusText);
        updateActions();
    }

    void revealSource() {
        if (!mirror_.active()) {
            setStatus(copy_.noMirror);
            return;
        }
        const WindowCandidate candidate = mirror_.source();
        if (!WindowCatalog::revalidate(candidate, processId_)) {
            stopMirror(copy_.noMirror);
            return;
        }
        if (IsIconic(candidate.handle) != FALSE) {
            ShowWindowAsync(candidate.handle, SW_RESTORE);
        }
        if (SetForegroundWindow(candidate.handle) == FALSE) {
            setStatus(L"Windows did not allow the source window to take focus.");
        }
    }

    void updateActions() const {
        EnableWindow(
            pinButton_,
            sessionNotificationRegistered_ && selectedWindow().has_value()
        );
        const BOOL hasMirror = mirror_.active() ? TRUE : FALSE;
        EnableWindow(revealButton_, hasMirror);
        EnableWindow(unpinButton_, hasMirror);
    }

    void setStatus(const std::wstring& text) const {
        SetWindowTextW(status_, text.c_str());
    }

    void setStatus(const wchar_t* text) const {
        SetWindowTextW(status_, text);
    }

    bool ensureSessionNotifications() {
        if (!sessionNotificationRegistered_) {
            sessionNotificationRegistered_ = WTSRegisterSessionNotification(
                mainWindow_,
                NOTIFY_FOR_THIS_SESSION
            ) != FALSE;
        }
        return sessionNotificationRegistered_;
    }

    bool addTrayIcon() {
        trayIconAdded_ = false;
        trayIcon_ = {};
        trayIcon_.cbSize = sizeof(trayIcon_);
        trayIcon_.hWnd = mainWindow_;
        trayIcon_.uID = trayIconIdentifier;
        trayIcon_.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP | NIF_SHOWTIP;
        trayIcon_.uCallbackMessage = trayCallbackMessage;
        trayIcon_.hIcon = icon_;
        wcscpy_s(trayIcon_.szTip, L"Fuwa");
        if (Shell_NotifyIconW(NIM_ADD, &trayIcon_) != FALSE) {
            trayIconAdded_ = true;
            trayIcon_.uVersion = NOTIFYICON_VERSION_4;
            Shell_NotifyIconW(NIM_SETVERSION, &trayIcon_);
        }
        return trayIconAdded_;
    }

    void onTrayEvent(UINT event) {
        if (event == NIN_SELECT || event == NIN_KEYSELECT
            || event == WM_LBUTTONUP) {
            showControlWindow();
            return;
        }
        if (event != WM_CONTEXTMENU && event != WM_RBUTTONUP) {
            return;
        }

        trayForeground_ = WindowCatalog::foreground(processId_);
        HMENU menu = CreatePopupMenu();
        if (menu == nullptr) {
            return;
        }
        AppendMenuW(menu, MF_STRING, commandTrayOpen, copy_.trayOpen);
        AppendMenuW(
            menu,
            MF_STRING,
            commandTrayPinForeground,
            copy_.trayPinForeground
        );
        AppendMenuW(
            menu,
            MF_STRING | (mirror_.active() ? MF_ENABLED : MF_GRAYED),
            commandTrayUnpin,
            copy_.unpin
        );
        AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
        AppendMenuW(menu, MF_STRING, commandTrayAbout, copy_.trayAbout);
        AppendMenuW(menu, MF_STRING, commandTrayQuit, copy_.trayQuit);

        POINT cursor{};
        GetCursorPos(&cursor);
        SetForegroundWindow(mainWindow_);
        const BOOL command = TrackPopupMenu(
            menu,
            TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON,
            cursor.x,
            cursor.y,
            0,
            mainWindow_,
            nullptr
        );
        DestroyMenu(menu);
        if (command != 0) {
            onCommand(static_cast<UINT>(command));
        }
    }

    void onCommand(UINT command) {
        switch (command) {
        case controlRefresh:
            refreshWindowList();
            break;
        case controlPin:
            pinSelectedWindow();
            break;
        case controlReveal:
            revealSource();
            break;
        case controlUnpin:
        case commandTrayUnpin:
            stopMirror(copy_.noMirror);
            break;
        case commandTrayOpen:
            showControlWindow();
            break;
        case commandTrayPinForeground:
            if (trayForeground_) {
                startMirror(*trayForeground_);
            } else {
                setStatus(copy_.noForeground);
            }
            trayForeground_.reset();
            break;
        case commandTrayAbout:
            MessageBoxW(
                mainWindow_,
                copy_.aboutText,
                L"Fuwa",
                MB_OK | MB_ICONINFORMATION
            );
            break;
        case commandTrayQuit:
            shuttingDown_ = true;
            DestroyWindow(mainWindow_);
            break;
        default:
            break;
        }
    }

    void showControlWindow() {
        ShowWindow(mainWindow_, SW_SHOWNORMAL);
        SetForegroundWindow(mainWindow_);
        refreshWindowList();
    }

    void cleanup() {
        KillTimer(mainWindow_, mirrorTimerIdentifier);
        mirror_.stop();
        if (hotKeyRegistered_) {
            UnregisterHotKey(mainWindow_, globalHotKeyIdentifier);
            hotKeyRegistered_ = false;
        }
        if (sessionNotificationRegistered_) {
            WTSUnRegisterSessionNotification(mainWindow_);
            sessionNotificationRegistered_ = false;
        }
        if (trayIconAdded_) {
            Shell_NotifyIconW(NIM_DELETE, &trayIcon_);
            trayIconAdded_ = false;
        }
        if (headingFont_ != nullptr) {
            DeleteObject(headingFont_);
            headingFont_ = nullptr;
        }
        if (bodyFont_ != nullptr) {
            DeleteObject(bodyFont_);
            bodyFont_ = nullptr;
        }
    }

    HINSTANCE instance_ = nullptr;
    DWORD processId_ = 0;
    UINT taskbarCreatedMessage_ = 0;
    UiCopy copy_{};
    HWND mainWindow_ = nullptr;
    HWND heading_ = nullptr;
    HWND description_ = nullptr;
    HWND list_ = nullptr;
    HWND refreshButton_ = nullptr;
    HWND pinButton_ = nullptr;
    HWND revealButton_ = nullptr;
    HWND unpinButton_ = nullptr;
    HWND status_ = nullptr;
    HFONT headingFont_ = nullptr;
    HFONT bodyFont_ = nullptr;
    HICON icon_ = nullptr;
    NOTIFYICONDATAW trayIcon_{};
    bool trayIconAdded_ = false;
    bool hotKeyRegistered_ = false;
    bool sessionNotificationRegistered_ = false;
    bool shuttingDown_ = false;
    std::vector<WindowCandidate> candidates_;
    std::optional<WindowCandidate> trayForeground_;
    MirrorSession mirror_;
};

} // namespace
} // namespace fuwa::windows

int WINAPI wWinMain(
    HINSTANCE instance,
    HINSTANCE,
    PWSTR,
    int showCommand
) {
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);

    INITCOMMONCONTROLSEX controls{
        .dwSize = sizeof(INITCOMMONCONTROLSEX),
        .dwICC = ICC_LISTVIEW_CLASSES | ICC_STANDARD_CLASSES
    };
    if (InitCommonControlsEx(&controls) == FALSE) {
        return 1;
    }

    HANDLE singleInstance = CreateMutexW(
        nullptr,
        TRUE,
        fuwa::windows::singleInstanceName
    );
    if (singleInstance == nullptr) {
        return 1;
    }
    if (GetLastError() == ERROR_ALREADY_EXISTS) {
        if (HWND existing = FindWindowW(
                fuwa::windows::mainWindowClassName,
                nullptr
            )) {
            ShowWindow(existing, SW_SHOWNORMAL);
            SetForegroundWindow(existing);
        }
        CloseHandle(singleInstance);
        return 0;
    }

    fuwa::windows::Application application(instance);
    const int result = application.run(showCommand);
    ReleaseMutex(singleInstance);
    CloseHandle(singleInstance);
    return result;
}
