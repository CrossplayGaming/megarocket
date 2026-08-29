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
}
