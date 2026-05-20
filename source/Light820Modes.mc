import Toybox.AntPlus;
import Toybox.Lang;

module Light820Modes {
    const ACTION_MODE = "mode";
    const ACTION_REFRESH = "refresh";
    const PROFILE_CHECKING = "checking";
    const PROFILE_COMPATIBLE_TAILLIGHT = "compatible_taillight";
    const PROFILE_UNSUPPORTED = "unsupported";
    const PROFILE_UNKNOWN = "unknown";
    // Cached containers are app-local read-only values. Do not mutate returned mode or battery dictionaries.
    var _standardModesCache = null;
    var _batteryNew = null;
    var _batteryGood = null;
    var _batteryOk = null;
    var _batteryLow = null;
    var _batteryCritical = null;
    var _batteryUnknown = null;

    // Returns a shared read-only mode catalog to avoid per-frame draw allocations.
    function standardModes() as Array<Dictionary> {
        if (_standardModesCache != null) {
            return _standardModesCache;
        }

        _standardModesCache = [
            modeSpec("off", "Off", "Light Off", AntPlus.LIGHT_MODE_OFF, "off"),
            modeSpec("solid", "Solid", "25 lm", AntPlus.LIGHT_MODE_ST_21_40, "steady"),
            modeSpec("peloton", "Peloton", "8 lm", AntPlus.LIGHT_MODE_ST_0_20, "steady"),
            modeSpec("night_flash", "Night Flash", "40 lm", AntPlus.LIGHT_MODE_SLOW_FLASH, "flash"),
            modeSpec("day_flash", "Day Flash", "100 lm", AntPlus.LIGHT_MODE_FAST_FLASH, "flash")
        ];
        return _standardModesCache;
    }

    function modeSpec(key as String, label as String, detail as String, mode, kind as String) as Dictionary {
        return {
            "key" => key,
            "label" => label,
            "detail" => detail,
            "mode" => mode,
            "kind" => kind
        };
    }

    function buildVisibleModes(capableModes) as Array<Dictionary> {
        var visible = [];
        var standards = standardModes();

        for (var i = 0; i < standards.size(); i++) {
            var standard = standards[i];
            if (supportsMode(capableModes, standard["mode"])) {
                visible.add(standard);
            }
        }

        addCustomModeIfSupported(visible, capableModes, AntPlus.LIGHT_MODE_CUSTOM_1, 1);
        addCustomModeIfSupported(visible, capableModes, AntPlus.LIGHT_MODE_CUSTOM_2, 2);
        addCustomModeIfSupported(visible, capableModes, AntPlus.LIGHT_MODE_CUSTOM_3, 3);
        addCustomModeIfSupported(visible, capableModes, AntPlus.LIGHT_MODE_CUSTOM_4, 4);
        addCustomModeIfSupported(visible, capableModes, AntPlus.LIGHT_MODE_CUSTOM_5, 5);

        return visible;
    }

    function classifyProfile(capableModes) as String {
        if (hasCompatibleTaillightCapabilities(capableModes)) {
            return PROFILE_COMPATIBLE_TAILLIGHT;
        }

        if (capableModes != null) {
            return PROFILE_UNSUPPORTED;
        }

        return PROFILE_UNKNOWN;
    }

    function isProfileCommandAllowed(profile) as Boolean {
        var normalizedProfile = valueToString(profile);
        if (normalizedProfile.equals(PROFILE_COMPATIBLE_TAILLIGHT)) {
            return true;
        }
        return false;
    }

    function actionEquals(kind, expected as String) as Boolean {
        return valueToString(kind).equals(expected);
    }

    function canUseSingleTaillightNetworkFallback(lightCount, primaryType, profile) as Boolean {
        if (!isProfileCommandAllowed(profile)) {
            return false;
        }
        if (lightCount != 1) {
            return false;
        }
        return primaryType == AntPlus.LIGHT_TYPE_TAILLIGHT;
    }

    function resolveListenerPrimaryMode(reportedMode, pendingMode, postCommandPollsRemaining as Number) {
        if (pendingMode != null && postCommandPollsRemaining > 0 && reportedMode != pendingMode) {
            return pendingMode;
        }

        return reportedMode;
    }

    function listenerGenerationMatches(observed as Number, current as Number) as Boolean {
        return observed == current;
    }

    function profileSummary(profile as String) as String {
        return profileLabel(profile);
    }

    function supportsMode(capableModes, mode) as Boolean {
        if (capableModes == null) {
            return false;
        }

        for (var i = 0; i < capableModes.size(); i++) {
            if (capableModes[i] == mode) {
                return true;
            }
        }

        return false;
    }

    function hasCompatibleTaillightCapabilities(capableModes) as Boolean {
        return supportsMode(capableModes, AntPlus.LIGHT_MODE_OFF) &&
            supportsMode(capableModes, AntPlus.LIGHT_MODE_ST_21_40) &&
            supportsMode(capableModes, AntPlus.LIGHT_MODE_ST_0_20) &&
            supportsMode(capableModes, AntPlus.LIGHT_MODE_SLOW_FLASH) &&
            supportsMode(capableModes, AntPlus.LIGHT_MODE_FAST_FLASH);
    }

    function labelForMode(mode) as String {
        if (mode == AntPlus.LIGHT_MODE_OFF) {
            return "Off";
        }
        if (mode == AntPlus.LIGHT_MODE_ST_21_40) {
            return "Solid";
        }
        if (mode == AntPlus.LIGHT_MODE_ST_0_20) {
            return "Peloton";
        }
        if (mode == AntPlus.LIGHT_MODE_SLOW_FLASH) {
            return "Night Flash";
        }
        if (mode == AntPlus.LIGHT_MODE_FAST_FLASH) {
            return "Day Flash";
        }

        var customIndex = customModeIndex(mode);
        if (customIndex != null) {
            return "Custom " + customIndex;
        }

        return "Mode " + valueToString(mode);
    }

    function customModeIndex(mode) {
        if (mode == AntPlus.LIGHT_MODE_CUSTOM_1) {
            return 1;
        }
        if (mode == AntPlus.LIGHT_MODE_CUSTOM_2) {
            return 2;
        }
        if (mode == AntPlus.LIGHT_MODE_CUSTOM_3) {
            return 3;
        }
        if (mode == AntPlus.LIGHT_MODE_CUSTOM_4) {
            return 4;
        }
        if (mode == AntPlus.LIGHT_MODE_CUSTOM_5) {
            return 5;
        }
        return null;
    }

    function batteryIndicator(status) as Dictionary {
        if (status == AntPlus.BATT_STATUS_NEW) {
            if (_batteryNew == null) {
                _batteryNew = batterySpec("New", 4, "normal");
            }
            return _batteryNew;
        }
        if (status == AntPlus.BATT_STATUS_GOOD) {
            if (_batteryGood == null) {
                _batteryGood = batterySpec("Good", 4, "normal");
            }
            return _batteryGood;
        }
        if (status == AntPlus.BATT_STATUS_OK) {
            if (_batteryOk == null) {
                _batteryOk = batterySpec("OK", 2, "normal");
            }
            return _batteryOk;
        }
        if (status == AntPlus.BATT_STATUS_LOW) {
            if (_batteryLow == null) {
                _batteryLow = batterySpec("Low", 1, "warn");
            }
            return _batteryLow;
        }
        if (status == AntPlus.BATT_STATUS_CRITICAL) {
            if (_batteryCritical == null) {
                _batteryCritical = batterySpec("Critical", 0, "critical");
            }
            return _batteryCritical;
        }
        if (_batteryUnknown == null) {
            _batteryUnknown = batterySpec("?", 0, "unknown");
        }
        return _batteryUnknown;
    }

    function addCustomModeIfSupported(visible as Array, capableModes, mode, index as Number) as Void {
        if (supportsMode(capableModes, mode)) {
            visible.add(modeSpec("custom_" + index, "Custom " + index, "", mode, "custom"));
        }
    }

    function batterySpec(label as String, level as Number, severity as String) as Dictionary {
        return {
            "label" => label,
            "level" => level,
            "severity" => severity
        };
    }

    function profileLabel(profile as String) as String {
        var normalizedProfile = valueToString(profile);
        if (normalizedProfile.equals(PROFILE_COMPATIBLE_TAILLIGHT)) {
            return "Light profile";
        }
        if (normalizedProfile.equals(PROFILE_UNSUPPORTED)) {
            return "Unsupported profile";
        }
        if (normalizedProfile.equals(PROFILE_CHECKING)) {
            return "Checking profile";
        }
        return "Unknown profile";
    }

    function valueToString(value) as String {
        if (value == null) {
            return "?";
        }
        return value.toString();
    }
}
