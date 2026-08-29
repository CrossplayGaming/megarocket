cmake_minimum_required(VERSION 3.10)

project(megarocket)

# Junctions/symlinks (see android/README.md):
#   SDL        -> deps SDL2 source
#   SDL3       -> deps SDL3 source (patched: Java glue in org.libsdl3.app)
#   omnispeak  -> the omnispeak fork
#   keen13port -> keen13/port
#   launcher   -> launcher/
#   refkeen    -> the refkeen fork (Keen Dreams)
add_subdirectory(SDL)
add_subdirectory(SDL3)
add_subdirectory(omnispeak)
add_subdirectory(keen13port)
add_subdirectory(launcher)
add_subdirectory(refkeen)
