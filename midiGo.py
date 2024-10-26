import mido
import socket

# Set up the UDP socket
udp_ip = "127.0.0.1"  # Localhost
udp_port = 5005  # Port number
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

midiCh = 1
port_name = 'IAC Driver Bus 1'

with mido.open_input(port_name) as inport:
    print(f"Listening for MIDI messages on channel {midiCh}...")
    for msg in inport:
        if not msg.is_meta and msg.channel == midiCh-1:
            if msg.control in [0, 2, 3, 4, 5 ,6,7,10, 12, 13, 14, 15 ,16,17]:
                # Send the control number and value as a string
                message = f"{msg.control}:{msg.value}"
                sock.sendto(message.encode(), (udp_ip, udp_port))
