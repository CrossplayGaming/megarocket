package com.megarocket.omnispeak;

import org.libsdl.app.SDLActivity;

public class OmnispeakActivity extends SDLActivity {
    @Override
    protected String[] getLibraries() {
        return new String[] {
            "SDL2",
            "omnispeak"
        };
    }
}
