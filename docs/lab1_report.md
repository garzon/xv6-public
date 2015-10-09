# lab1_report

### 1. Be familiar with GDB

#### Tasks
- Debug XV6 with QEMU and GDB, trace BIOS step by step
beginning with first instruction
- Set a breakpoint at address 0x7c00, where the boot loader will be loaded,
and keep track of the instructions step by step and disassemble the
instructions using x/i command. Compare the code sequences with the code
in bootasm.S 

#### Report
This is the code dumped by me using gdb(with peda extension and my customized .gdbinit file).

```
The target architecture is assumed to be i8086
[f000:fff0]
=>   0xffff0:	jmp    0xf000:0xe05b
   0xffff5:	xor    BYTE PTR ds:0x322f,dh
   0xffff9:	xor    bp,WORD PTR [bx]
   0xffffb:	cmp    WORD PTR [bx+di],di
0x0000fff0 in ?? ()
+ symbol-file kernel
gdb-peda$ break *0x7c00
Breakpoint 1 at 0x7c00
gdb-peda$ c
Continuing.
0x6f20:	0xf000d319	0x00000000	0x00006f62	0x00000000
0x6f30:	0x0000f839	0x0000f82d	0x00000080	0x00000000
0x6f40:	0x0000d385	0x000f237e	0x00000000	0x00007c00
0x6f50:	0x000f2a08	0x000f4670	0x00000000	0x00007c00
0x6f60:	0x000007c0	0x00000000	0x00000000	0x00000000
EAX:0x0000aa55; EBX:0x00000000; ECX:0x00000000; EDX:0x00000080; EBP:0x00000000
[   0:7c00]
=>=> 0x7c00:	cli    
   0x7c01:	xor    ax,ax
   0x7c03:	mov    ds,ax
   0x7c05:	mov    es,ax

Breakpoint 1, 0x00007c00 in ?? ()
gdb-peda$ x/20i
   0x7c07:	mov    ss,ax
   0x7c09:	in     al,0x64
   0x7c0b:	test   al,0x2
   0x7c0d:	jne    0x7c09
   0x7c0f:	mov    al,0xd1
   0x7c11:	out    0x64,al
   0x7c13:	in     al,0x64
   0x7c15:	test   al,0x2
   0x7c17:	jne    0x7c13
   0x7c19:	mov    al,0xdf
   0x7c1b:	out    0x60,al
   0x7c1d:	lgdtw  ds:0x7c78
   0x7c22:	mov    eax,cr0
   0x7c25:	or     eax,0x1
   0x7c29:	mov    cr0,eax
   0x7c2c:	jmp    0x8:0x7c31
```

Start at 0xffff0, where is a jmp instruction that makes it jump to 0xe05b where is the entry point of BIOS.
The difference between bootasm.S and the code above is that the placeholder(the code segment label like seta20.1, etc) is replaced by an address and the suffix of instructions(b,q,...) is not displayed(and displayed in Intel format that I set). Mostly, the code is the same as the one in bootasm.S.

In bootasm.S:
```asm
seta20.1:
  inb     $0x64,%al               # Wait for not busy
  testb   $0x2,%al
  jnz     seta20.1
  movb    $0xd1,%al               # 0xd1 -> port 0x64
  outb    %al,$0x64

seta20.2:
  inb     $0x64,%al               # Wait for not busy
  testb   $0x2,%al
  jnz     seta20.2
  movb    $0xdf,%al               # 0xdf -> port 0x60
  outb    %al,$0x60
```
Read the KBC status from port 0x64 in a loop,
to wait for the controller to be available.
Send 0xdf command to KBC to activate A20GATE, which makes the 32-bit memory address available,
and wait for the execution of the command.

### 2. Analyze how does boot loader switch the processor from real mode to 32-bit protected mode

```asm
  lgdt    gdtdesc
  movl    %cr0, %eax
  orl     $CR0_PE, %eax
  movl    %eax, %cr0
```
load the prepared GDT and set the PE bit of %cr0 to 1 to enable protected mode
GDT stores the segmentation information, like the size and the offset of a segmentation, etc.

```asm
  ljmp    $(SEG_KCODE<<3), $start32
```

Use `ljmp` to refresh the segmentation selector and set up the heap space.
In addition, because of the pipeline mechanism of CPU, CPU has already read and interpreted the following instructions.
To prevent the error of interpretation caused by the change of mode, ljmp force CPU to re-read the instructions in 32-bit mode. Jump into 32-bit mode and get ready to execute the C code.

### 3. Analyze how does boot loader load XV6 kernel in EFL format. How to load disk sectors and how to load ELF binaries?

First, read the first page and check that if it is an elf executable.
Then, read each segment of the elf using the infomation in header.
To read a segment, the program reads the sectors containing the data by sending their offset to port 0x1f2~0x1f7,
and send the 0x20 cmd which means reading sector, and using insl instruction to store the data.
Finally, 

```c
  entry = (void(*)(void))(elf->entry);
  entry();
```

casting the elf entry point address to a function pointer to jump to the entry point and executes the instructions of kernel.

### 4. Determine where the kernel initializes its stack, and exactly where in memory
its stack is located. How does the kernel reserve space for its stack? And at
which "end" of this reserved area is the stack pointer initialized to point to?

First, find the bootmain address.

```
gdb-peda$ c
Continuing.
0x7c00:	0x8ec031fa	0x8ec08ed8	0xa864e4d0	0xb0fa7502
0x7c10:	0xe464e6d1	0x7502a864	0xe6dfb0fa	0x16010f60
0x7c20:	0x200f7c78	0xc88366c0	0xc0220f01	0x087c31ea
0x7c30:	0x10b86600	0x8ed88e00	0x66d08ec0	0x8e0000b8
0x7c40:	0xbce88ee0	0x00007c00	0x0000e2e8	0x00b86600
EAX:0x00000000; EBX:0x00000000; ECX:0x00000000; EDX:0x00000080; EBP:0x00000000
=> 0x7c48:	call   0x7d2f
   0x7c4d:	mov    ax,0x8a00
   0x7c51:	mov    dx,ax
   0x7c54:	out    dx,ax
   0x7c56:	mov    ax,0x8ae0

Breakpoint 3, 0x00007c48 in ?? ()
gdb-peda$ ni
0x7bfc:	0x00007c4d	0x8ec031fa	0x8ec08ed8	0xa864e4d0
0x7c0c:	0xb0fa7502	0xe464e6d1	0x7502a864	0xe6dfb0fa
0x7c1c:	0x16010f60	0x200f7c78	0xc88366c0	0xc0220f01
0x7c2c:	0x087c31ea	0x10b86600	0x8ed88e00	0x66d08ec0
0x7c3c:	0x8e0000b8	0xbce88ee0	0x00007c00	0x0000e2e8
EAX:0x00000000; EBX:0x00000000; ECX:0x00000000; EDX:0x00000080; EBP:0x00000000
=> 0x7d2f:	push   ebp
   0x7d30:	mov    ebp,esp
   0x7d32:	push   edi
   0x7d33:	push   esi
   0x7d34:	push   ebx
```

By comparing the instructions, we can find that 0x7d2f is the address of bootmain.
Then, dump the bootmain.

```
gdb-peda$ x/50i $eip
=> 0x7d2f:	push   ebp
   0x7d30:	mov    ebp,esp
   0x7d32:	push   edi
   0x7d33:	push   esi
   0x7d34:	push   ebx
   0x7d35:	sub    esp,0x1c
   0x7d38:	mov    DWORD PTR [esp+0x8],0x0
   0x7d40:	mov    DWORD PTR [esp+0x4],0x1000
   0x7d48:	mov    DWORD PTR [esp],0x10000
   0x7d4f:	call   0x7ce7
   0x7d54:	cmp    DWORD PTR ds:0x10000,0x464c457f
   0x7d5e:	jne    0x7db7
   0x7d60:	mov    eax,ds:0x1001c
   0x7d65:	lea    ebx,[eax+0x10000]
   0x7d6b:	movzx  esi,WORD PTR ds:0x1002c
   0x7d72:	shl    esi,0x5
   0x7d75:	add    esi,ebx
   0x7d77:	cmp    ebx,esi
   0x7d79:	jae    0x7db1
   0x7d7b:	mov    edi,DWORD PTR [ebx+0xc]
   0x7d7e:	mov    eax,DWORD PTR [ebx+0x4]
   0x7d81:	mov    DWORD PTR [esp+0x8],eax
   0x7d85:	mov    eax,DWORD PTR [ebx+0x10]
   0x7d88:	mov    DWORD PTR [esp+0x4],eax
   0x7d8c:	mov    DWORD PTR [esp],edi
   0x7d8f:	call   0x7ce7
   0x7d94:	mov    ecx,DWORD PTR [ebx+0x14]
   0x7d97:	mov    eax,DWORD PTR [ebx+0x10]
   0x7d9a:	cmp    ecx,eax
   0x7d9c:	jbe    0x7daa
   0x7d9e:	add    edi,eax
   0x7da0:	sub    ecx,eax
   0x7da2:	mov    eax,0x0
   0x7da7:	cld    
   0x7da8:	rep stos BYTE PTR es:[edi],al
   0x7daa:	add    ebx,0x20
   0x7dad:	cmp    esi,ebx
   0x7daf:	ja     0x7d7b
   0x7db1:	call   DWORD PTR ds:0x10018
   0x7db7:	add    esp,0x1c
   0x7dba:	pop    ebx
   0x7dbb:	pop    esi
   0x7dbc:	pop    edi
   0x7dbd:	pop    ebp
   0x7dbe:	ret
```

Find the entry point and break

```
gdb-peda$ break *0x7db1
Breakpoint 4 at 0x7db1
gdb-peda$ c
Continuing.
0x7bd0:	0x00000000	0x00000000	0x00000000	0x00000000
0x7be0:	0x00000000	0x00000000	0x00000000	0x00000000
0x7bf0:	0x00000000	0x00000000	0x00000000	0x00007c4d
0x7c00:	0x8ec031fa	0x8ec08ed8	0xa864e4d0	0xb0fa7502
0x7c10:	0xe464e6d1	0x7502a864	0xe6dfb0fa	0x16010f60
EAX:0x00000000; EBX:0x00010074; ECX:0x00000000; EDX:0x000001f0; EBP:0x00007bf8
=> 0x7db1:	call   DWORD PTR ds:0x10018
   0x7db7:	add    esp,0x1c
   0x7dba:	pop    ebx
   0x7dbb:	pop    esi
   0x7dbc:	pop    edi

Breakpoint 4, 0x00007db1 in ?? ()
gdb-peda$ ni
0x7bcc:	0x00007db7	0x00000000	0x00000000	0x00000000
0x7bdc:	0x00000000	0x00000000	0x00000000	0x00000000
0x7bec:	0x00000000	0x00000000	0x00000000	0x00000000
0x7bfc:	0x00007c4d	0x8ec031fa	0x8ec08ed8	0xa864e4d0
0x7c0c:	0xb0fa7502	0xe464e6d1	0x7502a864	0xe6dfb0fa
EAX:0x00000000; EBX:0x00010074; ECX:0x00000000; EDX:0x000001f0; EBP:0x00007bf8
=> 0x10000c:	mov    eax,cr4
   0x10000f:	or     eax,0x10
   0x100012:	mov    cr4,eax
   0x100015:	mov    eax,0x10a000
   0x10001a:	mov    cr3,eax
0x0010000c in ?? ()
gdb-peda$ x/20i $eip
=> 0x10000c:	mov    eax,cr4
   0x10000f:	or     eax,0x10
   0x100012:	mov    cr4,eax
   0x100015:	mov    eax,0x10a000
   0x10001a:	mov    cr3,eax
   0x10001d:	mov    eax,cr0
   0x100020:	or     eax,0x80010000
   0x100025:	mov    cr0,eax
   0x100028:	mov    esp,0x8010c650
   0x10002d:	mov    eax,0x801037a8
   0x100032:	jmp    eax
   0x100034:	push   ebp
   0x100035:	mov    ebp,esp
   0x100037:	sub    esp,0x28
   0x10003a:	mov    DWORD PTR [esp+0x4],0x801084a4
   0x100042:	mov    DWORD PTR [esp],0x8010c660
   0x100049:	call   0x104eac
   0x10004e:	mov    DWORD PTR ds:0x80110570,0x80110564
   0x100058:	mov    DWORD PTR ds:0x80110574,0x80110564
   0x100062:	mov    DWORD PTR [ebp-0xc],0x8010c694
gdb-peda$ 
```

Find the mov *, esp instruction

```
gdb-peda$ 
0x7bcc:	0x00007db7	0x00000000	0x00000000	0x00000000
0x7bdc:	0x00000000	0x00000000	0x00000000	0x00000000
0x7bec:	0x00000000	0x00000000	0x00000000	0x00000000
0x7bfc:	0x00007c4d	0x8ec031fa	0x8ec08ed8	0xa864e4d0
0x7c0c:	0xb0fa7502	0xe464e6d1	0x7502a864	0xe6dfb0fa
EAX:0x80010011; EBX:0x00010074; ECX:0x00000000; EDX:0x000001f0; EBP:0x00007bf8
=> 0x100028:	mov    esp,0x8010c650
   0x10002d:	mov    eax,0x801037a8
   0x100032:	jmp    eax
   0x100034:	push   ebp
   0x100035:	mov    ebp,esp
0x00100028 in ?? ()
gdb-peda$ 
0x8010c650:	0x00000000	0x00000000	0x00000000	0x00000000
0x8010c660 <bcache>:	0x00000000	0x00000000	0x00000000	0x00000000
0x8010c670 <bcache+16>:	0x00000000	0x00000000	0x00000000	0x00000000
0x8010c680 <bcache+32>:	0x00000000	0x00000000	0x00000000	0x00000000
0x8010c690 <bcache+48>:	0x00000000	0x00000000	0x00000000	0x00000000
EAX:0x80010011; EBX:0x00010074; ECX:0x00000000; EDX:0x000001f0; EBP:0x00007bf8
=> 0x10002d:	mov    eax,0x801037a8
   0x100032:	jmp    eax
   0x100034:	push   ebp
   0x100035:	mov    ebp,esp
   0x100037:	sub    esp,0x28
0x0010002d in ?? ()
gdb-peda$ 
```

We can see that the stack pointer was set to 0x8010c650, and the ebp is still 0x7bf8.
Then we see the critical instruction.

```
gdb-peda$ x/20i $eip
=> 0x100032:	jmp    eax
   0x100034:	push   ebp
   0x100035:	mov    ebp,esp
   0x100037:	sub    esp,0x28
gdb-peda$ si
0x8010c650:	0x00000000	0x00000000	0x00000000	0x00000000
0x8010c660 <bcache>:	0x00000000	0x00000000	0x00000000	0x00000000
0x8010c670 <bcache+16>:	0x00000000	0x00000000	0x00000000	0x00000000
0x8010c680 <bcache+32>:	0x00000000	0x00000000	0x00000000	0x00000000
0x8010c690 <bcache+48>:	0x00000000	0x00000000	0x00000000	0x00000000
EAX:0x801037a8; EBX:0x00010074; ECX:0x00000000; EDX:0x000001f0; EBP:0x00007bf8
=> 0x801037a8 <main>:	push   ebp
   0x801037a9 <main+1>:	mov    ebp,esp
   0x801037ab <main+3>:	and    esp,0xfffffff0
   0x801037ae <main+6>:	sub    esp,0x10
   0x801037b1 <main+9>:	mov    DWORD PTR [esp+0x4],0x80400000
main () at main.c:19
19	{
```

Then we enter main.c.
So the kernel set esp to 0x8010c650, and the address larger than this address is the reserved stack.
```
=> 0x100028:	mov    esp,0x8010c650
```

### Addition - shutdown or exit

In fact, I have implemented the `shutdown` command in this commit https://github.com/garzon/xv6-public/commit/ab8709b72c154998528e4ae258d5d02b697e9ca2
And I draw a diagram to explain the work flow. https://github.com/garzon/xv6-public/blob/master/docs/syscall%E5%9B%BE%E8%A7%A3.png