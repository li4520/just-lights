import Toybox.Application;
import Toybox.Lang;

class Light820App extends Application.AppBase {
    public function initialize() {
        AppBase.initialize();
    }

    public function onStart(state as Dictionary?) as Void {
    }

    public function onStop(state as Dictionary?) as Void {
    }

    public function getInitialView() {
        var dataField = new $.Light820DataField();
        return [dataField, new $.Light820InputDelegate(dataField)];
    }
}
