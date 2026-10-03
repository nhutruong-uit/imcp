#pragma once

class QApplication;

// Same look on Windows and macOS: Fusion style + light palette + style sheet (QSS)
// The style sheet resources/styles/app.qss (a CSS-like file) styles widgets by object name (PageTitle,
// ErrorText, Sidebar...) and by property (variant=primary, card), which is why the pages set those names.
namespace Theme {
void apply(QApplication& app);

// Shared colors (matching the heading color of the report; app.qss repeats the main ones)
inline constexpr const char* kPrimary = "#1F3864";
inline constexpr const char* kAccent = "#2E75B6";
inline constexpr const char* kText = "#1E293B";
inline constexpr const char* kMuted = "#64748B";
inline constexpr const char* kBorder = "#E2E8F0";
// Icon colors: on light backgrounds, inside input fields, on the dark sidebar / primary buttons
inline constexpr const char* kIcon = "#334155";
inline constexpr const char* kIconMuted = "#94A3B8";
inline constexpr const char* kIconOnDark = "#FFFFFF";
inline constexpr const char* kIconSidebar = "#E2E8F0";
// Text colors of highlighted table cells (positive: passed/taught/active, negative: failed/cancelled/debt)
inline constexpr const char* kPositiveText = "#15803D";
inline constexpr const char* kNegativeText = "#DC2626";
} // namespace Theme
