Reconstructed Commander Keen 1-3 Source Code
Copyright (C) 2021-2026 K1n9_Duk3
===============================================================================

This is an UNOFFICIAL reconstruction of the original Keen 1-3 source code.
The code is based on the source code for Hovertank 3-D and The Catacomb.

Hovertank 3-D Source Code
Copyright (C) 1993-2014 Flat Rock Software

The Catacomb Source Code
Copyright (C) 1993-2014 Flat Rock Software

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.


Getting this code to compile
============================

You will need:

- Turbo C++ 1.00  (for all versions up to and including 1.31)
- Turbo Assembler 2.0 (or later)
- Borland C++ 2.0 (for versions 1.32 and 1.34, a.k.a. Gravis and PSA releases)
- copies of the original Keen 1-3 executables (for data extraction)
- CKPatch and/or K1n9_Duk3's Patching Utility (for data extraction)
- DOSBox (or a real DOS computer)
- this source code archive

You will need Turbo Assembler 2.0 (or later) and Turbo C++ 1.00 to compile this
code into exact recreations of the original executables. Please note that using
Turbo C++ 1.01 will NOT work if you want to verify that this code compiles into
EXACT recreations, since it generates slightly different code.

If you do not care about exact recreations, you should be able to use later
versions of Turbo C++ or Borland C++ without many problems. Only Turbo C++ 3.0
is known to cause problems with this code. Keep in mind that Turbo C (the old
non-C++ compiler) will NOT work, since it doesn't support the modern // single
line comments used all over the .C and .H source files. Please read the section
"Using a different compiler" down below for further information.

In addition to the compiler and this source code, you will also need to extract
some data files from the original executables. I have provided patch scripts to
extract that data from the original executables. To use these patch scripts,
you will need one of the following tools:

CKPatch v0.11.3 (unofficial) - 16 bit DOS application
http://ny.duke4.net/files.html

K1n9_Duk3's Patching Utility v2.2 (or later) - Win32 application
http://k1n9duk3.shikadi.net/patcher.html

Note that if you want to extract the data from the Keen 1 beta and/or versions
1.32 or 1.34, you will have to use K1n9_Duk3's Patching Utility. CKPatch does
not support these versions and will not be able to process the respective patch
files. Since the executables in the PSA release (Keen 1 v1.34, Keen 2+3 v1.32)
were compressed with PKLITE, which cannot be decompressed by K1n9_Duk3's
Patching Utility, you will have to decompress that file before you can extract
the data. A copy of PKLITE is included in this archive and you can use it to
decompress the executable. Copy PKLITE.EXE and KEEN1.EXE into the same
directory, then mount it in DOSBox (drag-and-drop PKLITE.EXE onto DOSBox.exe,
for example) and then type the command "pklite -x keen1.exe" (without the
quotes) at the DOSBox prompt and hit Enter. Repeat this for KEEN2.EXE and
KEEN3.EXE if necessary.

Copy the patching programs into the "static" subdirectory, along with copies of
the original Keen 1-3 executables. The Keen 1-3 executables should be named
KEEN1.EXE, KEEN2.EXE and KEEN3.EXE respectively, otherwise the patching 
programs might have trouble recognizing the files.

If you are using K1n9_Duk3's Patching Utility, simply run it and open the patch
file (*.PAT) you want to use. If K1n9_Duk3's Patching Utility found more than
one supported version of the executables (or none at all), it will ask you to
open the executable manually. Save the extracted files into the "static"
directory using the suggested file names.

If you are going to use CKPatch, just copy the files as described above, then
use the provided batch files as described in the following section.


Setting up a working environment in DOSBox
------------------------------------------

The Turbo C++ compiler and TASM, as well as CKPATCH, MAKEOBJ and LZEXE, are all
DOS programs, so you will need a system that is capable of running DOS programs
or you will have to use an emulator like DOSBox to run these programs.

If you are going to use DOSBox, start out by preparing a base directory on your
system that you are going to mount as drive C: in DOSBox (mounting your real C:
drive as C: in DOSBox is NOT recommended). Let's assume your base directory is
"C:\BASE". Extract the contents of this package into that directory.

You could just start DOSBox and manually mount your base directory as the C:
drive in DOSBox, but this project comes with a couple of batch files that make
the process much easier, as long as things are set up correctly.

In case you didn't know, dragging and dropping a file onto DOSBox.exe (or onto
a shortcut to DOSBox.exe) will start DOSBox and mount the directory in which
that file is located in as the C: drive in DOSBox, then it will try to execute
that file in DOSBox.

Extracting data from the original executables
---------------------------------------------

The first order of business is to extract the data from the original Keen 1-3
executables, since you will not be able to compile the code without that data.
If you haven't already done so, copy the executables (KEEN1.EXE, KEEN2.EXE and
KEEN3.EXE) into the static directory.

If you want to use the CKPatch tools, and you have already copied the CKPatch
and the Keen 1-3 executables into the STATIC directory, simply drag-and-drop
RIPNMAKE.BAT onto your shortcut to DOSBox. This will extract (rip) the data
from the executables via CKPatch and then convert the extracted data into .OBJ
and .C files and place those files into the correct directories.

If you want to use K1n9_Duk3's Patching Utility to extract the data, you must
open each of the "ripck*.pat" files with that utility and save the extracted
data in the STATIC directory using the suggested names. After that is done, you
need to drag-and-drop the MAKEOBJS.BAT file from the source's root directory
onto your shortcut to DOSBox.

Here is a list of the various versions and how to extract their data:

 Keen 1 beta : open ripck1beta.pat with K1n9_Duk3's Patching Utility (KDPU)
 Keen 1 v1.0 : unsupported, extract data from v1.1 or v1.31 instead
 Keen 1 v1.1 : run rip.bat (in DOSBox) or open ripck1.pat with KDPU
 Keen 1 v1.3 : unsupported, extract data from v1.1 or v1.31 instead
 Keen 1 v1.31: run rip.bat (in DOSBox) or open ripck1.pat with KDPU
 Keen 1 v1.32: open ripck1v132.pat with KDPU
 Keen 1 v1.34: decompress KEEN1.EXE with "PKLITE -x KEEN1.EXE" and then
               open ripck1v134.pat with KDPU
 
 Keen 2 v1.0 : run rip.bat (in DOSBox) or open ripck2.pat with KDPU
 Keen 2 v1.1 : unsupported, extract data from v1.31 instead
 Keen 2 v1.31: run rip.bat (in DOSBox) or open ripck2.pat with KDPU
 Keen 2 v1.32: decompress KEEN2.EXE with "PKLITE -x KEEN2.EXE" and then
               open ripck2v132.pat with KDPU
 
 Keen 3 v1.0 : run rip.bat (in DOSBox) or open ripck3.pat with KDPU
 Keen 3 v1.1 : unsupported, extract data from v1.31 instead
 Keen 3 v1.31: run rip.bat (in DOSBox) or open ripck3.pat with KDPU
 Keen 3 v1.32: decompress KEEN3.EXE with "PKLITE -x KEEN3.EXE" and then
               open ripck3v132.pat with KDPU
 
Keen 1 v1.0, v1.1, v1.3 and v1.31 contain exactly the same data, so you don't
need to extract the data from more than one of these versions. This does NOT
apply to Keen 2 and 3. The text-based ending screen in v1.0 differs from the
one used in v1.1 and v1.31 of these episodes, and the ENDTEXT, PREVIEWS and the
text-based ending screen in v1.32 differ from the ones in all earlier versions.
 
NOTE: You cannot drag-and-drop the make.bat file from the STATIC directory onto
your shortcut to DOSBox! Doing so would mount the STATIC directory as drive C:
in DOSBox and the batch script would not be able to access the other 
directories outside the STATIC directory and therefore will not be able to
write the .OBJ files to the correct directories and it won't be able to run
TILINF2C to convert the tile attributes into .C files, since that tool is
located in its own directory outside the STATIC directory.

If you modify any of the data files after extracting them, you should use
MAKEOBJS.BAT to convert them into the respective .OBJ and .C files again. You
should NOT use RIPNMAKE.BAT in that case, since that file will overwrite your
files with the data extracted from the original executables.


Your base directory should now contain up to three new .C files:

	TINFCK1.C
	TINFCK2.C
	TINFCK3.C
	TINFK1B.C      (Keen 1 beta version only)

And each of the RCK1*, RCK2* and RCK3* directories should now contain these:

	ENDSCRN.OBJ
	ENDTEXT.OBJ    (Keen 2 and 3 only)
	HELPTEXT.OBJ   (Keen 2 and 3 only)
	INTROSCN.OBJ   (Keen 1 v1.32 only)
	PREVIEWS.OBJ   (Keen 2 and 3 only)
	SOUNDS.OBJ     (Keen 2 and 3 only)
	STORYTXT.OBJ   (Keen 2 and 3 only)

You can exit from DOSBox after this is done. Simply type "exit" at the prompt
and hit Enter.

If you want to be able to compile exact recreations of version 1.0 of Keen 2
and 3, you will need to put the KEEN2.EXE and KEEN3.EXE files of these versions
in the STATIC directory and run the extraction patch scripts a second time.

Setting up the compiler paths
-----------------------------

Before you can compile the code, you will need to edit MOUNTDIR.BAT and insert
the correct paths to your Turbo C++ and Turbo Assembler directories in the
respective lines containing the "mount" commands.

I decided to mount the Turbo C++ directory as drive X: in DOSBox so that the
name of your Turbo C++ directory will not cause any problems and you should not
need to edit any settings in the project files to get the code to compile, at
least as long as your copy of Turbo C++ was installed with the default settings
for its subdirectories (BIN, INCLUDE, LIB). The Turbo Assembler directory is
mounted as drive W: to make its directory name equally irrelevant for the rest
of the batch files.

NOTE: You need to mount the directory that contains TASM.EXE as drive W:, which
means you will need to use the BIN subdirectory of the Assembler's directory
when using Turbo Assembler 4.0 or above.

If you want to compile version 1.32 or later, you need to edit USE_BC20.BAT and
insert the path to your Borland C++ 2.0 directory in the line containing the
"mount" command. Since Borland C++ 2.0 comes bundled with a copy of Turbo
Assembler, there is no need to mount a separate directory for it.


Compiling the code:
-------------------

I have provided a set of batch files that will mount the compiler and assembler
directories and then open the respective project in the Turbo C++ IDE. These
batch files are:

	RCK1.BAT   - Keen 1
	RCK2.BAT   - Keen 2
	RCK3.BAT   - Keen 3

Simply drag-and-drop the batch file onto your shortcut to DOSBox and it will
open the respective file in the IDE. After the project is loaded, simply press
F9 (or select "Compile" -> "Make EXE file" from the menu) to compile the code.

Note that there are only 3 project files in this source code archive (one for
each episode) and these project files are for version 1.31 of the game. If you
want to compile the code for the other versions, you will have to use MAKE and
the respective makefile (see below).

With the current code base, it is completely normal to get a bunch of compiler
warnings when compiling the code in Turbo C++ 1.00. All warnings are about a
value being assigned to a local variable that is ultimately never used in that
function (or a function parameter being unused in the function). These warnings
are mostly harmless, the code is just wasting a bit of memory and CPU cycles on
these assignments. These warnings are to be expected for version 1.31:

 Keen 1 -  5 Warnings
 --------------------
 - KEENACTS.C:
   'dxmove'        in RideObj
   'showbossintro' in LevelLoop
 - IDLIB.C:
   'zero'          in CalibrateJoy
   'joy'           in CalibrateJoy
 - KEENSCRN.C:
   'lines'         in DrawTextScreen

 Keen 2 - 11 Warnings
 --------------------
 - IDLIB.C:
   'zero'          in CalibrateJoy
   'joy'           in CalibrateJoy
   'compression'   in LoadGraphics
 - KEENACTS.C:
   'dxmove'        in RideObj
   'showbossintro' in LevelLoop
 - KEENSCRN.C:
   'anim'          in DrawHighscores
   'ty'            in DrawHighscores
   'tx'            in DrawHighscores
   'lines'         in DrawTextScreen
   'var_24'        in ShowOrderingScreen
   'var_22'        in ShowOrderingScreen

 Keen 3 - 12 Warnings
 --------------------
 - IDLIB.C:
   'zero'          in CalibrateJoy
   'joy'           in CalibrateJoy
   'compression'   in LoadGraphics
 - KEENACTS.C:
   'dxmove'        in RideObj
   'hit' parameter in EnemyShotContact
 - KEENSCRN.C:
   'anim'          in DrawHighscores
   'ty'            in DrawHighscores
   'tx'            in DrawHighscores
   'lines'         in DrawTextScreen
   'var_14'        in ShowOrderingScreen
   'var_12'        in ShowOrderingScreen
   'var_10'        in ShowOrderingScreen

Note: The command-line compiler will show an additional "Restarting compile
using assembly" warning for IDLIB.C, since the "#pragma inline" directive is
not present in that file. MAKE (see below) uses the command-line compiler and
will show this warning message. The pre-1.31 versions may also cause TASM to
display an "Arithmetic overflow" warning for the temporary KEENDEMO.ASM file.
For some reason, the compiler lets the assembler add 65532 to the offset of a
variable instead of subtracting 4 from the offset. In this case, the compiler
expects the arithmetic overflow to occur, otherwise the code would not work as
intended. So don't worry about that warning.

If everything worked fine, the compiler should show a "Success" message at the
end. You can simply press ALT+X or select "File" -> "Quit" to quit to the DOS
prompt. Then you can close the DOSBox window or type "exit" and hit ENTER to
quit DOSBox. Don't just close the DOSBox window while the Turbo C++ IDE is
still running, that would leave a 256k swap file in your base directory.

If you get compiler errors, select "Options" -> "Directories..." and make sure
the include and library directories are correct for the Turbo C++ directory you
are using. Keep in mind that the paths refer to the drives mounted in DOSBox,
not your real system drives.

If the compiler crashes DOSBox or locks up when compiling a file, please refer
to the "Technical difficulties" section below for possible ways to fix this.
You can also try using MAKE instead of TC to compile the code. MAKE appears to
be a lot more stable than TC, but it's a bit harder to work with.


Compiling the code via MAKE:
----------------------------

The first step is to drag-and-drop either MOUNTDIR.BAT or USE_BC20.BAT onto
your shortcut to DOSBox to mount the directories and set up the PATH variable.
Use MOUNTDIR.BAT for the earlier versions (1.31 and earlier) and USE_BC20.BAT
for the later special releases (version 1.32 and later).

To compile the code via the MAKE utility, type this at the command prompt:

MAKE -fRCK1.MAK

Where "RCK1.MAK" is the makefile you want to use. You can also type the
following command instead:

BUILD RCK1

The BUILD.BAT file is set up to run MAKE and insert its own parameter into the
"-f" parameter for MAKE, adding the ".MAK" extension. In other words, BUILD is
a bit shorter to type.

The examples above will compile episode 1 version 1.31. You can compile the
other episodes and versions as well by simply replacing "RCK1" with the name of
the respective makefile (without the .MAK extension). Please note that MAKE
does not use the .PRJ project file at all. You will need to edit the makefiles
if you want to change compiler options, add or remove source files, etc.

Here is a list of the makefiles and the episode and version they stand for:

  RCK1BETA - Keen 1 beta (November 1990)
  RCK1V10  - Keen 1 version 1.0
  RCK1V11  - Keen 1 version 1.1
  RCK1V13  - Keen 1 version 1.3
  RCK1     - Keen 1 version 1.31
  RCK1V132 - Keen 1 version 1.32 (requires Borland C++ 2.0)
  RCK1V134 - Keen 1 version 1.34 (requires Borland C++ 2.0)
  
  RCK2V10  - Keen 2 version 1.0
  RCK2V11  - Keen 2 version 1.1
  RCK2     - Keen 2 version 1.31
  RCK2V132 - Keen 2 version 1.32 (requires Borland C++ 2.0)
  
  RCK3V10  - Keen 3 version 1.0
  RCK3V11  - Keen 3 version 1.1
  RCK3     - Keen 3 version 1.31
  RCK3V132 - Keen 3 version 1.32 (requires Borland C++ 2.0)

Using MAKE instead of TC might require less memory, so try this alternative if
you run out of memory when compiling the code in the IDE. MAKE is also far less
likely to lock up or make DOSBox 0.74-3 crash, so if any technical problems
occur when compiling the code via TC, try the MAKE command instead.

One of the disadvantages of MAKE is that compiler warnings and errors may get
scrolled off the screen when compiling many files. One way to counter that is
to redirect console output to a text file when running MAKE. For example, you
could rewrite the MAKE command in BUILD.BAT as follows:

make -f%1.MAK > %1.LOG

This will redirect the output of MAKE (and all the other programs run by MAKE)
to a text file with the extension .LOG. For example, "BUILD RCK1" would create
a text file named RCK1.LOG that you can open in a text editor to read and
scroll through all the warnings and error messages. It's still not quite as
easy to use as the IDE's messages window, but it's better than not being able
to read some of the messages at all.


Recreating the original executables
===================================

Unlike my Keen 4-6 reconstructions, there is really not all that much to pay
attention to when it comes to Keen 1-3 version 1.31 and earlier.

- Use Turbo C++ 1.00
- Use Turbo Assembler 2.0 or above
- Extract the data from the original executables
- Drag-and-drop VERIFY.BAT onto your shortcut to DOSBox

The VERIFY.BAT file will compile each of the supported versions of Keen 1-3
(using MAKE), compress the new executable with LZEXE (if necessary) and then
verify the checksum of the executable. If the checksum does not match, it will
offer to delete the .OBJ files and re-compile the current project. This might
occasionally be necessary due to some compiler quirks.

For reference, these are the results you should be getting (after compression):

Keen 1 beta         : size = 79322 bytes, CRC = 8222B42D (uncompressed!)
Keen 1 version 1.0  : size = 43622 bytes, CRC = F0CC0FEE
Keen 1 version 1.1  : size = 51226 bytes, CRC = D30E6C3A
Keen 1 version 1.3  : size = 50774 bytes, CRC = F45B2C41
Keen 1 version 1.31 : size = 51190 bytes, CRC = 14C4FF5F

Keen 2 version 1.0  : size = 58307 bytes, CRC = CD2CCDE7
Keen 2 version 1.1  : size = 57951 bytes, CRC = 1332A67C
Keen 2 version 1.31 : size = 58335 bytes, CRC = 69FA894D

Keen 3 version 1.0  : size = 61619 bytes, CRC = FD286F5A
Keen 3 version 1.1  : size = 61231 bytes, CRC = E392F1F2
Keen 3 version 1.31 : size = 61599 bytes, CRC = 723DB48E

NOTE: You MUST use the version of LZEXE that comes with this source code. There
are some slightly different versions of LZEXE v0.91 to be found online,
including a beta release of an English translation (see lzexe91e.zip), but this
particular translation cannot be used to recreate the original Keen 1-3
executables, since it produces slightly different files.


Versions 1.32 and 1.34 were originally compiled with Borland C++ 2.0, so the
process differs a little:

- Use Borland C++ 2.0
- Extract the data from the original executables
- Drag-and-drop VERIFY2.BAT onto your shortcut to DOSBox

For reference, these are the results you should be getting (after compression):

Keen 1 version 1.32 : size = 51959 bytes, CRC = 77DA8C7C
Keen 1 version 1.34 : size = 49684 bytes, CRC = 1F9BEBB6 (PKLITE compression)

Keen 2 version 1.32 : size = 56066 bytes, CRC = 00F683A4 (PKLITE compression)
Keen 3 version 1.32 : size = 58735 bytes, CRC = E5BB85AD (PKLITE compression)

The executeables in the PSA releases (Keen 1 v1.34, Keen 2 and 3 v1.32) were
compressed with PKLITE. Version 1.05 appears to be the one that was used, or at
least using PKLITE v1.05 will allow you to compress the new executables into an
exact copy of the original file. I have included a shareware copy of PKLITE
v1.05 in this source code package. I have already extracted the files from the
original self-extracting archive, but I also included the self-extracting
pklte105.exe just in case you need it.

###############################################################################
WARNING: Versions 1.32 and 1.34 use a different EGAHEAD format than the earlier
versions. Graphics files from version 1.31 and earlier can only be used with
the executables from version 1.31 and earlier. Graphics files from the later
versions can only be used with executables from the later versions.
###############################################################################


Some comments on the versions
=============================

While comparing the code differences between the various versions of Keen 1-3,
it soon became obvious that version 1.0 of Keen 2 and Keen 3 must have been
compiled from a later code base than Keen 1 version 1.1. For example, the
DrawTextScreen function and the sparksgone variable exist in Keen 2 and 3
version 1.0 but they didn't exist in Keen 1 version 1.1. For this reason, the
version 1.0 of these episodes is internally treated as version 1.2 of the code.

Keen 2 and 3 version 1.32 are the counterparts to Keen 1 version 1.34. Even
though the version number differs, they are compiled from the same revision of
the shared source code. They also use the same date string "8/7/91" after the
version number.

The versions 1.32 and 1.34 don't actually fix any bugs in the code, nor do they
add any useful new features. That is why the only project files available in
this release are set up for version 1.31 by default. Version 1.34 actually adds
a new bug that prevents the game from quitting to DOS when an error message is
passed to the Quit function. That, in combination with the fact that versions
1.32 and 1.34 use a different EGAHEAD format that might be incompatible with
existing modding tools for Keen 1-3, makes them a bad basis for source modding.
You are probably better off basing source code mods on the 1.31 code.

There are still a couple of bugs and some potentially problematic code design
in the 1.31 code base. The most severe one is described in the "Recommended
source code modifications" section below. Just search the code for the words
BUG and WARNING to find the others.


Using a different compiler
==========================

If you want to use this source code to create your own modified version of one
of the Keen episodes 1 to 3, I would strongly recommend that you upgrade to
Borland C++ 3.1 instead of using Turbo C++ 1.00. Borland C++ 3.1 is more stable
and it can use far more memory when compiling the code, so you will be less
likely to run out of memory when compiling complex code. It also features
syntax highlighting in the built-in editor, but you are probably better off
using a modern text editor with syntax highlighting for C code instead.

To use Borland C++ instead of Turbo C++, you will need to edit the _RUNTC.BAT
file and replace the "tc" command with "bc". After this change, you should be
able to drag-and-drop any of the RCK?.BAT files onto your shortcut to DOSBox
and the files will now try to open the associated project in Borland C++
instead of Turbo C++.

If you want to use MAKE and the makefiles to compile the code in Borland C++,
you will need to edit each of the RCK*.MAK files in a text editor and change
the line starting with "CC = tcc" into "CC = bcc" because the command-line
compiler executable in Borland C++ is BCC.EXE, not TCC.EXE. You could also go
to the BIN subdirectory of your Borland C++ installation and create a copy of
BCC.EXE and name the copy TCC.EXE if you prefer that.

Of course, you will also need to edit MOUNTDIRS.BAT and make sure your Borland
C++ directory gets mounted as drive X: in DOSBox. Note that Borland C++ 2.0,
3.0 and 3.1 come bundled with a copy of Turbo Assembler, which means you don't
need to mount a separate TASM directory as drive W: and you don't need the
";W:\" bit at the end of the new PATH environment string. The compiler is most
likely going to use the TASM.EXE file from your Borland C++ directory anyway.

You should avoid using Turbo C++ 3.0 (I mean "Turbo C++", not "Borland C++"!)
because Turbo C++ 3.0 has a major bug in its huge pointer implementation.
Using ++ or -- on a huge pointer variable (like in the WriteHuge function in
KEENMAIN.C and in the LZW decompression code in IDLIB.C) will generate
incorrect code when compiled with Turbo C++ 3.0. This would not be a (excuse
the pun) huge problem for Keen 2 and 3, since they omit the LZW decompression
code by default and the WriteHuge function is never used at all, but I strongly
recommend avoiding Turbo C++ 3.0 whenever you can.


Recommended source code modifications
-------------------------------------

Using a different compiler means you will not be able to compile the code into
100% identical copies of the original executables anyway, so you can -- and you
should -- get rid of the BSSCHEAT files. Those files just rename the variables
in the so-called BSS segment (uninitialized global/static variables) to make
them appear in the same order as in the original executables. If the compiler
encounters any problems related to these renamed variables, it will report the
new names instead of the names used in the .C files, which just makes dealing
with warnings and error messages more complicated than it needs to be. There
are two ways to get rid of the renaming:

 1: Edit BSSCHEAT.H and BSSCHEAT.EQU and delete literally everything.

 2: Edit VERSION.H and delete the #include "BSSCHEAT.H" directive, then edit
    IDASM.ASM and delete the INCLUDE "BSSCHEAT.EQU" line. You can also delete
    the BSSCHEAT.H and BSSCHEAT.EQU files after these changes.

###############################################################################
But BEWARE: There is an extremely nasty bug in the source code that will
inevitably cause memory corruption when you play the games. That bug is found
in the ScanWorldMap function in KEENDEMO.C, where the code attempts to use an
invalid index to access the entrances array. Just search for "#if 1" in that
file and turn it into "#if 0" to use the bugfix that I have prepared for you.
###############################################################################

Since the info plane value 255 is used to mark the player's spawn position on
the world map, the original code will ALWAYS find that value in the info plane
and it will ALWAYS write to entrances[254] as a result. But the entrances array
has a length of 16, so this operation will definitely corrupt whatever follows
after the entrances array in memory. In the original Keen 1-3 executables, this
will write to the buffers that got assigned to the stdin and stdout streams.
These streams aren't used mid-game, so the corruption will usually be harmless.

But as soon as you move away from the original compiler version (Turbo C++ 1.00
or Borland C++ 2.0) or my BSS layout recreation "cheat", you cannot rely on the
variables having the same order anymore. That is why you ABSOLUTELY NEED TO FIX
THAT BUG!

There are a few other routines that may lead to memory corruption. Most of the
routines that add a new entry to an array of data structures do not check if
there is any space left to add a new entry. Examples are RF_PlaceSprite,
RF_PlaceTile, FindFreeObj and FindFreePObj. This is usually not a problem, but
it can become a problem when a mod places too many things (too many bridges or
too many actors) in a level. Having too many active bridges in a level could
fill the PObj list (there can only be up to 16 PObj entries by default). Too
many enemies can also be a problem, especially when those enemies can fire
projectiles. And having too many sprites behind foreground tiles could cause
the game to add too many entries to the tilearray and/or add too many entries
to the coverlist array.

It would be a good idea to add a few lines of code that check if there is space
left and then either quit with an error message when there is not enough space
for another entry, or simply skip adding the new entry. The latter will not
always be possible without causing other problems: FindFreeObj and FindFreePObj
are expected to return a valid pointer to the new object entry, so you would
need to either rewrite all the code that uses these functions or you will have
to make the functions overwrite an old array entry.


DOSBox 0.74-3 issues and workarounds
====================================

When using the latest "official" DOSBox build version 0.74-3 for Windows, you
will face certain quirks when working with Turbo C++ or Borland C++.

- Using the "Build all" option from the "Compile" menu will not work as
  intended. It will have the same effect as "Make EXE file", meaning only the
  files that have been changed will be re-compiled.

- TASM might be unable to overwrite outdated .OBJ files. If you get an "Error
  writing object file" message, delete the respective .OBJ file manually
  outside DOSBox and compile again. The preceding "Transfer to program: Turbo
  Assembler" message should tell you which file caused this error.

  Note: If you are using MAKE, the old .OBJ file will be deleted automatically
  when TASM reports an error, so you can usually run the exact same command a
  second time and it should work.

- While I was working on my reconstruction of the BioMenace source code, I had
  a few problems with the Borland C++ 2.0 IDE outright crashing DOSBox
  sometimes. This hasn't happened to me while using Turbo C++ 1.00 yet, but
  that doesn't mean it won't happen to you.

Other "forks" of DOSBox might have already fixed these problems. DOSBox Staging
v0.81.0 doesn't appear to have these problems, so you might want to use that
instead of the "official" DOSBox version.


Technical difficulties
======================

I had a lot of technical difficulties with Borland C++ 2.0 while reconstructing
the source code for various versions of BioMenace last year. Turbo C++ 1.00 is
the predecessor of that compiler, so similar issues are to be expected here.

I already had a few instances where the Turbo C++ 1.00 IDE just locked up and
didn't respond to anything. You are probably better off using MAKE instead of
TC to compile the code.


Special Thanks
==============

I would like to thank Adrian Carmack, John Carmack, Tom Hall and John Romero
for creating Commander Keen 1-3 in the first place.

Special thanks to John Carmack (and the rest of id Software) for releasing the
Wolfenstein 3-D and Spear of Destiny source code to the public in July 1995.

Extra special thanks to the late Richard Mandel of Flat Rock Software and
everybody else involved in the process of getting the source code of some of
the games id Software made for Softdisk (Catacomb series, Hovertank, Keen
Dreams) released to the public. I have learned a lot from the source code of
these games and this project certainly would not have been possible without it.

Thanks to PCKF users Multimania and Calvero for supplying additional
information regarding the names of functions, variables and constants.

And last, but not least, I would like to thank NY00123 for sharing a lot of
valuable information about the "gamesrc-ver-recreation" project in various
public posts on the RGB Classic Games Forum (among other places). That's where
I first heard about the TDUMP utility, which is certainly a much better way to
extract names from the debugging information that some executables came with.
And using IDA to open executables and then make IDA generate ASM files that can
be compared more easily using tools like FC in Windows/DOS is pretty much the
best way to track down differences between those two executables without going
insane.

[END OF FILE]