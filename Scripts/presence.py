from pypresence import Presence
import time
import os

from image import upload

imgbb_api_key = "<YOUR IMGBB API KEY HERE>"
CLIENT_ID = "YOUR DISCORD CLIENT ID HERE"  # Discord app client ID

RPC = Presence(CLIENT_ID)

try:
    RPC.connect()
    print("[DEBUG] Connected to Discord RPC.")
except Exception as e:
    print("[ERROR] Failed to connect to Discord RPC:", e)

last_presence = ""
sep = chr(31)
presence_file = "../../../Save/discord_presence.txt"

while True:
    try:
        if not os.path.exists(presence_file):
            print(f"[DEBUG] Presence file not found: {presence_file}")
            time.sleep(1)
            continue

        with open(presence_file, "r", encoding="utf-8") as f:
            presence = f.read().strip()
        # print(f"[DEBUG] Read presence: {presence}")

        if presence != last_presence:
            parts = presence.split(sep)
            print(f"[DEBUG] Split parts: {parts}")

            # pad missing fields with empty strings
            while len(parts) < 9:
                parts.append("")

            state, details, diff, meter, artist, pack, step_artist, banner, cdtitle = parts
            print(f"[DEBUG] Parsed fields -> state: {state}, details: {details}, diff: {diff}, meter: {meter}, artist: {artist}, pack: {pack}, step_artist: {step_artist}, banner: {banner}, cdtitle: {cdtitle}")

            if state == "Idle":
                print("[DEBUG] Updating RPC for Idle state")
                RPC.update(
                    state=state,
                    details=details,
                    large_image="<ARROW.PNG HERE>"
                )
            else:
                # fix relative paths
                banner_path = banner
                cdtitle_path = cdtitle

                if banner_path:
                    if banner_path.startswith("/"):
                        banner_path = "../../.." + banner_path
                    else:
                        banner_path = "../../../" + banner_path

                if cdtitle_path:
                    if cdtitle_path.startswith("/"):
                        cdtitle_path = "../../.." + cdtitle_path
                    else:
                        cdtitle_path = "../../../" + cdtitle_path

                print(f"[DEBUG] Banner path: {banner_path}")
                print(f"[DEBUG] CDTitle path: {cdtitle_path}")

                try:
                    banner_url = upload(banner_path, imgbb_api_key) if banner_path else None
                    print(f"[DEBUG] Banner URL: {banner_url}")
                except Exception as e:
                    print("[ERROR] Banner upload failed:", e)
                    banner_url = None

                try:
                    cdtitle_url = upload(cdtitle_path, imgbb_api_key) if cdtitle_path else None
                    print(f"[DEBUG] CDTitle URL: {cdtitle_url}")
                except Exception as e:
                    print("[ERROR] CDTitle upload failed:", e)
                    cdtitle_url = None

                print("[DEBUG] Updating RPC for playing state")
                # Updating RPC for playing state
                rpc_kwargs = {
                    "name": details,
                    "state": f"[{meter}] {step_artist}" if diff or meter else "",
                    "details": artist or "",
                    "large_image": banner_url or "<ARROW.PNG HERE>",
                    # "large_url": f"https://itgdb.s1sh.xyz/pack_search/?search_by=name&q={pack}",
                    "large_text": pack
                }

                # Only add small_image if cdtitle_url exists
                if cdtitle_url:
                    rpc_kwargs["small_image"] = cdtitle_url

                RPC.update(**rpc_kwargs)

            last_presence = presence
        # else:
        # print("[DEBUG] Presence unchanged, skipping update.")

    except Exception as e:
        print("[ERROR] Exception in main loop:", e)

    time.sleep(1)
