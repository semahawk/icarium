#!/usr/bin/env python3

from lark import Lark, Transformer, v_args

grammar = """
    start: instr*
    instr: /set/ reg "," imm ["shl" imm] -> set
          | /load/ reg "," reg ["off" imm] -> load
          | /store/ reg "," reg ["off" imm] -> store
          | /nop/ -> nop
          | /halt/ -> halt

    !reg: /r[0-9]+/ -> reg
        | "pc" -> reg
    !sep: /[\\n;]/

    !imm: /0b[0-1]+/ -> imm
        | /0c[0-7]+/ -> imm
        | /(0d)?[0-9]+/ -> imm
        | /0x[0-9a-fA-F]+/ -> imm

    COMMENT: /#(.*)/

    %import common.WS -> WS
    %ignore COMMENT
    %ignore WS
"""

asm = """
set r1, 0x00008010 shl 32
set r2, 0x73
load r3, r1
store r2, r1 off 0x10
load r3, r1
nop
nop
halt
halt
"""

def ris(opcode, variant, reg, imm, shl = 0):
    return opcode << 57 | variant << 55 | reg << 50 | imm << 6 | shl

def rro(opcode, variant, reg_dst, reg_src, off = 0):
    return opcode << 57 | variant << 55 | reg_dst << 50 | reg_src << 45 | off

def i(opcode, variant, imm):
    return opcode << 57 | imm

@v_args(inline = True)
class Compiler(Transformer):
    def reg(self, *args):
        if self == "pc":
            reg_id = 31
        else:
            reg_id = str(self)[1:]

        return int(reg_id)

    def imm(self, *args):
        return int(self, base=0)

    def nop(self, *args):
        return i(0b0000000, 0b00, 0)

    def halt(self, *args):
        return i(0b1111111, 0b00, 0)

    def set(self, *args):
        reg = args[0]
        imm = args[1]

        try:
            shl = args[2]
        except:
            shl = 0

        return ris(0b0000001, 0b00, reg, imm, shl)

    def load(self, *args):
        reg_dst = args[0]
        reg_src = args[1]

        try:
            off = args[2]
        except:
            off = 0

        return rro(0b0000010, 0b00, reg_dst, reg_src, off)

    def store(self, *args):
        reg_src = args[0]
        reg_dst = args[1]

        try:
            off = args[2]
        except:
            off = 0

        return rro(0b0000011, 0b00, reg_dst, reg_src, off)

    def start(self, *args):
        for instr in [self, *args]:
            print("{:016x}".format(instr))

parser = Lark(grammar, parser = 'lalr', transformer = Compiler)
tree = parser.parse(asm)
