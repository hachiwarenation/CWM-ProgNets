/* -*- P4_16 -*- */

/*
 * P4 Simple XOR encryption, v1
 *
 * This program implements a simple protocol. It can be carried over Ethernet
 * (Ethertype 0x1234).
 *
 * The Protocol header looks like this:
 *
 *     <--tag-->       <--cmd-->
 *     0       1       2       3               
 * +-------+-------+-------+-------+
 * |   P       4       $      e/d  |
 * +-------+-------+-------+-------+
 * |    data                       |
 * +-------+-------+-------+-------+
 * |    data                       |
 * +-------+-------+-------+-------+
 * |    etc.                       |
 * +-------+-------+-------+-------+
 *
 *
 * P is ASCII Letter 'P' (0x50)
 * 4 is ASCII Letter '4' (0x34)
 * $ is ASCII Letter '$' (0x24)
 * e/d are ASCII Letter 'e' (0x65) or 'd' (0x64)
 * 
 *
 * The device receives a packet, performs an en/decryption based on the
 * command and sends the packet back out of the same port it came in on,
 * while swapping the source and destination addresses.
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
const bit<16> P4SH_ETYPE  = 0x1234;
const bit<8>  P4SH_P      = 0x50;   // 'P'
const bit<8>  P4SH_4      = 0x34;   // '4'
const bit<8>  P4SH_DOLLAR = 0x24;
const bit<8>  P4SH_e      = 0x65;
const bit<8>  P4SH_d      = 0x64;

/* And also the key until I figure out how to write it at the control plane */
const bit<64> P4SH_KEY_E = 0xcafeacce55c0ffee;
const bit<64> P4SH_KEY_D = 0x0123456789abcdef;

/* Create the custom header */
header SecureHeader {
    // I was going to use header stacks but im not smart enough :(
    bit<16> tag;
    bit<16> cmd;
    bit<64> row0; // want to implement varbit in future
    bit<64> row1;
    bit<64> row2;
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
        
        transition select(packet.lookahead<SecureHeader>().tag) {
            (P4SH_P ++ P4SH_4) : parse_p4sh;
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
        /* Swaps MAC addresses and port */
          temp = hdr.ethernet.dstAddr;
          hdr.ethernet.dstAddr = hdr.ethernet.srcAddr;
          hdr.ethernet.srcAddr = temp;
          standard_metadata.egress_spec = standard_metadata.ingress_port;
    }

    action operation_encrypt() {
        /* XOR with encryption key */
        // There is definitely a better way to implement this... a for loop?
        hdr.p4sh.row0 = hdr.p4sh.row0 ^ P4SH_KEY_E;
        hdr.p4sh.row1 = hdr.p4sh.row1 ^ P4SH_KEY_E;
        hdr.p4sh.row2 = hdr.p4sh.row2 ^ P4SH_KEY_E;
        send_back();
    }
    
    action operation_decrypt() {
        /* XOR with decryption key */
        hdr.p4sh.row0 = hdr.p4sh.row0 ^ P4SH_KEY_D;
        hdr.p4sh.row1 = hdr.p4sh.row1 ^ P4SH_KEY_D;
        hdr.p4sh.row2 = hdr.p4sh.row2 ^ P4SH_KEY_D;
        send_back();
    }

    action operation_drop() {
        mark_to_drop(standard_metadata);
    }

    table calculate {
        key = {
            hdr.p4sh.cmd        : exact;
        }
        actions = {
            operation_encrypt;
            operation_decrypt;
            operation_drop;
        }
        const default_action = operation_drop();
        const entries = {
            P4SH_DOLLAR ++ P4SH_e : operation_encrypt();
            P4SH_DOLLAR ++ P4SH_d : operation_decrypt();
        }
    }

    apply {
        if (hdr.p4sh.isValid()) {
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
        packet.emit(hdr.p4sh);
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
