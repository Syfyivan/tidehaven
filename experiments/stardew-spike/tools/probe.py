"""Controlled integration probe. Never claimed as physical keyboard/human testing."""
import argparse
import json
import math
from pathlib import Path
import time

ROOT = Path(__file__).resolve().parents[3] / "artifacts/stardew-spike/sessions"
parser = argparse.ArgumentParser()
parser.add_argument("session")
parser.add_argument("kind")
parser.add_argument("x", type=float, nargs="?", default=0)
parser.add_argument("y", type=float, nargs="?", default=0)
parser.add_argument("--sail-x", type=float, default=0)
parser.add_argument("--sail-y", type=float, default=0)
args = parser.parse_args()
session = (ROOT / args.session).resolve()
if session.parent != ROOT.resolve():
    raise ValueError("Only a direct isolated session is allowed")

def read():
    for _ in range(10):
        try:
            return json.loads((session / "state.json").read_text(encoding="utf-8-sig"))
        except (OSError, ValueError):
            time.sleep(.1)
    raise RuntimeError("No readable probe state")

def send(kind, x=0, y=0, sx=0, sy=0):
    command = dict(Id=time.time_ns()//1_000_000, Kind=kind, X=x, Y=y, SailX=sx, SailY=sy)
    temp = session / "command.tmp"
    temp.write_text(json.dumps(command), encoding="utf-8")
    temp.replace(session / "command.json")
    limit = time.monotonic() + 12
    while time.monotonic() < limit:
        state = read()
        if state["LastCommandId"] == command["Id"]:
            time.sleep(.3)
            state = read()
            with (session / "probe-evidence.jsonl").open("a", encoding="utf-8") as out:
                out.write(json.dumps(dict(Command=command, State=state)) + "\n")
            if state.get("Error"):
                raise RuntimeError(state["Error"])
            return state
        time.sleep(.15)
    raise TimeoutError(f"Command was not acknowledged: {kind}")

if args.kind == "status":
    result = read()
elif args.kind == "navigateDive":
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        state = read()
        player = next(p for p in state["Spike"]["World"]["Players"] if p["PlayerId"] == state["Player"]["Id"])
        if not player["IsDiving"]:
            raise RuntimeError("Player is not diving")
        dx, dy = args.x-player["X"], args.y-player["Y"]
        distance = math.hypot(dx,dy)
        if distance < 30:
            result = send("stop")
            break
        threat = state["Spike"]["World"]["Threat"]
        tx,ty = threat["X"]-player["X"],threat["Y"]-player["Y"]
        if math.hypot(tx,ty)<145:
            send("harpoon",tx,ty)
        send("input", dx/distance,dy/distance)
    else:
        send("stop")
        raise TimeoutError("Dive target not reached")
else:
    result = send(args.kind,args.x,args.y,args.sail_x,args.sail_y)

compact = {k:v for k,v in result.items() if k != "Spike"}
if result.get("Spike"):
    compact["Spike"] = dict(result["Spike"])
    compact["Spike"]["World"] = {k:v for k,v in result["Spike"]["World"].items() if k != "Deck"}
    compact["Spike"]["World"]["DeckCells"] = len(result["Spike"]["World"]["Deck"])
print(json.dumps(compact,ensure_ascii=False))
