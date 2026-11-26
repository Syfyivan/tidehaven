using System.Text.Json;
using TidehavenSpike.Core;

int assertions = 0;
int scenarios = 0;
void Check(bool condition, string description)
{
    assertions++;
    if (!condition) throw new InvalidOperationException(description);
}
void Test(string name, Action action)
{
    action();
    scenarios++;
    Console.WriteLine("PASS " + name);
}
SmallWorld Crew()
{
    var world = new SmallWorld();
    world.RegisterPlayer(11);
    world.RegisterPlayer(22);
    return world;
}
PlayerDiveState Player(SmallWorld world, long id) => world.Snapshot().Players.Single(p => p.PlayerId == id);
float Distance(float ax, float ay, float bx, float by) => MathF.Sqrt((ax - bx) * (ax - bx) + (ay - by) * (ay - by));
void SwimTogetherTo(SmallWorld world, long[] ids, float x, float y)
{
    for (int i = 0; i < 500; i++)
    {
        var snapshot = world.Snapshot();
        bool allArrived = true;
        foreach (long id in ids)
        {
            var player = snapshot.Players.Single(p => p.PlayerId == id);
            if (!player.IsDiving) throw new InvalidOperationException("SwimTogetherTo diver returned unexpectedly: " + player.LastReturnReason);
            float distance = Distance(player.X, player.Y, x, y);
            if (distance <= 5) { world.SetDiveInput(id, 0, 0); continue; }
            allArrived = false;
            if (Distance(player.X, player.Y, snapshot.Threat.X, snapshot.Threat.Y) < SmallWorld.HarpoonRange - 10 && player.HarpoonCooldown == 0)
                world.TryHarpoon(id, "approach-defense-" + id + "-" + i, snapshot.Threat.X - player.X, snapshot.Threat.Y - player.Y);
            world.SetDiveInput(id, x - player.X, y - player.Y);
        }
        if (allArrived) return;
        world.Tick(0.025f);
    }
    throw new InvalidOperationException("SwimTogetherTo did not reach destination.");
}
void RejectsRestore(WorldPersistent saved, string message)
{
    bool rejected = false;
    try { SmallWorld.Restore(saved); }
    catch (ArgumentException) { rejected = true; }
    Check(rejected, message);
}

Test("initial deck and deep-copy snapshots", () =>
{
    var world = Crew();
    var first = world.Snapshot();
    Check(first.Deck.Count == 96 && first.Anchored, "initial 12x8 anchored deck");
    Check(first.Deck.Any(c => c.X == 6 && c.Y == 6) && first.Deck.Any(c => c.X == 17 && c.Y == 13), "initial deck coordinates");
    first.Deck[0].X = -99;
    first.Players[0].Oxygen = -99;
    first.Threat.X = -99;
    Check(world.Snapshot().Deck.All(c => c.X >= 6), "snapshot deck detached");
    Check(Player(world, 11).Oxygen == SmallWorld.MaximumOxygen, "snapshot player detached");
    Check(world.Snapshot().Threat.X == SmallWorld.ThreatStartX, "snapshot threat detached");
});

Test("expansion validates before charging and survives request replay", () =>
{
    var world = Crew();
    int charges = 0;
    bool Spend() { charges++; return true; }
    Check(world.TryExpand(11, "far", 0, 0, Spend).Code == "not_adjacent", "remote tile refused");
    Check(world.TryExpand(11, "outside", -1, 6, Spend).Code == "outside_map", "out-of-map tile refused");
    Check(world.TryExpand(11, "existing", 6, 6, Spend).Code == "cell_exists", "existing tile refused");
    Check(charges == 0, "invalid expansion never charges");
    Check(world.TryExpand(11, "expand-1", 5, 6, Spend).Success, "adjacent expansion accepted");
    var replay = world.TryExpand(11, "expand-1", 5, 6, Spend);
    Check(replay.Success && replay.Duplicate && charges == 1, "duplicate expansion does not charge");
    Check(world.TryExpand(22, "expand-1", 5, 6, Spend).Code == "request_collision", "cross-player request collision refused");
    Check(world.TryExpand(11, "expand-1", 5, 7, Spend).Code == "request_collision", "changed request payload refused");
    Check(world.Snapshot().Deck.Count == 97, "one exact added tile");
    var restored = SmallWorld.Restore(world.CapturePersistent());
    restored.RegisterPlayer(11);
    Check(restored.TryExpand(11, "expand-1", 5, 6, Spend).Duplicate && charges == 1, "restart keeps charged request receipt");
});

Test("failed charge and missing crew do not mutate deck", () =>
{
    var world = Crew();
    int callbacks = 0;
    Check(world.TryExpand(11, "poor", 5, 6, () => { callbacks++; return false; }).Code == "wood_unavailable", "insufficient wood rejected");
    Check(world.TryExpand(11, "poor", 5, 6, () => { callbacks++; return true; }).Duplicate, "failed request replay stable");
    Check(callbacks == 1 && world.Snapshot().Deck.Count == 96, "failed charge leaves deck unchanged");
    world.SetOnDeck(11, false);
    Check(world.TryExpand(11, "ashore", 5, 6, () => { callbacks++; return true; }).Code == "not_on_deck", "ashore build denied");
    Check(callbacks == 1, "ashore cannot charge");
});

Test("host authority includes input tick and inventory callbacks", () =>
{
    var client = new SmallWorld(false);
    int effects = 0;
    client.RegisterPlayer(11);
    Check(client.TryExpand(11, "client", 5, 6, () => { effects++; return true; }).Code == "not_host", "client expansion refused");
    Check(client.TryCollect(11, "client-ore", () => { effects++; return true; }).Code == "not_host", "client reward refused");
    Check(client.TrySail(11, 1, 0).Code == "not_host", "client sailing refused");
    Check(!client.SetDiveInput(11, 1, 0), "client input cannot mutate authority");
    client.Tick(1);
    Check(effects == 0 && client.Snapshot().Players.Count == 0 && client.Snapshot().SimulationSeconds == 0, "client tick and registration have no effect");
});

Test("sailing blocks divers and ashore players", () =>
{
    var world = Crew();
    Check(world.TrySail(11, 1, 0).Code == "anchored", "anchor blocks sail");
    Check(world.TryDive(22, "guest-dive").Success, "guest dives");
    Check(world.TryToggleAnchor(11, "raise-anchor").Code == "crew_away" && world.Snapshot().Anchored, "diver prevents lifting anchor");
    Check(world.TrySail(11, 1, 0).Code == "anchored", "refused anchor lift still blocks departure");
    world.SetOnDeck(22, true);
    Check(world.TryToggleAnchor(11, "still-diving").Code == "crew_away", "native deck location does not end dive");
    world.TryReturn(22, "guest-return");
    world.SetOnDeck(22, false);
    Check(world.TryToggleAnchor(11, "ashore-anchor").Code == "crew_away", "ashore crew prevents lifting anchor");
    world.SetOnDeck(22, true);
    Check(world.TryToggleAnchor(11, "raise-ready").Success, "whole crew permits lifting anchor");
    int receipts = world.CapturePersistent().Requests.Count;
    Check(world.TrySail(11, 1, 1).Success, "whole crew permits departure");
    var snapshot = world.Snapshot();
    Check(Math.Abs(Distance(0, 0, snapshot.ShipX, snapshot.ShipY) - SmallWorld.SailStep) < 0.01, "diagonal sailing speed bounded");
    Check(world.TrySail(11, float.NaN, 0).Code == "invalid_direction", "non-finite movement refused");
    Check(world.CapturePersistent().Requests.Count == receipts, "helm updates do not fill receipt ledger");
    world.SetOnDeck(22, false);
    Check(world.TrySail(11, 1, 0).Code == "crew_away", "leaving deck stops unanchored movement");
    Check(world.TryToggleAnchor(11, "drop-safely").Success && world.Snapshot().Anchored, "dropping anchor remains safe when crew is away");
});

Test("host above water still simulates guest and independent return", () =>
{
    var world = Crew();
    world.TryDive(22, "guest-only");
    world.SetDiveInput(22, 1, 0);
    world.Tick(1);
    Check(Player(world, 22).X > SmallWorld.SpawnX && Player(world, 22).Oxygen < SmallWorld.MaximumOxygen, "guest moves and consumes oxygen without diving host");
    Check(!Player(world, 11).IsDiving && Player(world, 11).OnDeck, "host remains above water");
    world.TryDive(11, "host-now");
    Check(world.TryReturn(22, "guest-alone-back").Success, "guest return works");
    Check(Player(world, 11).IsDiving && !Player(world, 22).IsDiving, "return belongs only to requested player");
    Check(!world.SetDiveInput(11, float.PositiveInfinity, 0), "invalid dive input refused");
});

Test("two divers race for one ore and full bag leaves it available", () =>
{
    var world = Crew();
    world.TryDive(11, "ore-dive-a");
    world.TryDive(22, "ore-dive-b");
    int rewards = 0;
    Check(world.TryCollect(11, "far-ore", () => { rewards++; return true; }).Code == "too_far", "ore requires proximity");
    SwimTogetherTo(world, new[] { 11L, 22L }, SmallWorld.OreX, SmallWorld.OreY);
    Check(world.TryCollect(22, "full-bag", () => false).Code == "reward_rejected", "full bag rejects transaction");
    Check(!world.Snapshot().OreDepleted && rewards == 0, "full bag preserves ore");
    var winner = world.TryCollect(22, "ore-win", () => { rewards++; return true; });
    Check(winner.Success && world.Snapshot().OreDepleted, "first accepted reward consumes ore");
    Check(world.TryCollect(22, "ore-win", () => { rewards++; return true; }).Duplicate, "reward request replay suppressed");
    Check(world.TryCollect(11, "ore-lose", () => { rewards++; return true; }).Code == "ore_depleted", "second diver cannot collect same node");
    Check(rewards == 1, "exactly one inventory reward");
    var restored = SmallWorld.Restore(world.CapturePersistent());
    restored.RegisterPlayer(22);
    Check(restored.Snapshot().OreDepleted && restored.TryCollect(22, "ore-win", () => { rewards++; return true; }).Duplicate, "save keeps depletion and reward request receipt");
    Check(rewards == 1, "restore does not reissue reward");
});

Test("harpoon repels threat and replay cannot repeat displacement", () =>
{
    var world = Crew();
    world.TryDive(11, "harpoon-dive");
    for (int i = 0; i < 400; i++)
    {
        var s = world.Snapshot();
        var p = s.Players.Single(p => p.PlayerId == 11);
        if (Distance(p.X, p.Y, s.Threat.X, s.Threat.Y) < 130) break;
        world.SetDiveInput(11, s.Threat.X - p.X, s.Threat.Y - p.Y);
        world.Tick(0.025f);
    }
    world.SetDiveInput(11, 0, 0);
    var before = world.Snapshot();
    var player = Player(world, 11);
    float dx = before.Threat.X - player.X, dy = before.Threat.Y - player.Y;
    Check(world.TryHarpoon(11, "hit", dx, dy).Code == "threat_repulsed", "aimed nearby harpoon hits");
    var after = world.Snapshot();
    Check(after.Threat.KnockbackSeconds > 0 && Distance(after.Threat.X, after.Threat.Y, before.Threat.X, before.Threat.Y) > 20, "threat displaced and stunned");
    Check(world.TryHarpoon(11, "hit", dx, dy).Duplicate && world.Snapshot().Threat.X == after.Threat.X, "replay does not repeat knockback");
    Check(world.TryHarpoon(11, "too-fast", dx, dy).Code == "cooldown", "host enforces harpoon cooldown");
});

Test("threat returns only touched diver without inventory callbacks", () =>
{
    var world = Crew();
    world.TryDive(22, "victim");
    for (int i = 0; i < 500 && Player(world, 22).IsDiving; i++) world.Tick(0.05f);
    var player = Player(world, 22);
    Check(!player.IsDiving && player.OnDeck && player.LastReturnReason == "threat", "threat safely returns victim");
    Check(Player(world, 11).OnDeck && world.CapturePersistent().Requests.Count == 1, "rescue creates no inventory or request effects");
});

Test("oxygen expires while swimming and safely returns the diver", () =>
{
    var world = Crew();
    world.TryDive(22, "oxygen-dive");
    // Continually repel the single threat, exercising oxygen independently of
    // injury while retaining the actual host threat simulation.
    for (int i = 0; i < 1200 && Player(world, 22).IsDiving; i++)
    {
        var s = world.Snapshot();
        var p = Player(world, 22);
        if (Distance(p.X, p.Y, s.Threat.X, s.Threat.Y) < 140 && p.HarpoonCooldown == 0)
            world.TryHarpoon(22, "oxygen-defense-" + i, s.Threat.X - p.X, s.Threat.Y - p.Y);
        world.Tick(0.05f);
    }
    var returned = Player(world, 22);
    Check(!returned.IsDiving && returned.OnDeck && returned.LastReturnReason == "oxygen", "oxygen exhaustion safely returns diver");
    Check(returned.InputX == 0 && returned.InputY == 0, "safe return clears held movement");
});

Test("JSON persistence excludes dive transient state and restores safely", () =>
{
    var world = Crew();
    world.TryToggleAnchor(11, "sail-anchor");
    world.TrySail(11, -1, 1);
    world.TryToggleAnchor(11, "dive-anchor");
    world.TryDive(22, "persist-diver");
    world.SetDiveInput(22, 1, 1);
    world.Tick(0.5f);
    string json = JsonSerializer.Serialize(world.CapturePersistent());
    Check(!json.Contains("Oxygen") && !json.Contains("Players") && !json.Contains("Items") && !json.Contains("Stack"), "save contains no divers or inventory contents");
    var saved = JsonSerializer.Deserialize<WorldPersistent>(json) ?? throw new InvalidOperationException("deserialize failed");
    var restored = SmallWorld.Restore(saved);
    Check(restored.Snapshot().Players.Count == 0 && restored.Snapshot().ShipX == world.Snapshot().ShipX, "persistent ship restored without active divers");
    restored.RegisterPlayer(22);
    Check(Player(restored, 22).OnDeck && !Player(restored, 22).IsDiving && Player(restored, 22).Oxygen == SmallWorld.MaximumOxygen, "reconnected player safely on deck");
    saved.Deck[0].X = -1;
    Check(restored.Snapshot().Deck[0].X == 6, "restored world does not retain mutable save references");
});

Test("invalid persistence cannot create detached or duplicate deck state", () =>
{
    var disconnected = Crew().CapturePersistent();
    disconnected.Deck.Add(new DeckCell { X = 0, Y = 0 });
    RejectsRestore(disconnected, "disconnected deck rejected");
    var duplicate = Crew().CapturePersistent();
    duplicate.Deck.Add(new DeckCell { X = 6, Y = 6 });
    RejectsRestore(duplicate, "duplicate deck rejected");
    var position = Crew().CapturePersistent();
    position.ShipX = float.NaN;
    RejectsRestore(position, "non-finite persistent coordinate rejected");
    var missingBase = Crew().CapturePersistent();
    missingBase.Deck[0] = new DeckCell { X = 5, Y = 6 };
    RejectsRestore(missingBase, "initial deck removal rejected");
});

Test("receipt cap rejects new item effects and preserves old replay protection", () =>
{
    var saved = Crew().CapturePersistent();
    for (int i = 0; i < SmallWorld.MaxRequests - 1; i++)
        saved.Requests.Add(new RequestReceipt { RequestId = "old-" + i, PlayerId = 11, Operation = "anchor", Success = true, Code = "anchored" });
    var world = SmallWorld.Restore(saved);
    world.RegisterPlayer(11);
    world.RegisterPlayer(22);
    Check(world.TryDive(22, "last-receipt").Success, "last free receipt accepted");
    int charges = 0;
    Check(world.TryExpand(11, "cap-expansion", 5, 6, () => { charges++; return true; }).Code == "request_limit", "full receipt ledger rejects new charge");
    Check(charges == 0 && world.CapturePersistent().Requests.Count == SmallWorld.MaxRequests, "cap cannot evict or charge");
    Check(world.TryToggleAnchor(11, "old-0").Duplicate && world.Snapshot().Anchored, "old request remains replay protected");
    Check(world.TryReturn(22, "safe-return-at-cap").Success && Player(world, 22).OnDeck, "receipt cap cannot trap diver");
});

Test("inventory callbacks cannot reenter or save unfinished transactions", () =>
{
    var world = Crew();
    int charges = 0;
    ActionResult? nested = null;
    bool savingBlocked = false;
    var outer = world.TryExpand(11, "outer", 5, 6, () =>
    {
        charges++;
        nested = world.TryExpand(11, "nested", 5, 7, () => { charges++; return true; });
        try { world.CapturePersistent(); }
        catch (InvalidOperationException) { savingBlocked = true; }
        return true;
    });
    Check(outer.Success && nested is not null && nested.Code == "request_busy", "reentrant inventory operation refused");
    Check(charges == 1 && world.Snapshot().Deck.Count == 97, "only outer inventory transaction committed");
    Check(savingBlocked && world.CapturePersistent().Requests.Count == 1, "no incomplete receipt can be serialized");
});

Test("ambiguous native inventory exceptions cannot be retried or forgotten", () =>
{
    var world = Crew();
    int nativeChanges = 0;
    var failed = world.TryExpand(11, "ambiguous", 5, 6, () =>
    {
        nativeChanges++;
        throw new InvalidOperationException("simulated native hook failure after mutation");
    });
    Check(failed.Code == "inventory_callback_failed" && world.Snapshot().InventoryFaulted, "ambiguous callback freezes item transactions");
    Check(world.TryExpand(11, "ambiguous", 5, 6, () => { nativeChanges++; return true; }).Duplicate, "same ambiguous request never reinvokes callback");
    Check(world.TryExpand(11, "fresh-request", 5, 6, () => { nativeChanges++; return true; }).Code == "inventory_fault", "new request cannot bypass ambiguous inventory outcome");
    Check(nativeChanges == 1 && world.Snapshot().Deck.Count == 96, "core does not fabricate inventory rollback or expansion");
    var restored = SmallWorld.Restore(world.CapturePersistent());
    restored.RegisterPlayer(11);
    Check(restored.Snapshot().InventoryFaulted, "fault survives persistence using existing receipt");
    Check(restored.TryExpand(11, "after-restore", 5, 6, () => { nativeChanges++; return true; }).Code == "inventory_fault" && nativeChanges == 1, "reload of faulted state cannot repeat item mutation");
    Check(restored.TryDive(11, "faulted-world-dive").Success && restored.TryReturn(11, "faulted-world-return").Success, "inventory fault does not prevent safe return");
});

Test("ore callback exceptions cannot duplicate rewards with a new request", () =>
{
    var world = Crew();
    world.TryDive(11, "ore-fault-dive-a");
    world.TryDive(22, "ore-fault-dive-b");
    SwimTogetherTo(world, new[] { 11L, 22L }, SmallWorld.OreX, SmallWorld.OreY);
    int grants = 0;
    Check(world.TryCollect(11, "ore-fault", () => { grants++; throw new InvalidOperationException("after native grant"); }).Code == "inventory_callback_failed", "ambiguous reward recognized");
    Check(world.TryCollect(22, "ore-second", () => { grants++; return true; }).Code == "inventory_fault", "other player cannot duplicate ambiguous ore grant");
    Check(grants == 1 && !world.Snapshot().OreDepleted, "no invented ore commit after callback failure");
    Check(SmallWorld.Restore(world.CapturePersistent()).Snapshot().InventoryFaulted, "ambiguous reward remains blocked after restore");
});

Test("disconnect and reconnect clear motion but retain request history", () =>
{
    var world = Crew();
    int charges = 0;
    world.TryExpand(22, "before-disconnect", 5, 6, () => { charges++; return true; });
    world.TryDive(22, "dive-before-disconnect");
    world.SetDiveInput(22, 1, 0);
    world.Tick(1);
    float oxygen = Player(world, 22).Oxygen;
    world.RegisterPlayer(22);
    Check(Player(world, 22).IsDiving && Player(world, 22).Oxygen == oxygen, "idempotent registration cannot refill active diver");
    world.RemovePlayer(22);
    Check(world.Snapshot().Players.Count == 1 && !world.SetDiveInput(22, 1, 0), "disconnected player has no active movement");
    Check(world.TryDive(22, "dive-before-disconnect").Code == "player_missing", "disconnected old request is not acknowledged as active");
    Check(world.TryToggleAnchor(11, "one-crew-anchor").Success && world.TrySail(11, 1, 0).Success, "disconnected transient diver does not strand connected crew");
    world.RegisterPlayer(22);
    var joined = Player(world, 22);
    Check(joined.OnDeck && !joined.IsDiving && joined.InputX == 0 && joined.InputY == 0, "reconnect is safe and clears previous held input");
    var stale = world.TryDive(22, "dive-before-disconnect");
    Check(stale.Duplicate && !Player(world, 22).IsDiving, "old dive acknowledgement cannot restart dive after reconnect");
    Check(world.TryExpand(22, "before-disconnect", 5, 6, () => { charges++; return true; }).Duplicate && charges == 1, "reconnect retains charged expansion receipt");
});

Test("persistent resource state and receipt meaning must agree", () =>
{
    var missingOreReceipt = Crew().CapturePersistent();
    missingOreReceipt.OreDepleted = true;
    RejectsRestore(missingOreReceipt, "depleted ore without successful grant receipt rejected");
    var unconsumedReward = Crew().CapturePersistent();
    unconsumedReward.Requests.Add(new RequestReceipt { RequestId = "ore", PlayerId = 11, Operation = "collect", Success = true, Code = "ore_collected" });
    RejectsRestore(unconsumedReward, "grant receipt with reusable ore rejected");
    unconsumedReward.OreDepleted = true;
    unconsumedReward.Requests.Add(new RequestReceipt { RequestId = "ore-again", PlayerId = 22, Operation = "collect", Success = true, Code = "ore_collected" });
    RejectsRestore(unconsumedReward, "two successful ore grants rejected");
    var expansionMissing = Crew().CapturePersistent();
    expansionMissing.Requests.Add(new RequestReceipt { RequestId = "tile", PlayerId = 11, Operation = "expand:5:6", Success = true, Code = "expanded" });
    RejectsRestore(expansionMissing, "expansion receipt without tile rejected");
    var unchargedTile = Crew().CapturePersistent();
    unchargedTile.Deck.Add(new DeckCell { X = 5, Y = 6 });
    RejectsRestore(unchargedTile, "extra deck without successful charge receipt rejected");
    var wrongCode = Crew().CapturePersistent();
    wrongCode.Requests.Add(new RequestReceipt { RequestId = "wrong", PlayerId = 11, Operation = "anchor", Success = true, Code = "ore_collected" });
    RejectsRestore(wrongCode, "mismatched operation result rejected");
    var duplicateId = Crew().CapturePersistent();
    duplicateId.Requests.Add(new RequestReceipt { RequestId = "duplicate", PlayerId = 11, Operation = "anchor", Success = true, Code = "unanchored" });
    duplicateId.Requests.Add(new RequestReceipt { RequestId = "duplicate", PlayerId = 11, Operation = "anchor", Success = true, Code = "anchored" });
    RejectsRestore(duplicateId, "duplicate persisted request identity rejected");
    var failedInput = Crew();
    failedInput.TryDive(11, "input-dive");
    failedInput.TryHarpoon(11, "nan-direction", float.NaN, 0);
    Check(SmallWorld.Restore(failedInput.CapturePersistent()).CapturePersistent().Requests.Count == 2, "valid rejected input receipts remain restorable");
});

Test("inventory reservations validate and deduplicate before owner mutation", () =>
{
    var world = Crew();
    Check(world.PrepareInventory(11, "bad-kind", "anchor").Code == "invalid_inventory_kind", "only inventory operations can be prepared");
    Check(world.PrepareInventory(11, "remote-prepare", "expand", 0, 0).Code == "not_adjacent", "prepare validates expansion geometry");
    var prepared = world.PrepareInventory(11, "prepared-expansion", "expand", 5, 6);
    Check(prepared.Success && prepared.Code == "inventory_prepared", "valid preparation grants owner authorization");
    Check(world.Snapshot().Deck.Count == 96 && world.Snapshot().PendingInventoryCount == 1, "preparation does not build before inventory outcome");
    var duplicate = world.PrepareInventory(11, "prepared-expansion", "expand", 5, 6);
    Check(duplicate.Success && duplicate.Duplicate && duplicate.Code == "inventory_prepared", "duplicate preparation preserves exact authorization");
    Check(world.PrepareInventory(22, "prepared-expansion", "expand", 5, 6).Code == "request_collision", "another owner cannot reuse preparation");
    Check(world.PrepareInventory(11, "prepared-expansion", "expand", 5, 7).Code == "request_collision", "changed prepared coordinates refused");
    Check(world.PrepareInventory(22, "other-preparation", "expand", 5, 6).Code == "cell_reserved", "same cell cannot be reserved twice");
    int charges = 0;
    Check(world.TryExpand(22, "sync-reserved", 5, 6, () => { charges++; return true; }).Code == "cell_reserved", "synchronous expansion respects reservation");
    Check(world.TryExpand(11, "prepared-expansion", 5, 6, () => { charges++; return true; }).Code == "inventory_prepared", "same-ID legacy call cannot execute owner authorization");
    Check(charges == 0, "reserved target invokes no native inventory callback");
    Check(world.CompleteInventory(22, "prepared-expansion", true).Code == "request_collision", "wrong owner cannot acknowledge reservation");
    Check(world.CompleteInventory(11, "never-prepared", true).Code == "inventory_not_prepared", "invented ACK cannot create a tile");
    Check(world.CompleteInventory(11, "prepared-expansion", true).Code == "expanded", "owner success commits reserved tile");
    var repeatedAck = world.CompleteInventory(11, "prepared-expansion", false);
    Check(repeatedAck.Success && repeatedAck.Duplicate && repeatedAck.Code == "expanded", "contradictory replay cannot reverse successful ACK");
    Check(world.PrepareInventory(11, "prepared-expansion", "expand", 5, 6).Code == "expanded", "prepare after commit returns final receipt");
    Check(world.Snapshot().Deck.Count == 97 && world.Snapshot().PendingInventoryCount == 0, "exactly one tile and no stale reservation");
});

Test("owner rejection releases the reservation without permitting same-ID retry", () =>
{
    var world = Crew();
    world.PrepareInventory(11, "poor-owner", "expand", 5, 6);
    Check(world.CompleteInventory(11, "poor-owner", false).Code == "wood_unavailable", "owner rejection records failed charge");
    Check(world.Snapshot().PendingInventoryCount == 0 && world.Snapshot().Deck.Count == 96, "rejection releases tile without building");
    var replay = world.CompleteInventory(11, "poor-owner", true);
    Check(!replay.Success && replay.Duplicate && replay.Code == "wood_unavailable", "late opposite outcome cannot retry rejected owner transaction");
    Check(world.PrepareInventory(11, "poor-owner", "expand", 5, 6).Code == "wood_unavailable", "same-ID prepare cannot authorize inventory a second time");
    Check(world.PrepareInventory(22, "new-owner", "expand", 5, 6).Code == "inventory_prepared", "another transaction may reserve released tile");
    Check(world.CompleteInventory(22, "new-owner", true).Success, "replacement reservation commits normally");
    Check(SmallWorld.Restore(world.CapturePersistent()).Snapshot().Deck.Count == 97, "failed and committed receipts remain coherent in save");
});

Test("two divers reserve one ore and complete after returning", () =>
{
    var world = Crew();
    world.TryDive(11, "reserved-ore-dive-a");
    world.TryDive(22, "reserved-ore-dive-b");
    Check(world.PrepareInventory(11, "ore-too-far", "collect").Code == "too_far", "ore preparation requires current proximity");
    SwimTogetherTo(world, new[] { 11L, 22L }, SmallWorld.OreX, SmallWorld.OreY);
    Check(world.PrepareInventory(11, "first-ore-reservation", "collect").Code == "inventory_prepared", "first diver reserves ore");
    Check(world.PrepareInventory(22, "second-ore-reservation", "collect").Code == "ore_reserved", "other diver cannot reserve same ore");
    int grants = 0;
    Check(world.TryCollect(22, "legacy-ore-race", () => { grants++; return true; }).Code == "ore_reserved" && grants == 0, "legacy reward callback also respects reservation");
    Check(world.CompleteInventory(11, "first-ore-reservation", false).Code == "reward_rejected", "full owner bag releases ore");
    Check(!world.Snapshot().OreDepleted, "rejected owner grant leaves ore available");
    Check(world.PrepareInventory(22, "winning-ore-reservation", "collect").Success, "new request can claim released ore");
    world.TryReturn(22, "return-before-ore-ack");
    world.SetOnDeck(22, false);
    Check(world.CompleteInventory(22, "winning-ore-reservation", true).Code == "ore_collected", "accepted grant commits even after owner leaves dive and deck");
    Check(world.CompleteInventory(22, "winning-ore-reservation", true).Duplicate, "duplicate reward ACK does not consume twice");
    var saved = world.CapturePersistent();
    Check(saved.Requests.Count(r => r.Operation == "collect" && r.Success) == 1 && saved.PendingInventory.Count == 0, "exactly one committed ore receipt");
    Check(SmallWorld.Restore(saved).Snapshot().OreDepleted, "reservation outcome persists as normal depletion");
});

Test("pending owner transactions survive disconnect and JSON restore", () =>
{
    var world = Crew();
    world.PrepareInventory(22, "offline-expansion", "expand", 5, 6);
    world.RemovePlayer(22);
    Check(world.Snapshot().PendingInventoryCount == 1, "disconnect does not discard inventory authorization");
    var captured = world.CapturePersistent();
    captured.PendingInventory[0].X = 0;
    Check(world.CapturePersistent().PendingInventory[0].X == 5, "captured pending requests are detached copies");
    string json = JsonSerializer.Serialize(world.CapturePersistent());
    var saved = JsonSerializer.Deserialize<WorldPersistent>(json)!;
    var restored = SmallWorld.Restore(saved);
    saved.PendingInventory[0].Y = 0;
    Check(restored.Snapshot().Players.Count == 0 && restored.Snapshot().PendingInventoryCount == 1, "restore keeps authorization without transient owner registration");
    Check(restored.CompleteInventory(22, "offline-expansion", true).Code == "expanded", "late authenticated ACK commits without requiring online owner");
    Check(restored.CompleteInventory(22, "offline-expansion", true).Duplicate && restored.Snapshot().Deck.Count == 97, "offline ACK replay cannot repeat effect");
    restored.RegisterPlayer(22);
    Check(restored.PrepareInventory(22, "offline-expansion", "expand", 5, 6).Code == "expanded", "reconnected owner receives final receipt");
});

Test("pending inventory persistence rejects conflicting or fabricated reservations", () =>
{
    WorldPersistent PendingExpansion()
    {
        var world = Crew();
        world.PrepareInventory(11, "pending", "expand", 5, 6);
        return world.CapturePersistent();
    }
    var duplicateCell = PendingExpansion();
    duplicateCell.PendingInventory.Add(new PreparedInventory { RequestId = "other", PlayerId = 22, Kind = "expand", X = 5, Y = 6 });
    RejectsRestore(duplicateCell, "two reservations cannot own same cell");
    var duplicateIdentity = PendingExpansion();
    duplicateIdentity.PendingInventory.Add(new PreparedInventory { RequestId = "pending", PlayerId = 22, Kind = "expand", X = 5, Y = 7 });
    RejectsRestore(duplicateIdentity, "pending request identities are unique");
    var alreadyFinal = PendingExpansion();
    alreadyFinal.Requests.Add(new RequestReceipt { RequestId = "pending", PlayerId = 11, Operation = "expand:5:6", Code = "wood_unavailable" });
    RejectsRestore(alreadyFinal, "pending and final ledgers must not share identity");
    var existingTile = PendingExpansion();
    existingTile.PendingInventory[0].X = 6;
    RejectsRestore(existingTile, "reservation cannot target already-built tile");
    var detached = PendingExpansion();
    detached.PendingInventory[0].X = 0;
    RejectsRestore(detached, "pending expansion must be adjacent to committed deck");
    var invalidKind = PendingExpansion();
    invalidKind.PendingInventory[0].Kind = "dive";
    RejectsRestore(invalidKind, "non-inventory reservation rejected");
    var ore = Crew().CapturePersistent();
    ore.PendingInventory.Add(new PreparedInventory { RequestId = "ore-a", PlayerId = 11, Kind = "collect" });
    ore.PendingInventory.Add(new PreparedInventory { RequestId = "ore-b", PlayerId = 22, Kind = "collect" });
    RejectsRestore(ore, "ore cannot have two pending owners");
    ore.PendingInventory.RemoveAt(1);
    ore.OreDepleted = true;
    ore.Requests.Add(new RequestReceipt { RequestId = "old-ore", PlayerId = 22, Operation = "collect", Success = true, Code = "ore_collected" });
    RejectsRestore(ore, "depleted ore cannot retain pending reward authorization");
});

Test("pending authorizations reserve ledger space and old saves remain readable", () =>
{
    var saved = Crew().CapturePersistent();
    string oldJson = JsonSerializer.Serialize(new { saved.Version, saved.ShipX, saved.ShipY, saved.Anchored, saved.OreDepleted, saved.Deck, saved.Requests });
    var old = SmallWorld.Restore(JsonSerializer.Deserialize<WorldPersistent>(oldJson)!);
    Check(old.Snapshot().PendingInventoryCount == 0 && old.Snapshot().Deck.Count == 96, "save without new pending property restores safely");
    for (int i = 0; i < SmallWorld.MaxRequests - 1; i++)
        saved.Requests.Add(new RequestReceipt { RequestId = "capacity-" + i, PlayerId = 11, Operation = "anchor", Success = true, Code = "anchored" });
    var world = SmallWorld.Restore(saved);
    world.RegisterPlayer(11);
    Check(world.PrepareInventory(11, "last-slot-reserved", "expand", 5, 6).Success, "reservation consumes last ledger slot");
    Check(world.PrepareInventory(11, "beyond-cap", "expand", 5, 7).Code == "request_limit", "pending counts against cap without evicting receipts");
    Check(world.PrepareInventory(11, "last-slot-reserved", "expand", 5, 6).Duplicate, "pending replay still works at capacity");
    var restored = SmallWorld.Restore(world.CapturePersistent());
    Check(restored.CompleteInventory(11, "last-slot-reserved", true).Success, "reserved completion always has ledger capacity");
    Check(restored.CapturePersistent().Requests.Count == SmallWorld.MaxRequests && restored.Snapshot().PendingInventoryCount == 0, "completion transfers rather than grows ledger slot");
    var client = new SmallWorld(false);
    Check(client.PrepareInventory(11, "client-reserve", "expand", 5, 6).Code == "not_host", "client cannot authorize native inventory");
    Check(client.CompleteInventory(11, "client-ack", true).Code == "not_host", "client cannot commit authoritative world effects");
});

Console.WriteLine($"TIDEHAVEN_SPIKE_CORE_OK scenarios={scenarios} assertions={assertions}");
