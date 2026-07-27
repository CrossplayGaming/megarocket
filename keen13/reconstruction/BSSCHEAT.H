#ifndef BSSCHEAT
#define BSSCHEAT
/*
=============================================================================
BSS LAYOUT RECREATION CHEAT

I couldn't use my old trick of grouping the BSS segment variables into a
struct to recreate the original layout, since some of the variables need to
be accessed from the assembly code. That's part of the reason why Keen 1-3
were more difficult to reconstruct than Keen 4-6.

Make sure these names match the ones used in BSSCHEAT.EQU!
=============================================================================
*/

#if VERSION <= VER_131

// KEENMAIN.C:
/*
#define lasttimecount  _o0me
#define monxmax        _4KNO
#define monymax        __jo4
#define originxmin     _X8PZ
#define originymin     _mw1E
#define EGApage        _wrr0
#define mapwidthextra  _leSi
#define ox             _ckt_
#define uservect       _Qw5Z
#define _unk_main_1    _yU68
#define coverlist      _kLwY
#define joystickok     _DsXc
#define oy             _Qh9W
#define tics           _XCZF
#define oldtiles       _dl_p
#define cheatmode      _8dax
#define playerxmax     _ymBy
#define playerymax     _qCCx
#define numobj         _e5D0
#define coverlistptr   _y_E3
#define oldtiles2      _Q7FD
#define lastdir        _uSGs
#define spritelist     _LVhK
#define mapbwide       _8miL
#define mapwwide       _iOJH
#define picbuf         _LakO
#define piclist        _eFLi
#define _unk_main_2    _X3mz
#define mapplane       _TEnH
#define mapheight      _x_oS
#define _unk_main_3    _EKPx
#define LevelDone      _T7qU
#define cyclespeed     _BW2e
#define tilelist       _Jt31
#define levelnum       _UrTR
#define resetgame      _fV5x
#define spritesshown   _Xtvr
#define LevelNumber    _np7O
#define lastextra      _P_xp
#define spritelistptr  _1SYo
#define levelheader    _eBZU
#define picsshown      _eX_v
#define piclistptr     _U3aV
#define originx        _5xbg
#define originy        _noCz
#define tilesshown     _F_Di
#define objlist        _jzE7
#define tilelistptr    _q6fd
#define KBDstarted     _q_gE
#define originxmax     _Unh_
#define originymax     _uoiD
#define SNDstarted     _jEJj
#define _unk_main_4    _bUKD
*/
// KEENACTS.C:

//These names aready generate the correct order, no need to rename them.
/*
#define ctrl          _mQll
#define ctrl2         _1YmS
#define pobjlist      _I_nL
#define pobjcount     _NKO_
#define switchxtile   _NOPu
#define switchytile   _kD18
#define sparksgone    _Ke29
#define lightson      _kM3Z
#define obon          _FQTj
#define ankhtime      _6vUC
#define buttontouched _yyvn
*/

// IDLIB.C:

#define lzw_compbuf      _O7mb
#define spriteDestOffset _Ghni
#define score            _cEoi
#define lzw_codes        _Skph
#define JoyXlow          _M81P
#define JoyXhigh         _dpRm
#define JoyYlow          _tmSp
#define JoyYhigh         _Ua4d
#define sx               __wud
#define keyB1            _QU6f
#define keyB2            _dzWS
#define _unk_idlib_2     _05Xg
#define str              _Wfyn
#define egasprites       _TdZU
#define key              _HH_E
#define lzw_bitbuffer    _0waq
#define lzw_bitsavail    _l9bY
#define sy               _dHc2
#define _unk_idlib_3     _iEDV
#define charptr          _aFEX
#define _unk_idlib_4     _PgfF
#define level            _QYG7
#define image            _q0Hi
#define lzw_maxcodelen   _yZIC
#define lzw_dest         _DWje
#define _unk_idlib_5     _maKQ
#define playermode       _URLl
#define numpics          _9qMy
#define maprle           _yLNT
#define lzw_maxcode      _9OOb
#define picptr           _iCPL
#define spritetable      _hvqR
#define numtiles         _MXRE
#define leftedge         _5VS1
#define lzw_tablesize    _pgt5
#define win_xl           _XTuE
#define win_xh           _RE68
#define lzw_extrabits    _9EWD
#define win_yl           _1wXZ
#define win_yh           _m6Ys
#define demoptr          _drzm
#define pictable         _IW_Q
#define tileptr          _q_aj
#ifdef OLDKEYBOARD
#define keydown          _ZdBR
#endif
#define MouseSensitivity _2CCC
#define numchars         _UYda
#define demobuffer       _R_EJ
#define lzw_codelen      _vdFl
#define _unk_idlib_6     _J6GC
#define numsprites       _ZCHx
#define videocard        _96iU
#define indemo           _Majy
#define lzw_stack        _mdkw
#define _unk_idlib_7     _1Plz
#define lzw_values       _2zMM
#define spriteSourceOffset _fkNs
#define lastparalloc     _MBoW
#define ch               _cb0f

// KEENSCRN.C:

#define mapkeen          _USqN

// KEENDEMO.C:

#define previewsPtr      _CZ2q
#define infoBlockMask    _c13h
#define textLineOffsets  _oD4T
#define textdataPtr      _Wu5W
#define textWindowX      _QlvG
#define textWindowMinY   _q_wS
#define textVisibleLines _QsxM
#define textWindowMaxY   _jEY6
#define forcemenu        _I3zx
#define messiexmove      _23_q
#define messieymove      _2zaW
#define worldkeenx       _w9Bv
#define worldkeeny       _WdCv
#define messiex          _nVdN
#define messiey          _ZKeL
#define messiedummy      _SZFK
#define worldCamX        _vEgo
#define worldCamY        _JphN
#define storytxtPtr      _jfiS
#define messiecount      _WxJp
#define entrances        _7UKD
#define line_offsets     _B6ly
#define restoredGame     _sPMH
#define helptextPtr      __nNN
#define messieshape      _KvOZ
#define messiecooldown   _bmpF
#define gamestate        _Hw1s
#define warps            _KSRe
#define messieoldtilex   _HO3Y
#define messieoldtiley   _Nqt_
#define messiestate      _7RU9
#define endtextPtr       _d96b
#define oldx             _RJwp
#define oldy             _0B8n
#define canSave          _tn9l
#define highscores       _g8ZQ
#define olderror         _oF_4

#else	// version 1.32 and 1.34

// KEENMAIN.C:
/*
#define objlist        _o0me
#define tilelistptr    _4KNO
#define KBDstarted     __jo4
#define originxmax     _X8PZ
#define originymax     _mw1E
#define SNDstarted     _wrr0
#define _unk_main_4    _leSi
#define lasttimecount  _ckt_
#define monxmax        _Qw5Z
#define monymax        _yU68
#define originxmin     _kLwY
#define originymin     _DsXc
#define EGApage        _Qh9W
#define mapwidthextra  _XCZF
#define ox             _dl_p
#define uservect       _8dax
#define _unk_main_1    _ymBy
#define coverlist      _qCCx
#define joystickok     _e5D0
#define oy             _y_E3
#define tics           _Q7FD
#define oldtiles       _uSGs
#define cheatmode      _LVhK
#define playerxmax     _8miL
#define playerymax     _iOJH
#define numobj         _LakO
#define coverlistptr   _eFLi
#define oldtiles2      _X3mz
#define lastdir        _TEnH
#define spritelist     _x_oS
#define mapbwide       _EKPx
#define mapwwide       _T7qU
#define picbuf         _BW2e
#define piclist        _Jt31
#define _unk_main_2    _UrTR
#define mapplane       _fV5x
#define mapheight      _Xtvr
#define _unk_main_3    _np7O
#define LevelDone      _P_xp
#define cyclespeed     _1SYo
#define tilelist       _eBZU
#define levelnum       _eX_v
#define resetgame      _U3aV
#define spritesshown   _5xbg
#define LevelNumber    _noCz
#define lastextra      _F_Di
#define spritelistptr  _jzE7
#define levelheader    _q6fd
#define picsshown      _q_gE
#define piclistptr     _Unh_
#define originx        _uoiD
#define originy        _jEJj
#define tilesshown     _bUKD
*/
// KEENACTS.C:

//These names aready generate the correct order, no need to rename them.
/*
#define ankhtime       _mQll
#define buttontouched  _1YmS
#define ctrl           _I_nL
#define ctrl2          _NKO_
#define pobjlist       _NOPu
#define pobjcount      _kD18
#define switchxtile    _Ke29
#define switchytile    _kM3Z
#define sparksgone     _FQTj
#define lightson       _6vUC
#define obon           _yyvn
*/

// IDLIB.C:

#define lastparalloc     _O7mb
#define ch               _Ghni
#define lzw_compbuf      _cEoi
#define spriteDestOffset _Skph
#define score            _M81P
#define lzw_codes        _dpRm
#define JoyXlow          _tmSp
#define JoyXhigh         _Ua4d
#define JoyYlow          __wud
#define JoyYhigh         _QU6f
#define sx               _dzWS
#define latchsize        _05Xg
#define keyB1            _Wfyn
#define keyB2            _TdZU
#define _unk_idlib_2     _HH_E
#define str              _0waq
#define egasprites       _l9bY
#define key              _dHc2
#define lzw_bitbuffer    _iEDV
#define lzw_bitsavail    _aFEX
#define sy               _PgfF
#define _unk_idlib_3     _QYG7
#define charptr          _q0Hi
#define _unk_idlib_4     _yZIC
#define level            _DWje
#define image            _maKQ
#define lzw_maxcodelen   _URLl
#define lzw_dest         _9qMy
#define _unk_idlib_5     _yLNT
#define playermode       _9OOb
#define numpics          _iCPL
#define maprle           _hvqR
#define lzw_maxcode      _MXRE
#define picptr           _5VS1
#define spritetable      _pgt5
#define numtiles         _XTuE
#define leftedge         _RE68
#define lzw_tablesize    _9EWD
#define win_xl           _1wXZ
#define win_xh           _m6Ys
#define lzw_extrabits    _drzm
#define win_yl           _IW_Q
#define win_yh           _q_aj
#define demoptr          _ZdBR
#define pictable         _2CCC
#define tileptr          _UYda
#ifdef OLDKEYBOARD
#define keydown          _R_EJ
#endif
#define MouseSensitivity _vdFl
#define numchars         _J6GC
#define demobuffer       _ZCHx
#define lzw_codelen      _96iU
#define _unk_idlib_6     _Majy
#define numsprites       _mdkw
#define videocard        _1Plz
#define indemo           _2zMM
#define lzw_stack        _fkNs
#define _unk_idlib_7     _MBoW
#define lzw_values       _cb0f
#define spriteSourceOffset _USqN

// KEENSCRN.C:

#define mapkeen          _CZ2q

// KEENDEMO.C:

#define endtextPtr       _c13h
#define oldx             _oD4T
#define oldy             _Wu5W
#define canSave          _QlvG
#define highscores       _q_wS
#define olderror         _QsxM
#define previewsPtr      _jEY6
#define infoBlockMask    _I3zx
#define textLineOffsets  _23_q
#define textdataPtr      _2zaW
#define textWindowX      _w9Bv
#define textWindowMinY   _WdCv
#define textVisibleLines _nVdN
#define textWindowMaxY   _ZKeL
#define forcemenu        _SZFK
#define messiexmove      _vEgo
#define messieymove      _JphN
#define worldkeenx       _jfiS
#define worldkeeny       _WxJp
#define messiex          _7UKD
#define messiey          _B6ly
#define messiedummy      _sPMH
#define worldCamX        __nNN
#define worldCamY        _KvOZ
#define storytxtPtr      _bmpF
#define messiecount      _Hw1s
#define entrances        _KSRe
#define line_offsets     _HO3Y
#define restoredGame     _Nqt_
#define helptextPtr      _7RU9
#define messieshape      _d96b
#define messiecooldown   _RJwp
#define gamestate        _0B8n
#define warps            _tn9l
#define messieoldtilex   _g8ZQ
#define messieoldtiley   _oF_4
#define messiestate      _wyar

#endif	// if VERSION <= VER_131 ... else ...

#endif	// ifndef BSSCHEAT