import Toybox.AntPlus;
import Toybox.Lang;
import Toybox.Test;

module Light820UiTests {
    (:test)
    function hitZones_mapSplitRefreshAndFixedStandardRows(logger as Logger) as Boolean {
        var ui = new Light820Ui();
        ui.prepareHitZones(480, 800, fullStandardState());

        Test.assertEqual(6, ui.getHitZoneCount());
        Test.assertEqual(AntPlus.LIGHT_MODE_OFF, ui.findAction(20, 70)["mode"]);
        Test.assertEqual(Light820Modes.ACTION_REFRESH, ui.findAction(450, 70)["kind"]);
        Test.assertEqual(AntPlus.LIGHT_MODE_ST_21_40, ui.findAction(240, 220)["mode"]);
        Test.assertEqual(AntPlus.LIGHT_MODE_ST_0_20, ui.findAction(240, 360)["mode"]);
        Test.assertEqual(AntPlus.LIGHT_MODE_SLOW_FLASH, ui.findAction(240, 500)["mode"]);
        Test.assertEqual(AntPlus.LIGHT_MODE_FAST_FLASH, ui.findAction(240, 640)["mode"]);

        Test.assert(ui.findAction(0, 0) == null);
        Test.assert(ui.findAction(470, 20) == null);
        Test.assert(ui.findAction(240, 780) == null);
        return true;
    }

    (:test)
    function compactLayout_keepsFiveRowsVisibleOnEdge840Geometry(logger as Logger) as Boolean {
        var ui = new Light820Ui();
        ui.prepareHitZones(246, 322, fullStandardState());

        Test.assertEqual(6, ui.getHitZoneCount());
        Test.assertEqual(AntPlus.LIGHT_MODE_OFF, ui.findAction(20, 50)["mode"]);
        Test.assertEqual(Light820Modes.ACTION_REFRESH, ui.findAction(200, 50)["kind"]);
        Test.assertEqual(AntPlus.LIGHT_MODE_ST_21_40, ui.findAction(120, 110)["mode"]);
        Test.assertEqual(AntPlus.LIGHT_MODE_ST_0_20, ui.findAction(120, 160)["mode"]);
        Test.assertEqual(AntPlus.LIGHT_MODE_SLOW_FLASH, ui.findAction(120, 210)["mode"]);
        Test.assertEqual(AntPlus.LIGHT_MODE_FAST_FLASH, ui.findAction(120, 260)["mode"]);
        Test.assert(ui.findAction(120, 312) == null);
        return true;
    }

    (:test)
    function missingStandardModes_renderDisabledWithoutHitZones(logger as Logger) as Boolean {
        var ui = new Light820Ui();
        var state = {
            "modes" => Light820Modes.buildVisibleModes([
                AntPlus.LIGHT_MODE_OFF,
                AntPlus.LIGHT_MODE_FAST_FLASH
            ])
        };

        ui.prepareHitZones(246, 322, state);

        Test.assertEqual(3, ui.getHitZoneCount());
        Test.assertEqual(AntPlus.LIGHT_MODE_OFF, ui.findAction(20, 50)["mode"]);
        Test.assertEqual(Light820Modes.ACTION_REFRESH, ui.findAction(200, 50)["kind"]);
        Test.assert(ui.findAction(120, 110) == null);
        Test.assert(ui.findAction(120, 160) == null);
        Test.assert(ui.findAction(120, 210) == null);
        Test.assertEqual(AntPlus.LIGHT_MODE_FAST_FLASH, ui.findAction(120, 260)["mode"]);
        return true;
    }

    (:test)
    function hitZones_doNotOverlapGapsOrFooter(logger as Logger) as Boolean {
        var ui = new Light820Ui();
        ui.prepareHitZones(246, 322, fullStandardState());

        var off = ui.getHitZone(0);
        var refresh = ui.getHitZone(1);
        var dayFlash = ui.getHitZone(5);

        Test.assert(ui.findAction(off["x"] + off["w"], off["y"] + 5) == null);
        Test.assertEqual(Light820Modes.ACTION_REFRESH, ui.findAction(refresh["x"], refresh["y"])["kind"]);
        Test.assert(ui.findAction(refresh["x"] + refresh["w"], refresh["y"] + 5) == null);
        Test.assert(ui.findAction(dayFlash["x"] + 5, dayFlash["y"] + dayFlash["h"]) == null);
        Test.assert(ui.findAction(120, 318) == null);
        return true;
    }

    (:test)
    function allTargetGeometries_keepZonesInsideVisibleArea(logger as Logger) as Boolean {
        assertZonesFit(480, 800);
        assertZonesFit(470, 720);
        assertZonesFit(390, 564);
        assertZonesFit(246, 322);
        assertZonesFit(240, 400);
        return true;
    }

    function assertZonesFit(width as Number, height as Number) as Void {
        var ui = new Light820Ui();
        ui.prepareHitZones(width, height, fullStandardState());

        for (var i = 0; i < ui.getHitZoneCount(); i++) {
            var zone = ui.getHitZone(i);
            Test.assert(zone["x"] >= 0);
            Test.assert(zone["y"] >= 0);
            Test.assert(zone["x"] + zone["w"] <= width);
            Test.assert(zone["y"] + zone["h"] < height);
        }

        Test.assert(ui.findAction(width - 10, 10) == null);
        Test.assert(ui.findAction(width / 2, height - 5) == null);
        Test.assert(ui.findAction(width / 2, height - 25) == null);
    }

    function fullStandardState() as Dictionary {
        return {
            "modes" => Light820Modes.buildVisibleModes([
                AntPlus.LIGHT_MODE_OFF,
                AntPlus.LIGHT_MODE_ST_21_40,
                AntPlus.LIGHT_MODE_ST_0_20,
                AntPlus.LIGHT_MODE_SLOW_FLASH,
                AntPlus.LIGHT_MODE_FAST_FLASH
            ])
        };
    }
}
