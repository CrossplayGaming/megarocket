/* Reconstructed Commander Keen 1-3 Source Code
 * Copyright (C) 2021-2026 K1n9_Duk3
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#ifndef __VERSION_H__
#define __VERSION_H__

#ifndef EPISODE
#define EPISODE 1
#endif

#define VER_BETA 0x00B0
#define VER_100  0x0100
#define VER_110  0x0110
#define VER_120  0x0120	// a.k.a. Keen 2 and 3 v1.0
#define VER_130  0x0130 // a.k.a. Keen 2 and 3 v1.1
#define VER_131  0x0131
#define VER_132  0x0132
#define VER_134  0x0134 // a.k.a. Keen 2 and 3 v1.32

#ifndef VERSION
#define VERSION VER_131
#endif


/*
===============================================================================
	VERSION CHECKS
===============================================================================
*/

#if VERSION <= VER_100 //------------------------------------------------------

// Keen 1 v1.0 and the beta don't display a version number at startup
#undef VERSIONNAME

#elif VERSION == VER_110 //----------------------------------------------------

#define VERSIONNAME "1.1"

#elif VERSION == VER_120 //----------------------------------------------------

// Keen 2 and Keen 3 v1.0 were compiled from a more up-to-date code base than
// Keen 1 v1.1, but they were declared version 1.0 since there were no earlier
// releases of these two games. For this reason, version 1.0 of Keen 2 and 3
// is internally treated as version 1.2 of the code base in this source code.
#if EPISODE == 1
#define VERSIONNAME "1.2"
#else
#define VERSIONNAME "1.0"
#endif

#elif VERSION == VER_130 //----------------------------------------------------

// Again, the Keen 2 and 3 version numbers don't match the Keen 1 version.
#if EPISODE == 1
#define VERSIONNAME "1.3"
#else
#define VERSIONNAME "1.1"
#endif

#elif VERSION == VER_131 //----------------------------------------------------

#define VERSIONNAME "1.31 1/23/90"	// should have been 91, not 90

#elif VERSION == VER_132 //----------------------------------------------------

#define VERSIONNAME "1.32 5/21/91"

#elif VERSION == VER_134 //----------------------------------------------------

// This is the Precision Software Applications release for the United Kingdom.
// Once again, Keen 2 and 3 use a different version number than Keen 1 for the
// same code base. Looks like they didn't build any Keen 2 or 3 counterparts
// for Keen 1 version 1.32 5/21/91 ("pre-registered" Gravis release).
#if EPISODE == 1
#define VERSIONNAME "1.34    8/7/91"
#else
#define VERSIONNAME "1.32    8/7/91"
#endif

#else //-----------------------------------------------------------------------

#error undefined game version

#endif // end of VERSION checks -----------------------------------------------


/*
===============================================================================
	EPISODE CHECKS
===============================================================================
*/

#if (EPISODE == 1) //----------------------------------------------------------

#define EXTENSION "CK1"
#define PARTNAME "1"
#include "GRAPHCK1.H"
#include "SNDSCK1.H"

#elif (EPISODE == 2) //--------------------------------------------------------

#define EXTENSION "CK2"
#define PARTNAME "2"
#include "GRAPHCK2.H"
#include "SNDSCK2.H"
#define TEXTSLINKED
#define SOUNDSLINKED

#elif (EPISODE == 3) //--------------------------------------------------------

#define EXTENSION "CK3"
#define PARTNAME "3"
#include "GRAPHCK3.H"
#include "SNDSCK3.H"
#define TEXTSLINKED
#define SOUNDSLINKED

#else //-----------------------------------------------------------------------

#error unsupported episode number!

#endif	// end of EPISODE checks ----------------------------------------------


#ifdef VERSIONNAME
#define LOADMSG "Loading Commander Keen part "PARTNAME"... (version "VERSIONNAME")"
#else
#define LOADMSG "Loading Commander Keen part "PARTNAME"..."
#endif

#if VERSION <= VER_120
#define OLDKEYBOARD
#endif

#include "BSSCHEAT.H"

#endif	// __VERSION_H__
