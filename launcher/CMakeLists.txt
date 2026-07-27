cmake_minimum_required(VERSION 3.10...4.0)
project(keenlauncher C)

# The shell that fronts all seven games.  Deliberately dependency-light: SDL2
# (already vendored in deps/) and a baked bitmap font, nothing else -- see the
# header comment in launcher.c for why there is no widget toolkit here.

find_package(SDL2 REQUIRED)

add_executable(keenlauncher WIN32 launcher.c)
set_property(TARGET keenlauncher PROPERTY C_STANDARD 99)
target_link_libraries(keenlauncher PRIVATE SDL2::SDL2 SDL2::SDL2main)

if(MSVC)
	target_compile_definitions(keenlauncher PRIVATE _CRT_SECURE_NO_WARNINGS)
endif()

# keep SDL2.dll next to the exe so the launcher runs from its own folder
add_custom_command(TARGET keenlauncher POST_BUILD
	COMMAND ${CMAKE_COMMAND} -E copy_if_different
		$<TARGET_FILE:SDL2::SDL2> $<TARGET_FILE_DIR:keenlauncher>)
