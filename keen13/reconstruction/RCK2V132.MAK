.AUTODEPEND

PROJECT = rck2v132
CONFIGFILE = $(PROJECT).cfg
MAKEFILE = $(PROJECT).mak

.PATH.obj = $(PROJECT)

#		*Translator Definitions*
CC = bcc +$(CONFIGFILE)
TASM = TASM
TLIB = tlib
TLINK = tlink
LIBPATH = X:\LIB
INCLUDEPATH = X:\INCLUDE


#		*Implicit Rules*
.c.obj:
  $(CC) -c {$< }

.cpp.obj:
  $(CC) -c {$< }

#		*List Macros*


EXE_dependencies =  \
 tinfck2.obj \
 keenmain.obj \
 idlibc.obj \
 keen2act.obj \
 keendemo.obj \
 keenscrn.obj \
 $(PROJECT)\idasm.obj \
 $(PROJECT)\endtext.obj \
 $(PROJECT)\helptext.obj \
 $(PROJECT)\previews.obj \
 $(PROJECT)\sounds.obj \
 $(PROJECT)\storytxt.obj \
 $(PROJECT)\endscrn.obj

#		*Explicit Rules*
$(PROJECT)\$(PROJECT).exe: $(CONFIGFILE) $(EXE_dependencies)
  $(TLINK) /x/c @&&|
$(LIBPATH)\c0s.obj+
$(PROJECT)\tinfck2.obj+
$(PROJECT)\keenmain.obj+
$(PROJECT)\idlibc.obj+
$(PROJECT)\keen2act.obj+
$(PROJECT)\keendemo.obj+
$(PROJECT)\keenscrn.obj+
$(PROJECT)\idasm.obj+
$(PROJECT)\endtext.obj+
$(PROJECT)\helptext.obj+
$(PROJECT)\previews.obj+
$(PROJECT)\sounds.obj+
$(PROJECT)\storytxt.obj+
$(PROJECT)\endscrn.obj
$(PROJECT)\$(PROJECT)
		# no map file
$(LIBPATH)\cs.lib
|


#		*Individual File Dependencies*
tinfck2.obj: $(CONFIGFILE) tinfck2.c 

keenmain.obj: $(CONFIGFILE) keenmain.c 

idlibc.obj: $(CONFIGFILE) idlibc.c 

keen2act.obj: $(CONFIGFILE) keen2act.c 

keendemo.obj: $(CONFIGFILE) keendemo.c 

keenscrn.obj: $(CONFIGFILE) keenscrn.c 

$(PROJECT)\idasm.obj: $(MAKEFILE) idasm.asm 
	$(TASM) /MX /ZI /O /DNEWORDER idasm.asm,$(PROJECT)\idasm.obj

#		*Compiler Configuration File*
$(CONFIGFILE): $(MAKEFILE)
  copy &&|
-f-
-v
-vi-
-weas
-n$(PROJECT)
-DVERSION=0x0134
-I$(INCLUDEPATH)
-L$(LIBPATH)
-DEPISODE=2
-P-.C
| $(CONFIGFILE)


