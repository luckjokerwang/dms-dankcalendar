import QtQuick
import Quickshell
import qs.Common
import qs.Services

QtObject {
    id: root

    // 通知模式偏好: "both" (双轨通知) | "native" (仅系统原生桌面通知) | "toast" (仅 DMS Toast 悬浮胶囊) | "none" (完全关闭)
    property string notificationMode: "both"

    /**
     * 发送系统通知核心方法
     * @param {string} summary - 通知主标题 (必填)
     * @param {string} body - 通知正文详细内容 (可选)
     * @param {string} icon - 图标名称 (可选，如 "calendar", "alarm", "dialog-information", "dialog-error")
     * @param {string} type - 消息等级 ("info" | "warning" | "error" | "success")
     */
    function notify(summary, body, icon, type) {
        var s = (summary || "").trim();
        var b = (body || "").trim();
        if (!s) return;

        var mode = (root.notificationMode || "both").toLowerCase().trim();
        if (mode === "none") return;

        var t = type || "info";
        var ic = icon;
        if (!ic || ic === "calendar" || ic === "dialog-information") {
            ic = "com.danklinux.dankcalendar";
        } else if (t === "error" && !icon) {
            ic = "dialog-error";
        } else if (t === "warning" && !icon) {
            ic = "dialog-warning";
        }

        // 1. DMS 前端高亮悬浮 Toast 胶囊 (屏幕前台滑出，支持 both 与 toast 模式)
        if (mode === "both" || mode === "toast") {
            if (typeof ToastService !== "undefined" && ToastService) {
                var toastMsg = s + (b ? ("\n" + b) : "");
                if (t === "error") {
                    if (typeof ToastService.showError === "function") ToastService.showError(toastMsg);
                } else if (t === "warning") {
                    if (typeof ToastService.showWarning === "function") ToastService.showWarning(toastMsg);
                } else {
                    if (typeof ToastService.showInfo === "function") ToastService.showInfo(toastMsg);
                }
            }
        }

        // 2. Linux 系统原生桌面通知 (沉淀写入通知中心历史，支持 both 与 native 模式)
        if (mode === "both" || mode === "native") {
            var cmd = [
                "sh", "-c",
                'ICON="$3"; ' +
                'if [ "$ICON" = "com.danklinux.dankcalendar" ] && [ -f "/usr/share/icons/hicolor/scalable/apps/com.danklinux.dankcalendar.svg" ]; then ' +
                '  ICON="/usr/share/icons/hicolor/scalable/apps/com.danklinux.dankcalendar.svg"; ' +
                'fi; ' +
                'if command -v dms >/dev/null 2>&1; then ' +
                '  dms notify "$1" "$2" --app "Dank Calendar" --icon "$ICON"; ' +
                'elif command -v notify-send >/dev/null 2>&1; then ' +
                '  notify-send -a "Dank Calendar" -i "$ICON" "$1" "$2"; ' +
                'fi',
                "sh", s, b, ic
            ];
            Quickshell.execDetached(cmd);
        }
    }

    /**
     * 发送测试通知，供设置界面与调试一键体验
     */
    function sendTestNotification() {
        var modeDesc = "双轨通知 (桌面通知 + Toast 胶囊)";
        var mode = (root.notificationMode || "both").toLowerCase().trim();
        if (mode === "native") {
            modeDesc = "仅系统原生桌面通知";
        } else if (mode === "toast") {
            modeDesc = "仅 DMS Toast 悬浮胶囊";
        } else if (mode === "none") {
            modeDesc = "完全关闭通知 (当前静音)";
        }

        if (mode === "none") {
            if (typeof ToastService !== "undefined" && typeof ToastService.showInfo === "function") {
                ToastService.showInfo("当前通知模式为「完全关闭」，系统不会发送任何通知。");
            }
            return;
        }

        notify(
            "🔔 Dank Calendar 通知测试",
            "当前模式: " + modeDesc + "\n您的系统原生桌面通知功能已就绪，通知将自动沉淀在通知中心！",
            "com.danklinux.dankcalendar",
            "info"
        );
    }
}
