cmake_minimum_required(VERSION 3.10)

project(megarocket)

# Junctions/symlinks (see android/README.md):
#   SDL        -> deps SDL2 source
#   omnispeak  -> the omnispeak fork
#   keen13port -> keen13/port
#   launcher   -> launcher/
add_subdirectory(SDL)
add_subdirectory(omnispeak)
add_subdirectory(keen13port)
add_subdirectory(launcher)
