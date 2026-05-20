import Toybox.AntPlus;
import Toybox.Lang;
import Toybox.Test;

module Light820ModesTests {
    (:test)
    function standardCatalog_mapsCompatibleLightLabelsAndOrder(logger as Logger) as Boolean {
        var modes = Light820Modes.standardModes();

        Test.assertEqual(5, modes.size());
        Test.assertEqual("Off", modes[0]["label"]);
        Test.assertEqual("Light Off", modes[0]["detail"]);
        Test.assertEqual(AntPlus.LIGHT_MODE_OFF, modes[0]["mode"]);
        Test.assertEqual("Solid", modes[1]["label"]);
        Test.assertEqual(AntPlus.LIGHT_MODE_ST_21_40, modes[1]["mode"]);
        Test.assertEqual("Peloton", modes[2]["label"]);
        Test.assertEqual(AntPlus.LIGHT_MODE_ST_0_20, modes[2]["mode"]);
        Test.assertEqual("Night Flash", modes[3]["label"]);
        Test.assertEqual(AntPlus.LIGHT_MODE_SLOW_FLASH, modes[3]["mode"]);
        Test.assertEqual("Day Flash", modes[4]["label"]);
        Test.assertEqual(AntPlus.LIGHT_MODE_FAST_FLASH, modes[4]["mode"]);

        return true;
    }

    (:test)
    function fixedModeAndBatterySpecs_areSharedReadOnlyCaches(logger as Logger) as Boolean {
        Test.assert(Light820Modes.standardModes() == Light820Modes.standardModes());
        Test.assert(
            Light820Modes.batteryIndicator(AntPlus.BATT_STATUS_GOOD) ==
            Light820Modes.batteryIndicator(AntPlus.BATT_STATUS_GOOD)
        );
        Test.assert(
            Light820Modes.batteryIndicator(null) ==
            Light820Modes.batteryIndicator(AntPlus.BATT_STATUS_INVALID)
        );

        return true;
    }

    (:test)
    function visibleModes_filtersByCapabilitiesAndSupportsOnOffCollapse(logger as Logger) as Boolean {
        var full = Light820Modes.buildVisibleModes([
            AntPlus.LIGHT_MODE_OFF,
            AntPlus.LIGHT_MODE_ST_21_40,
            AntPlus.LIGHT_MODE_ST_0_20,
            AntPlus.LIGHT_MODE_SLOW_FLASH,
            AntPlus.LIGHT_MODE_FAST_FLASH
        ]);

        Test.assertEqual(5, full.size());
        Test.assertEqual("Off", full[0]["label"]);
        Test.assertEqual("Day Flash", full[4]["label"]);

        var limited = Light820Modes.buildVisibleModes([AntPlus.LIGHT_MODE_OFF]);
        Test.assertEqual(1, limited.size());
        Test.assertEqual("Off", limited[0]["label"]);

        var missing = Light820Modes.buildVisibleModes([
            AntPlus.LIGHT_MODE_OFF,
            AntPlus.LIGHT_MODE_FAST_FLASH
        ]);
        Test.assertEqual(2, missing.size());
        Test.assertEqual("Off", missing[0]["label"]);
        Test.assertEqual("Day Flash", missing[1]["label"]);

        Test.assertEqual(0, Light820Modes.buildVisibleModes(null).size());
        Test.assertEqual(0, Light820Modes.buildVisibleModes([]).size());
        return true;
    }

    (:test)
    function customModes_appearOnlyWhenAdvertised(logger as Logger) as Boolean {
        var none = Light820Modes.buildVisibleModes([AntPlus.LIGHT_MODE_OFF]);
        Test.assertEqual(1, none.size());

        var one = Light820Modes.buildVisibleModes([
            AntPlus.LIGHT_MODE_OFF,
            AntPlus.LIGHT_MODE_CUSTOM_1
        ]);
        Test.assertEqual(2, one.size());
        Test.assertEqual("Custom 1", one[1]["label"]);

        var many = Light820Modes.buildVisibleModes([
            AntPlus.LIGHT_MODE_CUSTOM_2,
            AntPlus.LIGHT_MODE_CUSTOM_5
        ]);
        Test.assertEqual(2, many.size());
        Test.assertEqual("Custom 2", many[0]["label"]);
        Test.assertEqual("Custom 5", many[1]["label"]);

        return true;
    }

    (:test)
    function batteryIndicators_useCoarseStatusOnly(logger as Logger) as Boolean {
        Test.assertEqual(4, Light820Modes.batteryIndicator(AntPlus.BATT_STATUS_NEW)["level"]);
        Test.assertEqual(4, Light820Modes.batteryIndicator(AntPlus.BATT_STATUS_GOOD)["level"]);
        Test.assertEqual(2, Light820Modes.batteryIndicator(AntPlus.BATT_STATUS_OK)["level"]);
        Test.assertEqual("warn", Light820Modes.batteryIndicator(AntPlus.BATT_STATUS_LOW)["severity"]);
        Test.assertEqual("critical", Light820Modes.batteryIndicator(AntPlus.BATT_STATUS_CRITICAL)["severity"]);
        Test.assertEqual("unknown", Light820Modes.batteryIndicator(AntPlus.BATT_STATUS_INVALID)["severity"]);
        Test.assertEqual("unknown", Light820Modes.batteryIndicator(null)["severity"]);
        return true;
    }

    (:test)
    function profileClassifier_usesCapabilityShapeOnly(logger as Logger) as Boolean {
        var compatibleLightModes = [
            AntPlus.LIGHT_MODE_OFF,
            AntPlus.LIGHT_MODE_ST_21_40,
            AntPlus.LIGHT_MODE_ST_0_20,
            AntPlus.LIGHT_MODE_SLOW_FLASH,
            AntPlus.LIGHT_MODE_FAST_FLASH
        ];
        var compatibleLightPlusCustomModes = [
            AntPlus.LIGHT_MODE_OFF,
            AntPlus.LIGHT_MODE_ST_21_40,
            AntPlus.LIGHT_MODE_ST_0_20,
            AntPlus.LIGHT_MODE_SLOW_FLASH,
            AntPlus.LIGHT_MODE_FAST_FLASH,
            AntPlus.LIGHT_MODE_CUSTOM_1
        ];

        Test.assertEqual(
            Light820Modes.PROFILE_COMPATIBLE_TAILLIGHT,
            Light820Modes.classifyProfile(compatibleLightModes)
        );
        Test.assertEqual(
            Light820Modes.PROFILE_COMPATIBLE_TAILLIGHT,
            Light820Modes.classifyProfile(compatibleLightPlusCustomModes)
        );
        Test.assert(Light820Modes.isProfileCommandAllowed(Light820Modes.PROFILE_COMPATIBLE_TAILLIGHT));

        Test.assertEqual(
            Light820Modes.PROFILE_UNSUPPORTED,
            Light820Modes.classifyProfile([AntPlus.LIGHT_MODE_OFF])
        );
        Test.assert(!Light820Modes.isProfileCommandAllowed(Light820Modes.PROFILE_UNSUPPORTED));

        Test.assertEqual(
            Light820Modes.PROFILE_UNKNOWN,
            Light820Modes.classifyProfile(null)
        );
        Test.assert(!Light820Modes.isProfileCommandAllowed(Light820Modes.PROFILE_UNKNOWN));

        Test.assertEqual("Unknown profile", Light820Modes.profileSummary(Light820Modes.PROFILE_UNKNOWN));
        Test.assertEqual("Light profile", Light820Modes.profileSummary(Light820Modes.PROFILE_COMPATIBLE_TAILLIGHT));

        return true;
    }

    (:test)
    function singleTaillightFallback_isStrictlyGated(logger as Logger) as Boolean {
        Test.assert(
            Light820Modes.canUseSingleTaillightNetworkFallback(
                1,
                AntPlus.LIGHT_TYPE_TAILLIGHT,
                Light820Modes.PROFILE_COMPATIBLE_TAILLIGHT
            )
        );

        Test.assert(
            !Light820Modes.canUseSingleTaillightNetworkFallback(
                2,
                AntPlus.LIGHT_TYPE_TAILLIGHT,
                Light820Modes.PROFILE_COMPATIBLE_TAILLIGHT
            )
        );
        Test.assert(
            !Light820Modes.canUseSingleTaillightNetworkFallback(
                1,
                AntPlus.LIGHT_TYPE_HEADLIGHT,
                Light820Modes.PROFILE_COMPATIBLE_TAILLIGHT
            )
        );
        Test.assert(
            !Light820Modes.canUseSingleTaillightNetworkFallback(
                1,
                AntPlus.LIGHT_TYPE_TAILLIGHT,
                Light820Modes.PROFILE_UNSUPPORTED
            )
        );

        return true;
    }

    (:test)
    function actionEquals_usesStringValueComparison(logger as Logger) as Boolean {
        Test.assert(Light820Modes.actionEquals("mode", Light820Modes.ACTION_MODE));
        Test.assert(Light820Modes.actionEquals(Light820Modes.ACTION_REFRESH.toString(), Light820Modes.ACTION_REFRESH));
        Test.assert(!Light820Modes.actionEquals("mode", Light820Modes.ACTION_REFRESH));
        Test.assert(!Light820Modes.actionEquals(null, Light820Modes.ACTION_MODE));

        return true;
    }

    (:test)
    function listenerPrimaryMode_preservesPendingCommandDuringCallbackWindow(logger as Logger) as Boolean {
        Test.assertEqual(
            AntPlus.LIGHT_MODE_FAST_FLASH,
            Light820Modes.resolveListenerPrimaryMode(
                AntPlus.LIGHT_MODE_OFF,
                AntPlus.LIGHT_MODE_FAST_FLASH,
                2
            )
        );
        Test.assertEqual(
            AntPlus.LIGHT_MODE_FAST_FLASH,
            Light820Modes.resolveListenerPrimaryMode(
                AntPlus.LIGHT_MODE_FAST_FLASH,
                AntPlus.LIGHT_MODE_FAST_FLASH,
                2
            )
        );
        Test.assertEqual(
            AntPlus.LIGHT_MODE_OFF,
            Light820Modes.resolveListenerPrimaryMode(
                AntPlus.LIGHT_MODE_OFF,
                AntPlus.LIGHT_MODE_FAST_FLASH,
                0
            )
        );
        Test.assertEqual(
            AntPlus.LIGHT_MODE_OFF,
            Light820Modes.resolveListenerPrimaryMode(
                AntPlus.LIGHT_MODE_OFF,
                null,
                2
            )
        );

        return true;
    }

    (:test)
    function listenerGenerationMatches_onlyAcceptsCurrentGeneration(logger as Logger) as Boolean {
        Test.assert(Light820Modes.listenerGenerationMatches(7, 7));
        Test.assert(!Light820Modes.listenerGenerationMatches(6, 7));
        Test.assert(!Light820Modes.listenerGenerationMatches(8, 7));

        return true;
    }
}
