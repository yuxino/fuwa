cmake_minimum_required(VERSION 3.27)

set(FUWA_MARKETING_VERSION "0.1.6")
set(FUWA_BUILD_NUMBER "7")

project(
    FuwaWindows
    VERSION "${FUWA_MARKETING_VERSION}.${FUWA_BUILD_NUMBER}"
    DESCRIPTION "A local live window mirror"
    LANGUAGES CXX RC
)

if(NOT WIN32)
    message(FATAL_ERROR "The Fuwa Windows target must be configured on Windows.")
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(FUWA_TARGET_PROCESSOR "${CMAKE_GENERATOR_PLATFORM}")
if(FUWA_TARGET_PROCESSOR STREQUAL "")
    set(FUWA_TARGET_PROCESSOR "${CMAKE_CXX_COMPILER_ARCHITECTURE_ID}")
endif()
if(FUWA_TARGET_PROCESSOR STREQUAL "")
    set(FUWA_TARGET_PROCESSOR "${CMAKE_SYSTEM_PROCESSOR}")
endif()
string(TOLOWER "${FUWA_TARGET_PROCESSOR}" FUWA_PROCESSOR_LOWER)
if(FUWA_PROCESSOR_LOWER MATCHES "^(arm64|aarch64)$")
    set(FUWA_PACKAGE_ARCHITECTURE "arm64")
    set(FUWA_WINSPARKLE_ARCHITECTURE "ARM64")
elseif(FUWA_PROCESSOR_LOWER MATCHES "^(x64|amd64|x86_64)$")
    set(FUWA_PACKAGE_ARCHITECTURE "x64")
    set(FUWA_WINSPARKLE_ARCHITECTURE "x64")
else()
    message(FATAL_ERROR
        "Unsupported Windows target architecture: ${FUWA_TARGET_PROCESSOR}. "
        "Fuwa supports only x64 and ARM64."
    )
endif()

include(FetchContent)
FetchContent_Declare(
    FuwaWinSparkle
    URL "https://github.com/vslavik/winsparkle/releases/download/v0.9.4/WinSparkle-0.9.4.zip"
    URL_HASH "SHA256=6037df37fc263bd1650a1c4949681a9d40ffe991d01f35892a406cb5d103c976"
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
)
FetchContent_GetProperties(FuwaWinSparkle)
if(NOT fuwawinsparkle_POPULATED)
    FetchContent_Populate(FuwaWinSparkle)
endif()
set(FUWA_WINSPARKLE_ROOT
    "${fuwawinsparkle_SOURCE_DIR}/WinSparkle-0.9.4"
)
set(FUWA_WINSPARKLE_BINARY_DIR
    "${FUWA_WINSPARKLE_ROOT}/${FUWA_WINSPARKLE_ARCHITECTURE}/Release"
)
foreach(FUWA_WINSPARKLE_FILE WinSparkle.dll WinSparkle.lib)
    if(NOT EXISTS "${FUWA_WINSPARKLE_BINARY_DIR}/${FUWA_WINSPARKLE_FILE}")
        message(FATAL_ERROR
            "Pinned WinSparkle archive is missing ${FUWA_WINSPARKLE_FILE} "
            "for ${FUWA_PACKAGE_ARCHITECTURE}."
        )
    endif()
endforeach()

add_library(FuwaWinSparkleLibrary SHARED IMPORTED GLOBAL)
set_target_properties(FuwaWinSparkleLibrary PROPERTIES
    IMPORTED_IMPLIB "${FUWA_WINSPARKLE_BINARY_DIR}/WinSparkle.lib"
    IMPORTED_LOCATION "${FUWA_WINSPARKLE_BINARY_DIR}/WinSparkle.dll"
    INTERFACE_INCLUDE_DIRECTORIES "${FUWA_WINSPARKLE_ROOT}/include"
)

add_library(FuwaWindowsCore STATIC
    src/FuwaCore.cpp
)
target_include_directories(FuwaWindowsCore PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
)
target_compile_features(FuwaWindowsCore PUBLIC cxx_std_20)

add_executable(Fuwa WIN32
    src/FuwaWindows.cpp
    src/MirrorSession.cpp
    src/WindowCatalog.cpp
    resources/FuwaWindows.rc
)
target_include_directories(Fuwa PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
    "${CMAKE_CURRENT_SOURCE_DIR}/resources"
)
target_compile_features(Fuwa PRIVATE cxx_std_20)
target_compile_definitions(Fuwa PRIVATE
    FUWA_BUILD_NUMBER="${FUWA_BUILD_NUMBER}"
    FUWA_MARKETING_VERSION="${FUWA_MARKETING_VERSION}"
    FUWA_UPDATE_FEED_URL="https://github.com/yuxino/fuwa/releases/latest/download/appcast-windows-${FUWA_PACKAGE_ARCHITECTURE}.xml"
    UNICODE
    _UNICODE
    WIN32_LEAN_AND_MEAN
    NOMINMAX
    _WIN32_WINNT=0x0A00
    WINVER=0x0A00
)
target_link_libraries(Fuwa PRIVATE
    FuwaWindowsCore
    FuwaWinSparkleLibrary
    Comctl32
    Dwmapi
    Gdi32
    Shell32
    User32
    Wtsapi32
)
add_custom_command(TARGET Fuwa POST_BUILD
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
        "$<TARGET_FILE:FuwaWinSparkleLibrary>"
        "$<TARGET_FILE_DIR:Fuwa>"
    VERBATIM
)

function(configure_fuwa_msvc_target target)
    if(MSVC)
        target_compile_options(${target} PRIVATE
            "$<$<COMPILE_LANGUAGE:CXX>:/W4;/WX;/permissive-;/utf-8;/Zc:__cplusplus;/guard:cf>"
        )
        set_property(
            TARGET ${target}
            PROPERTY MSVC_RUNTIME_LIBRARY
                "MultiThreaded$<$<CONFIG:Debug>:Debug>"
        )
    endif()
endfunction()

configure_fuwa_msvc_target(FuwaWindowsCore)
configure_fuwa_msvc_target(Fuwa)
if(MSVC)
    target_link_options(Fuwa PRIVATE
        /DYNAMICBASE
        /GUARD:CF
        /MANIFEST:NO
        /NXCOMPAT
    )
endif()

enable_testing()
add_executable(FuwaWindowsCoreTests
    tests/FuwaCoreTests.cpp
)
target_link_libraries(FuwaWindowsCoreTests PRIVATE FuwaWindowsCore)
target_compile_features(FuwaWindowsCoreTests PRIVATE cxx_std_20)
configure_fuwa_msvc_target(FuwaWindowsCoreTests)
if(MSVC)
    target_link_options(FuwaWindowsCoreTests PRIVATE
        /DYNAMICBASE
        /GUARD:CF
        /NXCOMPAT
    )
endif()
add_test(NAME FuwaWindowsCoreTests COMMAND FuwaWindowsCoreTests)

install(TARGETS Fuwa RUNTIME DESTINATION ".")
install(FILES
    "$<TARGET_FILE:FuwaWinSparkleLibrary>"
    DESTINATION "."
)
install(FILES
    "${FUWA_WINSPARKLE_ROOT}/COPYING"
    "${FUWA_WINSPARKLE_ROOT}/COPYING.expat"
    DESTINATION "licenses/WinSparkle"
)

set(CPACK_VERBATIM_VARIABLES ON)

set(CPACK_GENERATOR "INNOSETUP")
set(CPACK_PACKAGE_NAME "Fuwa")
set(CPACK_PACKAGE_VERSION "${FUWA_MARKETING_VERSION}")
set(CPACK_PACKAGE_VENDOR "yuxino and Fuwa contributors")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Keep an ordinary application window visible as a local live mirror.")
set(CPACK_PACKAGE_HOMEPAGE_URL "https://github.com/yuxino/fuwa")
set(CPACK_PACKAGE_INSTALL_DIRECTORY "Fuwa")
set(CPACK_PACKAGE_FILE_NAME
    "Fuwa-${FUWA_MARKETING_VERSION}-windows-${FUWA_PACKAGE_ARCHITECTURE}-setup"
)
set(CPACK_PACKAGE_EXECUTABLES "Fuwa" "Fuwa")
set(CPACK_PACKAGE_CHECKSUM "SHA256")
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/../LICENSE")
set(CPACK_INNOSETUP_ARCHITECTURE "${FUWA_PACKAGE_ARCHITECTURE}")
set(CPACK_INNOSETUP_INSTALL_ROOT "{localappdata}/Programs")
set(CPACK_INNOSETUP_ALLOW_CUSTOM_DIRECTORY OFF)
set(CPACK_INNOSETUP_PROGRAM_MENU_FOLDER "Fuwa")
set(CPACK_INNOSETUP_CREATE_UNINSTALL_LINK ON)
set(CPACK_INNOSETUP_USE_MODERN_WIZARD ON)
set(CPACK_INNOSETUP_ICON_FILE
    "${CMAKE_CURRENT_SOURCE_DIR}/resources/Fuwa.ico"
)
set(CPACK_INNOSETUP_EXTRA_SCRIPTS
    "${CMAKE_CURRENT_SOURCE_DIR}/installer/FuwaDesktopShortcut.iss"
)
set(CPACK_INNOSETUP_SETUP_AppId "app.yuxino.fuwa.windows")
set(CPACK_INNOSETUP_SETUP_AppMutex "Local\\app.yuxino.fuwa.windows")
set(CPACK_INNOSETUP_SETUP_CloseApplications ON)
set(CPACK_INNOSETUP_SETUP_PrivilegesRequired "lowest")
set(CPACK_INNOSETUP_SETUP_RestartApplications ON)
set(CPACK_INNOSETUP_SETUP_UninstallDisplayIcon "{app}\\Fuwa.exe")

include(CPack)
