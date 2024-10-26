import json
import numpy as np
from sklearn.preprocessing import LabelEncoder
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
import joblib

# Define filenames
data_filename = "/Users/oracle/Documents/The Living Void/UNHEARD/dataAi/UNHEARD2.json"
model_filename = "/Users/oracle/Documents/The Living Void/UNHEARD/dataAi/UNHEARD2.joblib"
encoder_filename = "/Users/oracle/Documents/The Living Void/UNHEARD/dataAi/label_encoder_Unheard2.joblib"
maxLength = 302
#304

def load_data(filename):
    data = []
    try:
        with open(filename, "r", encoding="utf-8-sig") as f:  # Handle BOM if present
            for line_number, line in enumerate(f, start=1):
                line = line.strip()
                if line and line != ',':
                    try:
                        json_obj = json.loads(line)
                        data.append(json_obj)
                    except json.JSONDecodeError as e:
                        print(f"Error decoding JSON at line {line_number}: {e}")
                        print(f"Problematic line: {line}")
                        continue

    except FileNotFoundError:
        print(f"File '{filename}' not found.")

    return data


def preprocess_data(data, max_sequence_length=maxLength):
    X = []
    y = []
    
    for sample in data:
        movements = sample["movements"]
        gesture_label = sample["label"]
        
        features = []
        for movement in movements:
            features.extend([
                movement["right"]["x"], movement["right"]["y"], 
                movement["right"]["velocity"], movement["right"]["heightHand"], movement["right"]["turn"],
                movement["left"]["x"], movement["left"]["y"], 
                movement["left"]["velocity"], movement["left"]["heightHand"], movement["left"]["turn"]
            ])
        
        # Pad or truncate the sequence
        if len(features) < max_sequence_length * 10:
            features.extend([0] * (max_sequence_length * 10 - len(features)))
        else:
            features = features[:max_sequence_length * 10]
        
        X.append(features)
        y.append(gesture_label)
    
    return np.array(X), np.array(y)

def encode_labels(y):
    label_encoder = LabelEncoder()
    y_encoded = label_encoder.fit_transform(y)
    return y_encoded, label_encoder

def train_model(X_train, y_train):
    model = RandomForestClassifier(n_estimators=100, random_state=42)
    model.fit(X_train, y_train)
    return model

def evaluate_model(model, X_test, y_test):
    return model.score(X_test, y_test)

def save_model_and_encoder(model, label_encoder, model_filename, encoder_filename):
    joblib.dump(model, model_filename)
    joblib.dump(label_encoder, encoder_filename)

def load_model_and_encoder(model_filename, encoder_filename):
    model = joblib.load(model_filename)
    label_encoder = joblib.load(encoder_filename)
    return model, label_encoder

def predict_gesture(model, label_encoder, movements, max_sequence_length=maxLength):
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

# Main execution
data = load_data(data_filename)
X, y = preprocess_data(data)
y_encoded, label_encoder = encode_labels(y)

X_train, X_test, y_train, y_test = train_test_split(X, y_encoded, test_size=0.2, random_state=42)

model = train_model(X_train, y_train)

accuracy = evaluate_model(model, X_test, y_test)
print(f"Model accuracy: {accuracy * 100:.2f}%")

save_model_and_encoder(model, label_encoder, model_filename, encoder_filename)

# Example usage: Load model and label encoder for prediction
loaded_model, loaded_label_encoder = load_model_and_encoder(model_filename, encoder_filename)

def predict_gesture_from_movements(movements):
    gesture = predict_gesture(loaded_model, loaded_label_encoder, movements)
    return gesture

# You can now use predict_gesture_from_movements() with new data