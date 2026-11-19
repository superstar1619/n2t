// This file is part of www.nand2tetris.org
// and the book "The Elements of Computing Systems"
// by Nisan and Schocken, MIT Press.
// File name: projects/4/Fill.asm

// Runs an infinite loop that listens to the keyboard input. 
// When a key is pressed (any key), the program blackens the screen,
// i.e. writes "black" in every pixel. When no key is pressed, 
// the screen should be cleared.

//// Replace this comment with your code.
@SCREEN
D=A
@totalram
M=D
@unit
M=1
@num
M=0

(LOOP)
@unit
D=M
@num
M=D

@KBD
D=M
@NUM
D;JEQ
@unit
D=M
@totalram
A=M
M=D|M

(UPDATE)
@unit
D=M
M=D+M
D=M
@DEALT
D;JEQ
@LOOP
0;JMP

(NUM)
@unit
D=!M
@totalram
A=M
M=D&M
@UPDATE
0;JMP

(DEALT)
@unit
M=1
@totalram
DM=M+1
@KBD
D=D-A
@DEALT_TOTALRAM
D;JEQ
@LOOP
0;JMP

(DEALT_TOTALRAM)
@SCREEN
D=A
@totalram
M=D
@LOOP
0;JMP










