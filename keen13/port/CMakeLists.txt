cmake_minimum_required(VERSION 3.10...4.0)
project(keen13 C)

# Keen 1-3 port (Keen Launcher Phase 4).
# One shared tree builds all three episodes; game logic TUs are the
# reconstruction's sources compiled with the compat layer force-included,
# and idlib13 replaces the DOS/EGA engine layer.

set(K13_SHARED_SOURCES
	KEENMAIN.C
	KEENDEMO.C   # includes KEENSCRN.C only for VERSION <= 1.10
	KEENSCRN.C   # separate TU at v1.31 (matches RCK?.MAK)
	IDLIBC.C     # engine C layer (K13_PORT fences replace DOS-only parts)
)

if(TARGET SDL2)
	# SDL2 built in-tree (the Android project adds the SDL source
	# subdirectory before this one); its ALIAS provides SDL2::SDL2.
	set(SDL2_FOUND TRUE)
else()
	find_package(SDL2 QUIET)
endif()

function(k13_episode target ep)
	set(GAME_SOURCES
		${K13_SHARED_SOURCES}
		KEEN${ep}ACT.C
		K13TABLE.C   # zeroed tables; K13_RipTables() fills them at boot
	)
	set_source_files_properties(${GAME_SOURCES} PROPERTIES LANGUAGE C)

	if(ANDROID)
		# SDLActivity dlopens the game and calls SDL_main; the
		# wrapper in k13_android.c chdirs to app storage and calls
		# the reconstruction's entry, renamed via the define below.
		add_library(${target} SHARED ${GAME_SOURCES} idlib13.c dbopl.c k13_android.c)
		target_compile_definitions(${target} PRIVATE main=k13_realmain)
		# The reconstruction leans on tentative definitions merging
		# across TUs (Turbo C / MSVC semantics); clang needs -fcommon.
		target_compile_options(${target} PRIVATE -fcommon)
	else()
		add_executable(${target} ${GAME_SOURCES} idlib13.c dbopl.c)
	endif()
	set_property(TARGET ${target} PROPERTY C_STANDARD 11)

	target_compile_definitions(${target} PRIVATE
		EPISODE=${ep}
		VERSION=0x0131
		K13_PORT
		_CRT_SECURE_NO_WARNINGS
		_CRT_NONSTDC_NO_WARNINGS
	)

	if(MSVC)
		# Force-include the compat layer ahead of everything.
		target_compile_options(${target} PRIVATE /FI"${CMAKE_CURRENT_SOURCE_DIR}/k13_compat.h")
		# linker map so the crash reporter's module offsets resolve
		target_link_options(${target} PRIVATE /MAP)
	else()
		target_compile_options(${target} PRIVATE -include "${CMAKE_CURRENT_SOURCE_DIR}/k13_compat.h")
	endif()

	target_include_directories(${target} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

	# game defines its own main(); do NOT link SDL2main
	if(SDL2_FOUND)
		target_link_libraries(${target} PRIVATE SDL2::SDL2)
		target_compile_definitions(${target} PRIVATE K13_WITH_SDL=1)
		add_custom_command(TARGET ${target} POST_BUILD
			COMMAND ${CMAKE_COMMAND} -E copy_if_different
				$<TARGET_FILE:SDL2::SDL2> $<TARGET_FILE_DIR:${target}>)
	endif()
endfunction()

k13_episode(keen13 1)
k13_episode(keen13_ep2 2)
k13_episode(keen13_ep3 3)
