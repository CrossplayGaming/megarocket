package com.megarocket;

import android.os.Bundle;

import org.libsdl.app.SDLActivity;

/* Base class for the game activities: SDLActivity plus the on-screen
 * touch controls layered over the SDL surface. */
public class EngineActivity extends SDLActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
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
