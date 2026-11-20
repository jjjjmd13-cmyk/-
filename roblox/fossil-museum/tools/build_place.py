"""src/ 폴더의 스크립트를 Studio 에서 바로 열 수 있는 .rbxlx 파일로 묶습니다.

사용법:  python3 tools/build_place.py   →  FossilMuseum.rbxlx 생성
(Rojo 가 있다면 `rojo build -o FossilMuseum.rbxlx` 와 같은 결과입니다.)
"""

from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
OUT = ROOT / "FossilMuseum.rbxlx"

_ref = 0


def next_ref() -> str:
    global _ref
    _ref += 1
    return f"RBX{_ref:08X}"


def item(cls: str, name: str, children: list[str], source: str | None = None) -> str:
    props = [f'<string name="Name">{escape(name)}</string>']
    if source is not None:
        if "]]>" in source:
            raise ValueError(f"{name}: 소스에 ']]>' 가 있어요")
        props.append(f'<string name="Source"><![CDATA[{source}]]></string>')
    return (
        f'<Item class="{cls}" referent="{next_ref()}"><Properties>'
        + "".join(props)
        + "</Properties>"
        + "".join(children)
        + "</Item>"
    )


def script_item(path: Path) -> str:
    name = path.name
    source = path.read_text(encoding="utf-8")
    if name.endswith(".server.luau"):
        return item("Script", name[: -len(".server.luau")], [], source)
    if name.endswith(".client.luau"):
        return item("LocalScript", name[: -len(".client.luau")], [], source)
    return item("ModuleScript", name[: -len(".luau")], [], source)


def folder(name: str, path: Path) -> str:
    children = [script_item(p) for p in sorted(path.glob("*.luau"))]
    children += [folder(p.name, p) for p in sorted(path.iterdir()) if p.is_dir()]
    return item("Folder", name, children)


def main() -> None:
    body = [
        item("ReplicatedStorage", "ReplicatedStorage", [folder("Shared", SRC / "shared")]),
        item("ServerScriptService", "ServerScriptService", [folder("Server", SRC / "server")]),
        item(
            "StarterPlayer",
            "StarterPlayer",
            [item("StarterPlayerScripts", "StarterPlayerScripts", [folder("Client", SRC / "client")])],
        ),
    ]
    xml = '<roblox version="4">' + "".join(body) + "</roblox>\n"
    OUT.write_text(xml, encoding="utf-8")
    print(f"만들었어요: {OUT}")


if __name__ == "__main__":
    main()
