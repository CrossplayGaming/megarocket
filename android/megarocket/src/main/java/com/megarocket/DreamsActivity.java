package com.megarocket;

import java.io.File;

import android.os.Bundle;
import android.system.Os;

/* Keen Dreams, unified: the refkeen engine (SDL3) runs as an activity in
 * this APK, chdir'd into the collection's keendreams/game folder -- where
 * the launcher's importer puts the player's kdreams files -- and started
 * with the same arguments the desktop launcher uses, so it boots straight
 * into the game with no refkeen menus, pickers, or permissions.
 *
 * Note the base class: SDL3's Java glue, renamed to org.libsdl3.app (see
 * android/patch-sdl3-java-package.ps1) so it can live alongside the SDL2
 * glue the other activities use. */
public class DreamsActivity extends org.libsdl3.app.SDLActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        File game = new File(getExternalFilesDir(null), "keendreams/game");
        /* -cfgdir/-datadir are "assumed to exist" by refkeen */
        new File(game, "cfg").mkdirs();
        new File(game, "data").mkdirs();
        try {
            Os.setenv("RHLE_CWD", game.getAbsolutePath(), true);
        } catch (Exception e) {
            /* refkeen will report the missing files itself */
        }
        super.onCreate(savedInstanceState);
    }

    @Override
    protected String[] getLibraries() {
        return new String[] { "SDL3", "reflection-kdreams" };
    }

    @Override
    protected String[] getArguments() {
        /* same invocation as the desktop launcher's Dreams slot */
        return new String[] {
            "-gamever", "kdreamse100",
            "-cfgdir", "cfg",
            "-datadir", "data"
        };
    }

    /* refkeen's backend probes this over JNI.  All our data lives in the
     * app's own storage, so external-storage access is never needed. */
    public int requestReadExternalStoragePermission() {
        return 0;
    }

    @Override
    public void setOrientationBis(int w, int h, boolean resizable, String hint) {
        setRequestedOrientation(
            android.content.pm.ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE);
    }
}
