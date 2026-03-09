# WAR ROOM — AI Crisis Simulation Platform

**WAR ROOM** is an immersive, multi-agent AI crisis simulation platform. Users take on the role of the "Chairman" or "Director," navigating high-stakes, dynamically generated scenarios by orchestrating a team of specialized AI advisors.

This document outlines the holistic system architecture and the complex interactions between the Next.js frontend client and the robust AI-driven Python backend.

---

## 🏗️ High-Level Architecture Overview

The system is designed as a decoupled, real-time client-server application optimized for high-bandwidth, continuous state synchronization and raw audio streaming.

* **Frontend Client:** A highly responsive React/Next.js (App Router) Single Page Application styled with modern visuals and functional dashboards. Located in `./src`.
* **Backend Server:** A scalable, asynchronous Python FastAPI server orchestrating the AI lifecycle, maintaining state, and routing communications. Located in `./backend`.

### Core Interaction Paradigm

```mermaid
graph TD
    UI[Next.js Frontend] <-->|REST & WebSockets| GW[FastAPI Gateway]
    GW <-->|Audio/Commands| CH[Chairman Handler]
    CH <-->|WebRTC/Sockets| VP[LiveKit Voice Pipeline]
    VP <-->|Gemini Live API| AI[Agent Array]
    
    subgraph "AI Agent Array (Cloud Run)"
        SA[Scenario Analyst]
        A1[Legal Agent]
        A2[CMO Agent]
        A3[Engineer Agent]
        WA[World Agent]
        OA[Observer Agent]
        
        SA -.->|Initializes| A1
        SA -.->|Initializes| A2
        SA -.->|Initializes| A3
    end
    
    A1 -->|Tools| CB[Shared Crisis Board]
    A2 -->|Tools| CB
    A3 -->|Tools| CB
    WA -->|Timer: Escalation Events| CB
    OA -->|Reads Transcripts & Scores Trust| FS[(Firestore DB)]
    
    CB -->|Events| FS
    FS -->|Snapshot Listener| GW
```

WAR ROOM relies heavily on **Event-Driven Architecture (EDA)** paired with **WebRTC and WebSockets** to maintain an immersive illusion of simultaneous agent presence. The backend acts as a single source of truth, generating state changes using autonomous background AI reasoning loops, which are then eagerly synced to the UI.

---

## 📡 Frontend-Backend Interaction & Data Flow

Communication between the frontend visualization layer and the backend entity-management layer is categorized into three distinct pipelines:

### 1. RESTful Pre-Fetching and State Hydration

```mermaid
sequenceDiagram
    participant F as Next.js Frontend
    participant GW as FastAPI Gateway
    participant DB as Firestore
    participant A as AI Agent Array
    
    Note over F,A: 1. REST Pre-Fetching
    F->>GW: GET /api/sessions/{id}
    GW->>DB: Query Session State
    DB-->>GW: Return State
    GW-->>F: JSON Initial State
    
    Note over F,A: 2. WebSocket Event Bus
    A->>DB: Agent Action / Decision (Tool Call)
    DB->>GW: Snapshot Listener Triggered
    GW-->>F: Push Event (via ws://)
    F-->>F: Update React Context/UI
    
    Note over F,A: 3. Audio & Voice Pipeline
    F->>GW: Chairman Mic Audio
    GW->>A: Stream to Gemini Live
    A-->>GW: Agent Output (Text + Audio)
    GW-->>F: Voice Audio + Active Speaker Sync
```

**Mechanism:** Standard HTTP/JSON APIs (e.g., `GET /api/sessions/{session_id}`).

**Purpose:**
When the frontend first loads a view or when a user forcefully refreshes the page, the Next.js application queries the backend's REST Gateway to construct the initial UI.

* **Dashboard Population:** Fetching the scenario brief, agent rosters, crisis Intel, timeline escalations, and the current threat posture.
* **Session Management:** Sending initialization parameters to `POST /api/sessions` to instruct the Python bootstrapper to begin generating a scenario asynchronously.

### 2. The WebSocket Event Bus (The Nervous System)

**Mechanism:** Full-duplex WebSocket connections handled by `backend/gateway/connection_manager.py`.
**Purpose:**
Because crisis agents (e.g., Legal, PR, Military) and the "World Agent" act autonomously, the frontend cannot solely rely on polling.

* **Server-to-Client Push Events:** When an AI agent decides on a new policy, when the World Agent injects breaking news, or when the overall "Threat Level" changes, the backend broadcasts these events down the WebSocket.
* **UI Reactivity:** The frontend listens to these generic event payloads and dynamically updates React context, immediately rendering new crisis alerts, rendering agent thought-processes, and updating relationship/trust scores without a page reload.

### 3. The Audio & Voice Pipeline

**Mechanism:** WebSockets and LiveKit (WebRTC).
**Purpose:**
The most complex interaction layer, designed to handle "Gemini Live" bidirectional voice streams between the user and the AI array.

* **Client-to-Server:** The Next.js frontend captures the Chairman's microphone hardware, encodes the audio, and streams it via WebSocket directly to the `chairman_audio_ws.py` router on the backend.
* **Backend Transcription & Routing:** The backend receives the chunked audio, pipes it to the Gemini Live API for STT (Speech-to-Text) and intent reasoning, determines *which* AI agent should react, and triggers their specific logic loop.
* **Server-to-Client Audio:** Once an agent determines their response, the text is synthesized into ultra-realistic speech using ElevenLabs. This generated audio is then piped back to the frontend (either via LiveKit rooms or direct binary WebSocket chunks).
* **Active Speaker Gating:** To prevent chaotic "voice leakage" where multiple AIs talk simultaneously, the architecture enforces strict turn-based speaking locks. The backend emits active-speaker tokens, ensuring the frontend's audio player drops chunk overlaps and mutes inactive components.

---

## 🤖 Meet the Agents (The AI Ecosystem)

WAR ROOM is powered by a diverse array of specialized Artificial Intelligence agents, each fulfilling a unique role to create a cohesive, immersive simulation. Here is a breakdown of the agents you will interact with and the invisible hands guiding the experience.

### For the Director (Non-Technical Overview)

Imagine you are running a real crisis simulation exercise. You are the Director, but you need a team to help you bring the scenario to life.

* **The World Builder (Scenario Analyst):** Before the simulation begins, this agent preps the board. You tell them "We have an oil spill," and they generate the company details, the exact location, the initial news reports, and decide which expert advisors you'll need in the room.
* **Your Advisors (Crisis Agents):** These are the experts you actually talk to during the simulation. They have distinct personalities, roles (e.g., Chief Legal Officer, Military General), and voices. They listen to what you say, debate with each other, and propose solutions based on their specific domain knowledge.
* **The World Outside (World Agent):** The crisis doesn't wait for you. This agent acts as the unpredictable external world. It watches the clock and injects breaking news, lawsuits, or social media outrages exactly when you least expect them to keep the pressure high.
* **The Silent Judge (Observer Agent):** Sitting quietly in the corner of the room, this agent watches everything. It takes notes on who is arguing with whom, tracks if your team is contradicting itself, and calculates a running "Trust Score." If you say one thing but do another, this agent will notice and deduct points from your final resolution score.

### Under the Hood (Technical Implementation)

The system utilizes an Event-Driven Architecture (EDA) to coordinate multiple independent LLM processes, simulating a unified environment.

* **`ScenarioAnalyst`**: A single-shot generative pipeline invoked during session initialization. It calls the Gemini API to construct the crisis context, generate specific `SKILL.md` configurations for dynamic agents, and seed the Firestore database.
* **`CrisisAgent`**: The core conversational LLMs. Each dynamically summoned agent (e.g., Legal, PR) runs autonomously as its own class instance, utilizing **Gemini Live** for bidirectional audio/text reasoning and **ElevenLabs** for synthesized WebRTC voice transmission. They maintain their own isolated memory state and use function calling (tools) to write to the shared crisis board.
* **`WorldAgent`**: A timer-based execution engine. It does not participate in voice chat. Instead, it reads a predefined escalation schedule and asynchronously pushes structured `CRISIS_ESCALATION` events to the WebSocket gateway, forcing the connected clients (and the other Agents) to react.
* **`ObserverAgent`**: A continuous, silent analytical loop. It intercepts all agent transcripts and evaluates them against the shared session state using a specialized LLM instruction. It outputs structured JSON containing relationship deltas (alliances/conflicts), detects contradictions, and dynamically adjusts agent Trust Scores and overall Posture metrics in the shared database.

---

## 🧩 Architectural Breakdown

### The Frontend (Next.js)

* **`/src/app`:** Next.js Server Components acting as routing shells and fetching initial session context.
* **`/src/components`:** Heavy client-side interactive widgets (Dashboards, Map visualizations, Agent interaction panels). These components utilize custom hooks to maintain WebSocket connections and handle audio buffering.
* **Audio Player/Manager:** A specialized local AudioContext manager responsible for decoding base64 audio frames and sequentially playing AI responses while animating UI indicators.

### The Backend (FastAPI + AI Agents)

* **`/backend/main.py` & `/gateway`:** REST/WS controllers routing traffic into the simulation.
* **`/backend/agents`:** Isolated Python classes inheriting from a `BaseCrisisAgent`. Each agent maintains its own localized prompt memory and connects to Google's GenAI SDK independently to reason about incoming inputs.
* **State Store (Firestore/Mock Database):** The centralized ledger mapping the state of the session, agent decisions, and historical actions, allowing for immediate session recovery and performance observability.

```mermaid
graph LR
    subgraph "Isolated Agent Environment"
        A[Legal Agent]
        L[LlmAgent Wrapper]
        M1[(Private Memory DB)]
        A --- L
        L --> M1
    end
    
    subgraph "Shared Crisis Context"
        SB[(Shared Session DB)]
    end
    
    subgraph "Isolated Agent Environment"
        B[PR Agent]
        L2[LlmAgent Wrapper]
        M2[(Private Memory DB)]
        B --- L2
        L2 --> M2
    end
    
    L -- "Read/Write via Tools" --> SB
    L2 -- "Read/Write via Tools" --> SB
    
    M1 -.->|No Access| M2
```

---

## 🚀 Getting Started

To run the full stack locally for development:

### Prerequisites

* Node.js (v18+)
* Python 3.10+
* Requested API Keys (Google GenAI, ElevenLabs, LiveKit) specified in `./backend/.env`

### Run the Backend

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python main.py
```

*The backend will boot on `http://localhost:8000`.*

### Run the Frontend

```bash
# In an adjacent terminal window
cd [project-root]
npm install
npm run dev
```

*The frontend will be accessible at `http://localhost:3000`.*

### Deploy Backend to Google Cloud

To deploy the backend to Cloud Run with automated builds:

1. Run one-time setup: `./scripts/deploy/setup-gcp.sh`
2. Deploy: `./scripts/deploy/deploy.sh` (or use `--key backend/gcp-service-account.json` for CI)
3. Optional: Connect GitHub for auto-deploy on push to `main` — see [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)
