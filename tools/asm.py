from lark import Lark, Transformer, v_args

grammar = """
    start: instr*
    ?instr: opcode reg "," imm ["shl" imm] -> instr_ris
          | opcode reg "," reg ["off" imm] -> instr_rro
          | opcode [imm] -> instr_i

    !reg: /r[0-9]+/ -> reg
        | "pc" -> reg
    !sep: /[\\n;]/

    !imm: /0b[0-1]+/ -> imm
        | /0c[0-7]+/ -> imm
        | /(0d)?[0-9]+/ -> imm
        | /0x[0-9a-fA-F]+/ -> imm

    !opcode: "nop" -> nop
           | "set" -> set
           | "load" -> load
           | "store" -> store
           | "halt" -> halt

    COMMENT: /#(.*)/

    %import common.WS -> WS
    %ignore COMMENT
    %ignore WS
"""

asm = """
set r1, 0x00008010 shl 32
set r2, 0x73 shl 0
load r3, r1 off 0
store r2, r1 off 0x10
load r3, r1 off 0
nop
nop
halt
halt
"""

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

    def nop(self):   return 0b0000000
    def set(self):   return 0b0000001
    def load(self):  return 0b0000010
    def store(self): return 0b0000011
    def halt(self):  return 0b1111111

    def instr_ris(self, *args):
        opcode = int(str(self), base = 0)
        reg = args[0]
        imm = args[1]

        try:
            shl = args[2]
        except:
            shl = 0

        instr = opcode << 57 | reg << 50 | imm << 6 | shl

        return int(instr)

    def instr_rro(self, *args):
        opcode = int(str(self), base = 0)
        reg_dst = args[0]
        reg_src = args[1]

        try:
            off = args[2]
        except:
            off = 0

        instr = opcode << 57 | reg_dst << 50 | reg_src << 45 | off

        return instr

    def instr_i(self, *args):
        opcode = int(str(self), base = 0)

        try:
            imm = args[0]
        except:
            imm = 0

        instr = opcode << 57 | imm

        return instr

    def start(self, *args):
        for instr in [self, *args]:
            print("{:016x}".format(instr))

parser = Lark(grammar, parser = 'lalr', transformer = Compiler)
tree = parser.parse(asm)
