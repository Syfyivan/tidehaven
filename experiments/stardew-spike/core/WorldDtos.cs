using System.Collections.Generic;

namespace TidehavenSpike.Core;

public sealed class ActionResult
{
    public bool Success { get; set; }
    public bool Duplicate { get; set; }
    public string Code { get; set; } = "";
}

public sealed class DeckCell
{
    public int X { get; set; }
    public int Y { get; set; }
}

public sealed class PlayerDiveState
{
    public long PlayerId { get; set; }
    public bool IsDiving { get; set; }
    public bool OnDeck { get; set; }
    public float X { get; set; }
    public float Y { get; set; }
    public float Oxygen { get; set; }
    public float InputX { get; set; }
    public float InputY { get; set; }
    public float HarpoonCooldown { get; set; }
    public string LastReturnReason { get; set; } = "";
}

public sealed class ThreatState
{
    public float X { get; set; }
    public float Y { get; set; }
    public float KnockbackSeconds { get; set; }
}

public sealed class WorldSnapshot
{
    public int Version { get; set; } = 1;
    public double SimulationSeconds { get; set; }
    public float ShipX { get; set; }
    public float ShipY { get; set; }
    public bool Anchored { get; set; }
    public bool OreDepleted { get; set; }
    public bool InventoryFaulted { get; set; }
    public int PendingInventoryCount { get; set; }
    public List<DeckCell> Deck { get; set; } = new();
    public List<PlayerDiveState> Players { get; set; } = new();
    public ThreatState Threat { get; set; } = new();
}

public sealed class RequestReceipt
{
    public string RequestId { get; set; } = "";
    public long PlayerId { get; set; }
    public string Operation { get; set; } = "";
    public bool Success { get; set; }
    public string Code { get; set; } = "";
}

public sealed class PreparedInventory
{
    public string RequestId { get; set; } = "";
    public long PlayerId { get; set; }
    public string Kind { get; set; } = "";
    public int X { get; set; }
    public int Y { get; set; }
}

// No player motion or inventory is serialized here. Pending authorizations are
// retained until the authenticated owner reports its idempotent native outcome.
// Native inventory, owner receipts, and this DTO share the normal save boundary.
public sealed class WorldPersistent
{
    public int Version { get; set; } = 1;
    public float ShipX { get; set; }
    public float ShipY { get; set; }
    public bool Anchored { get; set; }
    public bool OreDepleted { get; set; }
    public List<DeckCell> Deck { get; set; } = new();
    public List<RequestReceipt> Requests { get; set; } = new();
    public List<PreparedInventory> PendingInventory { get; set; } = new();
}
