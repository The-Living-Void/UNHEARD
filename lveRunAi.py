import joblib
import numpy as np
import socket
import time
from collections import deque

# Load the model and label encoder
model = joblib.load("/Users/oracle/Documents/The Living Void/UNHEARD/testData/UNHEARD.joblib")
label_encoder = joblib.load("/Users/oracle/Documents/The Living Void/UNHEARD/testData/label_encoder_Unheard.joblib")

# Define parameters
max_sequence_length = 304
window_size = 100
prediction_interval = 1.5

# Set up UDP server to receive data
receive_ip = "127.0.0.1"
receive_port = 12348
receive_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
receive_sock.bind((receive_ip, receive_port))

# Set up UDP client to send data back to Processing
send_ip = "127.0.0.1"
send_port = 12349  # Different port for sending data back
send_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

def predict_gesture(movements, max_sequence_length=max_sequence_length):
    # Your existing predict_gesture function remains the same
    features = []
    for movement in movements:
        features.extend([
            movement["right"]["x"], movement["right"]["y"], 
            movement["right"]["velocity"], movement["right"]["heightHand"], movement["right"]["turn"],
            movement["left"]["x"], movement["left"]["y"], 
            movement["left"]["velocity"], movement["left"]["heightHand"], movement["left"]["turn"]
        ])
    
    if len(features) < max_sequence_length * 10:
        features.extend([0] * (max_sequence_length * 10 - len(features)))
    else:
        features = features[:max_sequence_length * 10]
    
    features = np.array(features).reshape(1, -1)
    prediction = model.predict(features)
    gesture = label_encoder.inverse_transform(prediction)
    return gesture[0]

def send_to_processing(gesture):
    # Define which gestures should trigger messages
    gesture_messages = {
        "Data": "ACTION_Data",
        "Sign Language": "ACTION_Sign Language",
        "Representation": "ACTION_Representation",        
        "Still/Not Moving": "ACTION_Still/Not Moving",
        
        # Add more gesture-message mappings as needed
    }
    
    if gesture in gesture_messages:
        message = gesture_messages[gesture]
        send_sock.sendto(message.encode(), (send_ip, send_port))
        print(f"Sent message '{message}' to Processing")

print(f"Listening for UDP data on {receive_ip}:{receive_port}")
print(f"Sending responses to {send_ip}:{send_port}")

movement_buffer = deque(maxlen=window_size)
last_prediction_time = time.time()

try:
    while True:
        data, addr = receive_sock.recvfrom(4096)
        movement_data = data.decode('utf-8').split(',')
        
        if len(movement_data) == 10:
            movement = {
                "right": {
                    "x": float(movement_data[0]),
                    "y": float(movement_data[1]),
                    "velocity": float(movement_data[2]),
                    "heightHand": float(movement_data[3]),
                    "turn": float(movement_data[4])
                },
                "left": {
                    "x": float(movement_data[5]),
                    "y": float(movement_data[6]),
                    "velocity": float(movement_data[7]),
                    "heightHand": float(movement_data[8]),
                    "turn": float(movement_data[9])
                }
            }
            movement_buffer.append(movement)
        
        current_time = time.time()
        if current_time - last_prediction_time >= prediction_interval and len(movement_buffer) == window_size:
            gesture = predict_gesture(list(movement_buffer))
            # print(f"Predicted gesture: {gesture}")
            send_to_processing(gesture)  # Send message back to Processing
            last_prediction_time = current_time

except KeyboardInterrupt:
    print("Stopping the gesture recognition system.")
finally:
    receive_sock.close()
    send_sock.close()