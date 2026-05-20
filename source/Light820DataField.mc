import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class Light820DataField extends WatchUi.DataField {
    private var _lightNetwork;
    private var _ui;
    private var _inputSummary = "";

    public function initialize() {
        DataField.initialize();
        _lightNetwork = new Light820LightNetwork();
        _ui = new Light820Ui();
    }

    public function onShow() as Void {
        _lightNetwork.show();
        _lightNetwork.refresh("show");
    }

    public function onHide() as Void {
        _lightNetwork.hide();
    }

    public function compute(info as Activity.Info) as Void {
        _lightNetwork.poll();
    }

    public function onTap(clickEvent as WatchUi.ClickEvent) as Lang.Boolean {
        return handleTap(clickEvent);
    }

    public function handleTap(clickEvent as WatchUi.ClickEvent) as Lang.Boolean {
        try {
            var coordinates = clickEvent.getCoordinates();
            if (coordinates == null || coordinates.size() < 2) {
                _inputSummary = "tap ?";
                requestUpdateSafely();
                return false;
            }

            var action = _ui.findAction(coordinates[0], coordinates[1]);
            if (action == null) {
                _inputSummary = "tap " + coordinates[0] + "," + coordinates[1] + " none";
                requestUpdateSafely();
                return false;
            }

            _inputSummary = "tap " + coordinates[0] + "," + coordinates[1] + " " + actionLabel(action);
            runAction(action);
            requestUpdateSafely();
            return true;
        } catch (e) {
            _inputSummary = "tap error";
            requestUpdateSafely();
            return false;
        }
    }

    public function handleSelect() as Lang.Boolean {
        try {
            _lightNetwork.refresh("select");
            requestUpdateSafely();
            return true;
        } catch (e) {
            _inputSummary = "select error";
            requestUpdateSafely();
            return false;
        }
    }

    public function onUpdate(dc as Dc) as Void {
        var state = _lightNetwork.getUiState();
        state["inputSummary"] = _inputSummary;
        state["backgroundColor"] = getBackgroundColor();
        _ui.draw(dc, state);
    }

    private function runAction(action as Dictionary) as Void {
        var kind = action["kind"];

        if (actionKindEquals(kind, Light820Modes.ACTION_REFRESH)) {
            _lightNetwork.refresh("manual");
            return;
        }

        if (actionKindEquals(kind, Light820Modes.ACTION_MODE)) {
            _lightNetwork.sendPrimaryMode(action["mode"], action["label"]);
        }
    }

    private function actionLabel(action as Dictionary) as String {
        var kind = action["kind"];
        if (actionKindEquals(kind, Light820Modes.ACTION_REFRESH)) {
            return "Refresh";
        }
        if (actionKindEquals(kind, Light820Modes.ACTION_MODE)) {
            return action["label"].toString();
        }
        return kind.toString();
    }

    private function actionKindEquals(kind, expected as String) as Boolean {
        return Light820Modes.actionEquals(kind, expected);
    }

    private function requestUpdateSafely() as Void {
        try {
            WatchUi.requestUpdate();
        } catch (e) {
        }
    }
}
