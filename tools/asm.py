#!/usr/bin/env python3

import sys
import argparse
from lark import Lark, Transformer, v_args

prog_argp = argparse.ArgumentParser(description='Icarium assembler')
prog_argp.add_argument('input',
    nargs='?', metavar='input', type=argparse.FileType('r'),
    default=sys.stdin,
    help='the input text file (stdin by default)')
prog_argp.add_argument('output',
    nargs='?', metavar='output', type=argparse.FileType('w'),
    default=sys.stdout,
    help='the output file (stdout by default)')
prog_argp.add_argument('--hex', const='hex', dest='output_type', action='store_const',
    help='output in ASCII hexadecimal numbers (default)')
prog_argp.add_argument('--bin', const='bin', dest='output_type', action='store_const',
    help='output in ASCII binary numbers')
prog_argp.add_argument('--rom', const='rom', dest='output_type', action='store_const',
    help='output suitable to plug into rom.v')

prog_args = prog_argp.parse_args()

class Cond():
    def __init__(self, cond = None):
        self.cond = cond
        self.encodings = {
            None:   0b0000,
            "":     0b0000,
            "z":    0b0001,
            "nz":   0b1001
        }

    def __str__(self):
        if self.cond is None:
            return ""
        else:
            return "." + str(self.cond)

    def __int__(self):
        return self.__index__()

    def __index__(self):
        return self.encodings[self.cond]

    def __lshift__(self, other):
        return self.encodings[self.cond] << other

class Shl():
    def __init__(self, shl = 0x0):
        if shl is None:
            self.shl = 0x0
        else:
            self.shl = shl

    def __str__(self):
        return "shl {}".format(self.shl)

    def __int__(self):
        return self.shl

    def __index__(self):
        return self.shl

    def __lshift__(self, other):
        return self.shl << other

    def __or__(self, other):
        return self.shl | other

    def __ror__(self, other):
        return self.shl | other

class Off():
    def __init__(self, off = 0x0):
        if off is None:
            self.off = 0x0
        else:
            self.off = off

    def __str__(self):
        return "off {}".format(self.off)

    def __int__(self):
        return self.off

    def __index__(self):
        return self.off

    def __lshift__(self, other):
        return self.off << other

    def __or__(self, other):
        return self.off | other

    def __ror__(self, other):
        return self.off | other

class Format():
    RRO, RIS, I = range(3)

class Instr(object):
    def __init__(self, mnem, opcode, format, cond = 0, emit = True,
                 imm = 0, dst_reg = 0, src_reg = 0, shl = 0, off = 0):
        self.mnem = mnem
        self.opcode = opcode
        self.format = format
        self.cond = cond
        self.e = emit
        self.dst_reg = dst_reg
        self.src_reg = src_reg
        self.imm = imm
        self.shl = shl
        self.off = off

    def emittable(self):
        return self.e is True

    def emit(self):
        if self.format == Format.I:
            return self.opcode  << 57 | \
                   self.format  << 55 | \
                   self.cond    << 51 | \
                   self.imm
        elif self.format == Format.RRO:
            return self.opcode  << 57 | \
                   self.format  << 55 | \
                   self.cond    << 51 | \
                   self.dst_reg << 46 | \
                   self.src_reg << 41 | \
                   self.off
        elif self.format == Format.RIS:
            return self.opcode  << 57 | \
                   self.format  << 55 | \
                   self.cond    << 51 | \
                   self.dst_reg << 46 | \
                   self.imm     << 5  | \
                   self.shl

    def __str__(self):
        if self.format == Format.RIS:
            return "{}{} r{}, 0x{:x} {}".format(self.mnem, self.cond, self.dst_reg, self.imm, self.shl)
        elif self.format == Format.RRO:
            return "{}{} r{}, r{} {}".format(self.mnem, self.cond, self.dst_reg, self.src_reg, self.off)

class Nop(Instr):
    def __init__(self, mnem, opcode, cond):
        super().__init__(mnem, opcode, Format.I, cond)

    def __str__(self):
        return "nop{}".format(self.cond)

class Halt(Instr):
    def __init__(self, mnem, opcode, cond):
        super().__init__(mnem, opcode, Format.I, cond)

    def __str__(self):
        return "halt{}".format(self.cond)

class Jump(Instr):
    def __init__(self, mnem, opcode, format, cond, imm):
        super().__init__(mnem, opcode, format, cond, imm = imm)

    def __str__(self):
        return "jump{} 0x{:x}".format(self.cond, self.imm)

class Set(Instr):
    def __init__(self, mnem, opcode, format, cond, dst, src, shl):
        super().__init__(mnem, opcode, format, cond, dst_reg = dst, imm = src, src_reg = src, shl = shl)

class Load(Instr):
    def __init__(self, mnem, opcode, format, cond, dst, src, off):
        super().__init__(mnem, opcode, format, cond, dst_reg = dst, src_reg = src, off = off)

class Store(Instr):
    def __init__(self, mnem, opcode, format, cond, src, dst, off):
        # nb. src and dst are swapped here - not really though
        super().__init__(mnem, opcode, format, cond, dst_reg = dst, src_reg = src, off = off)

    def __str__(self):
        if self.format == Format.RIS:
            return "{}{} 0x{:x}, r{} {}".format(self.mnem, self.cond, self.imm, self.dst_reg, self.imm, self.off)
        elif self.format == Format.RRO:
            return "{}{} r{}, r{} {}".format(self.mnem, self.cond, self.src_reg, self.dst_reg, self.off)

@v_args(inline = True)
class Compiler(Transformer):
    def __init__(self):
        self.current_pc = 0x0
        self.labels = {}

    def inc_pc(self):
        self.current_pc += 8

    def nop(self, op, cond):
        self.inc_pc()
        return Nop("nop", 0x0, Cond(cond))

    def halt(self, op, cond):
        self.inc_pc()
        return Halt("halt", 0x7f, Cond(cond))

    def jump(self, op, cond, imm):
        self.inc_pc()
        return Jump("jump", 0x04, Format.I, Cond(cond), imm)

    def set(self, op, cond, dst, src, shl):
        self.inc_pc()
        return Set("set", 0x01, Format.RIS, Cond(cond), dst, src, Shl(shl))

    def load(self, op, cond, dst, src, off):
        self.inc_pc()
        return Load("load", 0x02, Format.RRO, Cond(cond), dst, src, Off(off))

    def store(self, op, cond, src, dst, off):
        self.inc_pc()
        return Store("store", 0x03, Format.RRO, Cond(cond), src, dst, Off(off))

    def base(self, op, base_addr):
        new_pc = int(str(base_addr), base = 0)
        self.current_pc = new_pc
        print("# setting current base addr to 0x{:x}".format(new_pc))
        return Instr(0, 0, 0, emit = False)

    def label(self, label):
        label_name = label[:-1]
        print("# new label {} at 0x{:x}".format(label_name, self.current_pc))
        self.labels[label_name] = self.current_pc
        return Instr(0, 0, 0, emit = False)

    def reg(self, reg):
        if reg == "pc":
            reg_id = 31
        else:
            reg_id = int(str(reg)[1:])

        return reg_id

    def imm(self, value):
        return int(str(value), base = 0)

    def special_imm(self, imm):
        if (imm == "#pc"):
            print("# current pc is 0x{:x}".format(self.current_pc))
            return self.current_pc
        elif (imm[0] == "."):
            label_name = imm[1:]
            try:
                label_value = self.labels[label_name]
            except:
                raise Exception("label {} not found!".format(label_name))

            print("# label {} found with value {:x}".format(label_name, label_value))
            return label_value
        else:
            raise Exception("unknown special immediate value: {}".format(imm))

    def cond(self, cond):
        # print("-- condition: {}".format(cond))
        return cond

    def start(self, *instr):
        rom_addr = 0x0

        for instr in instr:
            if instr.emittable():
                if prog_args.output_type == 'hex' or prog_args.output_type == None:
                    print("{:016x}".format(instr.emit()), file = prog_args.output)
                elif prog_args.output_type == 'bin':
                    print("{:064b}".format(instr.emit()), file = prog_args.output)
                elif prog_args.output_type == 'rom':
                    print("16'h{:04x}: r_dat_o = 64'h{:016x}; // {}".format(rom_addr, instr.emit(), instr),
                        file = prog_args.output)
                    rom_addr += 8
                else:
                    raise Exception("unknown output type: {}".format(prog_args.output_type))

parser = Lark(open("asm.lark"), parser = 'lalr', transformer = Compiler(), maybe_placeholders = True)
tree = parser.parse(prog_args.input.read())
