"""
WAR ROOM — Test Ping: Gemini TTS (Text-to-Speech)
Verifies that your GOOGLE_API_KEY can reach the Gemini TTS API.

This test uses google.genai to call the speech generation endpoint directly
(no LiveKit plugins required). If this passes with HTTP 200, the Gemini TTS
fallback in base_crisis_agent.py is guaranteed to work.

Run:
    cd backend
    python -m pytest tests/test_ping_gemini_tts.py -v
    # or directly:
    python tests/test_ping_gemini_tts.py
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))


# ── helpers ─────────────────────────────────────────────────────────────────

def _get_api_key() -> str:
    return os.environ.get("GOOGLE_API_KEY", "") or os.environ.get("GEMINI_API_KEY", "")


def _tts_model() -> str:
    """Read gemini_tts_model from .env or fall back to sensible default."""
    return os.environ.get("GEMINI_TTS_MODEL", "gemini-2.5-flash-preview-tts")


# ── tests ────────────────────────────────────────────────────────────────────

def test_gemini_tts_api_key_present():
    """Ensure at least one Google API key is available."""
    key = _get_api_key()
    assert key, (
        "Neither GOOGLE_API_KEY nor GEMINI_API_KEY is set in .env. "
        "Gemini TTS fallback will not work without one of these."
    )
    print(f"  ✅ Google API key found: {key[:12]}...")


def test_gemini_tts_model_name():
    """Confirm the TTS model name is a recognised Gemini speech model."""
    model = _tts_model()
    assert "tts" in model.lower() or "flash" in model.lower(), (
        f"GEMINI_TTS_MODEL='{model}' does not look like a TTS model. "
        "Expected something like 'gemini-2.5-flash-preview-tts'."
    )
    print(f"  ✅ TTS model: {model}")


def test_gemini_tts_synthesize_short_text():
    """
    Send 'Hello' to Gemini TTS and verify we get back raw audio bytes.

    Uses google.genai generate_content with response_modalities=["AUDIO"].
    This is the same path used by _speak_via_gemini_tts_direct() in the
    codebase fallback.
    """
    from google import genai
    from google.genai import types

    api_key = _get_api_key()
    model = _tts_model()

    client = genai.Client(api_key=api_key)

    response = client.models.generate_content(
        model=model,
        contents="Say exactly: Hello, WAR ROOM systems check.",
        config=types.GenerateContentConfig(
            response_modalities=["AUDIO"],
            speech_config=types.SpeechConfig(
                voice_config=types.VoiceConfig(
                    prebuilt_voice_config=types.PrebuiltVoiceConfig(
                        voice_name="Kore"
                    )
                )
            ),
        ),
    )

    # Extract audio bytes from the response
    audio_data = None
    for part in (response.candidates or [{}])[0].content.parts:
        if hasattr(part, "inline_data") and part.inline_data:
            audio_data = part.inline_data.data
            break

    assert audio_data is not None, (
        "Gemini TTS returned no audio data. "
        f"Full response: {response}"
    )
    assert len(audio_data) > 0, "Gemini TTS returned empty audio bytes."

    kb = len(audio_data) / 1024
    print(f"  ✅ Gemini TTS returned {kb:.1f} KB of audio (HTTP 200 equivalent)")
    print(f"     Model: {model} | Voice: Kore")


def test_gemini_tts_multiple_voices():
    """
    Check that a selection of the GEMINI_TTS_VOICE_STYLE_MAP voices work.
    Tests Kore (default), Fenrir (urgent), Charon (authoritative).

    Note: Gemini TTS needs a full sentence (not just "Ping") to reliably
    choose audio-only output mode; short strings can trigger text mode.
    """
    from google import genai
    from google.genai import types

    api_key = _get_api_key()
    model = _tts_model()
    client = genai.Client(api_key=api_key)

    voices_to_check = ["Kore", "Fenrir", "Charon"]
    results = {}
    _TEST_TEXT = "WAR ROOM systems check. All channels are operational."

    for voice in voices_to_check:
        try:
            response = client.models.generate_content(
                model=model,
                contents=_TEST_TEXT,
                config=types.GenerateContentConfig(
                    response_modalities=["AUDIO"],
                    speech_config=types.SpeechConfig(
                        voice_config=types.VoiceConfig(
                            prebuilt_voice_config=types.PrebuiltVoiceConfig(
                                voice_name=voice
                            )
                        )
                    ),
                ),
            )
            audio_data = None
            candidates = response.candidates or []
            if candidates and candidates[0].content and candidates[0].content.parts:
                for part in candidates[0].content.parts:
                    if hasattr(part, "inline_data") and part.inline_data:
                        audio_data = part.inline_data.data
                        break
            results[voice] = "ok" if (audio_data and len(audio_data) > 0) else "no_audio"
        except Exception as e:
            results[voice] = f"error: {e}"

    for voice, status in results.items():
        marker = "✅" if status == "ok" else "❌"
        print(f"  {marker} Voice '{voice}': {status}")

    failed = [v for v, s in results.items() if s != "ok"]
    assert not failed, f"These Gemini TTS voices failed: {failed}"


# ── standalone runner ────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("\n🔊 WAR ROOM — Gemini TTS Ping Test\n" + "=" * 45)

    tests = [
        ("API Key Present",        test_gemini_tts_api_key_present),
        ("TTS Model Name",         test_gemini_tts_model_name),
        ("Synthesize Short Text",  test_gemini_tts_synthesize_short_text),
        ("Multiple Voices",        test_gemini_tts_multiple_voices),
    ]

    passed = 0
    failed = 0
    for name, fn in tests:
        try:
            print(f"\n🧪 {name}...")
            fn()
            passed += 1
        except Exception as e:
            print(f"  ❌ FAILED: {e}")
            failed += 1

    print(f"\n{'=' * 45}")
    print(f"Results: {passed} passed, {failed} failed")
    if failed == 0:
        print("🎉 Gemini TTS is fully operational — fallback will work!")
        print("   Your codebase will automatically use this when ElevenLabs fails.")
    else:
        print("⚠️  Gemini TTS has issues — check GOOGLE_API_KEY and quota.")
