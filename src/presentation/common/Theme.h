#pragma once

class QApplication;

// Same look on Windows and macOS: Fusion style + light palette + style sheet (QSS)
// The style sheet resources/styles/app.qss (a CSS-like file) styles widgets by object name (PageTitle,
// ErrorText, Sidebar...) and by property (variant=primary, card), which is why the pages set those names.
namespace Theme {
void apply(QApplication& app);

// Shared colors (matching the heading color of the report)
inline constexpr const char* kPrimary = "#1F3864";
inline constexpr const char* kAccent = "#2E75B6";
inline constexpr const char* kMuted = "#64748B";
inline constexpr const char* kDanger = "#DC2626";
inline constexpr const char* kSuccess = "#16A34A";
// Text colors of highlighted table cells (positive: passed/taught/active, negative: failed/cancelled/debt)
inline constexpr const char* kPositiveText = "#15803D";
inline constexpr const char* kNegativeText = "#DC2626";
} // namespace Theme
