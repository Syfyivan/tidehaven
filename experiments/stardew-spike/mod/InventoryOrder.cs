using TidehavenSpike.Core;

namespace TidehavenSpike;

public sealed class InventoryOrder
{
    public string Id { get; set; } = "";
    public long PlayerId { get; set; }
    public string Kind { get; set; } = "";
    public int X { get; set; }
    public int Y { get; set; }
    public bool? Outcome { get; set; }
}
public sealed class InventoryAck
{
    public string Id { get; set; } = "";
    public string Kind { get; set; } = "";
    public bool Success { get; set; }
}
public sealed class BridgeSave
{
    public WorldPersistent World { get; set; } = new();
    public List<InventoryOrder> Orders { get; set; } = new();
}
