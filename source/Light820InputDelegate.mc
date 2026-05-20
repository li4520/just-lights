import Toybox.Lang;
import Toybox.WatchUi;

class Light820InputDelegate extends WatchUi.BehaviorDelegate {
    private var _dataField;

    public function initialize(dataField as Light820DataField) {
        BehaviorDelegate.initialize();
        _dataField = dataField;
    }

    public function onTap(clickEvent as WatchUi.ClickEvent) as Lang.Boolean {
        return _dataField.handleTap(clickEvent);
    }

    public function onSelect() as Lang.Boolean {
        return _dataField.handleSelect();
    }
}
