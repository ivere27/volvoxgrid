#!/usr/bin/env python3
import argparse
import json
import re
from pathlib import Path


START_MARKER = "<!-- firebase-analytics:start -->"
END_MARKER = "<!-- firebase-analytics:end -->"
FIREBASE_VERSION = "12.7.0"


def load_config(config_path: Path) -> str:
    config = json.loads(config_path.read_text(encoding="utf-8"))
    if isinstance(config, dict) and isinstance(config.get("firebaseConfig"), dict):
        config = config["firebaseConfig"]
    if not isinstance(config, dict):
        raise SystemExit(f"{config_path} must contain a JSON object")
    return json.dumps(config, separators=(",", ":"), sort_keys=True)


def build_snippet(config_json: str) -> str:
    return f'''  {START_MARKER}
  <script>
    (async () => {{
      const [{{ initializeApp }}, {{ getAnalytics, isSupported }}] = await Promise.all([
        import("https://www.gstatic.com/firebasejs/{FIREBASE_VERSION}/firebase-app.js"),
        import("https://www.gstatic.com/firebasejs/{FIREBASE_VERSION}/firebase-analytics.js")
      ]);

      const firebaseConfig = {config_json};

      const app = initializeApp(firebaseConfig);
      if (await isSupported()) {{
        getAnalytics(app);
      }}
    }})().catch(() => {{}});
  </script>
  {END_MARKER}
'''


def strip_existing_snippet(text: str) -> str:
    text = re.sub(
        rf"\n?[ \t]*{re.escape(START_MARKER)}.*?[ \t]*{re.escape(END_MARKER)}\n?",
        "\n",
        text,
        flags=re.S,
    )
    return re.sub(
        r'\n?[ \t]*<script\b[^>]*>\s*(?:(?!</script>).)*firebase-app\.js(?:(?!</script>).)*firebase-analytics\.js(?:(?!</script>).)*</script>\n?',
        "\n",
        text,
        flags=re.S,
    )


def strip_file(html_path: Path) -> None:
    if not html_path.is_file():
        return

    text = strip_existing_snippet(html_path.read_text(encoding="utf-8"))
    html_path.write_text(text, encoding="utf-8")
    print(f"Removed Firebase Analytics from {html_path}")


def inject(html_path: Path, snippet: str) -> None:
    if not html_path.is_file():
        return

    text = strip_existing_snippet(html_path.read_text(encoding="utf-8"))
    body_match = re.search(r"</body\s*>", text, flags=re.I)
    if not body_match:
        raise SystemExit(f"{html_path} does not contain </body>")

    text = text[:body_match.start()] + snippet + text[body_match.start():]
    html_path.write_text(text, encoding="utf-8")
    print(f"Injected Firebase Analytics into {html_path}")


def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--config",
        default=repo_root / "firebase-analytics.json",
        type=Path,
        help="Path to firebase-analytics.json",
    )
    parser.add_argument(
        "--strip",
        action="store_true",
        help="Remove existing Firebase Analytics snippets instead of injecting",
    )
    parser.add_argument("html_files", nargs="+", type=Path)
    args = parser.parse_args()

    if args.strip:
        for html_file in args.html_files:
            strip_file(html_file)
        return

    if not args.config.is_file():
        print(f"Skipping Firebase Analytics injection: {args.config} not found")
        return

    snippet = build_snippet(load_config(args.config))
    for html_file in args.html_files:
        inject(html_file, snippet)


if __name__ == "__main__":
    main()
