# Slightly modified from original because it wasn't working on the computer (?)
#!/usr/bin/env python3

# re library is for RegEx substring matching
import re
# scapy is for handling packets
from scapy.all import *

class P4calc(Packet):
    name = "P4calc"
    fields_desc = [ StrFixedLenField("p", "P", length=1),
                    StrFixedLenField("four", "4", length=1),
                    XByteField("version", 0x01),
                    StrFixedLenField("op", "+", length=1),
                    IntField("operand_a", 0),
                    IntField("operand_b", 0),
                    IntField("result", 0xDEADBABE)]

bind_layers(Ether, P4calc, type=0x1234)

class NumParseError(Exception):
    pass

class OpParseError(Exception):
    pass

class Token:
    def __init__(self,type,value = None):
        self.type = type
        self.value = value

# takes a string s with cursor pointer at i, and a list of tokens ts
# creates a number token to add to ts and updates the cursor position to end 
# of number
def num_parser(s, i, ts):
    pattern = "^\s*([0-9]+)\s*"
    match = re.match(pattern,s[i:])
    if match:
        ts.append(Token('num', match.group(1)))
        return i + match.end(), ts
    raise NumParseError('Expected number literal.')

# same as above but creates an operator token instead
def op_parser(s, i, ts):
    pattern = "^\s*([-+&|^])\s*"
    match = re.match(pattern,s[i:])
    if match:
        ts.append(Token('num', match.group(1))) # err is there a mistake here?
        return i + match.end(), ts
    raise NumParseError("Expected binary operator '-', '+', '&', '|', or '^'.")


def make_seq(p1, p2):
    def parse(s, i, ts):
        i,ts2 = p1(s,i,ts)
        return p2(s,i,ts2)
    return parse

def get_if():
    # ISSUE: computer does not have "eth0" in its interface naming convention
    ifs=get_if_list()
    # need to use local ethernet interface - how to implement for any computer?
    iface= "enx0c37965f8a16" #"veth0-1" # "h1-eth0"
    ### DEBUGGING SECTION
    for i in get_if_list():
        if "eth0" in i:
            iface=i
            break;
    if not iface:
        print("Cannot find eth0 interface")
        exit(1)
    #print(iface)
    ###
    return iface

def main():
    # in this exercise we only use simple binary op expressions
    p = make_seq(num_parser, make_seq(op_parser,num_parser))
    s = ''
    iface = get_if() #"enx0c37965f8a16" # get_if()
    #iface = "veth0-1"

    while True:
        # emulating a Command-Line Interface
        s = input('> ')
        if s == "quit" or s == ":q":
            break
        print(s)
        try:
            i,ts = p(s,0,[])
            # need to use local ethernet address of raspberry pi here
            pkt = Ether(dst='e4:5f:01:8d:c8:32', type=0x1234) / P4calc(op=ts[1].value,
                                              operand_a=int(ts[0].value),
                                              operand_b=int(ts[2].value))

            pkt = pkt/' ' #stack packet onto whitespace string for empty payload

            pkt.show()
        
            # srp1 sends an OSI L2 packet and stops listening after 1 reply
            # Layer 2 because no need for routing 
            resp = srp1(pkt, iface=iface,timeout=5, verbose=False)
            if resp:
                p4calc=resp[P4calc]
                if p4calc:
                    print(p4calc.result)
                else:
                    print("cannot find P4calc header in the packet")
            else:
                print("Didn't receive response")
        except Exception as error:
            print(error)


if __name__ == '__main__':
    main()


