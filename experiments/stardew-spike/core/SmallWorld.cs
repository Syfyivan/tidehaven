using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace TidehavenSpike.Core;

/// <summary>
/// Host-only rules. The bridge must authenticate the sender as playerId and call
/// all methods serially on the game thread. Inventory callbacks are synchronous:
/// true commits exactly once; false must leave inventory untouched. Never replay
/// callbacks from snapshots, replies, or persistence.
/// </summary>
public sealed class SmallWorld
{
    public const int MapWidth = 32;
    public const int MapHeight = 24;
    public const int InitialDeckLeft = 6;
    public const int InitialDeckTop = 6;
    public const int InitialDeckWidth = 12;
    public const int InitialDeckHeight = 8;
    public const int ExpansionWoodCost = 5;
    public const int OreRewardCount = 1;
    public const int MaxRequests = 4096;
    public const float DiveWidth = 960;
    public const float DiveHeight = 540;
    public const float SpawnX = 80;
    public const float SpawnY = 90;
    public const float OreX = 600;
    public const float OreY = 390;
    public const float OreReach = 48;
    public const float MaximumOxygen = 45;
    public const float SwimSpeed = 180;
    public const float SailStep = 8;
    public const float HarpoonRange = 160;
    public const float ThreatStartX = 760;
    public const float ThreatStartY = 280;
    public const float ThreatSpeed = 48;
    public const float ThreatContactRange = 26;
    public const float ShipPositionLimit = 100000;

    private readonly bool isHost;
    private readonly HashSet<(int X, int Y)> deck = new();
    private readonly Dictionary<long, PlayerDiveState> players = new();
    private readonly Dictionary<string, RequestReceipt> requests = new(StringComparer.Ordinal);
    private readonly Dictionary<string, PreparedInventory> pendingInventory = new(StringComparer.Ordinal);
    private readonly ThreatState threat = new() { X = ThreatStartX, Y = ThreatStartY };
    private float shipX;
    private float shipY;
    private bool anchored = true;
    private bool oreDepleted;
    private bool inventoryFaulted;
    private bool executingRequest;
    private double simulationSeconds;

    public SmallWorld(bool isHost = true)
    {
        this.isHost = isHost;
        for (int y = InitialDeckTop; y < InitialDeckTop + InitialDeckHeight; y++)
            for (int x = InitialDeckLeft; x < InitialDeckLeft + InitialDeckWidth; x++)
                deck.Add((x, y));
    }

    public void RegisterPlayer(long playerId)
    {
        if (!isHost || players.ContainsKey(playerId)) return;
        players[playerId] = new PlayerDiveState
        {
            PlayerId = playerId, OnDeck = true, X = SpawnX, Y = SpawnY,
            Oxygen = MaximumOxygen, LastReturnReason = "registered"
        };
    }

    public void RemovePlayer(long playerId)
    {
        if (isHost) players.Remove(playerId);
    }

    public void SetOnDeck(long playerId, bool onDeck)
    {
        if (isHost && players.TryGetValue(playerId, out var player))
            player.OnDeck = !player.IsDiving && onDeck;
    }

    public bool SetDiveInput(long playerId, float x, float y)
    {
        if (!isHost || !Finite(x) || !Finite(y) || !players.TryGetValue(playerId, out var player) || !player.IsDiving)
            return false;
        Normalize(ref x, ref y);
        player.InputX = x;
        player.InputY = y;
        return true;
    }

    public ActionResult TryExpand(long playerId, string requestId, int x, int y, Func<bool> trySpendWood)
        => Execute(playerId, requestId, InventoryOperation("expand", x, y), () =>
        {
            var eligibility = ExpansionEligibility(playerId, x, y);
            if (eligibility is not null) return eligibility;
            var inventoryResult = InvokeInventory(trySpendWood, "wood_unavailable");
            if (inventoryResult is not null) return inventoryResult;
            deck.Add((x, y));
            return Ok("expanded");
        });

    public ActionResult TryDive(long playerId, string requestId)
        => Execute(playerId, requestId, "dive", () =>
        {
            if (!OnDeck(playerId)) return Fail("not_on_deck");
            if (!anchored) return Fail("anchor_required");
            var player = players[playerId];
            player.IsDiving = true;
            player.OnDeck = false;
            player.X = SpawnX;
            player.Y = SpawnY;
            player.Oxygen = MaximumOxygen;
            player.InputX = player.InputY = 0;
            player.HarpoonCooldown = 0;
            player.LastReturnReason = "";
            return Ok("diving");
        });

    public ActionResult TryReturn(long playerId, string requestId)
        => Execute(playerId, requestId, "return", () =>
        {
            if (!players[playerId].IsDiving) return Fail("not_diving");
            ReturnSafely(players[playerId], "manual");
            return Ok("returned");
        }, allowWithoutReceiptAtLimit: true);

    public ActionResult TryToggleAnchor(long playerId, string requestId)
        => Execute(playerId, requestId, "anchor", () =>
        {
            if (!OnDeck(playerId)) return Fail("not_on_deck");
            if (anchored && CrewAway()) return Fail("crew_away");
            anchored = !anchored;
            return Ok(anchored ? "anchored" : "unanchored");
        });

    // Continuous helm input has no item effects and does not consume request
    // receipts. The bridge should accept only the helmsman's authenticated input
    // at a host-controlled rate (10 Hz), not one movement per received packet.
    public ActionResult TrySail(long playerId, float dx, float dy)
    {
        if (!isHost) return Fail("not_host");
        if (!players.ContainsKey(playerId)) return Fail("player_missing");
        if (!OnDeck(playerId)) return Fail("not_on_deck");
        if (anchored) return Fail("anchored");
        if (CrewAway()) return Fail("crew_away");
        if (!Direction(ref dx, ref dy)) return Fail("invalid_direction");
        shipX = Math.Clamp(shipX + dx * SailStep, -ShipPositionLimit, ShipPositionLimit);
        shipY = Math.Clamp(shipY + dy * SailStep, -ShipPositionLimit, ShipPositionLimit);
        return Ok("sailed");
    }

    public ActionResult TryCollect(long playerId, string requestId, Func<bool> tryGiveOre)
        => Execute(playerId, requestId, "collect", () =>
        {
            var eligibility = CollectionEligibility(playerId);
            if (eligibility is not null) return eligibility;
            var inventoryResult = InvokeInventory(tryGiveOre, "reward_rejected");
            if (inventoryResult is not null) return inventoryResult;
            oreDepleted = true;
            return Ok("ore_collected");
        });

    // Reserve world eligibility before the inventory owner applies its native
    // change. The bridge stores/retries the order; only the owner may ACK it.
    public ActionResult PrepareInventory(long playerId, string requestId, string kind, int x = 0, int y = 0)
    {
        if (kind != "expand" && kind != "collect") return Fail("invalid_inventory_kind");
        if (kind == "collect") x = y = 0;
        return Execute(playerId, requestId, InventoryOperation(kind, x, y), () =>
        {
            var eligibility = kind == "expand" ? ExpansionEligibility(playerId, x, y) : CollectionEligibility(playerId);
            if (eligibility is not null) return eligibility;
            if (inventoryFaulted) return Fail("inventory_fault");
            pendingInventory.Add(requestId, new PreparedInventory
            {
                RequestId = requestId, PlayerId = playerId, Kind = kind, X = x, Y = y
            });
            return Ok("inventory_prepared");
        });
    }

    // A successful owner outcome is irrevocable: finish the reserved world
    // effect even after movement, return, disconnect, or a save/load boundary.
    public ActionResult CompleteInventory(long playerId, string requestId, bool success)
    {
        if (!isHost) return Fail("not_host");
        if (executingRequest) return Fail("request_busy");
        if (!ValidRequestId(requestId)) return Fail("request_invalid");
        if (pendingInventory.TryGetValue(requestId, out var prepared))
        {
            if (prepared.PlayerId != playerId) return Fail("request_collision");
            if (success)
            {
                if (prepared.Kind == "expand") deck.Add((prepared.X, prepared.Y));
                else oreDepleted = true;
            }
            string code = prepared.Kind == "expand"
                ? (success ? "expanded" : "wood_unavailable")
                : (success ? "ore_collected" : "reward_rejected");
            pendingInventory.Remove(requestId);
            requests.Add(requestId, new RequestReceipt
            {
                RequestId = requestId, PlayerId = playerId,
                Operation = InventoryOperation(prepared.Kind, prepared.X, prepared.Y), Success = success, Code = code
            });
            return new ActionResult { Success = success, Code = code };
        }
        if (requests.TryGetValue(requestId, out var previous))
            return previous.PlayerId == playerId && (previous.Operation == "collect" || previous.Operation.StartsWith("expand:", StringComparison.Ordinal))
                ? new ActionResult { Success = previous.Success, Duplicate = true, Code = previous.Code }
                : Fail("request_collision");
        return Fail("inventory_not_prepared");
    }

    public ActionResult TryHarpoon(long playerId, string requestId, float dx, float dy)
        => Execute(playerId, requestId,
            "harpoon:" + dx.ToString("R", CultureInfo.InvariantCulture) + ":" + dy.ToString("R", CultureInfo.InvariantCulture), () =>
        {
            var player = players[playerId];
            if (!player.IsDiving) return Fail("not_diving");
            if (player.HarpoonCooldown > 0) return Fail("cooldown");
            if (!Direction(ref dx, ref dy)) return Fail("invalid_direction");
            player.HarpoonCooldown = 0.45f;
            float tx = threat.X - player.X, ty = threat.Y - player.Y;
            float distance = Distance(player.X, player.Y, threat.X, threat.Y);
            if (distance > HarpoonRange || distance > 0.001f && (tx * dx + ty * dy) / distance < 0.75f)
                return Ok("harpoon_miss");
            threat.X = Math.Clamp(threat.X + dx * 85, 20, DiveWidth - 20);
            threat.Y = Math.Clamp(threat.Y + dy * 85, 20, DiveHeight - 20);
            threat.KnockbackSeconds = 1.4f;
            return Ok("threat_repulsed");
        });

    // Call once per host update, even if the host has no dive menu open.
    // Bound the supplied delta; the bridge can split a longer pause into calls.
    public void Tick(float elapsedSeconds)
    {
        if (!isHost) return;
        if (!Finite(elapsedSeconds) || elapsedSeconds < 0 || elapsedSeconds > 10)
            throw new ArgumentOutOfRangeException(nameof(elapsedSeconds));
        float remaining = elapsedSeconds;
        while (remaining > 0)
        {
            float step = Math.Min(remaining, 0.05f);
            TickStep(step);
            remaining = Math.Max(0, remaining - step);
        }
    }

    public WorldSnapshot Snapshot() => new()
    {
        ShipX = shipX, ShipY = shipY, Anchored = anchored, OreDepleted = oreDepleted, InventoryFaulted = inventoryFaulted,
        PendingInventoryCount = pendingInventory.Count,
        SimulationSeconds = simulationSeconds, Deck = CopyDeck(),
        Players = players.Values.OrderBy(p => p.PlayerId).Select(CopyPlayer).ToList(),
        Threat = new ThreatState { X = threat.X, Y = threat.Y, KnockbackSeconds = threat.KnockbackSeconds }
    };

    public WorldPersistent CapturePersistent()
    {
        if (executingRequest) throw new InvalidOperationException("Cannot save an incomplete inventory transaction.");
        return new WorldPersistent
        {
            ShipX = shipX, ShipY = shipY, Anchored = anchored, OreDepleted = oreDepleted,
            Deck = CopyDeck(), Requests = requests.Values.Select(CopyReceipt).ToList(),
            PendingInventory = pendingInventory.Values.Select(CopyPrepared).ToList()
        };
    }

    public static SmallWorld Restore(WorldPersistent saved, bool isHost = true)
    {
        if (saved is null || saved.Version != 1 || !Finite(saved.ShipX) || !Finite(saved.ShipY)
            || Math.Abs(saved.ShipX) > ShipPositionLimit || Math.Abs(saved.ShipY) > ShipPositionLimit
            || saved.Deck is null || saved.Deck.Count < InitialDeckWidth * InitialDeckHeight
            || saved.Deck.Count > MapWidth * MapHeight || saved.Requests is null || saved.PendingInventory is null
            || saved.Requests.Count > MaxRequests || saved.PendingInventory.Count > MaxRequests - saved.Requests.Count)
            throw new ArgumentException("Invalid Tidehaven spike save.", nameof(saved));
        var world = new SmallWorld(isHost);
        var restoredDeck = new HashSet<(int X, int Y)>();
        foreach (var cell in saved.Deck)
            if (cell is null || !InMap(cell.X, cell.Y) || !restoredDeck.Add((cell.X, cell.Y)))
                throw new ArgumentException("Invalid or duplicate deck cell.", nameof(saved));
        if (!world.deck.IsSubsetOf(restoredDeck))
            throw new ArgumentException("Initial deck cannot be removed.", nameof(saved));
        var reached = new HashSet<(int X, int Y)>(world.deck);
        while (true)
        {
            var additions = restoredDeck.Where(c => !reached.Contains(c) && Adjacent(reached, c.X, c.Y)).ToList();
            if (additions.Count == 0) break;
            reached.UnionWith(additions);
        }
        if (reached.Count != restoredDeck.Count)
            throw new ArgumentException("Disconnected deck cell.", nameof(saved));
        var expandedCells = new HashSet<(int X, int Y)>();
        int oreRewards = 0;
        foreach (var receipt in saved.Requests)
        {
            if (receipt is null || !ValidReceipt(receipt)
                || !world.requests.TryAdd(receipt.RequestId, CopyReceipt(receipt)))
                throw new ArgumentException("Invalid or duplicate request receipt.", nameof(saved));
            if (receipt.Success && receipt.Operation.StartsWith("expand:", StringComparison.Ordinal))
            {
                var parts = receipt.Operation.Split(':');
                int x = int.Parse(parts[1], CultureInfo.InvariantCulture), y = int.Parse(parts[2], CultureInfo.InvariantCulture);
                if (!restoredDeck.Contains((x, y)) || world.deck.Contains((x, y)) || !expandedCells.Add((x, y)))
                    throw new ArgumentException("Expansion receipt does not match the deck.", nameof(saved));
            }
            if (receipt.Success && receipt.Operation == "collect") oreRewards++;
            if (receipt.Code == "inventory_callback_failed") world.inventoryFaulted = true;
        }
        if (restoredDeck.Count != world.deck.Count + expandedCells.Count || oreRewards > 1 || saved.OreDepleted != (oreRewards == 1))
            throw new ArgumentException("Persistent resources do not match transaction receipts.", nameof(saved));
        var reservedCells = new HashSet<(int X, int Y)>();
        bool oreReserved = false;
        foreach (var prepared in saved.PendingInventory)
        {
            if (prepared is null || !ValidRequestId(prepared.RequestId)
                || world.requests.ContainsKey(prepared.RequestId)
                || !world.pendingInventory.TryAdd(prepared.RequestId, CopyPrepared(prepared)))
                throw new ArgumentException("Invalid or conflicting pending inventory request.", nameof(saved));
            if (prepared.Kind == "expand")
            {
                if (!InMap(prepared.X, prepared.Y) || restoredDeck.Contains((prepared.X, prepared.Y))
                    || !Adjacent(restoredDeck, prepared.X, prepared.Y) || !reservedCells.Add((prepared.X, prepared.Y)))
                    throw new ArgumentException("Invalid or conflicting expansion reservation.", nameof(saved));
            }
            else if (prepared.Kind == "collect")
            {
                if (prepared.X != 0 || prepared.Y != 0 || saved.OreDepleted || oreReserved)
                    throw new ArgumentException("Invalid or conflicting ore reservation.", nameof(saved));
                oreReserved = true;
            }
            else throw new ArgumentException("Invalid pending inventory kind.", nameof(saved));
        }
        world.deck.Clear();
        world.deck.UnionWith(restoredDeck);
        world.shipX = saved.ShipX;
        world.shipY = saved.ShipY;
        world.anchored = saved.Anchored;
        world.oreDepleted = saved.OreDepleted;
        // No transient divers survive a restore. The bridge places reconnecting
        // players on the deck and calls RegisterPlayer for each active farmer.
        return world;
    }

    private ActionResult Execute(long playerId, string requestId, string operation, Func<ActionResult> action,
        bool allowWithoutReceiptAtLimit = false)
    {
        if (!isHost) return Fail("not_host");
        if (executingRequest) return Fail("request_busy");
        if (!ValidRequestId(requestId)) return Fail("request_invalid");
        if (!players.ContainsKey(playerId)) return Fail("player_missing");
        if (requests.TryGetValue(requestId, out var previous))
            return previous.PlayerId == playerId && previous.Operation == operation
                ? new ActionResult { Success = previous.Success, Duplicate = true, Code = previous.Code }
                : Fail("request_collision");
        if (pendingInventory.TryGetValue(requestId, out var prepared))
            return prepared.PlayerId == playerId && InventoryOperation(prepared.Kind, prepared.X, prepared.Y) == operation
                ? new ActionResult { Success = true, Duplicate = true, Code = "inventory_prepared" }
                : Fail("request_collision");
        // An exhausted receipt ledger must not trap a diver. Return only changes
        // that player's transient state and cannot grant or spend inventory.
        if (requests.Count + pendingInventory.Count >= MaxRequests) return allowWithoutReceiptAtLimit ? action() : Fail("request_limit");
        var receipt = new RequestReceipt
        {
            RequestId = requestId, PlayerId = playerId, Operation = operation,
            Code = "request_in_progress"
        };
        requests.Add(requestId, receipt);
        executingRequest = true;
        try
        {
            var result = action();
            receipt.Success = result.Success;
            receipt.Code = result.Code;
            if (result.Code == "inventory_prepared") requests.Remove(requestId);
            return result;
        }
        finally { executingRequest = false; }
    }

    private ActionResult? InvokeInventory(Func<bool>? callback, string rejectedCode)
    {
        if (inventoryFaulted) return Fail("inventory_fault");
        try { return callback is not null && callback() ? null : Fail(rejectedCode); }
        catch (Exception)
        {
            // A callback may already have changed native inventory. Do not guess
            // a rollback or grant it again with a fresh request ID. This fault is
            // persisted by the receipt; resume from a coherent native save.
            inventoryFaulted = true;
            return Fail("inventory_callback_failed");
        }
    }

    private void TickStep(float dt)
    {
        simulationSeconds += dt;
        foreach (var player in players.Values)
        {
            player.HarpoonCooldown = Math.Max(0, player.HarpoonCooldown - dt);
            if (!player.IsDiving) continue;
            player.Oxygen = Math.Max(0, player.Oxygen - dt);
            if (player.Oxygen <= 0) { ReturnSafely(player, "oxygen"); continue; }
            player.X = Math.Clamp(player.X + player.InputX * SwimSpeed * dt, 20, DiveWidth - 20);
            player.Y = Math.Clamp(player.Y + player.InputY * SwimSpeed * dt, 20, DiveHeight - 20);
        }
        if (threat.KnockbackSeconds > 0)
        {
            threat.KnockbackSeconds = Math.Max(0, threat.KnockbackSeconds - dt);
            return;
        }
        var target = players.Values.Where(p => p.IsDiving)
            .OrderBy(p => Distance(p.X, p.Y, threat.X, threat.Y)).ThenBy(p => p.PlayerId).FirstOrDefault();
        if (target is null) return;
        float dx = target.X - threat.X, dy = target.Y - threat.Y;
        float distance = Distance(target.X, target.Y, threat.X, threat.Y);
        if (distance > 0.001f)
        {
            float step = Math.Min(ThreatSpeed * dt, distance);
            threat.X += dx / distance * step;
            threat.Y += dy / distance * step;
        }
        foreach (var player in players.Values)
            if (player.IsDiving && Distance(player.X, player.Y, threat.X, threat.Y) <= ThreatContactRange)
                ReturnSafely(player, "threat");
    }

    private static void ReturnSafely(PlayerDiveState player, string reason)
    {
        player.IsDiving = false;
        player.OnDeck = true;
        player.X = SpawnX;
        player.Y = SpawnY;
        player.Oxygen = MaximumOxygen;
        player.InputX = player.InputY = 0;
        player.HarpoonCooldown = 0;
        player.LastReturnReason = reason;
    }

    private bool OnDeck(long id) => players[id].OnDeck && !players[id].IsDiving;
    private bool CrewAway() => players.Values.Any(p => !p.OnDeck || p.IsDiving);
    private ActionResult? ExpansionEligibility(long playerId, int x, int y)
    {
        if (!OnDeck(playerId)) return Fail("not_on_deck");
        if (!InMap(x, y)) return Fail("outside_map");
        if (deck.Contains((x, y))) return Fail("cell_exists");
        if (!Adjacent(deck, x, y)) return Fail("not_adjacent");
        if (pendingInventory.Values.Any(p => p.Kind == "expand" && p.X == x && p.Y == y)) return Fail("cell_reserved");
        return null;
    }
    private ActionResult? CollectionEligibility(long playerId)
    {
        var player = players[playerId];
        if (!player.IsDiving) return Fail("not_diving");
        if (oreDepleted) return Fail("ore_depleted");
        if (Distance(player.X, player.Y, OreX, OreY) > OreReach) return Fail("too_far");
        if (pendingInventory.Values.Any(p => p.Kind == "collect")) return Fail("ore_reserved");
        return null;
    }
    private static string InventoryOperation(string kind, int x, int y) => kind == "expand"
        ? "expand:" + x.ToString(CultureInfo.InvariantCulture) + ":" + y.ToString(CultureInfo.InvariantCulture) : "collect";
    private static bool ValidReceipt(RequestReceipt receipt)
    {
        if (!ValidRequestId(receipt.RequestId) || string.IsNullOrEmpty(receipt.Operation) || receipt.Operation.Length > 160
            || string.IsNullOrEmpty(receipt.Code) || receipt.Code.Length > 64) return false;
        var parts = receipt.Operation.Split(':');
        string kind = parts[0];
        if (kind == "expand")
        {
            if (parts.Length != 3 || !int.TryParse(parts[1], NumberStyles.Integer, CultureInfo.InvariantCulture, out int x)
                || !int.TryParse(parts[2], NumberStyles.Integer, CultureInfo.InvariantCulture, out int y)) return false;
            if (receipt.Success && !InMap(x, y)) return false;
        }
        else if (kind == "harpoon")
        {
            if (parts.Length != 3 || !float.TryParse(parts[1], NumberStyles.Float, CultureInfo.InvariantCulture, out float dx)
                || !float.TryParse(parts[2], NumberStyles.Float, CultureInfo.InvariantCulture, out float dy)) return false;
            if (receipt.Success && (!Finite(dx) || !Finite(dy) || dx == 0 && dy == 0)) return false;
        }
        else if (parts.Length != 1) return false;
        string[] allowed = kind switch
        {
            "expand" => receipt.Success ? new[] { "expanded" } : new[] { "not_on_deck", "outside_map", "cell_exists", "not_adjacent", "cell_reserved", "wood_unavailable", "inventory_fault", "inventory_callback_failed" },
            "collect" => receipt.Success ? new[] { "ore_collected" } : new[] { "not_diving", "ore_depleted", "too_far", "ore_reserved", "reward_rejected", "inventory_fault", "inventory_callback_failed" },
            "dive" => receipt.Success ? new[] { "diving" } : new[] { "not_on_deck", "anchor_required" },
            "return" => receipt.Success ? new[] { "returned" } : new[] { "not_diving" },
            "anchor" => receipt.Success ? new[] { "anchored", "unanchored" } : new[] { "not_on_deck", "crew_away" },
            "harpoon" => receipt.Success ? new[] { "threat_repulsed", "harpoon_miss" } : new[] { "not_diving", "cooldown", "invalid_direction" },
            _ => Array.Empty<string>()
        };
        return allowed.Contains(receipt.Code);
    }
    private static bool InMap(int x, int y) => x >= 0 && y >= 0 && x < MapWidth && y < MapHeight;
    private static bool Adjacent(HashSet<(int X, int Y)> cells, int x, int y)
        => cells.Contains((x - 1, y)) || cells.Contains((x + 1, y)) || cells.Contains((x, y - 1)) || cells.Contains((x, y + 1));
    private static bool ValidRequestId(string id) => !string.IsNullOrWhiteSpace(id) && id.Length <= 96;
    private static bool Finite(float value) => !float.IsNaN(value) && !float.IsInfinity(value);
    private static float Distance(float ax, float ay, float bx, float by)
        => (float)Math.Sqrt((double)(ax - bx) * (ax - bx) + (double)(ay - by) * (ay - by));
    private static bool Direction(ref float x, ref float y)
    {
        if (!Finite(x) || !Finite(y) || x == 0 && y == 0) return false;
        double length = Math.Sqrt((double)x * x + (double)y * y);
        x = (float)(x / length); y = (float)(y / length);
        return true;
    }
    private static void Normalize(ref float x, ref float y)
    {
        if ((double)x * x + (double)y * y > 1) Direction(ref x, ref y);
    }
    private static ActionResult Ok(string code) => new() { Success = true, Code = code };
    private static ActionResult Fail(string code) => new() { Code = code };
    private List<DeckCell> CopyDeck() => deck.OrderBy(c => c.Y).ThenBy(c => c.X)
        .Select(c => new DeckCell { X = c.X, Y = c.Y }).ToList();
    private static RequestReceipt CopyReceipt(RequestReceipt r) => new()
    {
        RequestId = r.RequestId, PlayerId = r.PlayerId, Operation = r.Operation, Success = r.Success, Code = r.Code
    };
    private static PreparedInventory CopyPrepared(PreparedInventory p) => new()
    {
        RequestId = p.RequestId, PlayerId = p.PlayerId, Kind = p.Kind, X = p.X, Y = p.Y
    };
    private static PlayerDiveState CopyPlayer(PlayerDiveState p) => new()
    {
        PlayerId = p.PlayerId, IsDiving = p.IsDiving, OnDeck = p.OnDeck, X = p.X, Y = p.Y,
        Oxygen = p.Oxygen, InputX = p.InputX, InputY = p.InputY,
        HarpoonCooldown = p.HarpoonCooldown, LastReturnReason = p.LastReturnReason
    };
}
