On October 26th, 2018 I purchased the software assets of Full Moon Software.
Full Moon Software used to be known as Crescent Software.  They produced a line
of excellent development libraries for MS-DOS.  The supported environments were
QuickBASIC 4.x, Microsoft Professional Development System v7.x, and Visual 
Basic for DOS.

The idea behind obtaining these products was to release them to the public
domain to ensure that people could still access these things in the future.
While most developers will have no use for these products in a modern 
develoment environment, they still have value as an example of "how it was 
done" back in the heyday of x86 DOS development. 

The software in this repository hasn't been modified from how I received it 
from Ethan Winer, the original author.  While all the source files carry some 
kind of Copyright notice, the software is now in the public domain.

The contents of the installation floppies will be uploaded to the Internet
Archive soon and when the manuals are scanned, they'll be uploaded there
as well.  I'll update this readme file with a link to the manual scan when
it's available.

The original distribution disk files are available here:

http://annex.retroarchive.org/crescent/COMMDISK.ZIP


Gene Buckle, October 27th, 2018

I've attached the text from Full Moon Software's catalog description of 
PDQComm below.

-------------------------------------------------------------------------------
About Crescent Software:
After 20 years as a professional recording engineer and musician, Ethan
Winer founded Crescent Software in 1986, quickly building it to become the
leading provider of add-on products for use with Microsoft compiled BASIC
for DOS. During that time Ethan wrote numerous articles about DOS BASIC and
assembly language for all of the major programming magazines, and also
served as a contributing editor for PC Magazine. Ethan also received
Microsoft's MVP award every year since 1996 for his assistance in the
Microsoft BASIC programming newsgroups. In 1992 Ethan sold Crescent to his
partner Don Malin, and retired in order to pursue his musical interests.
==============================================================================

PDQCOMM(tm)
===========

Add Full-Featured Communications to Your Compiled BASIC Programs
----------------------------------------------------------------

PDQComm contains both high- and low-level communications routines that let you 
go far beyond what is possible using BASIC's native OPEN "COM" command alone. 
PDQComm was originally written for use with our P.D.Q. replacement link 
library, because the P.D.Q. OPEN statement doesn't support a Com port 
argument. Therefore, these tools are necessary to add communications when 
using P.D.Q. However, PDQComm is also ideal for use with regular BASIC 
programs, to avoid the need for ON ERROR and to add advanced features not 
available using BASIC commands alone. Many programmers prefer to avoid ON 
ERROR when possible, because of the code size and speed penalties that ON 
ERROR imposes.
     PDQComm offers many enhancements not available in BASIC such as 16550 
FIFO support, non-standard protocols, and XModem CRC, YModem, and ASCII file 
transfers. Other important enhancements include a unique LINE INPUT 
replacement that accepts a time-out value, functions to read and set the 
hardware lines, the ability to communicate at speeds up to 115k BPS, and much 
more. The timed input routine is particularly valuable because it prevents 
your PC from hanging if the remote terminal never sends a CHR$(13) to end the 
current line. PDQComm also lets you change the baud rate and other Com port 
parameters, even while the port is open. All of the PDQComm routines are 
designed to emulate the syntax of the BASIC routines they replace, to make 
them easier to learn and use. For example, to determine how many characters 
have been received and still wait to be read, you'd use the ComLoc function, 
as opposed to BASIC's LOC. Although PDQComm supports ports 1 through 4, only 
two ports may be open at one time, unless you have hardware specifically 
designed to operate all four ports at once.
     Also included are routines that emulate ANSI, DEC VT52 and VT100, Data 
General D215, and generic terminals. The ANSI emulation provides all the color 
and cursor control abilities of ANSI.SYS, without having to waste memory 
loading that driver. The emulation routines can operate within a windowed 
area, and you can even have multiple windows active at one time. You control 
how the emulation routines print, specifying either direct writing to video 
memory for maximum speed, or through the BIOS for compatibility with other 
programs.
     All the PDQComm routines are very small and thus add very little to the 
size of your .EXE files--the core routines needed for a complete terminal 
program add less than 2500 bytes! Compare that to the 12k compiled BASIC adds 
when you use OPEN "COM." Many useful examples are included, and the PDQComm 
documentation contains extensive tutorial information, including a complete 
overview of communications in general. Additional tutorials explain modems, 
serial cables, port parameters, and UARTs. All the important standard Hayes 
commands are described in detail, and each emulation also includes a table of 
control codes that are recognized.

THE FULL MOON PHILOSOPHY

As with all our products, full source code is provided at no additional cost, 
so you can see how the routines were designed and even modify them if you 
want. We genuinely want you to understand how our libraries work and be able 
to learn from them. All of our products are reasonably priced and include free 
technical assistance, but they are licensed for use by only one person using 
one computer at a time. Royalty payments are not required when our routines 
are incorporated into your compiled applications. However, you may not 
distribute our source, object, or library files. If your customers need to 
rebuild your program, they will need their own copy of our product(s).

THE BOTTOM LINE

PDQComm costs $129 and works with QuickBASIC 4.x, PDS 7.x, and VB/DOS. Add $8 
for UPS ground shipping to US addresses only (no P.O. boxes); Connecticut 
residents must add 6.0% sales tax or show proof of tax-exempt status when 
ordering. Please call for overnight and foreign shipping costs. We accept 
checks, MasterCard, and VISA. We do accept purchase orders, but they must be 
accompanied by full payment.

PDQComm(tm) is a trademark of Crescent Software, Inc.


