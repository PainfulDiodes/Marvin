# Marvin Z80 monitor program
Marvin is a simple monitor program designed to work with the [BeanZee](https://github.com/PainfulDiodes/BeanZee) Z80 development board. It will also work with my [Z80 breadboard computer](https://github.com/PainfulDiodes/z80-breadboard-computer), and should be easy to adapt for other Z80 homebrew designs.  

BeanZee is a board for experimentation and learning. The primary function of Marvin is to be able to load and run programs on BeanZee that have been written and cross-assembled or cross-compiled on a host computer.

Example programs to run on BeanZee are provided in [BeanZeeBytes](https://github.com/PainfulDiodes/BeanZeeBytes)

## Building Marvin
See the main [readme](./README.md)

## Marvin and BeanZee

The BeanZee board has 32k RAM and 8k / 32k ROM. Marvin (and other potential firmware) is loaded into the ROM. The top 4k of the RAM is reserved for system use (stack, buffers etc), but the remainder of the RAM is available for user programs.  

BeanZee has an FTDI UM245R USB interface for communication with a host computer using a terminal emulator.

Memory map:  
0000 - 7FFF : 32k ROM  
8000 - FFFF : 32k RAM  

Stack starts at top of RAM (FFFF) (working down)  
System RAM starts from F000

8000-EFFF is available for user progams.

Marvin expects to find an [FTDI UM245R USB to Parallel FIFO Development Module](https://ftdichip.com/wp-content/uploads/2020/08/DS_UM245R.pdf) at ports 0 and 1:

Port 0 : status (read only)  
Port 1 : data (read / write)

Status byte:  
Bit 0 : device ready for data to be written (active low)  
Bit 1 : data available in read buffer (active low)  

## Marvin and BeanBoard
In addition, with the BeanBoard build, additional ports are defined:

Port 2 / 3 : keyboard  
Port 4 : LCD control port  
Port 5 : LCD data port
Port 6 / 7 : GPIO  

## Basic interaction
When BeanZee is reset it responds with a Marvin welcome message and a prompt, similar to:

    MARVIN
    A super simple monitor program for Z80 homebrew
    (c) Stephen Willcock 2024
    https://github.com/PainfulDiodes
    >

*Using BeanBoard, either the BeanZee USB or the BeanBoard keyboard and display can be used for the console. The default console input/output for BeanBoard is the keyboard and LCD display. Holding down the BeanBoard Shift key when resetting BeanZee will switch to using the USB for the console, and holding down Ctrl will switch to using the BeanBoard keyboard/display. Resetting without either key keeps the console that was in use before the reset; after power-up it is the BeanBoard keyboard/display.*

Marvin interprets inputs character-by-character, echoing each character back to the console, and waits for a carriage return character (\r) before processing a command. 

Newline (\n) characters are also interpreted as an end-of-command, and so a \r\n combination will result in an additional empty command. This is harmless, but will be visible as an additional prompt line.

When sending responses back to the console, Marvin will terminate lines with \r\n.

This behaviour has been found to work with VT100/ANSI terminal emulation, e.g. GNU screen.

Backspace for correcting a command is supported - back to the start of the current line. Hitting the escape key (\e) will cause everything on the current line to be ignored, and move to a new line and new prompt.

Whitespace on a command is ignored. This allows for very compact commands, or for commands to be spaced out to make them easier to read.

Values are entered in hexadecimal (no prefix or suffix) and upper or lower case letters may be used for these values.

There are a handful of commands, most of them use a single letter, and these single-letter commands are case-sensitive.

## r command

The (r)ead command will read 16 bytes from memory and output the values to the console:

    >r
    0000: 31 ff ff c3 2a 00 db 00 cb 4f 20 fa db 01 c9 c5 

The r command uses a memory cursor which is initially reset to zero – so the first “r” after a reset will start reading from address zero – where Marvin is located.

The cursor will move forward with subsequent reads:

    >r
    0000: 31 ff ff c3 2a 00 db 00 cb 4f 20 fa db 01 c9 c5 
    >r
    0010: 47 db 00 cb 47 20 fa 78 d3 01 c1 c9 e5 7e fe 00 
    >r
    0020: 28 06 d3 01 23 c3 1d 00 e1 c9 11 00 00 21 77 01 
    >

You can also specify a memory location as a parameter after the r command, this will move the cursor to the address you provide:

    >r001a
    001a: c1 c9 e5 7e fe 00 28 06 d3 01 23 c3 1d 00 e1 c9 
    >r
    002a: 11 00 00 21 77 01 cd 1c 00 21 00 80 3e 3e cd 0f 
    >

As whitespace is ignored – “r001a” and “r 001a” are treated the same.

You can alternatively specify just the upper address byte to start reading from:

    >r02
    0200: 64 0a 00 4e 6f 20 64 61 74 61 20 74 6f 20 77 72 
    >

## x command

The e(x)ecute command causes the CPU to jump to and continue executing from a given address. In the example, the command is to execute from address zero, which is where Marvin starts, so Marvin initialises:

    >r00
    0000: 31 ff ff c3 2a 00 db 00 cb 4f 20 fa db 01 c9 c5 
    >x0000
    MARVIN
    A super simple monitor program for Z80 homebrew
    (c) Stephen Willcock 2024
    https://github.com/PainfulDiodes
    >

Doing an e(x)ecute Without an address will execute from the bottom of user RAM (0x8000).

## w command

The (w)rite command will write a number of bytes from the console into a given memory location.
The start (hex) address has to be provided after the w and then subsequent hex pairs are interpreted as a sequence of values to be written to consecutive addresses. The command

    w 8000 3e 0a d3 01 3e

will write

    Addr Value
    ---- -----
    8000 3e
    8001 0a
    8002 d3
    8003 01
    8004 3e

An entire program could be entered into memory using this command.

## : command

The Marvin load (:) command accepts data in Intel HEX format. Each command (line / record) is treated independently and like the w command it will write data to memory.

Intel HEX uses a colon to mark the beginning of a record and so we use the colon character to specify the load command.

A sample Intel HEX file:

    :109000003E0AD3013E48D3013E65D3013E6CD301F5
    :109010003E6CD3013E6FD3013E21D3013E0AD30102
    :05902000D301C30000B4
    :00000001FF

Taking the first line:  

* 10 is the number of data bytes being sent (in hex) – 16 bytes in this case
* 9000 is the load address (in hex)  
* 00 is the record type – which is “data”  
* 3E0AD3013E48D3013E65D3013E6CD301 is the actual data to be loaded (in hex)  
* F5 is a checksum that can be used to test the integrity of the data  

A program prepared as an Intel HEX format file may be loaded into memory by sending the file via a terminal emulator, and then it can be executed using the x command. Each line of the file is taken as a command, and hence the prompt “>” appears as each line is processed:

    MARVIN
    A super simple monitor program for Z80 homebrew
    (c) Stephen Willcock 2024
    https://github.com/PainfulDiodes

    >:109000003E0AD3013E48D3013E65D3013E6CD301F5
    >:109010003E6CD3013E6FD3013E21D3013E0AD30102
    >:05902000D301C30000B4
    >:00000001FF
    >x 9000

    Hello!

Marvin only supports a subset of the Intel HEX specification. For example:  

* Marvin does not accept anything before the “:” on a line (apart from whitespace which is ignored)
* Only the Intel HEX “data” record type is recognised
* The Intel HEX format uses a checksum for validating data integrity – this is ignored by Marvin
* As the command is interpreted and executed without checksum validation, if a record is truncated, then any complete bytes of data already received will be written to memory

## b / B commands

The `b` command launches BBC BASIC with a cold start — variables and any loaded program are cleared:

    $b

    BBC BASIC (Z80) Version 3.00
    (C) Copyright R.T.Russell 1987
    >

The `B` command (uppercase) launches with a warm start, resuming the existing program and variables:

    $B

    >

## BeanZeeBytes
Example programs that can be loaded and run on BeanZee can be found in [BeanZeeBytes](https://github.com/PainfulDiodes/BeanZeeBytes).