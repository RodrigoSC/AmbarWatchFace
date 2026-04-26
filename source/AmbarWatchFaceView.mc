import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Weather;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class AmbarWatchFaceView extends WatchUi.WatchFace {
    hidden var lastSlowUpdate as Number? = null;
    hidden var weather as Dictionary = {};

    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.WatchFace(dc));
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
    }

    function formatDate() as String {
        var today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dd = today.day < 10 ? "0" + today.day.toString() : today.day.toString();
        var mm = today.month < 10 ? "0" + today.month.toString() : today.month.toString();
        return dd + "-" + mm;
    }

    // Returns the HH:MM time at a given UTC offset (in minutes).
    function formatAltTimezone(offsetMinutes as Number) as String {
        var utc = Gregorian.utcInfo(Time.now(), Time.FORMAT_SHORT);
        var totalMins = ((utc.hour * 60 + utc.min + offsetMinutes) % 1440 + 1440) % 1440;
        var h = totalMins / 60;
        var m = totalMins % 60;
        var hh = h < 10 ? "0" + h.toString() : h.toString();
        var mm = m < 10 ? "0" + m.toString() : m.toString();
        return hh + ":" + mm;
    }

    function toThousands(nbr as Number?) as String {
        var res;
        if (nbr == null) {
            res = "--";
        } else if (nbr >= 1000) {
            res = (nbr / 1000).toString() + "." + ((nbr % 1000) / 100).toString() + "K";
        } else {
            res = nbr.toString();
        }
        return res;
    }

    function padNumber(nbr as String) {
        return nbr.length() < 2 ? "0" + nbr : nbr;
    } 
    
    function writeToLED(fieldId as String, value as String) {
        var mask = "";
        for (var i = 0; i < value.length(); i++) { mask += "$"; }
        (View.findDrawableById(fieldId + "Bg") as Text).setText(mask);
        (View.findDrawableById(fieldId) as Text).setText(value);
    }

    function getWeekDayPosition() as Number {
        var today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var pos = [77, 113, 140, 175, 202, 230, 258];
        return pos[today.day_of_week - 1];
    }

    function updateWeather() {
        var cc = Weather.getCurrentConditions();
        if (cc != null) {
            weather["Temp"] = cc.temperature as Number;
            weather["WindBear"] = cc.windBearing as Number;
            weather["WindSpeed"] = cc.windSpeed as Number;
            weather["Rain"] = cc.precipitationChance as Number;
        }
    }

    function getWindChar(windBear as Number) as String {
        var aux = (windBear + 23) % 360;
        if (aux < 45) { return "e"; }
        if (aux >= 45 && aux < 90) { return "f"; }
        if (aux >= 90 && aux < 135) { return "g"; }
        if (aux >= 135 && aux < 180) { return "h"; }
        if (aux >= 180 && aux < 225) { return "a"; }
        if (aux >= 225 && aux < 270) { return "b"; }
        if (aux >= 270 && aux < 315) { return "c"; }
        if (aux >= 315 && aux < 360) { return "d"; }
        return "-";
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
        var clockTime = System.getClockTime();
        var hour = clockTime.hour;
        var minute = clockTime.min;
        var unix_timestamp = Time.now().value();

        if(clockTime.sec % 60 == 0 or lastSlowUpdate == null or unix_timestamp - lastSlowUpdate >= 60) {
            lastSlowUpdate = unix_timestamp;
            updateWeather();
        }

        if (weather["Temp"] != null) {
            var tempData = weather["Temp"].format("%d") + "ª";
            if (weather["WindSpeed"] != null && weather["WindBear"] != null) {
                tempData += " " + getWindChar(weather["WindBear"]) + weather["WindSpeed"].format("%d") + " ";
            }            
            if (weather["Rain"] != null) {
                tempData += weather["Rain"] + "%";
            }
            writeToLED("WeatherLabel",tempData);
        }

        var altOffset = Application.Properties.getValue("AltTimezoneOffset") as Number?;

        var dateStr = (altOffset != null && altOffset != -9999)
            ? formatAltTimezone(altOffset)
            : formatDate();
        (View.findDrawableById("DateLabel") as Text).setText(dateStr);

        var wdText = (View.findDrawableById("WeekDayLabel") as Text);
        wdText.setLocation(getWeekDayPosition(), wdText.locY);

        var altDateStr = (altOffset != null && altOffset != -9999)
            ? formatDate()
            : "";
        (View.findDrawableById("AltDateLabel") as Text).setText(altDateStr);

        // Format time as HH:MM
        var timeStr = (hour / 10).toString() + (hour % 10).toString() + ":" +
                      (minute / 10).toString() + (minute % 10).toString();
        (View.findDrawableById("TimeLabel") as Text).setText(timeStr);

        var info = ActivityMonitor.getInfo();
        writeToLED("StepsValLabel",padNumber(toThousands(info.steps)));
        writeToLED("FloorsValLabel",padNumber(toThousands(info.floorsClimbed)));

        var notifications = System.getDeviceSettings().notificationCount;
        var notifStr = (notifications > 0) 
            ? toThousands(notifications)
            : "--";
        writeToLED("NotifsValLabel",padNumber(notifStr));
        
        var battery = System.getSystemStats().battery;
        (View.findDrawableById("BatteryLabel") as Text).setVisible(battery <= 5);
        
        View.onUpdate(dc);

        var rx = 35; var ry = 130; var rr = 20;
        var rw = dc.getWidth() - rx * 2;
        var rh = dc.getHeight() - ry * 2;
        var offset = 10;
        dc.setColor(0xFFA400, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawRoundedRectangle(rx, ry, rw, rh, rr);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(rx-offset, ry-offset, rw+offset*2, rh+offset*2, rr+offset);
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() as Void {
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() as Void {
    }

}
