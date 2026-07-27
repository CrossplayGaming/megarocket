@echo off
rem bcc makeobj.c

makeobj f ENDSCRN.CK1 ..\rck1\endscrn.obj _EndScreen _endscreen
..\TILINF2C\TILINF2C.EXE TILEINFO.CK1 ..\TINFCK1.C

if exist ENDSCRN.K1B makeobj f ENDSCRN.K1B ..\rck1beta\endscrn.obj _EndScreen _endscreen
if exist TILEINFO.K1B ..\TILINF2C\TILINF2C.EXE TILEINFO.K1B ..\TINFK1B.C

if exist ENDSCRN.PSA makeobj f ENDSCRN.PSA ..\rck1v134\endscrn.obj _EndScreen _endscreen

if exist INTROSCN.GRA makeobj f INTROSCN.GRA ..\rck1v132\introscn.obj _IntroScreen _introscn

if exist ENDSCRN1.CK2 makeobj f ENDSCRN1.CK2 ..\rck2v10\endscrn.obj _EndScreen _endscreen
if exist ENDTEXT.PS2  makeobj f ENDTEXT.PS2  ..\rck2v132\endtext.obj _EndText _endtext
if exist PREVIEWS.PS2 makeobj f PREVIEWS.PS2 ..\rck2v132\previews.obj _Previews _previews

makeobj f ENDSCRN.CK2 ..\rck2\endscrn.obj _EndScreen _endscreen
makeobj f SOUNDS.CK2 ..\rck2\sounds.obj _SoundFile __sounds
makeobj f ENDTEXT.CK2 ..\rck2\endtext.obj _EndText _endtext
makeobj f HELPTEXT.CK2 ..\rck2\helptext.obj _HelpText _helptext
makeobj f PREVIEWS.CK2 ..\rck2\previews.obj _Previews _previews
makeobj f STORYTXT.CK2 ..\rck2\storytxt.obj _StoryTxt _storytxt
..\TILINF2C\TILINF2C.EXE TILEINFO.CK2 ..\TINFCK2.C

if exist ENDSCRN1.CK3 makeobj f ENDSCRN1.CK3 ..\rck3v10\endscrn.obj _EndScreen _endscreen
if exist ENDTEXT.PS3  makeobj f ENDTEXT.PS3  ..\rck3v132\endtext.obj _EndText _endtext
if exist PREVIEWS.PS3 makeobj f PREVIEWS.PS3 ..\rck3v132\previews.obj _Previews _previews

makeobj f ENDSCRN.CK3 ..\rck3\endscrn.obj _EndScreen _endscreen
makeobj f SOUNDS.CK3 ..\rck3\sounds.obj _SoundFile __sounds
makeobj f ENDTEXT.CK3 ..\rck3\endtext.obj _EndText _endtext
makeobj f HELPTEXT.CK3 ..\rck3\helptext.obj _HelpText _helptext
makeobj f PREVIEWS.CK3 ..\rck3\previews.obj _Previews _previews
makeobj f STORYTXT.CK3 ..\rck3\storytxt.obj _StoryTxt _storytxt
..\TILINF2C\TILINF2C.EXE TILEINFO.CK3 ..\TINFCK3.C

copy ..\rck1\endscrn.obj ..\rck1v10\endscrn.obj
copy ..\rck1\endscrn.obj ..\rck1v11\endscrn.obj
copy ..\rck1\endscrn.obj ..\rck1v13\endscrn.obj
copy ..\rck1\endscrn.obj ..\rck1v132\endscrn.obj
copy ..\rck2\endscrn.obj ..\rck2v11\endscrn.obj
copy ..\rck3\endscrn.obj ..\rck3v11\endscrn.obj
copy ..\rck1v134\endscrn.obj ..\rck2v132\endscrn.obj
copy ..\rck1v134\endscrn.obj ..\rck3v132\endscrn.obj

copy ..\rck2\sounds.obj ..\rck2v10\sounds.obj
copy ..\rck2\sounds.obj ..\rck2v11\sounds.obj
copy ..\rck2\sounds.obj ..\rck2v132\sounds.obj
copy ..\rck2\endtext.obj ..\rck2v10\endtext.obj
copy ..\rck2\endtext.obj ..\rck2v11\endtext.obj
copy ..\rck2\helptext.obj ..\rck2v10\helptext.obj
copy ..\rck2\helptext.obj ..\rck2v11\helptext.obj
copy ..\rck2\helptext.obj ..\rck2v132\helptext.obj
copy ..\rck2\previews.obj ..\rck2v10\previews.obj
copy ..\rck2\previews.obj ..\rck2v11\previews.obj
copy ..\rck2\storytxt.obj ..\rck2v10\storytxt.obj
copy ..\rck2\storytxt.obj ..\rck2v11\storytxt.obj
copy ..\rck2\storytxt.obj ..\rck2v132\storytxt.obj

copy ..\rck3\sounds.obj ..\rck3v10\sounds.obj
copy ..\rck3\sounds.obj ..\rck3v11\sounds.obj
copy ..\rck3\sounds.obj ..\rck3v132\sounds.obj
copy ..\rck3\endtext.obj ..\rck3v10\endtext.obj
copy ..\rck3\endtext.obj ..\rck3v11\endtext.obj
copy ..\rck3\helptext.obj ..\rck3v10\helptext.obj
copy ..\rck3\helptext.obj ..\rck3v11\helptext.obj
copy ..\rck3\helptext.obj ..\rck3v132\helptext.obj
copy ..\rck3\previews.obj ..\rck3v10\previews.obj
copy ..\rck3\previews.obj ..\rck3v11\previews.obj
copy ..\rck3\storytxt.obj ..\rck3v10\storytxt.obj
copy ..\rck3\storytxt.obj ..\rck3v11\storytxt.obj
copy ..\rck3\storytxt.obj ..\rck3v132\storytxt.obj
