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
            print("{:016x}".format(instr), file = prog_args.output)

parser = Lark(open("asm.lark"), parser = 'lalr', transformer = Compiler)
tree = parser.parse(prog_args.input.read())
