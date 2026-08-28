cmake_minimum_required(VERSION 3.10)

project(megarocket-keen13)

# SDL2 sources: a junction/symlink named "SDL" (see android/README.md)
add_subdirectory(SDL)

# Keen 1-3 port sources: a junction/symlink named "keen13port" pointing at
# keen13/port; its CMakeLists builds the three episode shared libraries on
# Android against the in-tree SDL2 target.
add_subdirectory(keen13port)
