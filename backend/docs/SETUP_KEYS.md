# WAR ROOM: Complete Setup & API Key Guide

Welcome to the WAR ROOM! This guide is designed for developers cloning the project from `github/OkeyAmy` who need to set up the environment from scratch.

Because WAR ROOM relies heavily on external AI and real-time streaming services, you need to provision several API keys before the backend will run. This document will walk you through exactly where to go and what to click to get every single key required in the `.env` file.

---

## Step 1: Clone the Repository

First, download the code from GitHub to your local machine:

```bash
git clone https://github.com/OkeyAmy/war-room.git
cd war-room/backend
```

Create your active environment file by copying the example:

```bash
cp .env.example .env
```

You will now fill out `backend/.env` using the keys gathered in the following steps.

---

## Step 2: Google Cloud & Firebase (Database)

WAR ROOM uses **Firestore** as its crisis ledger to sync state in real-time.

1. Go to the [Firebase Console](https://console.firebase.google.com/).
2. Click **Create a project** (e.g., name it `war-room-dev`).
3. Once the project is created, click the **Build** dropdown on the left menu, and select **Firestore Database**. Click **Create database** (Start in test mode for local development).
4. Now, go to **Project settings** (the gear icon near "Project Overview" on the top left).
5. Navigate to the **Service accounts** tab.
6. Click **Generate new private key** and save the `.json` file to your computer.
7. **Move this `.json` file** into your `backend/` directory (e.g., `backend/war-room-firebase-adminsdk.json`).

**Update your `.env`:**

```env
GCP_PROJECT_ID=your-firebase-project-id
GOOGLE_APPLICATION_CREDENTIALS=war-room-firebase-adminsdk.json
ENVIRONMENT=production # Use 'production' to use live Firebase instead of local emulator
```

---

## Step 3: Google Gemini (The Brains)

The AI cognitive engine relies on **Google Gemini** for reasoning, parsing the crisis board, and generating text.

1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey).
2. Sign in with your Google account.
3. Click the **Get API key** button.
4. Click **Create API key** (you can attach it to the Firebase Google Cloud project you created in Step 2, or create a new one).
5. Copy the generated key.

**Update your `.env`:**

```env
GOOGLE_API_KEY=AIzaSyYourGeneratedGeminiKeyHere
```

---

## Step 4: ElevenLabs (The Voices)

WAR ROOM uses **ElevenLabs** for ultra-realistic Text-to-Speech (TTS) and low-latency Speech-to-Text (STT) transcription.

1. Go to the [ElevenLabs Developer Portal](https://elevenlabs.io/) and create an account.
2. Click on your profile icon in the bottom left corner and select **Profile + API key**.
3. Under the **API Key** section, click the eye icon to reveal your key, and copy it.

**Update your `.env`:**

```env
ELEVENLABS_API_KEY=your-elevenlabs-api-key
ELEVENLABS_STT_MODEL=scribe_v2_realtime
ELEVENLABS_TTS_MODEL=eleven_turbo_v2_5
VOICE_BACKEND=livekit_elevenlabs
```

---

## Step 5: LiveKit (The Broadcast Stage)

WAR ROOM uses **LiveKit** as the WebRTC infrastructure to pipe audio between the browser and the Python agents with zero latency.

1. Go to [LiveKit Cloud](https://cloud.livekit.io/) and sign up.
2. Create a new **Project**.
3. Once your project is created, navigate to the **Settings** section in the left sidebar.
4. Look under the **Keys** tab. You will see a `wss://...` URL, an API Key, and an API Secret.
5. Click the eye icon to reveal the secret and copy all three values.

**Update your `.env`:**

```env
LIVEKIT_URL=wss://your-project.livekit.cloud
LIVEKIT_API_KEY=your-livekit-api-key
LIVEKIT_API_SECRET=your-livekit-api-secret
```

---

## Step 6: Final Verification

Your `backend/.env` file should now resemble this:

```env
# GCP Configuration
GCP_PROJECT_ID=war-room-dev
GOOGLE_APPLICATION_CREDENTIALS=war-room-firebase-adminsdk.json

# Gemini API
GOOGLE_API_KEY=AIzaSy...

# LiveKit
LIVEKIT_URL=wss://war-room-xyz.livekit.cloud
LIVEKIT_API_KEY=APIXXXXXXXX
LIVEKIT_API_SECRET=SecXXXXXXXX

# ElevenLabs
ELEVENLABS_API_KEY=sk_XXXXXXXX
ELEVENLABS_STT_MODEL=scribe_v2_realtime
ELEVENLABS_TTS_MODEL=eleven_turbo_v2_5

# FastAPI
HOST=0.0.0.0
PORT=8000
DEBUG=true
ENVIRONMENT=production
VOICE_BACKEND=livekit_elevenlabs
SINGLE_AGENT_VOICE_MODE=false
MAX_AGENTS_PER_SESSION=4
```

You are now ready to install the dependencies and boot the servers. See the root `README.md` for `npm install` and `pip install -r requirements.txt` instructions!
