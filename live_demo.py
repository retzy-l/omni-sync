import cv2
import torch
import torch.nn as nn
from torchvision import transforms, datasets
from PIL import Image
import numpy as np
import time
from collections import deque, Counter
import pyttsx3
import os

# ==========================================
# 1. MODEL ARCHITECTURE
# ==========================================
class ASLRobot(nn.Module):
    def __init__(self, num_classes=29):
        super(ASLRobot, self).__init__()
        self.features = nn.Sequential(
            nn.Conv2d(3, 32, kernel_size=3, padding=1),
            nn.BatchNorm2d(32), nn.ReLU(), nn.MaxPool2d(2, 2),
            
            nn.Conv2d(32, 64, kernel_size=3, padding=1),
            nn.BatchNorm2d(64), nn.ReLU(), nn.MaxPool2d(2, 2),
            
            nn.Conv2d(64, 128, kernel_size=3, padding=1),
            nn.BatchNorm2d(128), nn.ReLU(), nn.MaxPool2d(2, 2)
        )

        self.classifier = nn.Sequential(
            nn.Flatten(),
            nn.Dropout(0.5),
            nn.Linear(128 * 8 * 8, 512),
            nn.ReLU(),
            nn.Dropout(0.5),
            nn.Linear(512, num_classes)
        )

    def forward(self, x):
        x = self.features(x)
        x = self.classifier(x)
        return x


# ==========================================
# 2. HELPERS
# ==========================================
def speak_sentence(engine, text):
    if text.strip() == "":
        return
    try:
        engine.say(text)
        engine.runAndWait()
    except:
        pass

def save_mistake(frame, correct_label):
    folder = "mistakes_collection"
    os.makedirs(folder, exist_ok=True)
    filename = f"{folder}/{correct_label}_{int(time.time())}.jpg"
    cv2.imwrite(filename, frame)
    print(f"Saved mistake for learning: {correct_label}")

def draw_ui(frame, predicted_label, confidence, sentence, status_message, auto_add_progress):
    h, w, c = frame.shape
    NEON_GREEN = (50, 255, 50)
    NEON_BLUE = (255, 200, 50)
    WARNING_RED = (50, 50, 255)

    color = NEON_GREEN if confidence > 60 else WARNING_RED

    cv2.rectangle(frame, (100, 100), (350, 350), color, 2)

    bar_length = int(confidence * 2.5)
    cv2.rectangle(frame, (100, 360), (100 + bar_length, 370), color, -1)
    cv2.putText(frame, f"{int(confidence)}%", (360, 370), cv2.FONT_HERSHEY_PLAIN, 1, color, 1)

    if auto_add_progress > 0:
        cv2.rectangle(frame, (100, 380), (100 + int(auto_add_progress * 2.5), 390), NEON_BLUE, -1)

    overlay = frame.copy()
    cv2.rectangle(overlay, (0, h - 80), (w, h), (0, 0, 0), -1)
    cv2.addWeighted(overlay, 0.7, frame, 0.3, 0, frame)

    cv2.putText(frame, f"DETECTED: {predicted_label}", (20, h - 45),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)
    cv2.putText(frame, f"SENTENCE: {sentence}|", (250, h - 45),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)

    if status_message:
        cv2.putText(frame, status_message, (w // 2 - 100, h // 2),
                    cv2.FONT_HERSHEY_SIMPLEX, 1.2, (0, 255, 255), 3)


# ==========================================
# 3. MAIN PROGRAM
# ==========================================
def main():
    MODEL_PATH = "asl_robot_brain.pth"
    DATA_DIR = "./asl_alphabet_train/asl_alphabet_train"

    print("Loading class names...")
    dummy_dataset = datasets.ImageFolder(root=DATA_DIR)
    CLASSES = dummy_dataset.classes
    print("Classes:", CLASSES)

    # Initialize voice
    try:
        engine = pyttsx3.init()
        engine.setProperty("rate", 150)
    except:
        engine = None

    print("Loading model...")
    device = torch.device("cpu")
    model = ASLRobot(num_classes=len(CLASSES))
    model.load_state_dict(torch.load(MODEL_PATH, map_location=device))
    model.eval()

    transform = transforms.Compose([
        transforms.Resize((64, 64)),
        transforms.ToTensor(),
        transforms.Normalize(
            (0.5, 0.5, 0.5),
            (0.5, 0.5, 0.5)
        )
    ])

    cap = cv2.VideoCapture(0)

    sentence = ""
    history = deque(maxlen=5)

    last_pred = "nothing"
    hold_frames = 0
    REQUIRED = 45

    BLOCKED = ["nothing", "space", "del", "J", "Z"]

    status_msg = ""
    timer = 0

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        frame = cv2.flip(frame, 1)

        x1, y1, x2, y2 = 100, 100, 350, 350
        roi = frame[y1:y2, x1:x2]

        img = Image.fromarray(cv2.cvtColor(roi, cv2.COLOR_BGR2RGB))
        tensor = transform(img).unsqueeze(0)

        with torch.no_grad():
            out = model(tensor)
            probs = torch.softmax(out, dim=1)
            conf, idx = torch.max(probs, 1)
            pred = CLASSES[idx.item()]
            conf = conf.item() * 100

        history.append(pred)
        pred = Counter(history).most_common(1)[0][0]

        # AUTO TYPING FIXED
        if pred == last_pred and pred not in BLOCKED:
            hold_frames += 1
            if hold_frames == REQUIRED:
                sentence += pred
                status_msg = "AUTO TYPED"
                timer = 30
                hold_frames = 0
        else:
            last_pred = pred
            hold_frames = 0

        progress = min(100, (hold_frames / REQUIRED) * 100)

        if timer > 0:
            timer -= 1
        else:
            status_msg = ""

        draw_ui(frame, pred, conf, sentence, status_msg, progress)

        cv2.imshow("ASL Robot", frame)

        key = cv2.waitKey(1) & 0xFF

        if key == ord("q"):
            break
        elif key == 13:  # ENTER → speak
            if engine:
                speak_sentence(engine, sentence)
            sentence = ""
        elif key == ord(" "):
            sentence += " "
        elif key == ord("d"):
            sentence = sentence[:-1]
        elif 97 <= key <= 122:  # a-z
            ch = chr(key).upper()
            save_mistake(roi, ch)

    cap.release()
    cv2.destroyAllWindows()


if __name__ == "__main__":
    main()