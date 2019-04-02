#!/usr/bin/env python3

import sys
import argparse
import struct
from lark import Lark, Transformer, Visitor, Tree, Token, v_args
from lark.visitors import Transformer_InPlace, Interpreter, visit_children_decor

prog_argp = argparse.ArgumentParser(description='Icarium assembler')
prog_argp.add_argument('input',
    nargs='?', metavar='input', type=argparse.FileType('r'),
    default=sys.stdin,
    help='the input text file (stdin by default)')
prog_argp.add_argument('--hex', type = argparse.FileType('w'),
    help = "output file (ASCII hexadecimal numbers)")
prog_argp.add_argument('--bin', type = argparse.FileType('w'),
    help = "output file (ASCII binary numbers)")
prog_argp.add_argument('--rom', type = argparse.FileType('w'),
    help = "output file (output suitable for rom.v)")
prog_argp.add_argument('--raw', type = argparse.FileType('wb', 0),
    help = "output file (raw binary data)")

prog_args = prog_argp.parse_args()

class Cond():
    def __init__(self, cond = None):
        if cond != None and cond[0] == ".":
            self.cond = cond[1:]
        else:
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
        if self.shl == 0x0:
            return ""
        else:
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
        if self.off == 0x0:
            return ""
        else:
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
    # BARE is not a real instruction format, it's just used for the .emit
    # directive
    RRO, RIS, I, BARE = range(4)

class Instr(object):
    def __init__(self, mnem, opcode, format, cond = 0, emit = True,
                 imm = 0, dst_reg = 0, src_reg = 0, shl = 0, off = 0, bare = 0):
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
        self.bare = bare

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
        elif self.format == Format.BARE:
            return self.bare

    def __str__(self):
        if self.format == Format.RIS:
            return "{}{} r{}, 0x{:x} {}".format(self.mnem, self.cond, self.dst_reg, self.imm, self.shl)
        elif self.format == Format.RRO:
            return "{}{} r{}, r{} {}".format(self.mnem, self.cond, self.dst_reg, self.src_reg, self.off)
        elif self.format == Format.BARE:
            return "{}".format(self.mnem)

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
    def __init__(self, mnem, opcode, format, cond, **kwargs):
        super().__init__(mnem, opcode, format, cond, **kwargs)

    def __str__(self):
        if self.format == Format.I:
            return "jump{} 0x{:x}".format(self.cond, self.imm)
        elif self.format == Format.RIS:
            return "jump{} r{}".format(self.cond, self.dst_reg)

class Set(Instr):
    def __init__(self, mnem, opcode, format, cond, **kwargs):
        super().__init__(mnem, opcode, format, cond, **kwargs)

class Load(Instr):
    def __init__(self, mnem, opcode, format, cond, dst, src, off):
        super().__init__(mnem, opcode, format, cond, dst_reg = dst, src_reg = src, off = off)

class Testbit(Instr):
    def __init__(self, mnem, opcode, cond, reg, bitpos):
        super().__init__(mnem, opcode, Format.RIS, cond, dst_reg = reg, imm = bitpos)

    def __str__(self):
        return "{}{} r{}, {}".format(self.mnem, self.cond, self.dst_reg, self.imm)

class Sub(Instr):
    def __init__(self, mnem, opcode, cond, reg, sub_value):
        super().__init__(mnem, opcode, Format.RIS, cond, dst_reg = reg, imm = sub_value)

    def __str__(self):
        return "{}{} r{}, {}".format(self.mnem, self.cond, self.dst_reg, self.imm)

class Shiftl(Instr):
    def __init__(self, mnem, opcode, cond, reg, shift):
        super().__init__(mnem, opcode, Format.RIS, cond, dst_reg = reg, imm = shift)

    def __str__(self):
        return "{}{} r{}, {}".format(self.mnem, self.cond, self.dst_reg, self.imm)

class Shiftr(Instr):
    def __init__(self, mnem, opcode, cond, reg, shift):
        super().__init__(mnem, opcode, Format.RIS, cond, dst_reg = reg, imm = shift)

    def __str__(self):
        return "{}{} r{}, {}".format(self.mnem, self.cond, self.dst_reg, self.imm)

class Or(Instr):
    def __init__(self, mnem, opcode, cond, dst_reg, src_reg):
        super().__init__(mnem, opcode, Format.RRO, cond, dst_reg = dst_reg, src_reg = src_reg)

    def __str__(self):
        return "{}{} r{}, r{}".format(self.mnem, self.cond, self.dst_reg, self.src_reg)

class And(Instr):
    def __init__(self, mnem, opcode, cond, dst_reg, src_reg):
        super().__init__(mnem, opcode, Format.RRO, cond, dst_reg = dst_reg, src_reg = src_reg)

    def __str__(self):
        return "{}{} r{}, r{}".format(self.mnem, self.cond, self.dst_reg, self.src_reg)

class Xor(Instr):
    def __init__(self, mnem, opcode, cond, dst_reg, src_reg):
        super().__init__(mnem, opcode, Format.RRO, cond, dst_reg = dst_reg, src_reg = src_reg)

    def __str__(self):
        return "{}{} r{}, r{}".format(self.mnem, self.cond, self.dst_reg, self.src_reg)

class Store(Instr):
    def __init__(self, mnem, opcode, format, cond, src, dst, off):
        # nb. src and dst are swapped here - not really though
        super().__init__(mnem, opcode, format, cond, dst_reg = dst, src_reg = src, off = off)

    def __str__(self):
        if self.format == Format.RIS:
            return "{}{} 0x{:x}, r{} {}".format(self.mnem, self.cond, self.dst_reg, self.imm, self.off)
        elif self.format == Format.RRO:
            return "{}{} r{}, r{} {}".format(self.mnem, self.cond, self.src_reg, self.dst_reg, self.off)

class Env():
    def __init__(self):
        self.labels = {}
        self.defines = {}
        self.aliases = {}

    def new_label(self, name, address):
        # TODO: check for conflicts/overwriting
        self.labels[name] = address

    def get_label(self, name):
        if name in self.labels.keys():
            return self.labels[name]
        else:
            return None

    def new_define(self, name, value):
        # TODO: check for conflicts/overwriting
        self.defines[name] = value

    def get_define(self, name):
        if name in self.defines.keys():
            return self.defines[name]
        else:
            return None

    def new_alias(self, alias_name, reg):
        # TODO: check for conflicts/overwriting
        self.aliases[alias_name] = reg

    def get_alias(self, alias_name):
        if alias_name in self.aliases.keys():
            return self.aliases[alias_name]
        else:
            return None

    def get_alias_rev(self, reg):
        for alias_name, r in self.aliases.items():
            if reg == r:
                return alias_name

        return None

@v_args(inline = True)
class Emitter(Transformer):
    def __init__(self, env):
        self.current_pc = 0x0
        self.env = env

    def inc_pc(self):
        self.current_pc += 8

    def nop(self, op, cond):
        self.inc_pc()
        return Nop("nop", 0x0, Cond(cond))

    def halt(self, op, cond):
        self.inc_pc()
        return Halt("halt", 0x7f, Cond(cond))

    def jump_i(self, op, cond, imm):
        self.inc_pc()
        return Jump("jump", 0x04, Format.I, Cond(cond), imm = imm)

    def jump_ris(self, op, cond, reg):
        self.inc_pc()
        return Jump("jump", 0x04, Format.RIS, Cond(cond), dst_reg = reg)

    def set_ris(self, op, cond, dst, src, shl):
        self.inc_pc()
        return Set("set", 0x01, Format.RIS, Cond(cond), dst_reg = dst, imm = src, shl = Shl(shl))

    def set_rro(self, op, cond, dst_reg, src_reg):
        self.inc_pc()
        return Set("set", 0x01, Format.RRO, Cond(cond), dst_reg = dst_reg, src_reg = src_reg, off = Off(0x0))

    def load(self, op, cond, dst, src, off):
        self.inc_pc()
        return Load("load", 0x02, Format.RRO, Cond(cond), dst, src, Off(off))

    def store(self, op, cond, src, dst, off):
        self.inc_pc()
        return Store("store", 0x03, Format.RRO, Cond(cond), src, dst, Off(off))

    def testbit(self, op, cond, reg, imm):
        self.inc_pc()
        return Testbit("testbit", 0x05, Cond(cond), reg, imm)

    def sub(self, op, cond, reg, sub_value):
        self.inc_pc()
        return Sub("sub", 0x06, Cond(cond), reg, sub_value)

    def add(self, op, cond, reg, add_value):
        self.inc_pc()
        return Instr("add", 0x0b, Format.RIS, Cond(cond), dst_reg = reg, imm = add_value)

    def shiftl(self, op, cond, reg, shift):
        self.inc_pc()
        return Shiftl("shiftl", 0x07, Cond(cond), reg, shift)

    def shiftr(self, op, cond, reg, shift):
        self.inc_pc()
        return Shiftr("shiftr", 0x0c, Cond(cond), reg, shift)

    def or_(self, op, cond, dst_reg, src_reg):
        self.inc_pc()
        return Or("or", 0x08, Cond(cond), dst_reg, src_reg)

    def and_(self, op, cond, dst_reg, src_reg):
        self.inc_pc()
        return And("and", 0x09, Cond(cond), dst_reg, src_reg)

    def xor(self, op, cond, dst_reg, src_reg):
        self.inc_pc()
        return Xor("xor", 0x0a, Cond(cond), dst_reg, src_reg)

    def base(self, op, base_addr):
        new_pc = int(str(base_addr), base = 0)
        self.current_pc = new_pc
        print("# [emit] setting current base addr to 0x{:x}".format(new_pc))
        return Instr(0, 0, 0, emit = False)

    def define(self, op, name, value):
        return Instr(0, 0, 0, emit = False)

    def label(self, label):
        return Instr(0, 0, 0, emit = False)

    def alias(self, op, alias_name, reg):
        print("# [emit] aliasing register {} to name {}".format(reg, alias_name))
        self.env.new_alias(alias_name, reg)
        return Instr(0, 0, 0, emit = False)

    def emit(self, op, imm):
        self.inc_pc()
        print("# emitting bare immediate {}".format(imm))
        return Instr(".emit", 0, Format.BARE, Cond(), bare = imm)

    def reg(self, reg):
        if reg == "pc":
            reg_id = 31
        else:
            if self.env.get_alias(reg) != None:
                reg_id = self.env.get_alias(reg)
                print("# [emit] found register alias {}, aliasing r{}".format(reg, reg_id))
            elif reg[0] == "r":
                reg_id = int(str(reg)[1:])
                alias = self.env.get_alias_rev(reg_id)

                if alias != None:
                    print("Warning: you're using register {} directly".format(reg))
                    print("Warning: but it's already aliased with name {}".format(alias))
                    print("Warning: you probably didn't intend to do this!")
            else:
                raise Exception("unknown register {}!".format(reg))

        return reg_id

    def expr_add(self, lhs, rhs):
        return lhs + rhs

    def expr_sub(self, lhs, rhs):
        return lhs - rhs

    def expr_mul(self, lhs, rhs):
        return lhs * rhs

    def expr_div(self, lhs, rhs):
        return lhs / rhs

    def imm(self, value):
        return int(str(value), base = 0)

    def special_imm(self, imm):
        if imm == "#pc":
            print("# [emit] resolving #pc to 0x{:x}".format(self.current_pc))
            return self.current_pc
        elif imm[0] == "#":
            name = imm[1:]

            if self.env.get_label(name) != None:
                value = self.env.get_label(name)
                print("# [emit] found label {} with value 0x{:x}".format(name, value))
            elif self.env.get_define(name) != None:
                value = self.env.get_define(name)
                print("# [emit] found define {} with value 0x{:x}".format(name, value))
            else:
                raise Exception("special identifier #{} not found!".format(name))

            return value
        else:
            raise Exception("unknown special immediate value: {}".format(imm))

    def cond(self, cond):
        # print("-- condition: {}".format(cond))
        return cond

    def start(self, *instr):
        return instr

@v_args(inline = True)
class Prerun(Transformer):
    def __init__(self, env):
        self.current_pc = 0x0
        self.env = env

    def __default__(self, *args):
        self.current_pc += 8

    def base(self, op, imm):
        print("# [prerun] setting new base address to 0x{:x}".format(imm))
        self.current_pc = imm

    def define(self, op, name, value):
        print("# [prerun] defining new name '{}' with value {} (0x{:x})".format(name, value, value))
        self.env.new_define(str(name), value)

    def label(self, name):
        label_name = name[:-1]
        print("# [prerun] new label {} at 0x{:x}".format(label_name, self.current_pc))
        self.env.new_label(label_name, self.current_pc)

    def alias(self, op, alias_name, reg):
        pass

    def expr(self, expr):
        pass

    def expr_add(self, lhs, rhs):
        return lhs + rhs

    def expr_sub(self, lhs, rhs):
        return lhs - rhs

    def expr_mul(self, lhs, rhs):
        return lhs * rhs

    def expr_div(self, lhs, rhs):
        return lhs / rhs

    def imm(self, imm):
        return int(str(imm), base = 0)

    def special_imm(self, imm):
        if imm == "#pc":
            print("# [prerun] resolving #pc to 0x{:x}".format(self.current_pc))
            return self.current_pc
        elif imm[0] == "#":
            name = imm[1:]

            if self.env.get_label(name) != None:
                value = self.env.get_label(name)
                print("# [prerun] found label {} with value 0x{:x}".format(name, value))
            elif self.env.get_define(name) != None:
                value = self.env.get_define(name)
                print("# [prerun] found define {} with value 0x{:x}".format(name, value))
            else:
                value = 1337

            return value
        else:
            raise Exception("unknown special immediate value: {}".format(imm))

    def include(self, op, path):
        pass
    def cond(self, cond):
        pass
    def reg(self, reg):
        pass
    def start(self, *instructions):
        pass

@v_args(inline = True)
class IncludeRun(Transformer_InPlace):
    def include(self, op, path):
        print("# [include] including file {}.icm into the compilation".format(path))
        parser = Lark(open("asm.lark"), lexer = 'contextual', parser = 'lalr', maybe_placeholders = True)
        with open(path + ".icm", "r") as f:
            tree = parser.parse(f.read())
            IncludeRun().transform(tree)
        return tree

env = Env()

parser = Lark(open("asm.lark"), lexer = 'contextual', parser = 'lalr', maybe_placeholders = True)
tree = parser.parse(prog_args.input.read())

IncludeRun().transform(tree)
Prerun(env).transform(tree)

print()
print("Prerun finished.")
print("Defines:")
for key in env.defines.keys():
    print("{:>24s} => 0x{:016x} ({})".format(key, env.defines[key], env.defines[key]))

print("Labels:")
for key in env.labels.keys():
    print("{:>24s} => 0x{:016x} ({})".format(key, env.labels[key], env.labels[key]))

print()
print("Emitting the instructions:")
print()

instr = Emitter(env).transform(tree)

rom_addr = 0x0

for instr in instr:
    if isinstance(instr, Instr) and instr.emittable():
        emited = instr.emit()

        if prog_args.hex != None:
            print("{:016x}".format(emited), file = prog_args.hex)

        if prog_args.bin != None:
            print("{:064b}".format(emited), file = prog_args.bin)

        if prog_args.rom != None:
            print("16'h{:04x}: r_dat_o = 64'h{:016x}; // {}".format(rom_addr, emited, instr),
                file = prog_args.rom)
            rom_addr += 8

        if prog_args.raw != None:
            prog_args.raw.write(struct.pack('>Q', emited))
