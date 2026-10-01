#pragma once

class QApplication;

// Giao diện thống nhất trên Windows và macOS: style Fusion + bảng màu sáng + stylesheet (QSS)
namespace Theme {
void apply(QApplication& app);

// Bảng màu dùng chung (đồng bộ với màu tiêu đề trong báo cáo)
inline constexpr const char* kPrimary = "#1F3864";
inline constexpr const char* kAccent = "#2E75B6";
inline constexpr const char* kMuted = "#64748B";
inline constexpr const char* kDanger = "#DC2626";
inline constexpr const char* kSuccess = "#16A34A";
} // namespace Theme
