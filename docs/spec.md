[TOC]

# Preface

This project is in it's very, very early stage, and most of the documentation below is not what is actually implemented, it's just my thoughts or ideas written down.

This documentation is written in [Typora](https://typora.io/) and this is the recommended tool for viewing it. A PDF version of this documentation should be available [here](spec.pdf) but it's not guaranteed to be up-to-date with this source.

# Design

The goal for Icarium is for it to be a very simple, embedded 64-bit System on Chip (SoC), which is suited for microkernels.

# Architecture

## Registers

| Name          | Description                                                  | Register id |
| ------------- | ------------------------------------------------------------ | ----------- |
| `r0`          | Reading this register will always return 0. Writing operations are ignored. | `5'h00`     |
| `r1`          | General purpose                                              | `5'h01`     |
| `r2`          | General purpose                                              | `5'h02`     |
| `r3`          | General purpose                                              | `5'h03`     |
| `r4`          | General purpose                                              | `5'h04`     |
| `r5`          | General purpose                                              | `5'h05`     |
| `r6`          | General purpose                                              | `5'h06`     |
| `r7`          | General purpose                                              | `5'h07`     |
| `r8`          | General purpose                                              | `5'h08`     |
| `r9`          | General purpose                                              | `5'h09`     |
| `r10`         | General purpose                                              | `5'h0a`     |
| `r11`         | General purpose                                              | `5'h0b`     |
| `r12`         | General purpose                                              | `5'h0c`     |
| `r13`         | General purpose                                              | `5'h0d`     |
| `r14`         | General purpose                                              | `5'h0e`     |
| `r15`         | General purpose                                              | `5'h0f`     |
| `r16`         | General purpose                                              | `5'h10`     |
| `r17`         | General purpose                                              | `5'h11`     |
| `r18`         | General purpose                                              | `5'h12`     |
| `r19`         | General purpose                                              | `5'h13`     |
| `r20`         | General purpose                                              | `5'h14`     |
| `r21`         | General purpose                                              | `5'h15`     |
| `r22`         | General purpose                                              | `5'h16`     |
| `r23`         | General purpose                                              | `5'h17`     |
| `r24`         | General purpose                                              | `5'h18`     |
| `r25`         | General purpose                                              | `5'h19`     |
| `r26`         | General purpose                                              | `5'h1a`     |
| `r27`         | General purpose                                              | `5'h1b`     |
| `r28`         | General purpose                                              | `5'h1c`     |
| `r29`         | General purpose                                              | `5'h1d`     |
| `r30` or `sp` | Stack pointer.                                               | `5'h1e`     |
| `r31` or `pc` | Program counter.                                             | `5'h1f`     |

## Status register

The status register is an internal, 64-bit, inaccessible register, which showcases the CPU's internal state.

| Bit(s) | Name               | Description                                                  |
| ------ | ------------------ | ------------------------------------------------------------ |
| `63:2` | _unused_           | RsvZ                                                         |
| `1`    | `CPU_STAT_Z`       | Set by various instructions if their execution ends in a '_zero_'  state, eg. if a register ends up with value `64'b0` |
| `0`    | `CPU_STAT_RUNNING` | Set to `1` if the CPU is in a running state (ie. if it's not in the halted state) |



## Instruction set

All instructions are 64 bit wide.

Every instruction can be executed conditionally.

### Conditionals

You can make any instruction execute or not depending on the CPU's internal state, by appending one of the suffixes to the instruction's opcode, eg.

```
nop.z
```

will execute the `nop` instruction only if the `CPU_STAT_Z` flag was set.

Full list of available conditionals:

| Condition      | Description                           | Bit encoding | Condition      | Description                                 | Bit encoding |
| -------------- | ------------------------------------- | ------------ | -------------- | ------------------------------------------- | ------------ |
| _no condition_ | Always execute                        | `4'b0000`    | _no condition_ | Always execute                              | `4'b1000`    |
| `.z`           | Zero - execute if `CPU_STAT_Z` is set | `4'b0001`    | `.nz`          | Not-zero - execute if `CPU_STAT_Z` is clear | `4'b1001`    |
|                |                                       | `4'b0010`    |                |                                             | `4'b1010`    |
|                |                                       | `4'b0011`    |                |                                             | `4'b1011`    |
|                |                                       | `4'b0100`    |                |                                             | `4'b1100`    |
|                |                                       | `4'b0101`    |                |                                             | `4'b1101`    |
|                |                                       | `4'b0110`    |                |                                             | `4'b1110`    |
|                |                                       | `4'b0111`    |                |                                             | `4'b1111`    |

General instruction formats:

### RIS (register, immediate, shift)

| Opcode (7 bits) | Format (2 bits) | Condition (4 bits) | Register (5 bits) | Immediate value (41 bits) | Shift (5 bits) |
| --------------- | --------------- | ------------------ | ----------------- | ------------------------- | -------------- |
| opcode [63:57]  | format [56:55]  | cond [54:51]       | reg [50:46]       | imm [45:5]                | shift [4:0]    |

### RRO (register, register, offset)

| Opcode (7 bits) | Format (2 bits) | Condition (4 bits) | Destination register (5 bits) | Source register (5 bits) | Offset (41 bits) |
| --------------- | --------------- | ------------------ | ----------------------------- | ------------------------ | ---------------- |
| opcode [63:57]  | format [56:55]  | cond [54:51]       | dst_reg [50:46]               | src_reg [45:41]          | off [40:0]       |

### I (immediate)

| Opcode (7 bits) | Format (2 bits) | Condition (4 bits) | Immediate value (51 bits) |
| --------------- | --------------- | ------------------ | ------------------------- |
| opcode [63:57]  | format [56:55]  | cond [54:51]       | imm [50:0]                |

### nop

Format: I

Opcode: `7'h0000000`

Does nothing.

### set (immediate)

Format: RIS

Opcode: `7'b0000001`

Variant: `2'b00`

```
set r1, 0x80000000 shl 16
```

Will set the register `r1` to the value `0x800000000000`

### set (using a register)

Format: RRO

Opcode: `7'b0000001`

```
set r1, r2
```

Will set the register `r1` to the value stored in register `r2`

### load (using a register)

Format: RRO

Opcode: `7'h0000010`

Variant: `2'b00`

```
load r2, r1, 0x10
```

Will issue a read bus cycle to access memory at address which is stored in register `r1` having added the offset of `0x10` to it, and storing the result of this bus transaction into register `r2`.

### store (using a register)

Format: RRO

Opcode: `7'h0000000`

Variant: `2'b00`

```
store r3, r1, 0x20
```

Will issue a write bus cycle with the data stored in address `r3` to the address stored in register `r1` having the offset `0x20` added

### testbit

Format: RIS

Opcode: `7'h5`

```
testbit <reg>, <imm>
```

This instruction will test if bit at position indicated by `<imm>` in register `<reg>` is set or not, and it will clear flag `CPU_STAT_Z` if the bit is set, and it will set flag `CPU_STAT_Z` if it's unset.

This instruction has no other side effects, except for changing the state of `CPU_STAT_Z`.

For example:

```
set r1, 0b100
testbit r1, 2
jump.nz .always_jump
```

Will always perform the jump.

### sub (immediate value)

Format: RIS

Opcode: `7'h6`

```
sub <reg>, <imm>
```

This instruction will effectively perform `reg = reg - imm`. The result can underflow, for example:

```
set r1, 0
sub r1, 1
```

will result in `r1` having the value `0xffffffffffffffff`. Unfortunately, there's no way yet to find if an underflow occurred.

Side effects: `CPU_STAT_Z` will be set if `<reg> - <imm> == 64'h0`. In other case, `CPU_STAT_Z` will be cleared.

### add (immediate value)

Format: RIS

Opcode: `7'h`b

```
add <reg>, <imm>
```

This instruction will effectively perform `reg = reg + imm`. The result can overflow.

### or (register, register)

Format: RRO

Opcode: `7'h8`

```
or <dest reg>, <source reg>
```

This instruction will essentially perform `dest reg = dest reg | source reg`.

### and (register, register)

Format: RRO

Opcode: `7'h9`

```
and <dest reg>, <source reg>
```

This instruction will essentially perform `dest reg = dest reg & source reg`.

### xor (register, register)

Format: RRO

Opcode: `7'ha`

```
xor <dest reg>, <source reg>
```

This instruction will essentially perform `dest reg = dest reg ^ source reg`.

### shiftl (immediate value)

Format: RIS

Opcode: `7'h7`

```
shiftl <reg>, <imm>
```

Will effectively perform `reg = reg << imm`. No side effects.

### shiftr (immediate value)

Format: RIS

Opcode: `7'hc`

```
shiftr <reg>, <imm>
```

Will effectively perform `reg = reg >> imm`. No side effects (at the moment).

### jump (using a register)

Format: RRO

Opcode: `7'h4`

```
jump <reg> [, off <imm>]
```

This instruction will set register `pc` to the value taken of `<reg> + <imm>` (`<imm>` can be negative, so backward jumps are possible)

```
jump <imm>
```

The assembler also supports this syntactic sugar syntax (so you can eg. jump to a label etc). When this is used the assembler will calculate the proper offset and implicitly use the `pc` register, turning it into this call:

```
jump pc, off <offset from current pc>
```

### call (register, offset)

Format: RRO

Opcode: `7'hd`

```
call <reg> off <imm>
```

This instruction will effectively decrement the `sp` register by 8, issue a bus write cycle to write value of `pc + 8` into address `sp`, and make a jump to `reg + imm`.

```
call <imm>
```

The assembler also supports this syntactic sugar syntax. In this case, just like in the `jump` case, the assembler will implicitly use the `pc` register, and calculate the correct offset.

### return

Format: I

Opcode: `7'he`

```
return
```

This instruction will effectively issue a bus read cycle to read from address `sp`, increment `sp` by 8, and then jump to address obtained from the bus read cycle.

### halt

Format: I

Opcode: `7'b1111111`

The `halt` instruction causes the CPU to halt. The only way of getting out of this state is by resetting the CPU.

# Conventions

## Bit attributes

| Attribute | Meaning                                           |
| --------- | ------------------------------------------------- |
| RW        | Read / write                                      |
| RO        | Read only                                         |
| RsvZ      | Reserved - always returns 0                       |
| RsvT      | Reserved - writing a 1 will cause the CPU to trap |

# Physical memory map

| Address range                               | Size   | Device                                        |
| ------------------------------------------- | ------ | --------------------------------------------- |
| `0x0000000000000000` - `0x0000800000000000` | 128TiB | [DDR RAM](#DDR controller)                    |
| `0x0000800000000000` - `0x0000800000000400` | 1KiB   | [ROM](#ROM)                                   |
| `0x0000800080000000` - `0x0000800080000400` | 1KiB   | [SRAM](#SRAM)                                 |
| `0x0000800100000000` - `0x0000800100000000` | ?      | [Syscon](#Syscon)                             |
| `0x0000800200000000` - `0x0000800200000000` | ?      | [Interconnect](#Interconnect)                 |
| `0x0000800300000000` - `0x0000800300000000` | ?      | [Interrupt controller](#Interrupt controller) |
| `0x0000801000000000` - `0x0000801000000000` | ?      | [UART](#UART)                                 |
| `0x0000802000000000` - `0x0000802000000000` | ?      | [SPI](#SPI)                                   |
| `0x0000803000000000` - `0x0000803000000000` | ?      | [I2C](#I2C)                                   |
| `0x0000804000000000` - `0x0000804000000000` | ?      | [GPIO](#GPIO)                                 |

# DDR Controller

# ROM

# SRAM

Just a simple static RAM.

On reset all RAM contents are initialized to `0x0`.

Note: access is always done using 8-byte words, and the lowest 3 bits of the address are completely ignored. This means, that eg. accessing `0x800080000002` will return the 8-byte word from `0x800080000000`

# Syscon

# Interconnect

# Interrupt controller

# UART

## Description

Icarium sports a very simple UART controller, which currently support a static configuration of 1 start bit, 8 data bits, no parity bits, 1 stop bit, 115200 baudrate.

There are no FIFOs, no DMA, nothing fancy.

## Initialization

The UART controller is initialized after power-on. You can simply start writing to `UART_DATA` to start transmitting bytes, or read from it when data is ready.

## Registers

### Register map

| Offset | Name                      | Description      |
| ------ | ------------------------- | ---------------- |
| `0x00` | [`UART_STAT`](#UART_STAT) | Status register  |
| `0x08` | [`UART_CTRL`](#UART_CTRL) | Control register |
| `0x10` | [`UART_DATA`](#UART_DATA) | Data register    |

### UART_STAT

| Bit(s) | Name                  | Reset value | Attribute | Description                                                  |
| ------ | --------------------- | ----------- | --------- | ------------------------------------------------------------ |
| `63:2` | -                     | `62'h0`     | RsvZ      | Reserved                                                     |
| `1`    | `STAT_RXD_DATA_READY` | `1'b0`      | RO        | Receiver data ready - if `1` then reading from `UART_DATA` will return valid data. |
| `0`    | `STAT_TXD_BUSY`       | `1'b0`      | RO        | Transmitter busy - if `1` then the controller is currently transmitting.<br />Note: if this bit is set, then any write to UART_DATA is ignored. |

### UART_CTRL

| Bit(s) | Name        | Reset value | Attribute | Description                                                  |
| ------ | ----------- | ----------- | --------- | ------------------------------------------------------------ |
| `63:3` | -           | `60'h0`     | RsvZ      | Reserved                                                     |
| `3:1`  | `CTRL_BAUD` | `3'b000`    | RW        | Baud rate - selects what baud rate to operate the UART on.<br /><br />`3'b000` - 1200<br />`3'b001` - 2400<br />`3'b010` - 4800<br />`3'b011` - 9600<br />`3'b100` - 19200<br />`3'b101` - 38400<br />`3'b110` - 57600<br />`3'b111` - 115200<br /><br />NOT IMPLEMENTED |
| `0`    | `CTRL_ENA`  | `1'b1`      | RW        | Enabled - shows the current state of the controller. If this bit is `1` then the controller is operating, and can send and receive data.<br /><br />NOT IMPLEMENTED |



### UART_DATA

| Bit(s) | Name   | Reset value | Attribute | Description                                                  |
| ------ | ------ | ----------- | --------- | ------------------------------------------------------------ |
| `63:8` | -      | `56'h0`     | RsvZ      | Reserved                                                     |
| `7:0`  | `DATA` | `8'h0`      | RW        | Writing to this register will trigger a transmit of the character, and reading from it will return any previously read character.<br /><br />Note: if `STAT_RXD_DATA_READY` is `0` then reading from this register will return invalid data<br />Note: if `STAT_TXD_BUSY` is `1` then any writes to this register are ignored. |

# SPI

# I2C

# GPIO