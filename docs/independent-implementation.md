# Independent Implementation Statement

Fuwa is an original, independently implemented macOS and Windows application distributed under the MIT License.

## Implementation sources

Fuwa's implementation is based on:

- Apple's public macOS frameworks and documentation, including ScreenCaptureKit, AppKit, Core Graphics, and Accessibility;
- Microsoft's public Win32 and Desktop Window Manager APIs and documentation;
- original product design, architecture, source code, tests, copy, and visual assets created for this repository;
- behavior observed through ordinary use of macOS and the project's own test fixtures.

Fuwa does not use private WindowServer, DWM, or Virtual Desktop APIs, copy code from another application, inject code into other processes, or require changes to operating-system security.

## Relationship to Topit

Topit was considered only as a product-research reference for the broad user need of keeping window content visible. Topit is AGPL-licensed. No Topit source code has been copied, translated, adapted, linked, or incorporated into Fuwa. Fuwa also does not copy Topit's assets, text, tests, file structure, or non-public implementation details.

The projects have different implementation boundaries: Fuwa uses public ScreenCaptureKit APIs for macOS mirror panels and public DWM thumbnail APIs for its Windows mirror window. Source-reveal actions use public platform activation APIs; they do not inject input or modify the source window's actual level.

Topit and its authors do not sponsor, endorse, or participate in Fuwa.

## Contributor requirements

Contributors must submit work they have the right to license under MIT. Do not consult and reproduce AGPL-covered implementation details for a Fuwa change, and do not paste third-party source, assets, copy, or tests into issues or pull requests. A contribution inspired by general product behavior must be implemented from public API documentation, independently written specifications, and original tests.

If provenance is uncertain, stop and discuss it with the maintainers before submitting the change.

---

## 独立实现说明

Fuwa 是一款原创、独立实现并以 MIT 许可证发布的 macOS 与 Windows 应用。其代码依据 Apple 与 Microsoft 公开 API 和文档、项目原创设计和测试编写。

Topit 仅用于了解“让窗口内容保持可见”这一通用产品需求。Topit 采用 AGPL 许可证；Fuwa 未复制、翻译、改写、链接或合并 Topit 的源码，也未复制其资产、文案、测试、文件结构或非公开实现细节。贡献者同样不得将这些内容带入 Fuwa。

Fuwa 在 macOS 通过公开 ScreenCaptureKit API 创建自有镜像面板，在 Windows 通过公开 DWM thumbnail API 创建自有镜像窗口；显示源窗口的操作只调用公开的平台激活 API，不注入输入，也不改变源窗口的真实层级。Topit 及其作者不赞助、背书或参与 Fuwa。
