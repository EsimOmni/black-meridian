"""Google Flow runner — LOGIN launcher.

Opens a PERSISTENT Chromium context with its OWN user_data_dir
(`flow-profile/`), navigates to Google Flow, and waits while you log in by
hand with your Google account. The profile then remembers the session so
later runner calls reuse it — no re-login.

Why a runner at all: Gemini Omni / Veo have NO official generation MCP (only
enterprise/Cloud MCP exists). Programmatic access is Vertex AI API; but to use
the Flow subscription's UI tier (Omni Flash, conversational revision) the
clean path is driving the Flow web UI. This is the vendor-independence layer
for Google's multimodal video.

Own user_data_dir, isolated from every other profile. Do NOT start while
another Chromium holds the same profile.

⚠️ GOOGLE LOGIN ANTI-BOT NOTE: Google sometimes blocks automation-controlled
browsers ("this browser may not be secure"). We pass
--disable-blink-features=AutomationControlled to reduce this. If Google still
refuses the Playwright Chromium, the fallback is: log in to Google in a normal
Chrome with this same user-data-dir once, OR complete login on a phone/another
device and let the session sync. The persistent profile keeps whatever session
lands in it.

Usage (from this dir, with a venv that has Playwright):
    ../.venv/Scripts/python.exe -u login.py
"""
from __future__ import annotations

import sys
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

# Flow lives under labs.google / its own app surface. Try the app entry; if it
# bounces to a Google sign-in, that's expected — log in there.
FLOW_URL = "https://labs.google/fx/tools/flow"
PROFILE_DIR = Path(__file__).resolve().parent / "flow-profile"


def main() -> int:
    login_timeout_s = 900  # 15 min to log in by hand (Google login is multi-step)
    PROFILE_DIR.mkdir(parents=True, exist_ok=True)
    print("[*] Google Flow login launcher")
    print(f"[*] Profile: {PROFILE_DIR}")
    print(f"[*] Opening {FLOW_URL} — log in with your Google account by hand.")
    print("    If it lands on a Google sign-in page, complete it there.")

    pw = sync_playwright().start()
    context = pw.chromium.launch_persistent_context(
        user_data_dir=str(PROFILE_DIR),
        headless=False,
        viewport={"width": 1440, "height": 900},
        accept_downloads=True,
        args=[
            "--disable-blink-features=AutomationControlled",
            "--disable-features=IsolateOrigins,site-per-process",
        ],
    )
    try:
        page = context.pages[0] if context.pages else context.new_page()
        page.goto(FLOW_URL, wait_until="domcontentloaded", timeout=60_000)
        page.wait_for_timeout(3500)

        print(f"[!] Log in to Google / Flow by hand now. Window stays open up to "
              f"{login_timeout_s}s.")
        print("    When done: close the window, OR leave it — the session is saved either way.")
        deadline = time.time() + login_timeout_s
        while time.time() < deadline:
            if not context.pages:  # you closed the window
                print("[ok] Window closed by user. Session persisted to profile.")
                return 0
            try:
                context.pages[0].wait_for_timeout(2000)
            except Exception:
                print("[ok] Window closed. Session persisted to profile.")
                return 0
        print("[ok] Window stayed open the full window; session persisted.")
        return 0
    finally:
        try:
            context.close()
        except Exception:
            pass
        try:
            pw.stop()
        except Exception:
            pass


if __name__ == "__main__":
    sys.exit(main())
