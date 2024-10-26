import json

def get_max_sequence_length(filename="/Users/oracle/Documents/The Living Void/UNHEARD/dataAi/UNHEARD2.json"):
    max_sequence_length = 0

    try:
        with open(filename, "r", encoding="utf-8-sig") as f:  # Handle BOM if present
            for line_number, line in enumerate(f, start=1):
                line = line.strip()
                if line and line != ',':
                    try:
                        data = json.loads(line)
                        movements = data["movements"]
                        sequence_length = len(movements) * 2  # Each movement has x and y coordinates, so multiply by 2
                        if sequence_length > max_sequence_length:
                            max_sequence_length = sequence_length
                    except json.JSONDecodeError as e:
                        print(f"Error decoding JSON at line {line_number}: {e}")
                        print(f"Problematic line: {line}")
                        # Attempt to find and handle non-printable characters or BOM

    except FileNotFoundError:
        print(f"File '{filename}' not found.")

    return max_sequence_length

# Get the maximum sequence length
max_sequence_length = get_max_sequence_length()
print(f"Maximum sequence length: {max_sequence_length}")
