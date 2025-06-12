/* -*- P4_16 -*- */

/*
 * P4 Simple XOR encryption, v1
 *
 * This program implements a simple protocol. It can be carried over Ethernet
 * (Ethertype 0x1234).
 *
 * The Protocol header looks like this:
 *
 *     0       1       2       3    ...      7              
 * +-------+-------+-------+-------+---+--------+
 * |   P       4      e/d     n/e    data       |
 * +-------+-------+-------+-------+---+--------+
 * |    data                                    |
 * +-------+-------+-------+-------+---+--------+
 * |    ""                                      |
 * +-------+-------+-------+-------+---+--------+
 * |    ""                                      |
 * +-------+-------+-------+-------+---+--------+
 *
 *
 * P is ASCII Letter 'P' (0x50)
 * 4 is ASCII Letter '4' (0x34)
 * e/d are ASCII Letter 'e' or 'd'
 * n/e are ASCII Letter 'n' or 'e'
 * 
 *
 * The device receives a packet, performs an en/decryption
 * and sends the packet back out of the same port it came in on, while
 * swapping the source and destination addresses.
 *
 * If the header is not valid, the packet is dropped.
 */

#include <core.p4>
#include <v1model.p4>

/*
 * Define the headers the program will recognize
 */

/*
 * Standard Ethernet header
 */
header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

/* Define some constants here for later use */
const bit<16> P4SH_ETYPE = 0x1234;
const bit<8>  P4SH_P     = 0x50;   // 'P'
const bit<8>  P4SH_4     = 0x34;   // '4'


/* Create the custom header */
header SecureHeader {
    // I was going to use header stacks but im not smart enough :(
    bit<64> row1;
    bit<64> row2;
    bit<64> row3;
    bii<64> row4;
}


/*
 * All headers, used in the program needs to be assembled into a single struct.
 * We only need to declare the type, but there is no need to instantiate it,
 * because it is done "by the architecture", i.e. outside of P4 functions
 */
struct headers {
    ethernet_t   ethernet;
    SecureHeader p4sh;
}

/*
 * All metadata, globally used in the program, also needs to be assembled
 * into a single struct. As in the case of the headers, we only need to
 * declare the type, but there is no need to instantiate it,
 * because it is done "by the architecture", i.e. outside of P4 functions
 */

struct metadata {
    /* In our case it is empty */
}

/*************************************************************************
 ***********************  P A R S E R  ***********************************
 *************************************************************************/
parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {
    state start {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            P4SH_ETYPE : check_p4sh;
            default      : accept;
        }
    }

    state check_p4sh {
        /* the following parse block looks if the packet is for encryption or decryption */
        
        transition select(packet.lookahead<SecureHeader>().data[0:7],
        packet.lookahead<SecureHeader>().data[8:15]) {
            (P4SH_P, P4SH_4) : parse_p4sh;
            default                    : accept;
        }
        
    }

    state parse_p4sh {
        packet.extract(hdr.p4sh);
        transition accept;
    }
}

/*************************************************************************
 ************   C H E C K S U M    V E R I F I C A T I O N   *************
 *************************************************************************/
control MyVerifyChecksum(inout headers hdr,
                         inout metadata meta) {
    apply { }
}

/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
                  
    bit<48> temp;
    
    action send_back() {
        /* */
          temp = hdr.ethernet.dstAddr;
          hdr.ethernet.dstAddr = hdr.ethernet.srcAddr;
          hdr.ethernet.srcAddr = temp;
          standard_metadata.egress_spec = standard_metadata.ingress_port;
    }

    action operation_xor() {
        /* operand_a ^ operand_b */
        send_back();
    }

    action operation_drop() {
        mark_to_drop(standard_metadata);
    }

    table calculate {
        key = {
            hdr.p4calc.op        : exact;
        }
        actions = {
            operation_add;
            operation_sub;
            operation_and;
            operation_or;
            operation_xor;
            operation_drop;
        }
        const default_action = operation_drop();
        const entries = {
            P4CALC_PLUS : operation_add();
            P4CALC_MINUS: operation_sub();
            P4CALC_AND  : operation_and();
            P4CALC_OR   : operation_or();
            P4CALC_CARET: operation_xor();
        }
    }

    apply {
        if (hdr.p4calc.isValid()) {
            calculate.apply();
        } else {
            operation_drop();
        }
    }
}

/*************************************************************************
 ****************  E G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply { }
}

/*************************************************************************
 *************   C H E C K S U M    C O M P U T A T I O N   **************
 *************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
    apply { }
}

/*************************************************************************
 ***********************  D E P A R S E R  *******************************
 *************************************************************************/
control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.p4calc);
    }
}

/*************************************************************************
 ***********************  S W I T C H ************************************
 *************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
