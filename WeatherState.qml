pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Clima actual y previsión. Usa wttr.in, que detecta la ciudad por la conexión
// y no necesita clave de API. Si no hay red, el panel muestra el error y deja
// volver a intentarlo.
Singleton {
    id: root

    property bool loading: false
    property bool ready: false
    property string error: ""
    property string place: ""
    property string description: ""
    property string temp: "--"
    property string feels: "--"
    property string humidity: "--"
    property string wind: "--"
    property string currentIcon: "weather-none-available"
    property string updated: ""
    property var hours: []
    property var days: []

    readonly property var spanishDays: ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"]

    function refresh(): void {
        if (weatherProc.running)
            return;
        root.loading = true;
        root.error = "";
        weatherProc.running = true;
    }

    function iconFor(code): string {
        if (code === 113)
            return "weather-clear";
        if (code === 116)
            return "weather-few-clouds";
        if (code === 119 || code === 122)
            return "weather-clouds";
        if (code === 143 || code === 248 || code === 260)
            return "weather-fog";
        if (code === 200 || code === 386 || code === 389
            || code === 392 || code === 395)
            return "weather-storm";
        if (code === 179 || code === 182 || code === 185
            || code === 227 || code === 230 || code === 320
            || code === 323 || code === 326 || code === 329
            || code === 332 || code === 335 || code === 338
            || code === 368 || code === 371)
            return "weather-snow";
        if (code === 176 || code === 263 || code === 266
            || code === 281 || code === 284 || code === 293
            || code === 296 || code === 299 || code === 353)
            return "weather-showers";
        if (code === 302 || code === 305 || code === 308
            || code === 311 || code === 314 || code === 356
            || code === 359 || code === 362 || code === 365)
            return "weather-rain";
        return "weather-none-available";
    }

    function textOf(entry, fallback): string {
        if (entry && entry.lang_es && entry.lang_es.length > 0)
            return entry.lang_es[0].value;
        if (entry && entry.weatherDesc && entry.weatherDesc.length > 0)
            return entry.weatherDesc[0].value;
        return fallback;
    }

    function hourLabel(value, index): string {
        if (index === 0)
            return "Ahora";
        const hour = Math.floor(Number(value) / 100);
        return (hour < 10 ? "0" + hour : hour) + " h";
    }

    function dayLabel(value, index): string {
        if (index === 0)
            return "Hoy";
        const parts = String(value).split("-");
        if (parts.length !== 3)
            return "";
        const date = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
        return root.spanishDays[date.getDay()];
    }

    function parse(raw): void {
        let data = null;
        try {
            data = JSON.parse(raw);
        } catch (e) {
            data = null;
        }

        if (!data || !data.current_condition || data.current_condition.length === 0) {
            root.error = "No se pudo leer el clima.";
            root.loading = false;
            return;
        }

        const current = data.current_condition[0];
        const area = data.nearest_area && data.nearest_area.length > 0
            ? data.nearest_area[0] : null;
        const areaName = area && area.areaName && area.areaName.length > 0
            ? area.areaName[0].value : "";
        const region = area && area.region && area.region.length > 0
            ? area.region[0].value : "";

        root.place = areaName + (region.length > 0 && region !== areaName
            ? " · " + region : "");
        root.description = root.textOf(current, "Sin datos");
        root.temp = String(current.temp_C);
        root.feels = String(current.FeelsLikeC);
        root.humidity = String(current.humidity);
        root.wind = String(current.windspeedKmph);
        root.currentIcon = root.iconFor(Number(current.weatherCode));
        root.updated = current.observation_time ? String(current.observation_time) : "";

        const forecast = data.weather && data.weather.length > 0
            ? data.weather : [];
        const currentDay = forecast.length > 0 ? forecast[0] : null;

        if (currentDay && currentDay.hourly && currentDay.hourly.length > 0) {
            const source = currentDay.hourly.slice(0, 5);
            root.hours = source.map((hour, index) => ({
                label: root.hourLabel(hour.time, index),
                temp: String(hour.tempC),
                icon: root.iconFor(Number(hour.weatherCode))
            }));
        } else {
            root.hours = [];
        }

        root.days = forecast.map((day, index) => {
            const noon = day.hourly && day.hourly.length > 4
                ? day.hourly[4] : (day.hourly && day.hourly.length > 0
                    ? day.hourly[0] : null);
            return {
                label: root.dayLabel(day.date, index),
                icon: noon ? root.iconFor(Number(noon.weatherCode))
                    : "weather-none-available",
                max: String(day.maxtempC),
                min: String(day.mintempC)
            };
        });

        root.ready = true;
        root.error = "";
        root.loading = false;
    }

    // Primera consulta y actualización cada 30 minutos.
    Timer {
        interval: 300
        running: true
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        interval: 1800000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    // La ciudad manual manda; si está vacía, wttr.in deduce la ubicación por
    // IP. La URL se codifica para admitir espacios, tildes y comas.
    readonly property string requestUrl: {
        const place = String(SettingsState.weatherPlace || "").trim();
        const base = place.length > 0
            ? "https://wttr.in/" + encodeURIComponent(place)
            : "https://wttr.in/";
        return base + "?format=j1&lang=es";
    }

    Connections {
        target: SettingsState

        function onWeatherPlaceChanged(): void {
            root.refresh();
        }
    }

    Process {
        id: weatherProc

        command: ["curl", "-fsS", "--max-time", "15",
            "-H", "Accept-Language: es", root.requestUrl]

        stdout: StdioCollector {
            id: weatherOut
        }

        onExited: (code) => {
            const raw = weatherOut.text.trim();
            if (code !== 0 || raw.length === 0) {
                root.error = "Sin conexión con el servicio de clima.";
                root.loading = false;
                return;
            }
            root.parse(raw);
        }
    }
}
