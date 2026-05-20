import Toybox.AntPlus;
import Toybox.Lang;

class Light820LightNetworkListener extends AntPlus.LightNetworkListener {
    private var _owner;
    private var _generation;

    public function initialize(owner, generation as Number) {
        LightNetworkListener.initialize();
        _owner = owner;
        _generation = generation;
    }

    public function onLightNetworkStateUpdate(data) as Void {
        if (_owner != null) {
            _owner.handleNetworkStateUpdate(data, _generation);
        }
    }

    public function onBikeLightUpdate(data) as Void {
        if (_owner != null) {
            _owner.handleBikeLightUpdate(data, _generation);
        }
    }
}
