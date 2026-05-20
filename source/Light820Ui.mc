import Toybox.Graphics;
import Toybox.Lang;

class Light820Ui {
    private const MIN_PADDING = 8;
    private const MIN_GAP = 4;
    private const SYSTEM_OVERLAY_RESERVED = 60;
    private const ACTIVE_ACCENT_WIDTH = 6;
    private const CHROME_BG = Graphics.COLOR_BLACK;
    private const CHROME_FG = Graphics.COLOR_WHITE;
    private const CHROME_DIM = Graphics.COLOR_LT_GRAY;
    private const SHOW_STATUS_DEBUG = false;
    private const SHOW_COMMAND_DEBUG = false;
    private const BRAND_TEXT = "windblows.cc";

    private var _hitZones = [];
    private var _lastWidth;
    private var _lastHeight;

    public function initialize() {
    }

    public function draw(dc as Dc, state as Dictionary) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var layout = buildControlLayout(width, height);
        var theme = resolveTheme(state);

        _lastWidth = width;
        _lastHeight = height;
        prepareHitZonesForLayout(layout, state);

        dc.setColor(theme["fg"], theme["bg"]);
        dc.clear();

        drawHeader(dc, layout, theme, state);
        drawModeRows(dc, layout, theme, state);
        drawFooterBattery(dc, layout, theme, state["primaryBattery"]);
    }

    public function prepareHitZones(width as Number, height as Number, state as Dictionary) as Void {
        prepareHitZonesForLayout(buildControlLayout(width, height), state);
    }

    private function prepareHitZonesForLayout(layout as Dictionary, state as Dictionary) as Void {
        _hitZones = [];

        var standards = Light820Modes.standardModes();
        var modes = state["modes"];

        var offRect = splitRowLeftRect(layout);
        var refreshRect = splitRowRightRect(layout);

        if (isModeEnabled(modes, standards[0]["mode"])) {
            addHitZone(offRect["x"], offRect["y"], offRect["w"], offRect["h"], {
                "kind" => Light820Modes.ACTION_MODE,
                "mode" => standards[0]["mode"],
                "label" => standards[0]["label"]
            });
        }

        addHitZone(refreshRect["x"], refreshRect["y"], refreshRect["w"], refreshRect["h"], {
            "kind" => Light820Modes.ACTION_REFRESH
        });

        for (var i = 1; i < standards.size(); i++) {
            if (!isModeEnabled(modes, standards[i]["mode"])) {
                continue;
            }

            var rect = modeRowRect(layout, i);
            addHitZone(rect["x"], rect["y"], rect["w"], rect["h"], {
                "kind" => Light820Modes.ACTION_MODE,
                "mode" => standards[i]["mode"],
                "label" => standards[i]["label"]
            });
        }
    }

    public function findAction(x as Number, y as Number) {
        for (var i = _hitZones.size() - 1; i >= 0; i--) {
            var zone = _hitZones[i];
            if (
                x >= zone["x"] &&
                x < (zone["x"] + zone["w"]) &&
                y >= zone["y"] &&
                y < (zone["y"] + zone["h"])
            ) {
                return zone["action"];
            }
        }

        return null;
    }

    public function getHitZoneCount() as Number {
        return _hitZones.size();
    }

    public function getHitZone(index as Number) {
        if (index < 0 || index >= _hitZones.size()) {
            return null;
        }
        return _hitZones[index];
    }

    private function drawHeader(dc as Dc, layout as Dictionary, theme as Dictionary, state as Dictionary) as Void {
        var pad = layout["pad"];
        var width = layout["width"];
        var headerHeight = layout["headerHeight"];

        dc.setColor(CHROME_BG, CHROME_BG);
        dc.fillRectangle(0, 0, width, headerHeight);
        dc.setColor(CHROME_FG, CHROME_BG);
        dc.drawText(pad, 1, headerFont(headerHeight), "Just Lights", Graphics.TEXT_JUSTIFY_LEFT);

        if (SHOW_STATUS_DEBUG && headerHeight >= 28) {
            var status = compactStatusLine(state);
            dc.setColor(CHROME_DIM, CHROME_BG);
            dc.drawText(debugRight(layout), 12, debugFont(), truncate(status, resolveDebugTextLimit(layout)), Graphics.TEXT_JUSTIFY_RIGHT);
        }

        if (SHOW_COMMAND_DEBUG && headerHeight >= 40) {
            var command = compactCommandLine(state);
            if (command != "") {
                dc.setColor(CHROME_DIM, CHROME_BG);
                dc.drawText(debugRight(layout), 24, debugFont(), truncate(command, resolveDebugTextLimit(layout)), Graphics.TEXT_JUSTIFY_RIGHT);
            }
        }

    }

    private function drawModeRows(dc as Dc, layout as Dictionary, theme as Dictionary, state as Dictionary) as Void {
        var standards = Light820Modes.standardModes();
        var modes = state["modes"];
        var currentMode = state["currentMode"];
        var offEnabled = isModeEnabled(modes, standards[0]["mode"]);

        drawButton(
            dc,
            splitRowLeftRect(layout),
            theme,
            safeString(standards[0]["label"]),
            buttonDetail(standards[0], offEnabled),
            offEnabled,
            offEnabled && currentMode != null && standards[0]["mode"] == currentMode
        );

        drawButton(
            dc,
            splitRowRightRect(layout),
            theme,
            "Refresh",
            null,
            true,
            false
        );

        for (var i = 1; i < standards.size(); i++) {
            var enabled = isModeEnabled(modes, standards[i]["mode"]);
            drawButton(
                dc,
                modeRowRect(layout, i),
                theme,
                safeString(standards[i]["label"]),
                buttonDetail(standards[i], enabled),
                enabled,
                enabled && currentMode != null && standards[i]["mode"] == currentMode
            );
        }
    }

    private function drawButton(dc as Dc, rect as Dictionary, theme as Dictionary, label as String, detail, enabled as Boolean, active as Boolean) as Void {
        var x = rect["x"];
        var y = rect["y"];
        var w = rect["w"];
        var h = rect["h"];
        var fill = active ? theme["fg"] : theme["bg"];
        var text = active ? theme["bg"] : theme["fg"];
        var border = enabled ? theme["fg"] : theme["dim"];

        if (!enabled) {
            text = theme["dim"];
        }

        dc.setColor(fill, fill);
        dc.fillRectangle(x, y, w, h);
        dc.setColor(border, fill);
        dc.drawRectangle(x, y, w, h);

        if (active) {
            dc.setColor(Graphics.COLOR_YELLOW, fill);
            dc.fillRectangle(x, y, ACTIVE_ACCENT_WIDTH, h);
            dc.fillRectangle(x + w - ACTIVE_ACCENT_WIDTH, y, ACTIVE_ACCENT_WIDTH, h);
        }

        dc.setColor(text, fill);
        dc.drawText(
            x + (w / 2),
            y + buttonLabelOffset(h, detail),
            buttonFont(h),
            truncate(label, resolveButtonTextLimit(w)),
            Graphics.TEXT_JUSTIFY_CENTER
        );

        if (detail != null && detail != "") {
            dc.setColor(active ? theme["bg"] : theme["dim"], fill);
            dc.drawText(x + (w / 2), y + detailOffset(h), Graphics.FONT_XTINY, truncate(detail.toString(), resolveButtonTextLimit(w)), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function drawFooterBattery(dc as Dc, layout as Dictionary, theme as Dictionary, battery) as Void {
        var level = 0;
        var severity = "unknown";

        if (battery instanceof Dictionary) {
            level = battery["level"];
            severity = safeString(battery["severity"]);
        }

        var width = layout["width"];
        var footerTop = layout["footerTop"];
        var footerHeight = layout["footerHeight"];
        var batteryWidth = width / 9;
        if (batteryWidth < 44) {
            batteryWidth = 44;
        }
        if (batteryWidth > 64) {
            batteryWidth = 64;
        }

        var batteryHeight = footerHeight - 12;
        if (batteryHeight > 22) {
            batteryHeight = 22;
        }
        if (batteryHeight < 12) {
            batteryHeight = 12;
        }

        var x = (width - batteryWidth) / 2;
        var y = footerTop + ((footerHeight - batteryHeight) / 2);
        var outlineColor = CHROME_FG;
        var fillColor = CHROME_FG;

        if (severity == "warn") {
            fillColor = Graphics.COLOR_YELLOW;
        } else if (severity == "critical") {
            fillColor = Graphics.COLOR_RED;
        } else if (severity == "unknown") {
            outlineColor = CHROME_DIM;
            fillColor = CHROME_DIM;
        }

        dc.setColor(CHROME_BG, CHROME_BG);
        dc.fillRectangle(0, footerTop, width, footerHeight);
        dc.setColor(CHROME_DIM, CHROME_BG);
        dc.drawText(layout["pad"], footerTop + footerTextOffset(footerHeight), Graphics.FONT_XTINY, BRAND_TEXT, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(outlineColor, CHROME_BG);
        dc.drawRectangle(x, y, batteryWidth - 5, batteryHeight);
        dc.fillRectangle(x + batteryWidth - 5, y + (batteryHeight / 3), 4, batteryHeight / 3);

        if (level > 0) {
            var segmentGap = 2;
            var innerX = x + 3;
            var innerY = y + 3;
            var innerHeight = batteryHeight - 6;
            var segmentWidth = ((batteryWidth - 11) - (3 * segmentGap)) / 4;

            dc.setColor(fillColor, CHROME_BG);
            for (var i = 0; i < level && i < 4; i++) {
                dc.fillRectangle(innerX + (i * (segmentWidth + segmentGap)), innerY, segmentWidth, innerHeight);
            }
        }
    }

    private function addHitZone(x as Number, y as Number, w as Number, h as Number, action as Dictionary) as Void {
        _hitZones.add({
            "x" => x,
            "y" => y,
            "w" => w,
            "h" => h,
            "action" => action
        });
    }

    private function buildControlLayout(width as Number, height as Number) as Dictionary {
        var pad = width / 40;
        if (pad < MIN_PADDING) {
            pad = MIN_PADDING;
        }

        var gap = height / 100;
        if (gap < MIN_GAP) {
            gap = MIN_GAP;
        }
        if (gap > 8) {
            gap = 8;
        }

        var headerHeight = height / 20;
        if (headerHeight < 28) {
            headerHeight = 28;
        }
        if (headerHeight > 32) {
            headerHeight = 32;
        }

        var footerHeight = height / 24;
        if (footerHeight < 22) {
            footerHeight = 22;
        }
        if (footerHeight > 30) {
            footerHeight = 30;
        }

        var modesTop = headerHeight + gap;
        var footerTop = height - footerHeight;
        var modesHeight = footerTop - modesTop - gap;
        var rowHeight = (modesHeight - (4 * gap)) / 5;

        if (rowHeight < 44) {
            rowHeight = 44;
            headerHeight = 28;
            footerHeight = 24;
            gap = MIN_GAP;
            modesTop = headerHeight + gap;
            footerTop = height - footerHeight;
            modesHeight = footerTop - modesTop - gap;
            rowHeight = (modesHeight - (4 * gap)) / 5;
        }

        return {
            "width" => width,
            "height" => height,
            "pad" => pad,
            "gap" => gap,
            "headerHeight" => headerHeight,
            "modesTop" => modesTop,
            "rowHeight" => rowHeight,
            "footerTop" => footerTop,
            "footerHeight" => footerHeight
        };
    }

    private function splitRowLeftRect(layout as Dictionary) as Dictionary {
        var pad = layout["pad"];
        var gap = layout["gap"];
        var w = (layout["width"] - (2 * pad) - gap) / 2;
        return {
            "x" => pad,
            "y" => layout["modesTop"],
            "w" => w,
            "h" => layout["rowHeight"]
        };
    }

    private function splitRowRightRect(layout as Dictionary) as Dictionary {
        var left = splitRowLeftRect(layout);
        return {
            "x" => left["x"] + left["w"] + layout["gap"],
            "y" => left["y"],
            "w" => left["w"],
            "h" => left["h"]
        };
    }

    private function modeRowRect(layout as Dictionary, rowIndex as Number) as Dictionary {
        var pad = layout["pad"];
        return {
            "x" => pad,
            "y" => layout["modesTop"] + (rowIndex * (layout["rowHeight"] + layout["gap"])),
            "w" => layout["width"] - (2 * pad),
            "h" => layout["rowHeight"]
        };
    }

    private function isModeEnabled(modes, mode) as Boolean {
        if (!(modes instanceof Array)) {
            return false;
        }

        for (var i = 0; i < modes.size(); i++) {
            if (modes[i]["mode"] == mode) {
                return true;
            }
        }

        return false;
    }

    private function buttonDetail(modeSpec as Dictionary, enabled as Boolean) as String {
        if (!enabled) {
            return "unavailable";
        }
        return safeString(modeSpec["detail"]);
    }

    private function resolveTheme(state as Dictionary) as Dictionary {
        var bg = state["backgroundColor"];
        if (bg == null) {
            bg = Graphics.COLOR_WHITE;
        }

        var fg = Graphics.COLOR_BLACK;
        var dim = Graphics.COLOR_DK_GRAY;
        if (bg == Graphics.COLOR_BLACK) {
            fg = Graphics.COLOR_WHITE;
            dim = Graphics.COLOR_LT_GRAY;
        }

        return {
            "bg" => bg,
            "fg" => fg,
            "dim" => dim
        };
    }

    private function compactStatusLine(state as Dictionary) as String {
        var status = safeString(state["networkStatus"]);
        var detail = safeString(state["networkDetail"]);
        var result = status;
        var compactDetail = compactNetworkDetail(detail);

        if (compactDetail != "") {
            result += " | " + compactDetail;
        }

        return result;
    }

    private function compactCommandLine(state as Dictionary) as String {
        var input = safeString(state["inputSummary"]);
        var command = safeString(state["commandStatus"]);

        if (input != "" && command != "") {
            return input + " | " + command;
        }
        if (input != "") {
            return input;
        }
        return command;
    }

    private function headerFont(headerHeight as Number) {
        return Graphics.FONT_SMALL;
    }

    private function debugFont() {
        return Graphics.FONT_XTINY;
    }

    private function debugRight(layout as Dictionary) as Number {
        return layout["width"] - SYSTEM_OVERLAY_RESERVED - layout["pad"];
    }

    private function buttonFont(height as Number) {
        if (height >= 82) {
            return Graphics.FONT_LARGE;
        }
        if (height < 52) {
            return Graphics.FONT_SMALL;
        }
        return Graphics.FONT_MEDIUM;
    }

    private function buttonLabelOffset(height as Number, detail) as Number {
        if (height >= 82) {
            return (height / 2) - 26;
        }
        if (detail != null && detail != "" && height >= 48) {
            return (height / 2) - 20;
        }
        if (height < 52) {
            return (height / 2) - 10;
        }
        return (height / 2) - 14;
    }

    private function detailOffset(height as Number) as Number {
        if (height >= 82) {
            return height - 24;
        }
        if (height < 52) {
            return height - 17;
        }
        return height - 22;
    }

    private function footerTextOffset(height as Number) as Number {
        if (height < 24) {
            return 1;
        }
        return (height / 2) - 7;
    }

    private function compactNetworkDetail(detail as String) as String {
        var result = detail;
        if (result.find("mode ") == 0) {
            result = result.substring(5, result.length());
        }
        result = replaceText(result, "; lights 1", " | 1 light");
        result = replaceText(result, "; lights ", " | ");
        result = appendLightsLabel(result);
        return result;
    }

    private function replaceText(value as String, needle as String, replacement as String) as String {
        var index = value.find(needle);
        if (index == null) {
            return value;
        }
        return value.substring(0, index) + replacement + value.substring(index + needle.length(), value.length());
    }

    private function appendLightsLabel(value as String) as String {
        var separator = value.find(" | ");
        if (separator == null) {
            return value;
        }

        var afterSeparator = value.substring(separator + 3, value.length());
        if (afterSeparator.find(" light") != null) {
            return value;
        }

        return value + " lights";
    }

    private function resolveDebugTextLimit(layout as Dictionary) as Number {
        var titleReserve = 112;
        if (layout["width"] < 300) {
            titleReserve = 78;
        }

        var usableWidth = layout["width"] - titleReserve - SYSTEM_OVERLAY_RESERVED - layout["pad"];
        var limit = usableWidth / 7;
        if (limit < 12) {
            return 12;
        }
        return limit;
    }

    private function resolveButtonTextLimit(width as Number) as Number {
        var limit = width / 7;
        if (limit < 8) {
            return 8;
        }
        return limit;
    }

    private function safeString(value) as String {
        if (value == null) {
            return "";
        }
        return value.toString();
    }

    private function truncate(value as String, maxLength as Number) as String {
        if (value.length() <= maxLength) {
            return value;
        }
        if (maxLength <= 1) {
            return value.substring(0, maxLength);
        }
        return value.substring(0, maxLength - 1) + "~";
    }
}
