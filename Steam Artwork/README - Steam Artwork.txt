Megarocket  -  Steam / SteamGridDB artwork set
================================================

grids/     grid_600x900 / 660x930 / 342x482   portrait capsules
           grid_920x430 / 460x215             landscape capsules
heroes/    hero_1920x620 / 3840x1240 / 1600x650   (+ .jpg alternates)
logos/     transparent PNG lock-up (rocket + wordmark)
icons/     512/256/128/64/32 PNG + multi-size icon.ico


WHERE IT CAME FROM
------------------
Everything is Megarocket's own visual identity plus art the ENGINES rendered
from this machine's game files:

  wordmark      the launcher's embossed big-font "MEGAROCKET" title, rendered
                from launcher_font_big.h with the exact outline/shade/light
                pass the launcher itself draws (face yellow, EGA palette)
  rocket        the EGA pixel rocket from android/make-icon.py -- the icon here
                is the same image as the Android app icon, so the library entry
                and the phone match
  starfield     the launcher's own fixed-seed scatter algorithm, reproduced
                pixel for pixel
  title strip   the seven title_art dumps (Keen 1-3, 4-6, Dreams), each in a
                launcher-style frame using that game's launcher accent colour

The title screens are rendered from THIS machine's game data, so the capsules
are personal-library artwork - fine on this Steam account, not for uploading
to SteamGridDB or redistributing.

Grids carry the wordmark; heroes are text-free (Steam overlays the logo at
runtime) with the rockets kept clear of the centre logo zone.


REBUILDING
----------
  python "build-configs\art_build.py"           everything
  python "build-configs\art_build.py" grids     one section
                                      (grids | heroes | logos | icons)

Pixel sources are integer-scaled with NEAREST; only the title-screen
downscales and the small-size derivatives use Lanczos.
