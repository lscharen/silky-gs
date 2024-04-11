; Swizzle tables based on AreaType
;
; IIgs palette index 0 is always the background color: 'BBB'
; IIgs palette index 0 is always the color cycling color 'RRR'
;
; The rest are remapped.
;
; Underground  (AreaType = $02)
;
; T0: $0F $29 $1A $09
; T1: --- $3C $1C $0F
; T2: --- $30 $21 $1C
; T3: --- RRR $17 $1C
; S0: --- --- $27 --- --> $37 $27 $16
; S1: --- $1C $36 $17
; S2: --- $16 $30 $27
; S3: --- $1D $3C $1C --> $0F  RR $29 $1A  $09 $3C $1C $30  $21 $17 $27 $36  $16 $1D $16 $18: 0 free colors
;                     --> $00 $01 $02 $03  $04 $05 $06 $07  $08 $09 $0A $0B  $0C $0D $0E $0F
;
; Mapped palettes
;
; T0: 0 2 3 4
; T1: 0 5 6 0
; T2: 0 7 8 6
; T3: 0 1 9 6
; S0: 0 E A F
; S1: 0 6 B 9
; S2: 0 C 7 A
; S3: 0 D 5 6
;
; Above Ground  (AreaType = $01)
;
; T0: $22 $29 $1A $0F
; T1: --- $36 $17 $0F
; T2: --- $30 $21 $0F
; T3: --- RRR $17 $0F
; S0: --- $16 $27 $18 --> $37 $27 $16
; S1: --- $1A $30 $27
; S2: --- $16 $30 $27                                                                $16 $18
; S3: --- $0F $36 $17 --> $22  RR $29 $1A  $0F $36 $17 $30  $21 $27 $1A $16  --- --- SS1 SS2 : 2 free colors
;                     --> $00 $01 $02 $03  $04 $05 $06 $07  $08 $09 $0A $0B  $0C $0D $0E $0F
; Mapped palettes
;
; T0: 0 2 3 4
; T1: 0 5 6 4
; T2: 0 7 8 4
; T3: 0 1 6 4
; S0: 0 E 9 F
; S1: 0 A 7 9
; S2: 0 B 7 9
; S3: 0 4 5 6
;
; Castle (AreaType = $00)
; Bowser changes S1 palette when he loads
;
; T0: $0F $30 $10 $00
; T1: --- $30 $10 $00
; T2: --- $30 $16 $00
; T3: --- RRR $17 $00
; S0: --- SS1 $27 SS2 
; S1: --- $1C $36 $17
; S2: --- $16 $30 $27                                                                $16 $18
; S3: --- $1D $30 $10 --> $0F  RR $30 $10  $00 $16 $17 $27  $1C $36 $17 $1D   --- --- SS1 SS2 : 2 free colors
;                     --> $00 $01 $02 $03  $04 $05 $06 $07  $08 $09 $0A $0B  $0C $0D $0E $0F
; Mapped palettes
;
; T0: 0 2 3 4
; T1: 0 2 3 4
; T2: 0 2 5 4
; T3: 0 1 6 4
; S0: 0 E 7 F
; S1: 0 8 9 A
; S2: 0 5 2 7
; S3: 0 B 2 3
;
; Water
;
; T0: BBB $15 $12 $25
; T1: --- $3A $1A $0F
; T2: --- $30 $12 $0F
; T3: --- RRR $12 $0F
; S0: --- SS1 $27 SS2 
; S1: --- $10 $30 $27
; S2: --- $16 $30 $27
; S3: --- $0F $30 $10 --> BBB RRR $15 $12  $25 $3A $1A $0F  $30 $12 $27 $10  $16 --- SS1 SS2 : 1 free colors
;                     --> $00 $01 $02 $03  $04 $05 $06 $07  $08 $09 $0A $0B  $0C $0D $0E $0F
; Mapped palettes
;
; T0: 0 2 3 4
; T1: 0 5 6 7
; T2: 0 8 9 7
; T3: 0 1 9 7
; S0: 0 E A F
; S1: 0 B 8 A
; S2: 0 C 8 A
; S3: 0 7 8 B