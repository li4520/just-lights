import Toybox.AntPlus;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

class Light820LightNetwork {
    private const NORMAL_POLL_INTERVAL_SEC = 300;
    private const POST_COMMAND_POLL_COUNT = 2;
    private const POST_COMMAND_POLL_INTERVAL_SEC = 1;
    private const COMMAND_CACHE_INTERVAL_SEC = 2;

    private var _network;
    private var _status = "unavailable";
    private var _detail = "not initialized";
    private var _lastState;
    private var _lastMode;
    private var _lightCount;
    private var _primaryMode;
    private var _primarySummary = "primary: ?";
    private var _capabilitySummary = "modes: ?";
    private var _batterySummary = "battery: ?";
    private var _commandSummary = "Ready";
    private var _profileState = Light820Modes.PROFILE_CHECKING;
    private var _profileSummary = Light820Modes.profileSummary(Light820Modes.PROFILE_CHECKING);
    private var _supportedModes = [];
    private var _secondaryRows = [];
    private var _primaryBattery = Light820Modes.batteryIndicator(null);
    private var _postCommandPollsRemaining = 0;
    private var _nextPostCommandPollTs;
    private var _lastPollTs;
    private var _pendingCommandMode;
    private var _listener;
    private var _listenerGeneration = 0;
    private var _listenerDirty = false;
    private var _visible = true;

    public function initialize() {
    }

    public function refresh(reason as String) as Void {
        releaseNetwork();
        _lastPollTs = null;
        clearPostCommandPolls();
        _status = "refreshing";
        _detail = "refresh " + reason;
        _commandSummary = "Refreshing";
        pollNow();
    }

    public function show() as Void {
        _visible = true;
    }

    public function hide() as Void {
        _visible = false;
        releaseNetwork();
        _lastPollTs = null;
        clearPostCommandPolls();
        _status = "hidden";
        _detail = "hidden";
        _commandSummary = "Paused";
    }

    public function poll() as Void {
        if (!_visible) {
            return;
        }

        if (_listenerDirty) {
            _listenerDirty = false;
            requestUpdateSafely();
        }

        var nowTs = Time.now().value();
        if (isPostCommandPollDue(nowTs)) {
            consumePostCommandPoll(nowTs);
            pollNow();
            return;
        }

        if (_lastPollTs == null || (nowTs - _lastPollTs) >= NORMAL_POLL_INTERVAL_SEC) {
            pollNow();
        }
    }

    private function pollNow() as Void {
        if (!ensureNetwork()) {
            return;
        }

        try {
            _lastPollTs = Time.now().value();
            _lastState = _network.getNetworkState();
            _lastMode = _network.getNetworkMode();
            updateStatusForState(_lastState);
        } catch (e) {
            recordError("poll", e);
        }
    }

    public function getUiState() as Dictionary {
        return {
            "networkStatus" => _status,
            "networkDetail" => _detail,
            "currentMode" => _primaryMode,
            "modes" => _supportedModes,
            "primarySummary" => _primarySummary,
            "capabilitySummary" => _capabilitySummary,
            "batterySummary" => _batterySummary,
            "primaryBattery" => _primaryBattery,
            "profileState" => _profileState,
            "profileSummary" => _profileSummary,
            "secondaryRows" => _secondaryRows,
            "commandStatus" => _commandSummary,
            "lastRefresh" => _status
        };
    }

    public function sendPrimaryMode(mode, label) as Boolean {
        if (!isCommandNetworkReady()) {
            return false;
        }

        try {
            var lights = _network.getBikeLights();
            var primary = getPrimaryLightFromLights(lights);
            if (primary == null) {
                _commandSummary = "No primary light";
                return false;
            }

            if (!lightSupportsMode(primary, mode)) {
                _commandSummary = "Mode unsupported";
                return false;
            }

            if (!isPrimaryProfileCommandAllowed(primary)) {
                _commandSummary = "Unsupported profile";
                return false;
            }

            var primaryResult = sendDirectMode(primary, mode);
            var networkResult = sendNetworkModeIfAllowed(lights, primary, mode);

            if (!primaryResult["sent"] && !networkResult["sent"]) {
                _commandSummary = commandFailedSummary(primaryResult, networkResult);
                _detail = "command: " + commandFailureDetail(primaryResult, networkResult);
                return false;
            }

            _commandSummary = commandSentSummary(label, primaryResult, networkResult);
            _primaryMode = mode;
            schedulePostCommandPolls(mode);
            return true;
        } catch (e) {
            _commandSummary = "Command failed";
            _detail = "command: " + errorToString(e);
            return false;
        }
    }

    public function handleNetworkStateUpdate(state, generation as Number) as Void {
        if (!isCurrentListenerGeneration(generation) || _network == null) {
            return;
        }

        try {
            _lastState = state;
            _lastMode = readNetworkModeSafely();
            _lastPollTs = Time.now().value();
            updateStatusForState(_lastState);
            preservePendingListenerPrimaryMode();
            markListenerDirty();
        } catch (e) {
            recordError("listener state", e);
            markListenerDirty();
        }
    }

    public function handleBikeLightUpdate(light, generation as Number) as Void {
        if (!isCurrentListenerGeneration(generation) || _network == null) {
            return;
        }

        try {
            _lastMode = readNetworkModeSafely();
            var lights = _network.getBikeLights();
            if (lights != null) {
                _lastState = AntPlus.LIGHT_NETWORK_STATE_FORMED;
                _status = "formed";
                updateFormedDetailForLights(lights);
                _lastPollTs = Time.now().value();
                preservePendingListenerPrimaryMode();
            }
            markListenerDirty();
        } catch (e) {
            recordError("listener light", e);
            markListenerDirty();
        }
    }

    private function ensureNetwork() as Boolean {
        if (_network != null) {
            return true;
        }

        if (!(AntPlus has :LightNetwork)) {
            _status = "unavailable";
            _detail = "LightNetwork API missing";
            return false;
        }

        if (AntPlus has :LightNetworkListener) {
            try {
                var listener = new Light820LightNetworkListener(self, _listenerGeneration);
                _network = new AntPlus.LightNetwork(listener);
                _listener = listener;
                _status = "forming";
                _detail = "LightNetwork listener initialized";
                return true;
            } catch (e) {
                _network = null;
                _listener = null;
            }
        }

        try {
            _network = new AntPlus.LightNetwork(null);
            _listener = null;
            _status = "forming";
            _detail = "LightNetwork poll fallback";
            return true;
        } catch (e) {
            recordError("init", e);
            return false;
        }
    }

    private function updateStatusForState(state) as Void {
        _lightCount = null;
        resetSummaries();

        if (state == AntPlus.LIGHT_NETWORK_STATE_FORMED) {
            _status = "formed";
            updateFormedDetail();
        } else if (state == AntPlus.LIGHT_NETWORK_STATE_FORMING) {
            _status = "forming";
            _detail = "mode " + networkModeToString(_lastMode);
        } else if (state == AntPlus.LIGHT_NETWORK_STATE_NOT_FORMED) {
            _status = "unavailable";
            _detail = "network not formed";
        } else {
            _status = "unavailable";
            _detail = "unknown state " + valueToString(state);
        }
    }

    private function updateFormedDetail() as Void {
        try {
            var lights = _network.getBikeLights();
            if (lights != null) {
                updateFormedDetailForLights(lights);
            }
        } catch (e) {
            _status = "formed";
            _detail = "formed; light list error";
        }
    }

    private function updateFormedDetailForLights(lights) as Void {
        _lightCount = lights.size();
        updateLightSummaries(lights);
        _detail = "mode " + networkModeToString(_lastMode) + "; lights " + valueToString(_lightCount);
    }

    private function resetSummaries() as Void {
        _primarySummary = "primary: ?";
        _capabilitySummary = "modes: ?";
        _batterySummary = "battery: ?";
        _primaryMode = null;
        _supportedModes = [];
        _secondaryRows = [];
        _primaryBattery = Light820Modes.batteryIndicator(null);
        _profileState = Light820Modes.PROFILE_CHECKING;
        _profileSummary = Light820Modes.profileSummary(_profileState);
    }

    private function updateLightSummaries(lights) as Void {
        if (lights.size() == 0) {
            _primarySummary = "primary: none";
            _capabilitySummary = "modes: none";
            _batterySummary = "battery: none";
            return;
        }

        var primary = choosePrimaryLight(lights);
        if (primary == null) {
            _primarySummary = "primary: unreadable";
            _capabilitySummary = "modes: unreadable";
            _batterySummary = "battery: unreadable";
            return;
        }

        _primarySummary = lightSummary(primary);
        _capabilitySummary = capableModesSummary(primary);
        _batterySummary = batterySummary(primary);
        _primaryMode = readLightMode(primary);
        var capableModes = readCapableModes(primary);
        _profileState = Light820Modes.classifyProfile(capableModes);
        _profileSummary = Light820Modes.profileSummary(_profileState);
        _supportedModes = Light820Modes.isProfileCommandAllowed(_profileState) ? Light820Modes.buildVisibleModes(capableModes) : [];
        updateSecondaryRows(lights, primary);
    }

    private function updateSecondaryRows(lights, primary) as Void {
        _secondaryRows = [];

        for (var i = 0; i < lights.size(); i++) {
            var light = lights[i];
            if (light == null || light == primary) {
                continue;
            }

            _secondaryRows.add({
                "label" => lightTypeToString(readLightType(light)) + " " + valueToString(readIdentifier(light)),
                "detail" => lightModeToString(readLightMode(light))
            });
        }
    }

    private function choosePrimaryLight(lights) {
        var fallback = null;

        for (var i = 0; i < lights.size(); i++) {
            var light = lights[i];
            if (light == null) {
                continue;
            }

            if (fallback == null) {
                fallback = light;
            }

            if (readLightType(light) == AntPlus.LIGHT_TYPE_TAILLIGHT) {
                return light;
            }
        }

        return fallback;
    }

    private function getPrimaryLightFromLights(lights) {
        if (lights == null || lights.size() == 0) {
            return null;
        }

        return choosePrimaryLight(lights);
    }

    private function lightSummary(light) as String {
        var identifier = readIdentifier(light);
        var components = readNumComponents(light);
        var type = lightTypeToString(readLightType(light));
        var mode = lightModeToString(readLightMode(light));

        return "primary " + valueToString(identifier) + "/" + valueToString(components) + " " + type + " " + mode;
    }

    private function capableModesSummary(light) as String {
        var modes = readCapableModes(light);
        if (modes == null) {
            return "modes: unknown";
        }

        return "modes " + modes.size() + ": " + modeListToString(modes);
    }

    private function readCapableModes(light) {
        if (!(light has :getCapableModes)) {
            return null;
        }

        try {
            return light.getCapableModes();
        } catch (e) {
            return null;
        }
    }

    private function batterySummary(light) as String {
        try {
            var identifier = chooseBatteryIdentifier(light);
            var battery = _network.getBatteryStatus(identifier);
            if (battery == null) {
                _primaryBattery = Light820Modes.batteryIndicator(null);
                return "battery " + valueToString(identifier) + ": unknown";
            }

            var status = readBatteryStatus(battery);
            _primaryBattery = Light820Modes.batteryIndicator(status);

            return "battery " + valueToString(identifier) + ": " + batteryStatusToString(status);
        } catch (e) {
            _primaryBattery = Light820Modes.batteryIndicator(null);
            return "battery: " + errorToString(e);
        }
    }

    private function isCommandNetworkReady() as Boolean {
        if (!isPollFresh(COMMAND_CACHE_INTERVAL_SEC)) {
            refreshCommandNetworkState();
        }

        if (_network == null) {
            _commandSummary = "Pair light first";
            return false;
        }

        if (_lastState != AntPlus.LIGHT_NETWORK_STATE_FORMED) {
            _commandSummary = _status == "forming" ? "Network forming" : "Pair light first";
            return false;
        }

        return true;
    }

    private function refreshCommandNetworkState() as Void {
        if (!ensureNetwork()) {
            return;
        }

        try {
            _lastPollTs = Time.now().value();
            _lastState = _network.getNetworkState();
            _lastMode = _network.getNetworkMode();
            if (_lastState == AntPlus.LIGHT_NETWORK_STATE_FORMING) {
                _status = "forming";
                _detail = "mode " + networkModeToString(_lastMode);
            } else if (_lastState == AntPlus.LIGHT_NETWORK_STATE_NOT_FORMED) {
                _status = "unavailable";
                _detail = "network not formed";
            }
        } catch (e) {
            recordError("command poll", e);
        }
    }

    private function isPollFresh(maxAgeSec as Number) as Boolean {
        if (_lastPollTs == null) {
            return false;
        }

        return (Time.now().value() - _lastPollTs) <= maxAgeSec;
    }

    private function lightSupportsMode(light, mode) as Boolean {
        return Light820Modes.supportsMode(readCapableModes(light), mode);
    }

    private function isPrimaryProfileCommandAllowed(primary) as Boolean {
        var capableModes = readCapableModes(primary);
        var profile = Light820Modes.classifyProfile(capableModes);

        _profileState = profile;
        _profileSummary = Light820Modes.profileSummary(profile);

        return Light820Modes.isProfileCommandAllowed(profile);
    }

    private function sendDirectMode(primary, mode) as Dictionary {
        if (!(primary has :setMode)) {
            return commandResult(false, "direct missing");
        }

        try {
            primary.setMode(mode);
            return commandResult(true, null);
        } catch (e) {
            return commandResult(false, "direct " + errorToString(e));
        }
    }

    private function sendNetworkModeIfAllowed(lights, primary, mode) as Dictionary {
        if (!shouldUseNetworkFallback(lights, primary)) {
            return commandResult(false, "network skipped");
        }

        try {
            _network.setTaillightsMode(mode);
            return commandResult(true, null);
        } catch (e) {
            return commandResult(false, "network " + errorToString(e));
        }
    }

    private function commandResult(sent as Boolean, error) as Dictionary {
        return {
            "sent" => sent,
            "error" => error
        };
    }

    private function shouldUseNetworkFallback(lights, primary) as Boolean {
        if (!(_network has :setTaillightsMode)) {
            return false;
        }

        if (lights == null) {
            return false;
        }

        return Light820Modes.canUseSingleTaillightNetworkFallback(
            lights.size(),
            readLightType(primary),
            _profileState
        );
    }

    private function commandSentSummary(label, primaryResult as Dictionary, networkResult as Dictionary) as String {
        var sentPrimary = primaryResult["sent"];
        var sentNetwork = networkResult["sent"];

        if (sentPrimary && sentNetwork) {
            return "Sent " + label + " direct+net";
        }
        if (sentNetwork) {
            return "Sent " + label + " network";
        }
        return "Sent " + label;
    }

    private function commandFailedSummary(primaryResult as Dictionary, networkResult as Dictionary) as String {
        if (networkResult["error"] != "network skipped") {
            return "Command failed";
        }
        if (primaryResult["error"] == "direct missing") {
            return "Primary unavailable";
        }
        return "Direct failed";
    }

    private function commandFailureDetail(primaryResult as Dictionary, networkResult as Dictionary) as String {
        var primaryError = primaryResult["error"];
        var networkError = networkResult["error"];

        if (primaryError == null) {
            primaryError = "direct ?";
        }
        if (networkError == null) {
            networkError = "network ?";
        }

        return primaryError + "; " + networkError;
    }

    private function schedulePostCommandPolls(mode) as Void {
        _postCommandPollsRemaining = POST_COMMAND_POLL_COUNT;
        _nextPostCommandPollTs = Time.now().value() + POST_COMMAND_POLL_INTERVAL_SEC;
        _pendingCommandMode = mode;
    }

    private function clearPostCommandPolls() as Void {
        _postCommandPollsRemaining = 0;
        _nextPostCommandPollTs = null;
        _pendingCommandMode = null;
    }

    private function isPostCommandPollDue(nowTs as Number) as Boolean {
        return _postCommandPollsRemaining > 0 &&
            _nextPostCommandPollTs != null &&
            nowTs >= _nextPostCommandPollTs;
    }

    private function consumePostCommandPoll(nowTs as Number) as Void {
        _postCommandPollsRemaining--;
        if (_postCommandPollsRemaining > 0) {
            _nextPostCommandPollTs = nowTs + POST_COMMAND_POLL_INTERVAL_SEC;
        } else {
            _nextPostCommandPollTs = null;
            _pendingCommandMode = null;
        }
    }

    private function releaseNetwork() as Void {
        _network = null;
        _listener = null;
        _listenerGeneration++;
    }

    private function isCurrentListenerGeneration(generation as Number) as Boolean {
        return Light820Modes.listenerGenerationMatches(generation, _listenerGeneration);
    }

    private function readNetworkModeSafely() {
        try {
            return _network.getNetworkMode();
        } catch (e) {
            return null;
        }
    }

    private function preservePendingListenerPrimaryMode() as Void {
        _primaryMode = Light820Modes.resolveListenerPrimaryMode(
            _primaryMode,
            _pendingCommandMode,
            _postCommandPollsRemaining
        );
    }

    private function markListenerDirty() as Void {
        _listenerDirty = true;
        if (!_visible) {
            return;
        }

        requestUpdateSafely();
    }

    private function requestUpdateSafely() as Void {
        try {
            WatchUi.requestUpdate();
        } catch (e) {
        }
    }

    private function chooseBatteryIdentifier(light) {
        var identifier = readIdentifier(light);
        if (identifier != null) {
            return identifier;
        }

        try {
            var identifiers = _network.getComponentIdentifiers();
            if (identifiers != null && identifiers.size() > 0) {
                return identifiers[0];
            }
        } catch (e) {
        }

        return null;
    }

    private function modeListToString(modes) as String {
        var summary = "";
        var limit = modes.size();
        if (limit > 6) {
            limit = 6;
        }

        for (var i = 0; i < limit; i++) {
            if (i > 0) {
                summary += ",";
            }
            summary += lightModeToString(modes[i]);
        }

        if (modes.size() > limit) {
            summary += ",...";
        }

        return summary;
    }

    private function readIdentifier(light) {
        if (light != null && light has :identifier) {
            return light.identifier;
        }

        return null;
    }

    private function readNumComponents(light) {
        if (light != null && light has :numComponents) {
            return light.numComponents;
        }

        return null;
    }

    private function readLightType(light) {
        if (light != null && light has :type) {
            return light.type;
        }

        return null;
    }

    private function readLightMode(light) {
        if (light != null && light has :mode) {
            return light.mode;
        }

        return null;
    }

    private function readBatteryStatus(battery) {
        if (battery != null && battery has :batteryStatus) {
            return battery.batteryStatus;
        }

        return null;
    }

    private function networkModeToString(mode) as String {
        if (mode == AntPlus.LIGHT_NETWORK_MODE_AUTO) {
            return "auto";
        }
        if (mode == AntPlus.LIGHT_NETWORK_MODE_HIGH_VIS) {
            return "high-vis";
        }
        if (mode == AntPlus.LIGHT_NETWORK_MODE_INDIVIDUAL) {
            return "individual";
        }
        return valueToString(mode);
    }

    private function lightTypeToString(type) as String {
        if (type == AntPlus.LIGHT_TYPE_HEADLIGHT) {
            return "head";
        }
        if (type == AntPlus.LIGHT_TYPE_TAILLIGHT) {
            return "tail";
        }
        if (type == AntPlus.LIGHT_TYPE_SIGNAL_CONFIG) {
            return "signal-config";
        }
        if (type == AntPlus.LIGHT_TYPE_SIGNAL_LEFT) {
            return "signal-left";
        }
        if (type == AntPlus.LIGHT_TYPE_SIGNAL_RIGHT) {
            return "signal-right";
        }
        if (type == AntPlus.LIGHT_TYPE_OTHER) {
            return "other";
        }
        return valueToString(type);
    }

    private function lightModeToString(mode) as String {
        return Light820Modes.labelForMode(mode);
    }

    private function batteryStatusToString(status) as String {
        var indicator = Light820Modes.batteryIndicator(status);
        return indicator["label"];
    }

    private function recordError(area as String, error) as Void {
        _status = "error";
        _detail = area + ": " + errorToString(error);
    }

    private function errorToString(error) as String {
        if (error != null && error has :getErrorMessage) {
            var message = error.getErrorMessage();
            if (message != null) {
                return message.toString();
            }
        }
        if (error != null) {
            return error.toString();
        }
        return "unknown";
    }

    private function valueToString(value) as String {
        if (value == null) {
            return "?";
        }
        return value.toString();
    }
}
