# python 3
docu_intro = """send_simple.py uses a basic XOR encryption to scramble/descramble a short message (ASCII-encoded) sent to/from a network device that is running encrypt_simple.p4"""

docu_help = """To use the program type a command word and a string, eg. $e Hello World!
	| cmd  | description              |
	|------|--------------------------|
	| $d   | Send msg to be decrypted |
	| $e   | Send msg to be encrypted |
	| help | Display this message	  |
	| quit | Quit program             |        
	| :q   | Quit program             |        
	"""

# DEFAULT KEYS for program
key_es = 0x0123456789abcdef
key_ds = 0xcafeacce55c0ffee

# PROTOCOL PARAMETERS
data_length = 24 # in Bytes

# scapy for handling packets
from scapy.all import *

# Firstly define useful classes
class SecureHeader(Packet):
	name = "SecureHeader"
	# using scapy.fields
	fields_desc = [ StrFixedLenField("tag", default="P4", length=2),
					StrFixedLenField("cmd", default="$$", length=2),
					# Not fixing data length in case future variable length
					StrField("data",default="Default entry") ] 

# Every packet associated with ethernet type 0x1234 is assumed to be
# at the layer of SecureHeader
bind_layers(Ether, SecureHeader, type=0x1234)


# Make the message fit the packet size (SIMPLE version so it is janky)
def format_simple(msg):
	if len(msg) < data_length:
		msg = msg + " "*(data_length-len(msg))
	elif len(msg) > data_length:
		# For now just truncate message - in future chop into multiple 24B chunks
		msg = msg[:data_length]
	return msg

# Apply simple encryption to string
def encrypt_simple(msg,key):
	# using f-string formatting to directly get the ASCII values
	ascii_hex = "0x"+"".join(f"{ord(char):0x}" for char in msg)
	temp_key = "0x"+str(key)[2:]*3
	# need to use int type for bitwise XOR
	encrypted = int(ascii_hex,16) ^ int(temp_key,16)
	return hex(encrypted)

# Apply simple decrytion
def decrypt_simple(msg):
	# TODO
	decrypted = 0
	return decrypted


def get_if():
	# using scapy.interfaces
	iface = "enx0c37965f8a16"
	for i in get_if_list():
		if "eth0" in i:
			iface=i
			break;
	if not iface:
		print("Cannot find eth0 interface")
		exit(1)
	print(iface)
	return iface
	
	
def main():
	iface = get_if()
	
	print("Type help for short documentation")	
	while True:
		# emulating a CLI
		inp = input("> ")
		if inp[:4] == "quit" or inp[:2] == ":q": # using :q from vim
			print("Stopped running send_simple.py")
			break
		elif inp[:4] == "help":
			print(docu_intro)
			print(docu_help)
		# use try/except so that the program doesn't stop when an error occurs
		else: #try: 
			cmd, msg = inp.split(" ", maxsplit=1)
			msg = format_simple(msg)
			pkt = Ether(dst="e4:5f:01:8d:c8:32", type=0x1234)
			
			match cmd: # Is there a better way to implement this?
				case "$d":
					enc_msg = encrypt_simple(msg,key_ds)
					print(f"{msg} encrypts to {enc_msg}...")
					pkt = pkt / SecureHeader(cmd=cmd,data=enc_msg)
				case "$e":
					pkt = pkt / SecureHeader(cmd=cmd,data=msg)
				case _:
					print("Not a supported command")	
											
			pkt = pkt/' ' #stack packet onto whitespace string for empty payload
			pkt.show()			
			
			# srp1 sends an OSI L2 packet and stops listening after 1 reply
            # Layer 2 because no need for routing 
			response = srp1(pkt, iface=iface,timeout=5, verbose=False)
			print(response)
			if response:
				p4sh = response[SecureHeader]
				if p4sh:
					print(p4sh.result)
				else:
					print("ERROR: cannot find SecureHeader header in packet")
			else:
				print("ERROR: Didn't receive response")
			
		#except Exception as error:
			#print(error)
	
if __name__ == "__main__":
	main()
	
	
	
