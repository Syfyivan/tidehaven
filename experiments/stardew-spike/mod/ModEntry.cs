using System.Text.Json;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using StardewModdingAPI;
using StardewModdingAPI.Events;
using StardewValley;
using StardewValley.GameData.Locations;
using TidehavenSpike.Core;
using xTile;
using xTile.Layers;
using xTile.Tiles;

namespace TidehavenSpike;

public sealed class ModEntry : Mod
{
    public const string DeckLocationName = "Tidehaven_Deck";
    public const string DiveLocationName = "Tidehaven_Dive";
    private const string TextureAsset = "Mods/Syfyivan.TidehavenSpike/Tiles";
    private SmallWorld world = new();
    private WorldSnapshot snapshot = new();
    private readonly Dictionary<long, Motion> inputs = new();
    private readonly HashSet<long> knownPlayers = new();
    private readonly Dictionary<string, InventoryOrder> inventoryOrders = new(StringComparer.Ordinal);
    private ActionResult lastResult = new() { Code = "ready" };
    private ProbeDriver? probe;
    private Motion? probeInput;
    private Texture2D? pixel;
    private Texture2D? diver;
    private bool appliedDive;
    private bool leaveRequested;
    private int deckCount = -1;
    private float inputClock;
    private float inventoryClock;
    private double clock;
    private bool saving;
    private string? fault;

    public override void Entry(IModHelper helper)
    {
        // This is deliberately unusable in a personal save until its experiment is reviewed.
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("TIDEHAVEN_SPIKE_SESSION")))
        {
            Monitor.Log("Use the isolated launcher. No changes have been enabled in this game.", LogLevel.Error);
            return;
        }
        helper.Events.Content.AssetRequested += AssetRequested;
        helper.Events.GameLoop.SaveLoaded += (_, _) => Loaded();
        helper.Events.GameLoop.Saving += (_, _) => Save();
        helper.Events.GameLoop.Saved += (_, _) => saving = false;
        helper.Events.GameLoop.DayEnding += (_, _) =>
        {
            if (Context.IsMainPlayer)
                foreach (var player in world.Snapshot().Players.Where(p => p.IsDiving))
                    world.TryReturn(player.PlayerId, "day-end-" + Guid.NewGuid().ToString("N"));
            appliedDive = false; leaveRequested = false;
            Game1.player.CanMove = true;
        };
        helper.Events.GameLoop.DayStarted += (_, _) =>
        {
            if (Game1.currentLocation?.Name == DiveLocationName) Game1.warpFarmer(DeckLocationName, 10, 10, false);
        };
        helper.Events.GameLoop.ReturnedToTitle += (_, _) => Reset();
        helper.Events.GameLoop.UpdateTicked += Update;
        helper.Events.Input.ButtonPressed += Press;
        helper.Events.Display.RenderedHud += Draw;
        helper.Events.Display.RenderedWorld += DrawOcean;
        helper.Events.Multiplayer.ModMessageReceived += Message;
        helper.Events.Multiplayer.PeerDisconnected += (_, e) => { world.RemovePlayer(e.Peer.PlayerID); knownPlayers.Remove(e.Peer.PlayerID); inputs.Remove(e.Peer.PlayerID); };
        probe = new ProbeDriver(this, helper, Monitor);
    }

    private void Reset()
    {
        world = new(); snapshot = world.Snapshot(); inputs.Clear(); knownPlayers.Clear(); inventoryOrders.Clear();
        appliedDive = false; leaveRequested = false; deckCount = -1; saving = false; fault = null; probeInput = null;
    }
    private void Loaded()
    {
        Reset();
        if (Context.IsMainPlayer)
        {
            try
            {
                string? bridgeText = Helper.Data.ReadSaveData<string>("bridge");
                if (bridgeText != null)
                {
                    var bridge = JsonSerializer.Deserialize<BridgeSave>(bridgeText) ?? throw new InvalidDataException("Missing bridge save.");
                    world = SmallWorld.Restore(bridge.World);
                    if (bridge.Orders.Count > SmallWorld.MaxRequests) throw new InvalidDataException("Too many inventory orders.");
                    foreach (var order in bridge.Orders)
                    {
                        if (string.IsNullOrWhiteSpace(order.Id) || order.Id.Length > 96 || order.Kind is not ("expand" or "collect") || !inventoryOrders.TryAdd(order.Id, order))
                            throw new InvalidDataException("Invalid inventory order.");
                        var pending = bridge.World.PendingInventory.FirstOrDefault(p => p.RequestId == order.Id);
                        var receipt = bridge.World.Requests.FirstOrDefault(p => p.RequestId == order.Id);
                        if (order.Outcome == null && (pending == null || pending.PlayerId != order.PlayerId || pending.Kind != order.Kind || pending.X != order.X || pending.Y != order.Y))
                            throw new InvalidDataException("Unmatched pending inventory order.");
                        string operation = order.Kind == "expand" ? $"expand:{order.X}:{order.Y}" : "collect";
                        if (order.Outcome != null && (receipt == null || receipt.PlayerId != order.PlayerId || receipt.Success != order.Outcome || receipt.Operation != operation))
                            throw new InvalidDataException("Unmatched completed inventory order.");
                    }
                    if (bridge.World.PendingInventory.Any(p => !inventoryOrders.ContainsKey(p.RequestId))) throw new InvalidDataException("Missing inventory order.");
                }
                else
                {
                    string? saved = Helper.Data.ReadSaveData<string>("world");
                    if (saved != null) world = SmallWorld.Restore(JsonSerializer.Deserialize<WorldPersistent>(saved)!);
                }
                snapshot = world.Snapshot();
            }
            catch (Exception e) { fault = "Saved world rejected; actions disabled"; Monitor.Log(e.ToString(), LogLevel.Error); }
        }
        // Dive movement is transient. Reload always returns to a safe native deck tile.
        if (Game1.currentLocation?.Name == DiveLocationName) Game1.warpFarmer(DeckLocationName, 10, 10, false);
        Game1.player.CanMove = true;
        RebuildDeck();
    }
    private void Save()
    {
        saving = true;
        if (Context.IsMainPlayer && fault == null)
            Helper.Data.WriteSaveData("bridge", JsonSerializer.Serialize(new BridgeSave { World = world.CapturePersistent(), Orders = inventoryOrders.Values.ToList() }));
    }
    private void AssetRequested(object? sender, AssetRequestedEventArgs e)
    {
        if (e.NameWithoutLocale.IsEquivalentTo("Data/Locations"))
            e.Edit(asset =>
            {
                var data = asset.AsDictionary<string, LocationData>().Data;
                foreach (string name in new[] { DeckLocationName, DiveLocationName })
                    data[name] = new LocationData { CreateOnLoad = new CreateLocationData { MapPath = "Maps/" + name, AlwaysActive = true } };
            });
        else if (e.NameWithoutLocale.IsEquivalentTo(TextureAsset)) e.LoadFrom(CreateTiles, AssetLoadPriority.Exclusive);
        else if (e.NameWithoutLocale.IsEquivalentTo("Maps/" + DeckLocationName)) e.LoadFrom(() => CreateMap(false), AssetLoadPriority.Exclusive);
        else if (e.NameWithoutLocale.IsEquivalentTo("Maps/" + DiveLocationName)) e.LoadFrom(() => CreateMap(true), AssetLoadPriority.Exclusive);
    }
    private Texture2D CreateTiles()
    {
        var texture = new Texture2D(Game1.graphics.GraphicsDevice, 48, 16);
        var colors = new Color[48 * 16];
        for (int y = 0; y < 16; y++) for (int x = 0; x < 48; x++)
        {
            colors[y * 48 + x] = x < 16
                ? ((x + y * 3) % 17 < 2 ? new Color(37, 104, 137) : new Color(23, 78, 112))
                : x < 32 ? (y % 8 == 0 || x == 16 ? new Color(91, 54, 34) : new Color(153 + x % 3 * 5, 103, 57))
                : Color.Transparent;
        }
        texture.SetData(colors); return texture;
    }
    private Map CreateMap(bool dive)
    {
        var map = new Map();
        map.Properties["Outdoors"] = "T";
        var sheet = new TileSheet("tidehaven", map, TextureAsset, new xTile.Dimensions.Size(3, 1), new xTile.Dimensions.Size(16, 16));
        map.AddTileSheet(sheet);
        foreach (string name in new[] { "Back", "Buildings", "Front" })
            map.AddLayer(new Layer(name, map, new xTile.Dimensions.Size(SmallWorld.MapWidth, SmallWorld.MapHeight), new xTile.Dimensions.Size(64, 64)));
        PaintMap(map, dive); return map;
    }
    private void PaintMap(Map map, bool dive)
    {
        var cells = snapshot.Deck.Select(c => (c.X, c.Y)).ToHashSet();
        if (cells.Count == 0) cells = new SmallWorld().Snapshot().Deck.Select(c => (c.X, c.Y)).ToHashSet();
        var back = map.GetLayer("Back"); var walls = map.GetLayer("Buildings");
        for (int y = 0; y < SmallWorld.MapHeight; y++) for (int x = 0; x < SmallWorld.MapWidth; x++)
        {
            bool floor = dive || cells.Contains((x, y));
            back.Tiles[x, y] = new StaticTile(back, map.TileSheets[0], BlendMode.Alpha, floor && !dive ? 1 : 0);
            walls.Tiles[x, y] = floor ? null : new StaticTile(walls, map.TileSheets[0], BlendMode.Alpha, 2);
        }
    }
    private void RebuildDeck()
    {
        if (deckCount == snapshot.Deck.Count) return;
        var location = Game1.getLocationFromName(DeckLocationName);
        if (location?.Map != null) { PaintMap(location.Map, false); deckCount = snapshot.Deck.Count; }
    }

    public void Board()
    {
        if (!Context.IsWorldReady || saving || fault != null) return;
        if (appliedDive || leaveRequested) { lastResult = new ActionResult { Code = "return_from_dive_first" }; return; }
        var farmer = Game1.player;
        if (!farmer.modData.ContainsKey(ModManifest.UniqueID + "/supplies"))
        {
            var wood = ItemRegistry.Create("(O)388", 30); var chest = ItemRegistry.Create("(BC)130");
            if (farmer.MaxItems - farmer.Items.Count(i => i != null) < 2 || !farmer.couldInventoryAcceptThisItem(wood) || !farmer.couldInventoryAcceptThisItem(chest)) return;
            farmer.addItemToInventoryBool(wood); farmer.addItemToInventoryBool(chest);
            farmer.modData[ModManifest.UniqueID + "/supplies"] = "1";
        }
        Game1.warpFarmer(DeckLocationName, 10, 10, false);
    }
    public void Leave()
    {
        if (!Context.IsWorldReady || saving) return;
        if (appliedDive) { leaveRequested = true; Request("return"); return; }
        Game1.player.CanMove = true;
        Game1.warpFarmer("Farm", 64, 15, false);
    }
    public void SetProbeInput(float x, float y, float sailX, float sailY) => probeInput = x == 0 && y == 0 && sailX == 0 && sailY == 0
        ? null : new Motion { X = x, Y = y, SailX = sailX, SailY = sailY };
    public object GetProbeState() => new { World = snapshot, LastResult = lastResult, Fault = fault, Saving = saving, InventoryOrders = inventoryOrders.Values.ToArray() };
    public void Request(string kind, float x = 0, float y = 0, string? requestId = null)
    {
        if (!Context.IsWorldReady || saving || fault != null) return;
        var action = new ActionRequest { Kind = kind, X = x, Y = y, Id = requestId ?? Guid.NewGuid().ToString("N") };
        if (Context.IsMainPlayer) Act(Game1.player.UniqueMultiplayerID, action);
        else Helper.Multiplayer.SendMessage(action, "Action", new[] { ModManifest.UniqueID }, new[] { Game1.MasterPlayer.UniqueMultiplayerID });
    }
    private void Act(long id, ActionRequest request)
    {
        if (saving || fault != null || string.IsNullOrWhiteSpace(request.Id) || request.Id.Length > 128) return;
        var farmer = Game1.getOnlineFarmers().FirstOrDefault(f => f.UniqueMultiplayerID == id);
        if (farmer == null || !knownPlayers.Contains(id)) return;
        world.SetOnDeck(id, farmer.currentLocation?.Name == DeckLocationName);
        ActionResult result = request.Kind switch
        {
            "expand" when float.IsFinite(request.X) && float.IsFinite(request.Y) && request.X == MathF.Truncate(request.X) && request.Y == MathF.Truncate(request.Y)
                && Math.Abs(request.X - farmer.Tile.X) + Math.Abs(request.Y - farmer.Tile.Y) <= 4
                => world.PrepareInventory(id, request.Id, "expand", (int)request.X, (int)request.Y),
            "dive" => world.TryDive(id, request.Id),
            "return" => world.TryReturn(id, request.Id),
            "anchor" => world.TryToggleAnchor(id, request.Id),
            "collect" => world.PrepareInventory(id, request.Id, "collect"),
            "harpoon" => world.TryHarpoon(id, request.Id, request.X, request.Y),
            _ => new ActionResult { Code = "invalid_action_or_distance" }
        };
        if (result.Code == "inventory_prepared")
        {
            if (!inventoryOrders.TryGetValue(request.Id, out var order))
            {
                order = new InventoryOrder { Id = request.Id, PlayerId = id, Kind = request.Kind, X = (int)request.X, Y = (int)request.Y };
                inventoryOrders.Add(request.Id, order);
            }
            Deliver(order);
            // A local-owner transaction can finish synchronously; preserve its final result.
            if (order.Outcome != null) return;
        }
        if (id == Game1.player.UniqueMultiplayerID) lastResult = result;
        else Helper.Multiplayer.SendMessage(result, "Result", new[] { ModManifest.UniqueID }, new[] { id });
        Publish();
    }
    private static bool SpendWood(Farmer farmer)
    {
        if (farmer.Items.Where(i => i?.QualifiedItemId == "(O)388").Sum(i => i.Stack) < SmallWorld.ExpansionWoodCost) return false;
        int left = SmallWorld.ExpansionWoodCost;
        for (int i = 0; i < farmer.Items.Count && left > 0; i++)
        {
            var item = farmer.Items[i]; if (item?.QualifiedItemId != "(O)388") continue;
            int take = Math.Min(left, item.Stack); item.Stack -= take; left -= take;
            if (item.Stack == 0) farmer.Items[i] = null;
        }
        return true;
    }
    private static bool GiveOre(Farmer farmer)
    {
        var ore = ItemRegistry.Create("(O)378", SmallWorld.OreRewardCount);
        if (!farmer.couldInventoryAcceptThisItem(ore)) return false;
        return farmer.addItemToInventoryBool(ore, false);
    }
    private string ReceiptKey(string id) => ModManifest.UniqueID + "/inventory/" + id;
    private void Deliver(InventoryOrder order)
    {
        if (order.PlayerId == Game1.player.UniqueMultiplayerID) ExecuteInventory(order);
        else Helper.Multiplayer.SendMessage(order, "InventoryOrder", new[] { ModManifest.UniqueID }, new[] { order.PlayerId });
    }
    private void ExecuteInventory(InventoryOrder order)
    {
        if (fault != null || saving || Game1.activeClickableMenu is StardewValley.Menus.SaveGameMenu or StardewValley.Menus.ReadyCheckDialog || order.PlayerId != Game1.player.UniqueMultiplayerID) return;
        if (Game1.player.modData.ContainsKey(ModManifest.UniqueID + "/inventoryFault")) { fault = "Ambiguous inventory transaction; restore a coherent save"; return; }
        string key = ReceiptKey(order.Id);
        InventoryAck ack;
        if (Game1.player.modData.TryGetValue(key, out string stored))
        {
            ack = JsonSerializer.Deserialize<InventoryAck>(stored) ?? throw new InvalidDataException("Invalid local inventory receipt.");
            if (ack.Id != order.Id || ack.Kind != order.Kind) { fault = "Inventory receipt collision"; return; }
        }
        else
        {
            bool success;
            try { success = order.Kind == "expand" ? SpendWood(Game1.player) : order.Kind == "collect" && GiveOre(Game1.player); }
            catch (Exception e)
            {
                Game1.player.modData[ModManifest.UniqueID + "/inventoryFault"] = order.Id;
                fault = "Native inventory failure; do not retry automatically"; Monitor.Log(e.ToString(), LogLevel.Error); return;
            }
            ack = new InventoryAck { Id = order.Id, Kind = order.Kind, Success = success };
            // Native farmhand saves include both inventory and modData. Replayed orders never mutate twice.
            Game1.player.modData[key] = JsonSerializer.Serialize(ack);
        }
        if (Context.IsMainPlayer) AcknowledgeInventory(Game1.player.UniqueMultiplayerID, ack);
        else Helper.Multiplayer.SendMessage(ack, "InventoryAck", new[] { ModManifest.UniqueID }, new[] { Game1.MasterPlayer.UniqueMultiplayerID });
    }
    private void AcknowledgeInventory(long sender, InventoryAck ack)
    {
        if (saving || !inventoryOrders.TryGetValue(ack.Id, out var order) || order.PlayerId != sender || order.Kind != ack.Kind) return;
        if (order.Outcome != null)
        {
            if (order.Outcome != ack.Success) { fault = "Inventory reconciliation mismatch"; Monitor.Log(fault, LogLevel.Error); }
            return;
        }
        ActionResult result = world.CompleteInventory(sender, ack.Id, ack.Success);
        if (result.Code is not ("expanded" or "ore_collected" or "wood_unavailable" or "reward_rejected"))
        { fault = "Inventory completion rejected: " + result.Code; return; }
        order.Outcome = ack.Success;
        if (sender == Game1.player.UniqueMultiplayerID) lastResult = result;
        else Helper.Multiplayer.SendMessage(result, "Result", new[] { ModManifest.UniqueID }, new[] { sender });
        Publish();
    }
    private void Message(object? sender, ModMessageReceivedEventArgs e)
    {
        if (!Context.IsWorldReady || e.FromModID != ModManifest.UniqueID) return;
        if (Context.IsMainPlayer)
        {
            if (!Game1.getOnlineFarmers().Any(f => f.UniqueMultiplayerID == e.FromPlayerID)) return;
            if (e.Type == "Action") Act(e.FromPlayerID, e.ReadAs<ActionRequest>());
            else if (e.Type == "Input") StoreInput(e.FromPlayerID, e.ReadAs<Motion>());
            else if (e.Type == "InventoryAck") AcknowledgeInventory(e.FromPlayerID, e.ReadAs<InventoryAck>());
        }
        else if (e.FromPlayerID == Game1.MasterPlayer.UniqueMultiplayerID)
        {
            if (e.Type == "Snapshot") snapshot = e.ReadAs<WorldSnapshot>();
            else if (e.Type == "Result") lastResult = e.ReadAs<ActionResult>();
            else if (e.Type == "InventoryOrder") ExecuteInventory(e.ReadAs<InventoryOrder>());
        }
    }
    private void StoreInput(long id, Motion input)
    {
        if (!float.IsFinite(input.X) || !float.IsFinite(input.Y) || !float.IsFinite(input.SailX) || !float.IsFinite(input.SailY)) return;
        input.ReceivedAt = clock; inputs[id] = input;
    }
    private void Publish()
    {
        snapshot = world.Snapshot();
        if (Context.IsMultiplayer) Helper.Multiplayer.SendMessage(snapshot, "Snapshot", new[] { ModManifest.UniqueID });
    }
    private void Update(object? sender, UpdateTickedEventArgs e)
    {
        probe?.Update();
        if (!Context.IsWorldReady || saving || fault != null) return;
        float elapsed = Math.Clamp((float)Game1.currentGameTime.ElapsedGameTime.TotalSeconds, 0, 0.1f);
        clock += elapsed; inputClock += elapsed; inventoryClock += elapsed;
        if (Context.IsMainPlayer)
        {
            var online = Game1.getOnlineFarmers().ToArray();
            foreach (var f in online)
            {
                knownPlayers.Add(f.UniqueMultiplayerID); world.RegisterPlayer(f.UniqueMultiplayerID);
                world.SetOnDeck(f.UniqueMultiplayerID, f.currentLocation?.Name == DeckLocationName);
            }
            foreach (long id in knownPlayers.Where(id => !online.Any(f => f.UniqueMultiplayerID == id)).ToArray())
            { world.RemovePlayer(id); inputs.Remove(id); knownPlayers.Remove(id); }
            foreach (var f in online)
            {
                var motion = inputs.TryGetValue(f.UniqueMultiplayerID, out var value) && clock - value.ReceivedAt < 0.4 ? value : new Motion();
                world.SetDiveInput(f.UniqueMultiplayerID, motion.X, motion.Y);
            }
            // Match native menu pause in solo; multiplayer remains live while either player has a menu.
            if (Context.IsMultiplayer || Game1.activeClickableMenu == null) world.Tick(elapsed);
            if (inventoryClock >= 1)
            {
                inventoryClock = 0;
                foreach (var order in inventoryOrders.Values.ToArray())
                {
                    var owner = online.FirstOrDefault(f => f.UniqueMultiplayerID == order.PlayerId);
                    if (owner != null && (order.Outcome == null || !owner.modData.ContainsKey(ReceiptKey(order.Id)))) Deliver(order);
                }
            }
        }
        if (inputClock >= 0.1f)
        {
            inputClock = 0;
            var motion = ReadInput();
            if (Context.IsMainPlayer)
            {
                StoreInput(Game1.player.UniqueMultiplayerID, motion);
                // One helm per host tick, never one movement per network message.
                var helm = inputs.Where(p => clock - p.Value.ReceivedAt < 0.4 && (p.Value.SailX != 0 || p.Value.SailY != 0))
                    .OrderBy(p => p.Key).FirstOrDefault();
                if (helm.Value != null) world.TrySail(helm.Key, helm.Value.SailX, helm.Value.SailY);
                Publish();
            }
            else Helper.Multiplayer.SendMessage(motion, "Input", new[] { ModManifest.UniqueID }, new[] { Game1.MasterPlayer.UniqueMultiplayerID });
        }
        RebuildDeck();
        bool diving = snapshot.Players.FirstOrDefault(p => p.PlayerId == Game1.player.UniqueMultiplayerID)?.IsDiving == true;
        if (diving != appliedDive)
        {
            appliedDive = diving;
            bool toFarm = !diving && leaveRequested;
            Game1.warpFarmer(diving ? DiveLocationName : toFarm ? "Farm" : DeckLocationName, toFarm ? 64 : 10, toFarm ? 15 : 10, false);
            if (!diving) leaveRequested = false;
            Game1.player.CanMove = !diving;
        }
        if (diving) Game1.player.CanMove = false;
    }
    private Motion ReadInput()
    {
        if (Game1.activeClickableMenu != null) return new Motion();
        if (probeInput != null) return new Motion { X = probeInput.X, Y = probeInput.Y, SailX = probeInput.SailX, SailY = probeInput.SailY };
        float Axis(SButton negative, SButton positive) => (Helper.Input.IsDown(positive) ? 1 : 0) - (Helper.Input.IsDown(negative) ? 1 : 0);
        return new Motion { X = Axis(SButton.A, SButton.D), Y = Axis(SButton.W, SButton.S), SailX = Axis(SButton.Left, SButton.Right), SailY = Axis(SButton.Up, SButton.Down) };
    }
    private void Press(object? sender, ButtonPressedEventArgs e)
    {
        if (!Context.IsWorldReady || Game1.activeClickableMenu != null || saving) return;
        if (e.Button == SButton.F8) Board();
        else if (e.Button == SButton.F9) Leave();
        else if (appliedDive)
        {
            if (e.Button == SButton.E) Request("collect");
            else if (e.Button == SButton.Escape) Request("return");
            else if (e.Button == SButton.F)
            {
                var p = snapshot.Players.First(p => p.PlayerId == Game1.player.UniqueMultiplayerID);
                Request("harpoon", snapshot.Threat.X - p.X, snapshot.Threat.Y - p.Y);
            }
            Helper.Input.Suppress(e.Button);
        }
        else if (Game1.currentLocation?.Name == DeckLocationName)
        {
            if (e.Button == SButton.J) Request("dive");
            else if (e.Button == SButton.K) Request("anchor");
            else if (e.Button == SButton.R) Request("expand", Game1.currentCursorTile.X, Game1.currentCursorTile.Y);
        }
    }
    private void Draw(object? sender, RenderedHudEventArgs e)
    {
        if (!Context.IsWorldReady) return;
        if (Game1.currentLocation?.Name != DeckLocationName && !appliedDive) return;
        pixel ??= MakePixel();
        var batch = e.SpriteBatch; int width = Game1.uiViewport.Width, height = Game1.uiViewport.Height;
        if (appliedDive)
        {
            batch.Draw(pixel, new Rectangle(0, 0, width, height), new Color(9, 31, 53));
            float scale = Math.Min(width / SmallWorld.DiveWidth, (height - 110) / SmallWorld.DiveHeight);
            int left = (int)((width - SmallWorld.DiveWidth * scale) / 2), top = 85;
            Rectangle Rect(float x,float y,int w,int h) => new(left+(int)(x*scale),top+(int)(y*scale),(int)(w*scale),(int)(h*scale));
            batch.Draw(pixel, Rect(0, 0, 960, 540), new Color(14, 61, 81));
            for (int y = 0; y < 10; y++) batch.Draw(pixel, Rect(0,y*54,960,2), new Color(24,89,103));
            batch.Draw(pixel, Rect(0, 518, 960, 22), new Color(48, 63, 67));
            if (!snapshot.OreDepleted)
            {
                batch.Draw(pixel,Rect(SmallWorld.OreX-15,SmallWorld.OreY-13,30,26),new Color(193,122,67));
                Label(batch,"COPPER  [E]",left+(int)((SmallWorld.OreX-40)*scale),top+(int)((SmallWorld.OreY+23)*scale),Color.Wheat);
            }
            batch.Draw(pixel, Rect(snapshot.Threat.X-22,snapshot.Threat.Y-9,44,18),new Color(174,80,75));
            foreach (var player in snapshot.Players.Where(p=>p.IsDiving))
            {
                if (diver == null && File.Exists(Path.Combine(Helper.DirectoryPath,"assets","diver.png"))) diver=Helper.ModContent.Load<Texture2D>("assets/diver.png");
                if (diver != null)
                {
                    int fw=diver.Width/6, fh=diver.Height/2;
                    int frame=(int)(snapshot.SimulationSeconds*7)%6;
                    batch.Draw(diver,Rect(player.X-38,player.Y-38,76,76),new Rectangle(frame*fw,0,fw,fh),Color.White);
                }
                else batch.Draw(pixel,Rect(player.X-12,player.Y-8,24,16),Color.Wheat);
                Label(batch,Game1.getOnlineFarmers().FirstOrDefault(f=>f.UniqueMultiplayerID==player.PlayerId)?.Name??"Diver",left+(int)((player.X-22)*scale),top+(int)((player.Y+30)*scale),Color.White);
            }
            var local=snapshot.Players.FirstOrDefault(p=>p.PlayerId==Game1.player.UniqueMultiplayerID);
            Label(batch,$"DIVE   OXYGEN {local?.Oxygen:0}s",20,12,Color.White);
            Label(batch,"WASD swim | E collect | F harpoon | Esc return",20,38,Color.White);
            Label(batch,"Technical slice: swimming art reused; environment and threat are placeholders.",20,height-28,Color.LightGray);
        }
        else
        {
            batch.Draw(pixel,new Rectangle(12,12,Math.Min(width-24,430),124),new Color(20,30,40,220));
            Label(batch,$"TIDEHAVEN  /  {(snapshot.Anchored?"ANCHORED":"SAILING")}",24,20,Color.Wheat);
            Label(batch,$"Position {snapshot.ShipX:0}, {snapshot.ShipY:0} | 5 wood / tile",24,46,Color.White);
            Label(batch,"R expand | K anchor | J dive",24,72,Color.White);
            Label(batch,"Arrows sail | F8 board | F9 farm",24,98,Color.White);
        }
        Label(batch,fault??lastResult.Code,20,appliedDive?64:144,fault==null?Color.LightGreen:Color.Red);
    }
    private Texture2D MakePixel() { var t = new Texture2D(Game1.graphics.GraphicsDevice,1,1); t.SetData(new[]{Color.White}); return t; }
    private void DrawOcean(object? sender, RenderedWorldEventArgs e)
    {
        if (!Context.IsWorldReady || Game1.currentLocation?.Name != DeckLocationName) return;
        pixel ??= MakePixel();
        var cells = snapshot.Deck.Select(c => (c.X, c.Y)).ToHashSet();
        int driftX = ((int)(snapshot.ShipX + clock * 4) % 48 + 48) % 48;
        int driftY = ((int)snapshot.ShipY % 48 + 48) % 48;
        for (int y=0;y<SmallWorld.MapHeight;y++) for (int x=0;x<SmallWorld.MapWidth;x++)
        {
            if(cells.Contains((x,y))) continue;
            e.SpriteBatch.Draw(pixel,new Rectangle(x*64+driftX-Game1.viewport.X,y*64+driftY-Game1.viewport.Y,12,3),new Color(49,126,153));
        }
    }
    private static void Label(SpriteBatch batch,string text,int x,int y,Color color) => batch.DrawString(Game1.smallFont,text,new Vector2(x,y),color,0,Vector2.Zero,0.8f,SpriteEffects.None,0);
}

public sealed class ActionRequest { public string Id { get; set; }=""; public string Kind { get; set; }=""; public float X { get; set; } public float Y { get; set; } }
public sealed class Motion { public float X { get; set; } public float Y { get; set; } public float SailX { get; set; } public float SailY { get; set; } public double ReceivedAt { get; set; } }
