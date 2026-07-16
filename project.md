
# CareBridge
### Bridging Communication Between Caregivers and Deaf Individuals using Apple Intelligence

## Overview

CareBridge is an assistive communication application designed to help **caregivers (CG)** and **deaf or hard-of-hearing individuals (TL)** communicate naturally in face-to-face interactions.

The application is worn by the caregiver (e.g. attached to the chest using a phone lanyard or wearable mount), allowing both parties to communicate hands-free.

The system supports **two-way communication**:

1. **Caregiver → Deaf Person**
   - Converts spoken language into live text.
2. **Deaf Person → Caregiver**
   - Recognizes BISINDO sign language using the camera, translates it into natural language, and reads it aloud.

---

# Problem Statement

Communication between caregivers and deaf individuals often requires:
- Writing on paper or typing on a phone.
- Limited knowledge of BISINDO by caregivers.
- Slow back-and-forth communication.
- Misunderstandings caused by incomplete gestures or missing context.

CareBridge aims to reduce these communication barriers by leveraging Apple's on-device AI frameworks.

---

# Target Users

### Primary User
- Caregiver (CG)

### Secondary User
- Deaf or Hard-of-Hearing Individual (TL)

---

# Communication Flow

## Flow 1 — Caregiver → Deaf Person

The caregiver speaks naturally while wearing the phone on their chest.

The application continuously listens using Apple's Speech framework.

### Workflow

```
Start
   │
   ▼
Caregiver Speaks
   │
   ▼
Speech Recognition
(Speech Framework)
   │
   ▼
Transcribed Text
   │
   ▼
Display Large Text
for Deaf User
```

### Apple Technologies

- Speech Framework
- AVFoundation
- SwiftUI

### Output

- Live subtitle
- Large readable text
- Conversation history (optional)

---

# Flow 2 — Deaf Person → Caregiver

The deaf user communicates using BISINDO sign language in front of the caregiver.

The camera captures the hand gestures.

CoreML recognizes each sign, while Foundation Models reconstruct incomplete phrases into natural Indonesian before reading them aloud.

### Workflow

```
Start
   │
   ▼
Camera Detects Hand Sign
   │
   ▼
Vision Framework
   │
   ▼
CoreML
Sign Classification
   │
   ▼
Raw Text
Example:
"Saya ... makan"
   │
   ▼
Foundation Models
Context Completion
Prompt Engineering
   │
   ▼
Natural Sentence
Example:
"Saya ingin makan sekarang."
   │
   ▼
Text-to-Speech
(AVSpeechSynthesizer)
   │
   ▼
Read Aloud
```

---

# Why Foundation Models?

Hand sign recognition is rarely perfect.

Instead of reading every recognized sign literally, Foundation Models can infer missing context to produce more natural sentences.

Example:

Detected:

```
Saya
Makan
```

Foundation Model Output:

```
Saya ingin makan.
```

---

Detected:

```
Tolong
Air
```

Foundation Model Output:

```
Tolong ambilkan saya air minum.
```

---

# AI Pipeline

```
Camera
   │
   ▼
Vision Framework
   │
   ▼
CoreML
(Sign Classification)
   │
   ▼
Raw Tokens
   │
   ▼
Foundation Models
(Context Understanding)
   │
   ▼
Natural Language
   │
   ▼
Text To Speech
```

---

# Apple Frameworks

## Speech Framework

- Speech-to-text
- Continuous recognition
- Live transcription

Used for:

```
Caregiver Speech
↓
Subtitle
```

---

## Vision Framework

- Camera pipeline
- Hand tracking
- Person detection

Used before CoreML.

---

## CoreML

Responsible for:

- BISINDO sign classification
- Gesture prediction
- Frame-by-frame inference

Example:

```
Camera Frame

↓

CoreML

↓

"Makan"
```

---

## Foundation Models

Responsible for:

- Understanding sentence context
- Recovering omitted words
- Correcting recognition errors
- Generating natural Indonesian

Example Prompt:

> Convert the following BISINDO tokens into a complete and natural Indonesian sentence. If words are missing due to recognition limitations, infer them using conversational context without changing the intended meaning.

Input:

```
Saya
Rumah
Pulang
```

Output:

```
Saya ingin pulang ke rumah.
```

---

## AVFoundation

Responsible for:

- Text-to-Speech
- Speaking translated sentences aloud

Example:

```
"Saya ingin pulang."

↓

🔊
Audio Output
```

---

# End-to-End Architecture

```
                Caregiver
                    │
              Speaks Naturally
                    │
                    ▼
            Speech Framework
                    │
                    ▼
              Live Transcription
                    │
                    ▼
          Large Text Display
                    │
────────────────────────────────────────────
                    │
               Deaf Person
                    │
            Signs in BISINDO
                    │
                    ▼
             Camera Capture
                    │
                    ▼
          Vision Hand Tracking
                    │
                    ▼
        CoreML Sign Recognition
                    │
                    ▼
           Foundation Models
      Context + Sentence Recovery
                    │
                    ▼
          AVSpeechSynthesizer
                    │
                    ▼
        Spoken Translation
```

---

# Key Features

## Live Speech-to-Text

- Real-time transcription
- Large, readable subtitles
- Hands-free operation

---

## BISINDO Recognition

- Camera-based sign recognition
- On-device inference
- Real-time prediction

---

## AI Sentence Completion

Foundation Models improve communication by:

- Filling missing words
- Correcting recognition mistakes
- Producing natural Indonesian
- Preserving conversational intent

---

## Text-to-Speech

- Speaks translated sentences aloud
- Helps caregivers understand responses immediately

---

# Advantages

- Fully on-device processing for privacy
- Hands-free communication
- Natural conversations
- Accessible for users without BISINDO knowledge
- Reduces communication barriers in caregiving environments

---

# Future Enhancements

- Continuous conversation mode
- Personalized sign language adaptation
- Emotion detection from facial expressions
- Conversation history
- Multi-language translation
- Apple Watch haptic notifications for conversation turns
- Offline BISINDO vocabulary expansion
