// 電池狀態（UPower，D-Bus 即時更新）與顯示用的共用函式，給系統選單（SystemBlock、SystemPopup）用。
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    // 有電池的裝置（排除電源供應器；可拆電池要在槽內）。
    readonly property var devices: UPower.devices.values.filter(d =>
        d.ready && d.type !== UPowerDeviceType.LinePower
        && (d.type !== UPowerDeviceType.Battery || d.isPresent))
    readonly property var laptop: devices.find(d => d.isLaptopBattery) ?? null
    readonly property var peripherals: devices.filter(d => !d.isLaptopBattery)

    // 筆電不在充電時才有警示；充電中一律正常。
    readonly property string laptopLevel: laptop && !charging(laptop) ? level(laptop) : "normal"

    // UPowerDeviceType 數值 → Material Icons 圖示，沒列到的用電池圖示。
    readonly property var kindIcons: ({
        2: "",  // Battery → laptop
        5: "",  // Mouse → mouse
        6: "",  // Keyboard → keyboard
        8: "",  // Phone → phone_android
        10: "", // Tablet → tablet（觸控筆會回報成這個）
        12: "", // GamingInput → sports_esports
        13: "", // Pen → edit
        17: "", // Headset → headset
        18: "", // Speakers → speaker
        19: ""  // Headphones → headphones
    })
    readonly property string batteryIcon: ""  // battery_std
    readonly property string chargingIcon: "" // battery_charging_full
    readonly property string alertIcon: ""    // battery_alert

    function pct(d) { return Math.floor(d.percentage * 100); }

    function charging(d) {
        return d.state === UPowerDeviceState.Charging
            || d.state === UPowerDeviceState.FullyCharged
            || d.state === UPowerDeviceState.PendingCharge;
    }

    // normal / warning / critical
    function level(d) {
        // 周邊狀態 Unknown 且 0% 通常是沒連線、讀不到電量（例如閒置的觸控筆），不警示。
        if (!d.isLaptopBattery && d.state === UPowerDeviceState.Unknown && pct(d) === 0)
            return "normal";
        return pct(d) <= Config.bar.battery.critical ? "critical"
             : pct(d) <= Config.bar.battery.warning ? "warning" : "normal";
    }

    function stateName(d) {
        switch (d.state) {
        case UPowerDeviceState.Charging: return I18n.tr("充電中");
        case UPowerDeviceState.Discharging: return I18n.tr("使用電池");
        case UPowerDeviceState.Empty: return I18n.tr("沒電");
        case UPowerDeviceState.FullyCharged: return I18n.tr("已充飽");
        case UPowerDeviceState.PendingCharge: return I18n.tr("等待充電");
        case UPowerDeviceState.PendingDischarge: return I18n.tr("等待放電");
        default: return I18n.tr("狀態不明");
        }
    }

    function duration(seconds) {
        const h = Math.floor(seconds / 3600);
        const m = Math.floor(seconds % 3600 / 60);
        return h > 0 ? I18n.tr("%1 小時 %2 分", h, m) : I18n.tr("%1 分", m);
    }

    // 筆電的剩餘／充飽時間（UPower 估不出來時是空字串）。
    function timeText(d) {
        if (charging(d))
            return d.timeToFull > 0 ? I18n.tr("%1後充飽", root.duration(d.timeToFull)) : "";
        return d.timeToEmpty > 0 ? I18n.tr("剩 %1", root.duration(d.timeToEmpty)) : "";
    }
}
