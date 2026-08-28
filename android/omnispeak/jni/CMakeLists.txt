cmake_minimum_required(VERSION 3.10)

project(megarocket-omnispeak)

# SDL2 sources: a junction/symlink named "SDL" (see android/README.md)
add_subdirectory(SDL)

# Omnispeak sources: a junction/symlink named "omnispeak"; its CMakeLists
# detects the in-tree SDL2 target and builds a shared library on Android.
add_subdirectory(omnispeak)
