package com.megarocket.keen13;

import org.libsdl.app.SDLActivity;

public class Keen2Activity extends SDLActivity {
    @Override
    protected String[] getLibraries() {
        return new String[] { "SDL2", "keen13_ep2" };
    }
}
