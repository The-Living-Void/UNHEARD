import socket
import json
import time
import os

# source testEnv/bin/activate
# Parameters
locationData = "/Users/oracle/Documents/The Living Void/UNHEARD/testData/UNHEARD_test2.json"
gesture_labels = ["Data", "Sign Language", "Representation", "Nothing/Noise","Still/Not Moving"]
num_sequences = 50  # Number of sequences per gesture
sequence_duration = 2.5  # Duration of each sequence in seconds


# Function to handle received data
# def handle_data(data, start_time):
#     current_time = time.time()
#     elapsed_time = current_time - start_time
#     normalized_timestamp = start_time + (elapsed_time // sequence_duration) * sequence_duration  # Normalize timestamp every 2 seconds
#     x, y = map(int, data.split(","))
#     return {"timestamp": normalized_timestamp, "x": x, "y": y}

def handle_data(data, start_time):
    current_time = time.time()
    elapsed_time = current_time - start_time
    normalized_timestamp = start_time + (elapsed_time // sequence_duration) * sequence_duration  # Normalize timestamp every 2 seconds
    
    # Split the data string into individual values
    xR, yR, velocity1R, heightHandR, turnR, xL, yL, velocity1L, heightHandL, turnL = map(float, data.split(","))
    
    return {
        "timestamp": normalized_timestamp,
        "right": {
            "x": xR,
            "y": yR,
            "velocity": velocity1R,
            "heightHand": heightHandR,
            "turn": turnR
        },
        "left": {
            "x": xL,
            "y": yL,
            "velocity": velocity1L,
            "heightHand": heightHandL,
            "turn": turnL
        }
    }

# Function to save data
def save_data(data, filename=locationData):
    # Check if file exists
    file_exists = os.path.isfile(filename)
    
    with open(filename, "a") as f:
        # If file exists and is not empty, add a comma for JSON array syntax
        if file_exists and os.stat(filename).st_size != 0:
            f.write(",\n")
        
        json.dump(data, f)
        f.write("\n")

# Function to count existing sequences for each label
def count_existing_sequences(filename):
    gesture_counts = {}
    if os.path.isfile(filename):
        with open(filename, "r") as f:
            for line in f:
                line = line.strip()
                if line:  # Check if line is not empty
                    try:
                        gesture_data = json.loads(line)
                        label = gesture_data["label"]
                        if label in gesture_counts:
                            gesture_counts[label] += 1
                        else:
                            gesture_counts[label] = 1
                    except json.JSONDecodeError as e:
                        print(f"Error decoding JSON: {e}")
                        continue
    return gesture_counts

# Set up UDP server
ip = "127.0.0.1"
port = 12348
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind((ip, port))

print(f"Listening for UDP data on {ip}:{port}")



# Count existing sequences
existing_counts = count_existing_sequences(locationData)

# Collecting data
try:
    for gesture_label in gesture_labels:
        if gesture_label in existing_counts:
            current_count = existing_counts[gesture_label]
        else:
            current_count = 0
        
        sequences_needed = num_sequences - current_count
        
        if sequences_needed <= 0:
            print(f"Skipping '{gesture_label}' as it already has {current_count} sequences.")
            continue
        
        for sequence_num in range(sequences_needed):
            data_list = []

            # Wait for the first data to arrive
            data, addr = sock.recvfrom(1024)

            # Start the timer now that we've received some data
            start_time = time.time()
            processed_data = handle_data(data.decode('utf-8'), start_time)
            data_list.append(processed_data)

            # Continue receiving data until the sequence duration is reached
            while time.time() - start_time < sequence_duration:
                data, addr = sock.recvfrom(1024)
                processed_data = handle_data(data.decode('utf-8'), start_time)
                data_list.append(processed_data)

            # Save collected sequence
            gesture_data = {"label": gesture_label, "movements": data_list}
            save_data(gesture_data)
            print(f"Saved sequence {sequence_num + 1} for gesture '{gesture_label}'")
finally:
    print("Data collection completed.")
