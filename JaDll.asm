
;****************************************************************************************************************;
;																												 ;
;	File: JaDll.asm																								 ;
;																												 ;
;	Binary Image Dilatation 																					 ;
;																											     ;
;	Author: Maciej Caban																						 ;
;																												 ;
;	version  1.0	/ 19.01.2023	- check neighbours from corners												 ;
;	version	 0.3	/ 18.01.2023	- check neighbours from top, bot, left and right							 ;
;	version	 0.2	/ 17.01.2023	- improve sending data to dll												 ;	
;	version	 0.1	/ 16.01.2023	- itaretes trought the image												 ;	
;																												 ;
;	Description:																								 ;
;		Dilation  works on simple rule:																			 ;
;			- if pixel has value "1" (its black) his value wouldnt change										 ;
;			- if pixel has value "0" (its white) program check values of neighbour pixels.						 ;
;				If one of them has value "1", value of checked pixel will change to "1"							 ;
;																												 ;
;****************************************************************************************************************;
;
;	Registers with start values
;		RCX i RSI - ptr on source image
;		RDX i RDI - ptr on destination image
;		R8 i RBX  - ptr on pair Wight and Height
;			R8[0] - Wight
;			R8[1] - Height
;			R8[2] - resolution
;		R9 - current (starting) pixel
;		R14 - last pixel
;
;	Other used registers
;		R10 - Wight (need to compare)
;		R12	- (Res - Wight)  used to calculate if  lower pixel exist  
;	
;		R13	-  used to calculate neighbour pixels pos
;		XMM0, XMM1	- used to calculate if cur  pixel has above and lower pixel
;
;	Registers used to work with corner neighbours
;		R11		-	used to move information wiht XMM2-5
;		XMM0	-	used to check values of registers 2-5
;		XMM2	-	hold information if pixel has left  neighbour
;		XMM3	-	hold information if pixel has above neighbour
;		XMM4	-	hold information if pixel has right neighbour
;		XMM5	-	hold information if pixel has below neighbour
;
;****************************************************************************************************************;

.code
asmDilatation proc
	; move datas to Registers from PTR (easier to use and compare)
	mov R10, QWORD PTR[R8]									;move Wight to R10 
	mov R12, QWORD PTR[R8+16]								;move (Res - Wight) to R12
	sub R12, R10								

_loop:
	cmp  R9, R14							;check if program reached last pixel -> finish program
	JE END_loop

	mov R11, 0								;set informarion about cross neighbours as fasle
	movd XMM2, R11 
	movd XMM3, R11 
	movd XMM4, R11
	movd XMM5, R11 
	mov R11, 1								

;pixel with the same pos
	cmp  BYTE PTR[RCX + R9], 1			 	;if it has "1" in source image set it "1" in destination image
	JE set_black

	
;pixel above
	movd XMM0, R10											;move wight to XMM0
	movd XMM1, R9											;move curr pixel pos to XMM1

	PCMPGTQ XMM0, XMM1						;check if has pixel above -> if Wight>curr pixel posistion 
	MOVD R13, XMM0							;move result of comparison to R13, FF if true, 0 if false
	CMP R13B, 255							
	JE no_above								;true -> pixel is in top row so it doesnt have pixel above

	movd XMM3, R11							;set inf about having above neighbour as true

	mov R13, RCX							;calculate pos of above pixel:   
	add R13, R9								;= currPix(r9) - wight(R10) + ptr on pixel0(RCX)
	SUB R13, R10							
	cmp  BYTE PTR[R13], 1					;check if pixel above has "1" as value
	JE set_black							;if true -> set pisxel "1"
no_above:


;pixel below
	movd XMM0, R12											;move res-wight to XMM0
	movd XMM1, R9											;move curr pixel pos to XMM1

	PCMPGTQ XMM1, XMM0						;check if has below pixel -> if (curr pixel posistion) > (res - wight)
	MOVD R13, XMM1							;move result of comparison to R12, FF if true, 0 if false
	CMP R13B, 255							
	JE no_below								;true -> pixel is in last row so it doesnt have pixel below

	movd XMM5, R11							;set inf about having below neighbour as true

	mov R13, RCX							;calculate pos of below pixel:   
	add R13, R9								;= currPix(r9) + wight(R10) + ptr on pixel0(RCX)
	add R13, R10							
	cmp  BYTE PTR[R13], 1					;check if  below pixel has "1" as value
	JE set_black							;if true -> set pisxel "1"
no_below:


;left pixel
	mov R13, R12							;set R13 as Roz-Wight (left, down corner)


left_bound:
	cmp R9, R13												;check if pixel pos  == R13
	JE no_left								;if true -> pixel belong to left bound -> doesnt have pixel on his left side

	CMP R13, R9								;if R13 reached value <curr pos (R9) -> curr pixel doesnt belong to left bound -> has left neighbour 
	JB has_left

	SUB R13, R10							;move to upper pixel on left bound
	JMP left_bound

	has_left:
	movd XMM2, R11							;set inf about having left neighbour as true

	mov R13, RCX							;calculate pos of left pixel:   
	add R13, R9								;= currPix(r9) -1 + ptr on pixel0(RCX)						
	cmp  BYTE PTR[R13-1], 1					;check if  left pixel has "1" as value
	JE set_black							;if true -> set pisxel "1"
no_left:

;right pixel
	mov R13, QWORD PTR[R8+16]				;mov rez to R13 (right, dowm corner)

right_bound:
	cmp R9, R13										;check if pixel pos == R13
	JE no_right								;if true -> pixel belong to right bound -> doesnt have pixel on his right side

	CMP R13, R9
	JB has_right

	SUB R13, R10							;move to upper pixel on right bound
	JMP right_bound

	has_right:

	movd XMM4, R11							;set inf about having right neighbour as true

	mov R13, RCX							;calculate pos of right pixel:   
	add R13, R9								;= currPix(r9) + 1 + ptr on pixel0(RCX)				
	cmp  BYTE PTR[R13+1], 1					;check if right pixel has "1" as value
	JE set_black							;if true -> set pisxel "1"
no_right:

;need to check corner pixels		
	

;left, above			
;if pixel has left and above neighbours -> has left,above neighbour
	mov R11,0
	movd XMM0, R11							;set 0 - need it to checking  
	PCMPEQB XMM0, XMM2						;check if there is 0 in XMM2 
	MOVD R11, XMM0							;move result of comparison to R11, FF if true, 0 if false
	CMP R11B, 255							;if true -> doenst have left  neighbour -> no need to check above one
	JE no_left_top

	mov R11,0
	movd XMM0, R11							;set 0 - need it to checking  
	PCMPEQB XMM0, XMM3						;check if there is 0 in XMM3 
	MOVD R11, XMM0							;move result of comparison to R11, FF if true, 0 if false
	CMP R11B, 255							;if true -> doenst have above neighbour 
	JE no_left_top

;has left top
	mov R13, RCX							;calculate pos of left, above pixel:   
	add R13, R9								;= currPix(r9) - 1 + ptr on pixel0(RCX) - Wight (R10)		
	sub R13, R10
	cmp  BYTE PTR[R13-1], 1					;check if  left, above pixel has "1" as value
	JE set_black							;if true -> set pisxel "1"
no_left_top:


;right, above			
;if pixel has right and above neighbours -> has right,above neighbour
	mov R11,0
	movd XMM0, R11							;set 0 - need it to checking  
	PCMPEQB XMM0, XMM3						;check if there is 0 in XMM3 
	MOVD R11, XMM0							;move result of comparison to R11, FF if true, 0 if false
	CMP R11B, 255							;if true -> doenst have above neighbour -> no need to check right one
	JE no_right_top

	mov R11,0
	movd XMM0, R11							;set 0 - need it to checking  
	PCMPEQB XMM0, XMM4						;check if there is 0 in XMM4 
	MOVD R11, XMM0							;move result of comparison to R11, FF if true, 0 if false
	CMP R11B, 255							;if true -> doenst have right  neighbour 
	JE no_right_top

;has right top
	mov R13, RCX							;calculate pos of right, above pixel:   
	add R13, R9								;= currPix(r9) + 1 + ptr on pixel0(RCX) - Wight (R10)		
	sub R13, R10
	cmp  BYTE PTR[R13+1], 1					;check if  right, above pixel has "1" as value
	JE set_black							;if true -> set pisxel "1"
no_right_top:


;right, below			
;if pixel has right and below neighbours -> has right,top neighbour
	mov R11,0
	movd XMM0, R11							;set 0 - need it to checking  
	PCMPEQB XMM0, XMM4						;check if there is 0 in XMM4 
	MOVD R11, XMM0							;move result of comparison to R11, FF if true, 0 if false
	CMP R11B, 255							;if true -> doenst have right neighbour -> no need to check below one
	JE no_right_below

	mov R11,0
	movd XMM0, R11							;set 0 - need it to checking  
	PCMPEQB XMM0, XMM5						;check if there is 0 in XMM5
	MOVD R11, XMM0							;move result of comparison to R11, FF if true, 0 if false
	CMP R11B, 255							;if true -> doenst have below  neighbour 
	JE no_right_below

;has right, below
	mov R13, RCX							;calculate pos of right, below pixel:   
	add R13, R9								;= currPix(r9) + 1 + ptr on pixel0(RCX) + Wight (R10)		
	add R13, R10
	cmp  BYTE PTR[R13+1], 1					;check if  right, below pixel has "1" as value
	JE set_black							;if true -> set pisxel "1"
no_right_below:


;left, below			
;if pixel has left and below neighbours -> has left,below neighbour
	mov R11,0
	movd XMM0, R11							;set 0 - need it to checking  
	PCMPEQB XMM0, XMM2						;check if there is 0 in XMM2 
	MOVD R11, XMM0							;move result of comparison to R11, FF if true, 0 if false
	CMP R11B, 255							;if true -> doenst have left  neighbour -> no need to check below one
	JE no_left_below

	mov R11,0
	movd XMM0, R11							;set 0 - need it to checking  
	PCMPEQB XMM0, XMM5						;check if there is 0 in XMM5
	MOVD R11, XMM0							;move result of comparison to R11, FF if true, 0 if false
	CMP R11B, 255							;if true -> doenst have below  neighbour 
	JE no_left_below

;has left, below
	mov R13, RCX							;calculate pos of left, below pixel:   
	add R13, R9								;= currPix(r9) + 1 + ptr on pixel0(RCX) + Wight (R10)		
	add R13, R10
	cmp  BYTE PTR[R13-1], 1					;check if  left, below pixel has "1" as value
	JE set_black							;if true -> set pisxel "1"
no_left_below:



move_to_next:								;move to next pixel
	inc R9			
	jmp _loop


set_black:									;set black and move to next pixel fdgfdg
	mov BYTE PTR [RDX+R9],1
	JMP move_to_next


END_loop:

ret
asmDilatation endp
end