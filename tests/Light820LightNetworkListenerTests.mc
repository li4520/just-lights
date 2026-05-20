import Toybox.AntPlus;
import Toybox.Lang;
import Toybox.Test;

class Light820FakeListenerOwner {
    var networkState;
    var networkGeneration;
    var lightData;
    var lightGeneration;

    public function handleNetworkStateUpdate(state, generation) as Void {
        networkState = state;
        networkGeneration = generation;
    }

    public function handleBikeLightUpdate(light, generation) as Void {
        lightData = light;
        lightGeneration = generation;
    }
}

module Light820LightNetworkListenerTests {
    (:test)
    function listener_forwardsNetworkAndLightCallbacksWithGeneration(logger as Logger) as Boolean {
        var owner = new Light820FakeListenerOwner();
        var listener = new Light820LightNetworkListener(owner, 42);

        listener.onLightNetworkStateUpdate(AntPlus.LIGHT_NETWORK_STATE_FORMED);
        listener.onBikeLightUpdate("updated-light");

        Test.assertEqual(AntPlus.LIGHT_NETWORK_STATE_FORMED, owner.networkState);
        Test.assertEqual(42, owner.networkGeneration);
        Test.assertEqual("updated-light", owner.lightData);
        Test.assertEqual(42, owner.lightGeneration);
        return true;
    }
}
