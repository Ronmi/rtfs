// 溫度、風扇等感測器（sysfs hwmon），每 3 秒更新。
// 用 Process 執行一次 grep 讀出所有檔案，而不是用 FileView：要讀的檔案有幾十個，
// 而且 hwmonN 編號會變，得先列目錄找名稱，FileView 不能列目錄；grep 一次就拿到同一時間點的快照。
// 資料內容跟 niri 專案的 scripts/temp 一致（感測器都用 hwmon 的 name 找）。
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // 狀態列上 CPU Package 溫度的門檻（°C）。
    readonly property real barWarn: 80
    readonly property real barCrit: 90

    // 感測器物件：{ name, temp (°C), warn, crit }；warn/crit 為 0 表示沒有門檻。
    property var packageSensor: null
    property var cores: []          // [{ id, temp }]，依核心編號排序
    property int fanRpm: -1         // -1：沒有風扇資料
    property string fanMode: ""
    property var ecSensors: []
    property var deviceSensors: []  // AMD CCD、NVMe、記憶體、Wi-Fi
    property int freqMHz: 0
    property var load: []           // 1、5、15 分鐘
    property real powerDraw: NaN    // 用電池時的耗電（W），接電源時為 NaN

    // cros_ec 感測器標籤 → 顯示名稱
    readonly property var ecLabels: ({
        "cpu_f75303@4d": I18n.tr("CPU（EC）"),
        "peci-temp": I18n.tr("CPU（PECI）"),
        "top_skin_f75303@4d": I18n.tr("機身表面"),
        "local_f75303@4d": I18n.tr("主機板"),
        "battery_temp@b": I18n.tr("電池"),
        "charger_temp@9": I18n.tr("充電器")
    })

    // 0 normal / 1 warning / 2 critical
    function level(sensor) {
        if (!sensor)
            return 0;
        if (sensor.crit > 0 && sensor.temp >= sensor.crit)
            return 2;
        if (sensor.warn > 0 && sensor.temp >= sensor.warn)
            return 1;
        return 0;
    }

    function parse(text) {
        // 每行「路徑:值」，依所在目錄分組。
        const dirs = {};
        for (const line of text.split("\n")) {
            const i = line.indexOf(":");
            if (i < 0)
                continue;
            const path = line.slice(0, i);
            const slash = path.lastIndexOf("/");
            const dir = path.slice(0, slash);
            // Qt 6.8 的 JS 引擎不支援 ??=
            if (!dirs[dir])
                dirs[dir] = {};
            dirs[dir][path.slice(slash + 1)] = line.slice(i + 1);
        }

        const hwmon = pattern => {
            for (const dir in dirs) {
                if (dir.startsWith("/sys/class/hwmon/") && pattern.test(dirs[dir].name ?? ""))
                    return dirs[dir];
            }
            return null;
        };
        // 毫度 → 度；cros_ec 的 _max 是假的（-273150），<= 0 一律當作沒有門檻。
        const milli = v => v !== undefined && Number(v) > 0 ? Number(v) / 1000 : 0;
        const sensor = (h, n, name) => h[`temp${n}_input`] === undefined ? null : {
            name: name,
            temp: Number(h[`temp${n}_input`]) / 1000,
            warn: milli(h[`temp${n}_max`]),
            crit: milli(h[`temp${n}_crit`])
        };
        const tempIndexes = h => Object.keys(h).map(k => k.match(/^temp(\d+)_input$/)?.[1])
            .filter(n => n !== undefined).sort((a, b) => a - b);

        // CPU：Intel 用 coretemp（Package + 各核心）；AMD 用 k10temp 或 zenpower
        // （Tctl／Tdie 當 Package，沒有各核心溫度，Tccd 是每個 CCD 一個，放進其他裝置）。
        const devs = [];
        let pkg = null;
        const coreList = [];
        const core = hwmon(/^coretemp$/);
        const amd = core ? null : hwmon(/^(k10temp|zenpower)$/);
        if (core) {
            for (const n of tempIndexes(core)) {
                const label = core[`temp${n}_label`] ?? "";
                const temp = Number(core[`temp${n}_input`]) / 1000;
                if (label.startsWith("Package"))
                    pkg = { name: "Package", temp: temp, warn: barWarn, crit: barCrit };
                else if (label.startsWith("Core "))
                    coreList.push({ id: Number(label.slice(5)), temp: temp });
            }
        } else if (amd) {
            const byLabel = {};
            for (const n of tempIndexes(amd))
                byLabel[amd[`temp${n}_label`] ?? `temp${n}`] = Number(amd[`temp${n}_input`]) / 1000;
            // Tdie 是實際溫度；Tctl 在部份型號上有偏移，只在沒有 Tdie 時用。
            const t = byLabel.Tdie ?? byLabel.Tctl;
            if (t !== undefined)
                pkg = { name: "Package", temp: t, warn: barWarn, crit: barCrit };
            for (const label of Object.keys(byLabel).filter(l => /^Tccd\d+$/.test(l)).sort())
                devs.push({ name: "CPU " + label.replace("Tccd", "CCD "), temp: byLabel[label], warn: barWarn, crit: barCrit });
        }
        packageSensor = pkg;
        cores = coreList.sort((a, b) => a.id - b.id);

        // Framework EC：風扇與機身感測器
        const ec = hwmon(/^cros_ec$/);
        fanRpm = ec?.fan1_input !== undefined ? Number(ec.fan1_input) : -1;
        fanMode = ({ "0": I18n.tr("全速"), "1": I18n.tr("手動"), "2": I18n.tr("自動") })[ec?.pwm1_enable] ?? "";
        ecSensors = ec ? tempIndexes(ec).map(n => {
            const label = ec[`temp${n}_label`] ?? `temp${n}`;
            return sensor(ec, n, ecLabels[label] ?? label);
        }) : [];

        // 其他裝置
        const nvme = hwmon(/^nvme$/);
        if (nvme) {
            for (const n of tempIndexes(nvme)) {
                const label = nvme[`temp${n}_label`];
                devs.push(sensor(nvme, n, !label || label === "Composite" ? "NVMe" : "NVMe #" + label.replace("Sensor ", "")));
            }
        }
        const spd = hwmon(/^spd5118$/);
        if (spd?.temp1_input !== undefined)
            devs.push(sensor(spd, 1, I18n.tr("記憶體")));
        const wifi = hwmon(/^iwlwifi/);
        if (wifi?.temp1_input !== undefined)
            devs.push(sensor(wifi, 1, "Wi-Fi"));
        deviceSensors = devs;

        // 平均頻率（kHz → MHz）
        const freqs = Object.keys(dirs).filter(d => d.startsWith("/sys/devices/system/cpu/cpufreq/"))
            .map(d => Number(dirs[d].scaling_cur_freq)).filter(f => f > 0);
        freqMHz = freqs.length ? Math.round(freqs.reduce((a, b) => a + b, 0) / freqs.length / 1000) : 0;

        load = (dirs["/proc"]?.loadavg ?? "").split(" ").slice(0, 3);

        // 用電池時的耗電：所有系統電池（type Battery、scope 不是 Device，排除觸控筆、滑鼠這類）加總。
        // 有的電池回報 power_now（µW），有的回報 current_now（µA）× voltage_now（µV）。
        let watts = 0, discharging = false;
        for (const dir in dirs) {
            const b = dirs[dir];
            if (!dir.startsWith("/sys/class/power_supply/") || b.type !== "Battery" || b.scope === "Device")
                continue;
            if (b.status !== "Discharging")
                continue;
            discharging = true;
            watts += b.power_now !== undefined ? Number(b.power_now) / 1e6
                : Number(b.current_now) * Number(b.voltage_now) / 1e12;
        }
        powerDraw = discharging ? watts : NaN;
    }

    Process {
        id: reader
        command: ["sh", "-c", "grep -Hs . "
            + "/sys/class/hwmon/hwmon*/name /sys/class/hwmon/hwmon*/temp*_input "
            + "/sys/class/hwmon/hwmon*/temp*_label /sys/class/hwmon/hwmon*/temp*_max "
            + "/sys/class/hwmon/hwmon*/temp*_crit /sys/class/hwmon/hwmon*/fan1_input "
            + "/sys/class/hwmon/hwmon*/pwm1_enable "
            + "/sys/devices/system/cpu/cpufreq/policy*/scaling_cur_freq /proc/loadavg "
            + "/sys/class/power_supply/*/type /sys/class/power_supply/*/scope "
            + "/sys/class/power_supply/*/status /sys/class/power_supply/*/current_now "
            + "/sys/class/power_supply/*/voltage_now /sys/class/power_supply/*/power_now"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Timer {
        interval: Config.bar.interval.sensors * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: reader.running = true
    }
}
