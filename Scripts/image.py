import os
import tempfile
from PIL import Image
import requests

def upload(banner_path: str, api_key: str) -> str:
    """
    Resize a banner image to 1024x1024 with transparent padding,
    upload it to imgbb, and return the URL.

    :param banner_path: Path to the local image
    :param api_key: Your imgbb API key
    :return: URL of uploaded image
    """
    # Load image
    img = Image.open(banner_path).convert("RGBA")

    # Resize with aspect ratio preserved
    width, height = img.size
    target_size = (1024, 1024)
    ratio = min(target_size[0] / width, target_size[1] / height)
    new_size = (int(width * ratio), int(height * ratio))
    img_resized = img.resize(new_size, Image.LANCZOS)

    # Transparent background
    background = Image.new("RGBA", target_size, (0, 0, 0, 0))
    x = (target_size[0] - new_size[0]) // 2
    y = (target_size[1] - new_size[1]) // 2
    background.paste(img_resized, (x, y), img_resized)

    # Save to temp file
    with tempfile.NamedTemporaryFile(delete=False, suffix=".png") as tmp:
        tmp_path = tmp.name
        background.save(tmp_path)

    # Upload to imgbb
    with open(tmp_path, "rb") as f:
        resp = requests.post(
            "https://api.imgbb.com/1/upload",
            data={"key": api_key, "expiration": 86400}, # 1d
            files={"image": f}
        )
    resp.raise_for_status()

    # Optional: clean up temp file
    os.remove(tmp_path)

    return resp.json()["data"]["url"]
