con_00  = $00 ; horisontally write ?? tiles
con_40  = $40 ; horisontally write a tile ?? times
con_80  = $80 ; vertically write ?? tiles
con_C0  = $C0 ; vertically write a tile ?? times

_off000_0x0050B0_05_00
  ddb $23E0
  db con_40 + $20   ; 
  db $AA   ; 
  ddb $23E8
  db con_40 + $08   ; 
  db $50   ; 
  ddb $23F0
  db con_40 + $08   ; 
  db $AF   ; 
  ddb $2062
  db con_00 + $01   ; 
  db $77   ; 
  ddb $2063
  db con_40 + $1A   ; 
  db $7A   ; 
  ddb $207D
  db con_00 + $01   ; 
  db $7C   ; 
  ddb $2082
  db con_C0 + $09   ; 
  db $78   ; 
  ddb $21A2
  db con_00 + $01   ; 
  db $79   ; 
  ddb $21A3
  db con_40 + $1A   ; 
  db $7B   ; 
  ddb $209D
  db con_C0 + $09   ; 
  db $7D   ; 
  ddb $21BD
  db con_00 + $01   ; 
  db $7E   ; 
  ddb $2083
  db con_40 + $1A   ; 
  db $FD   ; 
  ddb $20A3
  db con_40 + $1A   ; 
  db $FD   ; 
  ddb $20C3
  db con_40 + $1A   ; 
  db $FD   ; 
  ddb $20E3
  db con_40 + $1A   ; 
  db $FD   ; 
  ddb $2103
  db con_40 + $1A   ; 
  db $FD   ; 
  ddb $208B
  db con_00 + $0A   ; 
  db $5E, $FD, $FD, $60, $61, $61, $FD, $60, $61, $61   ; 
  ddb $20AB
  db con_00 + $0A   ; 
  db $5F, $FD, $FD, $5F, $62, $FD, $FD, $5F, $66, $68   ; 
  ddb $20CB
  db con_00 + $0A   ; 
  db $5F, $FD, $FD, $5F, $63, $FD, $FD, $5F, $67, $69   ; 
  ddb $20EB
  db con_00 + $0A   ; 
  db $5F, $FD, $FD, $64, $65, $61, $FD, $64, $65, $61   ; 
  ddb $2123
  db con_00 + $1A   ; 
  db $60, $61, $61, $FD, $5E, $FD, $FD, $FD, $5E, $FD, $60, $6A, $60, $6A, $FD, $60   ; 
  db $61, $6A, $FD, $60, $61, $61, $FD, $60, $61, $6A   ; 
  ddb $2143
  db con_00 + $1A   ; 
  db $5F, $62, $FD, $FD, $5F, $FD, $FD, $FD, $5F, $FD, $5F, $6B, $6C, $6D, $FD, $5F   ; 
  db $6E, $71, $FD, $5F, $66, $68, $FD, $5F, $6E, $71   ; 
  ddb $2163
  db con_00 + $1A   ; 
  db $5F, $63, $FD, $FD, $5F, $63, $FD, $FD, $5F, $FD, $5F, $74, $75, $5F, $FD, $5F   ; 
  db $6F, $72, $FD, $5F, $67, $69, $FD, $5F, $76, $72   ; 
  ddb $2183
  db con_00 + $1A   ; 
  db $64, $65, $61, $FD, $64, $65, $61, $FD, $5F, $FD, $5F, $FD, $FD, $5F, $FD, $5F   ; 
  db $70, $73, $FD, $64, $65, $61, $FD, $5F, $FD, $5F   ; 
  ddb $220A
  db con_00 + $0D   ; 
  db $01, $38, $8D, $37, $33, $A3, $3D, $8E, $38, $36, $33, $3C, $3D   ; 
  ddb $224A
  db con_00 + $0D   ; 
  db $02, $38, $8D, $37, $33, $A3, $3D, $8E, $38, $36, $33, $3C, $3D   ; 
  ddb $228A
  db con_00 + $08   ; 
  db $3C, $5B, $93, $5A, $3A, $33, $3B, $5A   ; 
  ddb $22CA
  db con_00 + $03   ; 
  db $7F, $80, $81   ; 
  ddb $22D2
  db con_00 + $05   ; 
  db $00, $3E, $3F, $40, $41   ; 
  ddb $2305
  db con_00 + $01   ; 
  db $83   ; 
  ddb $230B
  db con_00 + $05   ; 
  db $00, $3E, $3F, $40, $41   ; 
  ddb $2312
  db con_00 + $02   ; 
  db $82, $83   ; 
  ddb $2319
  db con_00 + $05   ; 
  db $00, $3E, $3F, $40, $41   ; 
  ddb $2369
  db con_00 + $0E   ; 
  db $FC, $01, $09, $08, $04, $38, $5A, $3B, $5A, $3A, $3D, $5A, $35, $5B   ; 
  db $00   ; end token

  ddb $3F00
  db con_00 + $14   ; 
  db $0F, $31, $12, $30   ; 
  db $0F, $25, $29, $0A   ; 
  db $0F, $30, $21, $01   ; 
  db $0F, $27, $17, $07   ; 
  db $0F, $30, $12, $26   ; 
  db $00   ; end token

  ddb $23CC
  db con_40 + $04   ; 
  db $55   ; 
  ddb $23D4
  db con_40 + $04   ; 
  db $55   ; 
  ddb $23DC
  db con_40 + $04   ; 
  db $55   ; 
  ddb $23E4
  db con_40 + $04   ; 
  db $55   ; 
  ddb $23EC
  db con_40 + $04   ; 
  db $55   ; 
  ddb $23F4
  db con_40 + $04   ; 
  db $55   ; 
  ddb $2108
  db con_00 + $06   ; 
  db $5A, $5B, $38, $38, $38, $38   ; 
  ddb $2128
  db con_00 + $06   ; 
  db $34, $5B, $5A, $93, $91, $39   ; 
  ddb $206A
  db con_00 + $08   ; 
  db $3C, $5B, $93, $5A, $3A, $33, $3B, $5A   ; 
  ddb $2082
  db con_00 + $01   ; 
  db $95   ; 
  ddb $20A2
  db con_C0 + $16   ; 
  db $96   ; 
  ddb $2362
  db con_00 + $01   ; 
  db $97   ; 
  ddb $2083
  db con_40 + $0C   ; 
  db $98   ; 
  ddb $2363
  db con_40 + $0C   ; 
  db $99   ; 
  ddb $208F
  db con_00 + $01   ; 
  db $9A   ; 
  ddb $20AF
  db con_C0 + $16   ; 
  db $9B   ; 
  ddb $236F
  db con_00 + $01   ; 
  db $9C   ; 
  ddb $20C5
  db con_00 + $08   ; 
  db $01, $38, $8D, $37, $33, $A3, $3D, $8E   ; 
  ddb $22C6
  db con_00 + $05   ; 
  db $3A, $5B, $3A, $33, $37   ; 
  ddb $22E4
  db con_80 + $03   ; 
  db $84, $85, $86   ; 
  ddb $22E5
  db con_40 + $08   ; 
  db $87   ; 
  ddb $2325
  db con_40 + $08   ; 
  db $88   ; 
  ddb $22ED
  db con_80 + $03   ; 
  db $89, $8A, $8B   ; 
  ddb $230B
  db con_00 + $01   ; 
  db $00   ; 
  db $00   ; end token

  ddb $2116
  db con_00 + $06   ; 
  db $5A, $5B, $38, $38, $38, $38   ; 
  ddb $2136
  db con_00 + $06   ; 
  db $34, $5B, $5A, $93, $91, $39   ; 
  ddb $2090
  db con_00 + $01   ; 
  db $95   ; 
  ddb $20B0
  db con_C0 + $16   ; 
  db $96   ; 
  ddb $2370
  db con_00 + $01   ; 
  db $97   ; 
  ddb $2091
  db con_40 + $0C   ; 
  db $98   ; 
  ddb $2371
  db con_40 + $0C   ; 
  db $99   ; 
  ddb $209D
  db con_00 + $01   ; 
  db $9A   ; 
  ddb $20BD
  db con_C0 + $16   ; 
  db $9B   ; 
  ddb $237D
  db con_00 + $01   ; 
  db $9C   ; 
  ddb $20D3
  db con_00 + $08   ; 
  db $02, $38, $8D, $37, $33, $A3, $3D, $8E   ; 
  ddb $22D4
  db con_00 + $05   ; 
  db $3A, $5B, $3A, $33, $37   ; 
  ddb $22F2
  db con_80 + $03   ; 
  db $84, $85, $86   ; 
  ddb $22F3
  db con_40 + $08   ; 
  db $87   ; 
  ddb $2333
  db con_40 + $08   ; 
  db $88   ; 
  ddb $22FB
  db con_80 + $03   ; 
  db $89, $8A, $8B   ; 
  ddb $2319
  db con_00 + $01   ; 
  db $00   ; 
  db $00   ; end token

  ddb $3F00
  db con_00 + $08   ; 
  db $0F, $30, $21, $11   ; 
  db $0F, $30, $25, $15   ; 
  ddb $3F10
  db con_00 + $0C   ; 
  db $0F, $30, $11, $26   ; 
  db $0F, $30, $15, $26   ; 
  db $0F, $30, $21, $12   ; 
  db $00   ; end token

  db $FF   ; 
  db $FF   ; 