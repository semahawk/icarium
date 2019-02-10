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

prog_args = prog_argp.parse_args()

def ris(opcode, variant, reg, imm, shl = 0):
    return Instr(opcode << 57 | variant << 55 | reg << 50 | imm << 6 | shl)

def rro(opcode, variant, reg_dst, reg_src, off = 0):
    return Instr(opcode << 57 | variant << 55 | reg_dst << 50 | reg_src << 45 | off)

def i(opcode, variant, imm):
    return Instr(opcode << 57 | imm)

class Instr():
    def __init__(self, encoding, emit = True):
        self.encoding = encoding
        self.emit = emit

@v_args(inline = True)
class Compiler(Transformer):
    def __init__(self):
        self.current_pc = 0x0

    def base(self, op, base_addr):
        new_pc = int(str(base_addr), base = 0)
        self.current_pc = new_pc
        # print("# setting current base addr to 0x{:x}".format(new_pc))
        return Instr(new_pc, emit = False)

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
            # print("# current pc is 0x{:x}".format(self.current_pc))
            return self.current_pc
        else:
            raise Exception("unknown special immediate value: {}".format(imm))

    def nop(self, op):
        # print("{}".format(op))
        self.current_pc += 8
        return i(0b0000000, 0b00, 0)

    def halt(self, op):
        # print("{}".format(op))
        self.current_pc += 8
        return i(0b1111111, 0b00, 0)

    def set(self, op, reg, imm, shl = 0):
        # print("{} r{}, 0x{:x} shl {}".format(op, reg, imm, shl))
        self.current_pc += 8
        return ris(0b0000001, 0b00, reg, imm, shl)

    def load(self, op, reg_dst, reg_src, off = 0):
        # print("{} r{}, r{} off {}".format(op, reg_dst, reg_src, off))
        self.current_pc += 8
        return rro(0b0000010, 0b00, reg_dst, reg_src, off)

    def store(self, op, reg_src, reg_dst, off = 0):
        # print("{} r{}, r{} off {}".format(op, reg_src, reg_dst, off))
        self.current_pc += 8
        return rro(0b0000011, 0b00, reg_dst, reg_src, off)

    def start(self, *instr):
        for instr in instr:
            if instr.emit:
                print("{:016x}".format(instr.encoding), file = prog_args.output)
                self.current_pc = 8

parser = Lark(open("asm.lark"), parser = 'lalr', transformer = Compiler())
tree = parser.parse(prog_args.input.read())
