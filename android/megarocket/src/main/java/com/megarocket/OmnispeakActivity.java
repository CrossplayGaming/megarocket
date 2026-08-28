package com.megarocket;

import java.io.File;

import org.libsdl.app.SDLActivity;

public class OmnispeakActivity extends SDLActivity {
    @Override
    protected String[] getLibraries() {
        return new String[] {
            "SDL2",
            "omnispeak"
        };
    }

    @Override
    protected String[] getArguments() {
        int episode = getIntent().getIntExtra("episode", 4);
        String rt = new File(getExternalFilesDir(null), "rt").getAbsolutePath();
        return new String[] {
            "/EPISODE", String.valueOf(episode),
            "/GAMEPATH", rt,
            "/USERPATH", rt
        };
    }
}
