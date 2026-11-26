"""Two-process LAN acceptance; scripted calls into native menus, not real-input QA."""
import argparse
import json
import math
from pathlib import Path
import subprocess
import sys
import time

parser = argparse.ArgumentParser()
parser.add_argument("phase", choices=["chain", "transfer", "oxygen", "save", "reload"])
parser.add_argument("--host", default="host-a")
parser.add_argument("--guest", default="guest-a")
args = parser.parse_args()
tool = Path(__file__).with_name("probe.py")
root = tool.resolve().parents[3] / "artifacts/stardew-spike"
report = root / f"live-{args.phase}-{int(time.time())}.json"
events = []
h, g = args.host, args.guest

def state(session):
    for attempt in range(10):
        try: return json.loads((root / "sessions" / session / "state.json").read_text(encoding="utf-8-sig"))
        except (OSError, ValueError):
            if attempt==9: raise
            time.sleep(.05)
def cmd(session,kind,*values):
    proc = subprocess.run([sys.executable,str(tool),session,kind,*map(str,values)],capture_output=True,text=True,timeout=18)
    if proc.returncode: raise RuntimeError(proc.stderr)
    result = json.loads(proc.stdout)
    events.append(dict(Session=session,Action=kind,State=result))
    return result
def wait(label, predicate, seconds=12):
    end=time.monotonic()+seconds
    while time.monotonic()<end:
        if predicate():
            events.append(dict(Check=label,Passed=True)); print("PASS "+label,flush=True);return
        time.sleep(.2)
    raise AssertionError(label)
def world(session): return state(session)["Spike"]["World"]
def local(session):
    s=state(session)
    return next(p for p in s["Spike"]["World"]["Players"] if p["PlayerId"]==s["Player"]["Id"])
def count(session,item): return sum(i["Stack"] for i in state(session)["Inventory"] if i["QualifiedItemId"]==item)
def board():
    for s in (h,g): cmd(s,"warpDeck")
    wait("two native deck players",lambda:all(state(s)["Player"]["Location"]=="Tidehaven_Deck" for s in (h,g)))
    # Same-location warps still run a native fade and clear the movement controller.
    time.sleep(1.5)
def dive(s):
    cmd(s,"dive")
    wait(s+" native dive location",lambda:local(s)["IsDiving"] and state(s)["Player"]["Location"]=="Tidehaven_Dive")
def surface(s):
    cmd(s,"return")
    wait(s+" returned to deck",lambda:not local(s)["IsDiving"] and state(s)["Player"]["Location"]=="Tidehaven_Deck")
def chest_ore(s): return sum(i["Stack"] for c in state(s)["Chests"] for i in c["Items"] if i["QualifiedItemId"]=="(O)378")

try:
    wait("host and farmhand loaded",lambda: all(state(s)["WorldReady"] and state(s)["Stage"]=="ready" for s in (h,g)),30)
    wait("native two-player membership",lambda:all(len(state(s)["Farmers"])==2 for s in (h,g)))
    if args.phase=="chain":
        board()
        wait("previous overnight deck restored",lambda:all(len(world(s)["Deck"])==97 for s in(h,g)))
        assert count(h,"(O)388")==25 and count(g,"(O)388")==30
        if not state(h)["Chests"]: cmd(h,"placeChest",10,11)
        wait("native chest replicated",lambda:all(len(state(s)["Chests"])==1 for s in(h,g)))
        cmd(g,"walkTo",11,12)
        wait("guest walks into expansion range",lambda:abs(state(g)["Player"]["X"]-11*64)<16 and abs(state(g)["Player"]["Y"]-12*64)<16)
        cmd(g,"expand",11,14)
        wait("guest wood charged and deck synchronized",lambda:count(g,"(O)388")==25 and all(len(world(s)["Deck"])==98 for s in(h,g)))
        cmd(g,"expand",11,14)
        assert count(g,"(O)388")==25
        cmd(h,"anchor")
        cmd(h,"input",0,0,"--sail-x",1)
        wait("shared sailing position changed",lambda:world(h)["ShipX"]>0 and world(g)["ShipX"]>0)
        cmd(h,"stop");cmd(h,"anchor")
        wait("anchor synchronized",lambda:all(world(s)["Anchored"] for s in(h,g)))
        cmd(h,"screenshot")
        dive(g)
        assert not local(h)["IsDiving"]
        cmd(h,"anchor")
        wait("crew away prevents unanchoring",lambda:state(h)["Spike"]["LastResult"]["Code"]=="crew_away" and world(h)["Anchored"])
        cmd(g,"navigateDive",600,390)
        cmd(g,"collect")
        wait("guest native inventory receives one ore",lambda:count(g,"(O)378")==1 and all(world(s)["OreDepleted"] for s in(h,g)))
        cmd(g,"collect")
        assert count(g,"(O)378")==1
        cmd(g,"screenshot")
        surface(g)
        cmd(g,"openChest",10,11)
        wait("guest native chest menu",lambda:state(g)["Menu"]=="ItemGrabMenu")
        cmd(g,"depositOre")
        wait("ore transferred through native chest menu",lambda:count(g,"(O)378")==0 and chest_ore(g)==1)
        cmd(g,"screenshot");cmd(g,"closeMenu")
        cmd(h,"openChest",10,11)
        wait("host sees same chest ore",lambda:state(h)["Menu"]=="ItemGrabMenu" and chest_ore(h)==1)
        cmd(h,"closeMenu")
        dive(h)
        assert not local(g)["IsDiving"] and state(g)["Player"]["Location"]=="Tidehaven_Deck"
        cmd(h,"screenshot");cmd(g,"screenshot")
        dive(g)
        wait("both divers independently represented",lambda:all(p["IsDiving"] for p in world(h)["Players"]))
        surface(h)
        assert local(g)["IsDiving"]
        surface(g)
    elif args.phase=="transfer":
        board()
        assert count(g,"(O)388")==25 and count(g,"(O)378")==1 and len(world(h)["Deck"])==98
        cmd(g,"openChest",10,11)
        wait("guest native chest menu",lambda:state(g)["Menu"]=="ItemGrabMenu")
        cmd(g,"depositOre")
        wait("ore transferred through native chest menu",lambda:count(g,"(O)378")==0 and chest_ore(g)==1)
        cmd(g,"screenshot");cmd(g,"closeMenu");cmd(h,"openChest",10,11)
        wait("host sees same chest ore",lambda:state(h)["Menu"]=="ItemGrabMenu" and chest_ore(h)==1)
        cmd(h,"closeMenu");dive(h)
        assert not local(g)["IsDiving"]
        cmd(h,"screenshot");cmd(g,"screenshot");dive(g)
        wait("both divers independently represented",lambda:all(p["IsDiving"] for p in world(h)["Players"]))
        surface(h);assert local(g)["IsDiving"];surface(g)
    elif args.phase=="oxygen":
        board();dive(h)
        waypoints=[(900,90),(900,480),(60,480),(60,90)]
        index=0; deadline=time.monotonic()+55
        while local(h)["IsDiving"] and time.monotonic()<deadline:
            p=local(h);target=waypoints[index]
            dx,dy=target[0]-p["X"],target[1]-p["Y"];length=math.hypot(dx,dy)
            if length<80: index=(index+1)%len(waypoints);continue
            cmd(h,"input",dx/length,dy/length)
        cmd(h,"stop")
        wait("oxygen rescue returns host without affecting guest",lambda:local(h)["LastReturnReason"]=="oxygen" and not local(g)["IsDiving"])
        assert count(h,"(O)378")==0 and chest_ore(g)==1
    elif args.phase=="save":
        board(); day=state(h)["Day"]
        before={s:state(s)["SaveCount"] for s in(h,g)}
        cmd(h,"sleep");cmd(g,"sleep")
        wait("both native save events and next day",lambda:all(state(s)["SaveCount"]>before[s] and state(s)["Day"]>day and state(s)["Menu"] is None for s in(h,g)),25)
        events.append(dict(SavedHost=state(h),SavedGuest=state(g)))
    else:
        board()
        wait("expanded deck restored after host restart",lambda:all(len(world(s)["Deck"])==98 for s in(h,g)))
        wait("native chest ore restored",lambda:all(chest_ore(s)==1 for s in(h,g)))
        assert count(g,"(O)388")==25 and count(g,"(O)378")==0
        assert all(world(s)["OreDepleted"] and not any(p["IsDiving"] for p in world(s)["Players"]) for s in(h,g))
        dive(g);cmd(g,"navigateDive",600,390);cmd(g,"collect")
        wait("saved depletion prevents another reward",lambda:state(g)["Spike"]["LastResult"]["Code"]=="ore_depleted" and count(g,"(O)378")==0)
        surface(g)
        cmd(h,"screenshot");cmd(g,"screenshot")
    report.write_text(json.dumps(dict(Passed=True,Phase=args.phase,Events=events),indent=2),encoding="utf-8")
    print("LIVE_OK "+str(report),flush=True)
except Exception as ex:
    report.write_text(json.dumps(dict(Passed=False,Phase=args.phase,Error=str(ex),Events=events),indent=2),encoding="utf-8")
    print("LIVE_FAILED "+str(report)+" "+str(ex),flush=True)
    raise
