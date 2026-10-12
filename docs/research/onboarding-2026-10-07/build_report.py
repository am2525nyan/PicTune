"""Rebuild the offline research report from observations.json and saved screenshots."""

import base64
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def build():
    data = json.loads((ROOT / "observations.json").read_text())
    assert len(data["apps"]) == 30, "The main collection must contain 30 distinct apps"
    assert len({item["id"] for item in data["apps"]}) == 30
    for app in data["apps"]:
        assert app["observed_steps"] and app["limitations"]
        assert app["evidence_url"].startswith("https://")
        assert app["official_url"].startswith("https://")
        assert app["images"], app["name"]
        for image in app["images"]:
            path = ROOT / image["path"]
            assert path.exists(), path
            image["src"] = "data:image/jpeg;base64," + base64.b64encode(path.read_bytes()).decode()
    encoded = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")
    template = (ROOT / "report.template.html").read_text()
    assert template.count("__RESEARCH_DATA__") == 1
    result = template.replace("__RESEARCH_DATA__", encoded)
    (ROOT / "index.html").write_text(result)
    print(f"Built {len(data['apps'])} app records: {len(result.encode()):,} bytes")


if __name__ == "__main__":
    build()
