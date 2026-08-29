package com.megarocket;

import android.os.Bundle;
import android.system.Os;

import org.libsdl.app.SDLActivity;

/* Base class for the game activities: SDLActivity plus the on-screen
 * touch controls layered over the SDL surface. */
public class EngineActivity extends SDLActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        try {
            /* SDL2 ranks openslES above AAudio; prefer AAudio (whose
             * backend we patch to request the LOW_LATENCY stream --
             * see android/patch-sdl2-lowlatency.ps1), falling back to
             * openslES where AAudio is unavailable. */
            Os.setenv("SDL_AUDIODRIVER", "AAudio,openslES", true);
        } catch (Exception e) {
            /* worst case: default driver order, higher audio latency */
        }
        super.onCreate(savedInstanceState);
        if (mLayout != null)
            mLayout.addView(new TouchOverlay(this));
    }

    /* SDL second-guesses the manifest's orientation from its window flags;
     * every game here is landscape. */
    @Override
    public void setOrientationBis(int w, int h, boolean resizable, String hint) {
        setRequestedOrientation(
            android.content.pm.ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE);
    }
}
