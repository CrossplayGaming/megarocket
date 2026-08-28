package com.megarocket.keen13;

import org.libsdl.app.SDLActivity;

public class Keen3Activity extends SDLActivity {
    @Override
    protected String[] getLibraries() {
        return new String[] { "SDL2", "keen13_ep3" };
    }
}
