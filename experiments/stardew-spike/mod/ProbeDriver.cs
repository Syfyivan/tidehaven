using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text.Json;
using HarmonyLib;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using StardewModdingAPI;
using StardewValley;
using StardewValley.Menus;
using StardewValley.Network;
using StardewValley.Objects;

namespace TidehavenSpike;

/// <summary>Opt-in, isolated test controls. These are scripted native actions, not human playtesting.</summary>
internal sealed class ProbeDriver
{
    private static readonly JsonSerializerOptions Json = new() { PropertyNameCaseInsensitive = true, WriteIndented = true };
    private static ProbeDriver? captureOwner;
    private static bool controlledChestRightClick;
    private readonly ModEntry mod;
    private readonly IModHelper helper;
    private readonly IMonitor monitor;
    private readonly string? session;
    private readonly ProbeConfig config = new();
    private long ticks;
    // Reusing an isolated session must not replay a previous process's final command (especially quit).
    private long lastCommandId = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
    private string stage = "disabled";
    private string? error;
    private string? commandResult;
    private string? screenshotPath;
    private string? pendingScreenshot;
    private int saveCount;
    private bool saving;
    private bool startupSent;
    private bool startupComplete;
    private bool slotActivated;

    public ProbeDriver(ModEntry mod, IModHelper helper, IMonitor monitor)
    {
        this.mod = mod;
        this.helper = helper;
        this.monitor = monitor;
        string? requested = Environment.GetEnvironmentVariable("TIDEHAVEN_SPIKE_SESSION");
        if (string.IsNullOrWhiteSpace(requested))
            return;

        try
        {
            string root = Path.GetFullPath(requested).TrimEnd(Path.DirectorySeparatorChar);
            string marker = Path.Combine("artifacts", "stardew-spike", "sessions") + Path.DirectorySeparatorChar;
            if (!root.Contains(Path.DirectorySeparatorChar + marker, StringComparison.OrdinalIgnoreCase) || !Directory.Exists(root))
                throw new InvalidOperationException("Probe session must already exist under artifacts/stardew-spike/sessions/.");

            // Only inspect path getters with directory creation explicitly disabled. Fail closed before save menus.
            foreach (string path in new[] { Constants.DataPath, Constants.LogDir, Constants.SavesPath,
                         StardewValley.Program.GetAppDataFolder(null, false), StardewValley.Program.GetLocalAppDataFolder(null, false) })
            {
                if (!Within(root, path))
                    throw new InvalidOperationException("The bootstrap did not redirect every game/SMAPI data path into this session.");
            }

            session = root;
            string configPath = Path.Combine(root, "probe.json");
            if (File.Exists(configPath))
                config = JsonSerializer.Deserialize<ProbeConfig>(File.ReadAllText(configPath), Json) ?? new ProbeConfig();
            config.Role = config.Role.ToLowerInvariant();
            if (config.Role is not ("" or "create" or "load" or "join"))
                throw new InvalidOperationException("Probe role must be create, load or join.");
            if (config.Role == "load" && (string.IsNullOrWhiteSpace(config.SaveFolder)
                || Path.GetFileName(config.SaveFolder) != config.SaveFolder || config.SaveFolder is "." or ".."))
                throw new InvalidOperationException("saveFolder must be one isolated save directory name.");

            helper.Events.GameLoop.Saving += (_, _) => saving = true;
            helper.Events.GameLoop.Saved += (_, _) => { saving = false; saveCount++; };
            captureOwner = this;
            var harmony = new Harmony("TidehavenSpike.IsolatedProbeCapture");
            harmony.Patch(
                AccessTools.Method(typeof(GameRunner), "Draw", new[] { typeof(GameTime) }),
                postfix: new HarmonyMethod(typeof(ProbeDriver), nameof(AfterGameDraw)));
            harmony.Patch(
                AccessTools.Method(typeof(Game1), "didPlayerJustRightClick", new[] { typeof(bool) }),
                prefix: new HarmonyMethod(typeof(ProbeDriver), nameof(BeforeDidPlayerJustRightClick)));
            stage = "waiting-title";
            monitor.Log("Controlled probe enabled with isolated native menus and save flow.", LogLevel.Info);
            WriteState();
        }
        catch (Exception ex)
        {
            stage = "blocked";
            error = ex.Message;
            monitor.Log($"Probe blocked: {ex.Message}", LogLevel.Error);
        }
    }

    public void Update()
    {
        if (session is null || stage == "blocked")
            return;
        if (config.Role.Length > 0 && Game1.options is { } options)
            options.pauseWhenOutOfFocus = false;
        ticks++;
        if (ticks % 10 != 0)
            return;
        try
        {
            AdvanceStartup();
            ReadCommand();
        }
        catch (Exception ex)
        {
            error = ex.GetBaseException().Message;
            commandResult = "error";
            monitor.Log($"Controlled probe action failed: {error}", LogLevel.Error);
        }
        WriteState();
    }

    private void AdvanceStartup()
    {
        if (startupComplete || config.Role.Length == 0)
            return;
        IClickableMenu? menu = Game1.activeClickableMenu is TitleMenu ? TitleMenu.subMenu : Game1.activeClickableMenu;

        if (menu is CharacterCustomization customization && startupSent)
        {
            FillCharacter(customization, config.Role == "create");
            stage = "creating-character";
            return;
        }
        if (Context.IsWorldReady)
        {
            startupComplete = true;
            stage = "ready";
            return;
        }
        if (!startupSent)
        {
            if (Game1.activeClickableMenu is not TitleMenu || TitleMenu.subMenu is not null)
                return;
            switch (config.Role)
            {
                case "create":
                    Game1.resetPlayer();
                    var creation = new CharacterCustomization(CharacterCustomization.Source.HostNewFarm, true);
                    Game1.startingCabins = 1;
                    TitleMenu.subMenu = creation;
                    break;
                case "load":
                    if (!Directory.Exists(Path.Combine(Constants.SavesPath, config.SaveFolder!)))
                        throw new InvalidOperationException("Requested isolated save directory does not exist.");
                    // Native filter matches farmer/farm display names and leaves null entries for misses.
                    // Scan only our already-isolated Saves directory, then select the exact slotName below.
                    TitleMenu.subMenu = new CoopMenu(tooManyFarms: false, splitScreen: false,
                        initialTab: CoopMenu.Tab.HOST_TAB, filter: null);
                    break;
                case "join":
                    Multiplayer multiplayer = helper.Reflection.GetField<Multiplayer>(typeof(Game1), "multiplayer").GetValue();
                    TitleMenu.subMenu = new FarmhandMenu(multiplayer.InitClient(new LidgrenClient(config.Address)));
                    break;
            }
            startupSent = true;
            stage = config.Role == "join" ? "connecting" : "opening-native-menu";
            return;
        }
        if (slotActivated || menu is not LoadGameMenu loadMenu)
            return;
        foreach (var slot in loadMenu.MenuSlots)
        {
            // The native host slot sets multiplayerMode before delegating to SaveFileSlot.Activate.
            if (config.Role == "load" && (loadMenu is not CoopMenu || slot.GetType().Name != "HostFileSlot"))
                continue;
            Farmer? farmer = FindField(slot.GetType(), "Farmer")?.GetValue(slot) as Farmer;
            if (farmer is null || (config.Role == "load" && farmer.slotName != config.SaveFolder))
                continue;
            MethodInfo? belongsToOther = slot.GetType().GetMethod("BelongsToAnotherPlayer");
            if (config.Role == "join" && belongsToOther?.Invoke(slot, null) is true)
                continue;
            slot.Activate();
            slotActivated = true;
            stage = config.Role == "join" ? "joining-farmhand" : "loading-host-save";
            break;
        }
    }

    private void FillCharacter(CharacterCustomization menu, bool host)
    {
        helper.Reflection.GetField<TextBox>(menu, "nameBox").GetValue().Text = config.Name;
        helper.Reflection.GetField<TextBox>(menu, "favThingBox").GetValue().Text = "Sea";
        Game1.player.Name = config.Name;
        Game1.player.favoriteThing.Value = "Sea";
        if (host)
        {
            helper.Reflection.GetField<TextBox>(menu, "farmnameBox").GetValue().Text = config.Farm;
            helper.Reflection.GetField<bool>(menu, "skipIntro").SetValue(true);
            Game1.player.farmName.Value = config.Farm;
        }
        helper.Reflection.GetMethod(menu, "optionButtonClick").Invoke("OK");
    }

    private void ReadCommand()
    {
        string path = Path.Combine(session!, "command.json");
        if (!File.Exists(path))
            return;
        ProbeCommand? command;
        try { command = JsonSerializer.Deserialize<ProbeCommand>(File.ReadAllText(path), Json); }
        catch (IOException) { return; }
        catch (JsonException) { return; } // The controller may be replacing its command file.
        if (command is null || command.Id <= lastCommandId)
            return;
        lastCommandId = command.Id;
        error = null;
        commandResult = "accepted";
        monitor.Log($"Controlled probe command {command.Id}: {command.Kind}", LogLevel.Info);
        if (command.Kind is "quit" or "screenshot")
        {
            if (command.Kind == "screenshot")
            {
                pendingScreenshot = Path.Combine(session!, $"screen-{command.Id}.png");
                commandResult = "awaiting-render";
            }
            else
            {
                if (saving || Game1.activeClickableMenu is SaveGameMenu)
                    throw new InvalidOperationException("Refusing to quit during native saving; wait for Saved and the next day.");
                mod.SetProbeInput(0, 0, 0, 0);
                stage = "quitting";
                WriteState();
                Game1.ExitToTitle(() => Game1.quit = true);
            }
            return;
        }
        if (!Context.IsWorldReady)
            throw new InvalidOperationException("Command requires a fully loaded player and world.");
        switch (command.Kind)
        {
            case "input": mod.SetProbeInput(command.X, command.Y, command.SailX, command.SailY); break;
            case "stop": mod.SetProbeInput(0, 0, 0, 0); break;
            case "warpDeck": mod.Board(); break;
            case "warpFarm": mod.Leave(); break;
            case "walkTo":
                Game1.player.controller = new StardewValley.Pathfinding.PathFindController(Game1.player, Game1.currentLocation, new Point((int)command.X, (int)command.Y), 2);
                commandResult = "native-path-requested";
                break;
            case "closeMenu": Game1.exitActiveMenu(); break;
            case "sleep":
                if (Game1.activeClickableMenu is not null)
                    throw new InvalidOperationException("Close the active menu before requesting native sleep.");
                mod.SetProbeInput(0, 0, 0, 0);
                Game1.saveOnNewDay = true;
                Game1.player.isInBed.Value = true;
                Game1.player.sleptInTemporaryBed.Value = true;
                Game1.currentLocation.answerDialogueAction("Sleep_Yes", null);
                commandResult = "native-sleep-requested";
                break;
            case "placeChest":
                StardewValley.Object? heldChest = Game1.player.Items.OfType<StardewValley.Object>()
                    .FirstOrDefault(item => item.QualifiedItemId == "(BC)130");
                if (heldChest is null)
                    throw new InvalidOperationException("No native chest is available in the player's inventory.");
                int previousSlot = Game1.player.CurrentToolIndex;
                bool placed;
                try
                {
                    // tryToPlaceItem consumes the selected inventory item, just like normal placement.
                    Game1.player.CurrentToolIndex = Game1.player.Items.IndexOf(heldChest);
                    placed = Utility.tryToPlaceItem(Game1.currentLocation, heldChest, (int)command.X * 64, (int)command.Y * 64);
                }
                finally { Game1.player.CurrentToolIndex = previousSlot; }
                if (!placed)
                    throw new InvalidOperationException("Native chest placement failed (inventory, range, collision or occupied tile).");
                break;
            case "openChest":
                if (!Game1.currentLocation.objects.TryGetValue(new Vector2((int)command.X, (int)command.Y), out var obj)
                    || obj is not Chest chest)
                    throw new InvalidOperationException("No native chest exists at the requested tile.");
                bool openRequested;
                // Scripted input edge only: retain native mutex acquisition, lid animation and menu opening.
                controlledChestRightClick = true;
                try { openRequested = chest.checkForAction(Game1.player, false); }
                finally { controlledChestRightClick = false; }
                if (!openRequested)
                    throw new InvalidOperationException("Native chest interaction failed.");
                commandResult = "controlled-right-click-requested";
                monitor.Log("Controlled right-click edge requested native chest opening; no physical mouse input was used.", LogLevel.Info);
                break;
            case "depositOre": DepositOre(); break;
            default:
                mod.Request(command.Kind, command.X, command.Y, $"probe-{Game1.player.UniqueMultiplayerID}-{command.Id}");
                commandResult = "mod-request-submitted";
                break;
        }
    }

    private static void DepositOre()
    {
        if (Game1.activeClickableMenu is not ItemGrabMenu menu)
            throw new InvalidOperationException("Wait for the native chest inventory menu before depositing.");
        int index = -1;
        for (int i = 0; i < Game1.player.Items.Count; i++)
            if (Game1.player.Items[i]?.QualifiedItemId is "(O)378" or "(O)380" or "(O)384" or "(O)386") { index = i; break; }
        if (index < 0 || index >= menu.inventory.inventory.Count)
            throw new InvalidOperationException("No ore stack is visible in the player's native inventory.");
        Point center = menu.inventory.inventory[index].bounds.Center;
        menu.receiveLeftClick(center.X, center.Y);
    }

    private static void AfterGameDraw() => captureOwner?.CapturePendingFrame();

    private static bool BeforeDidPlayerJustRightClick(ref bool __result)
    {
        if (!controlledChestRightClick)
            return true;
        controlledChestRightClick = false;
        __result = true;
        return false;
    }

    private void CapturePendingFrame()
    {
        if (pendingScreenshot is null)
            return;
        string output = pendingScreenshot;
        pendingScreenshot = null;
        try
        {
            GraphicsDevice device = Game1.graphics.GraphicsDevice;
            int width = device.PresentationParameters.BackBufferWidth;
            int height = device.PresentationParameters.BackBufferHeight;
            Color[] pixels = new Color[width * height];
            device.GetBackBufferData(pixels);
            using var texture = new Texture2D(device, width, height);
            texture.SetData(pixels);
            using (var stream = File.Create(output)) texture.SaveAsPng(stream, width, height);
            screenshotPath = output;
            commandResult = "captured-rendered-backbuffer";
        }
        catch (Exception ex) { error = ex.Message; commandResult = "screenshot-error"; }
        WriteState();
    }

    private void WriteState()
    {
        if (session is null)
            return;
        try
        {
            bool ready = Context.IsWorldReady;
            var map = ready ? Game1.currentLocation.Map : null;
            var backLayer = map?.GetLayer("Back");
            var state = new
            {
                Utc = DateTime.UtcNow, Role = config.Role, Stage = stage, WorldReady = ready,
                IsMainPlayer = Context.IsMainPlayer, LastCommandId = lastCommandId,
                CommandResult = commandResult, Error = error, Saving = saving, SaveCount = saveCount,
                Screenshot = screenshotPath, SaveFolder = ready ? Constants.SaveFolderName : null,
                Menu = Game1.activeClickableMenu?.GetType().Name,
                SubMenu = Game1.activeClickableMenu is TitleMenu ? TitleMenu.subMenu?.GetType().Name : null,
                Day = ready ? Game1.dayOfMonth : 0, Time = ready ? Game1.timeOfDay : 0,
                Viewport = new { Game1.viewport.X, Game1.viewport.Y, Game1.viewport.Width, Game1.viewport.Height },
                Map = map is null ? null : new
                {
                    map.DisplayWidth, map.DisplayHeight,
                    Back = backLayer is null ? null : new
                    {
                        backLayer.LayerWidth, backLayer.LayerHeight,
                        TileWidth = backLayer.TileSize.Width, TileHeight = backLayer.TileSize.Height
                    }
                },
                Player = ready ? new { Game1.player.Name, Id = Game1.player.UniqueMultiplayerID,
                    Location = Game1.currentLocation.NameOrUniqueName, X = Game1.player.Position.X, Y = Game1.player.Position.Y } : null,
                Farmers = ready ? Game1.getOnlineFarmers().Select(f => new { f.Name, Id = f.UniqueMultiplayerID,
                    Location = f.currentLocation?.NameOrUniqueName }).ToArray() : null,
                Inventory = ready ? Game1.player.Items.Where(i => i is not null).Select(i => new { i.QualifiedItemId, i.Stack }).ToArray() : null,
                Chests = ready ? Game1.currentLocation.objects.Pairs.Where(p => p.Value is Chest).Select(p => new
                {
                    X = p.Key.X, Y = p.Key.Y,
                    Items = ((Chest)p.Value).Items.Where(i => i is not null).Select(i => new { i.QualifiedItemId, i.Stack }).ToArray()
                }).ToArray() : null,
                Spike = ready ? mod.GetProbeState() : null
            };
            string target = Path.Combine(session, "state.json");
            string temp = target + ".tmp";
            File.WriteAllText(temp, JsonSerializer.Serialize(state, Json));
            File.Move(temp, target, true);
        }
        catch (Exception ex) { monitor.Log($"Probe state write failed: {ex.Message}", LogLevel.Warn); }
    }

    private static bool Within(string root, string path) => Path.GetFullPath(path).StartsWith(root + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase)
        || string.Equals(Path.GetFullPath(path), root, StringComparison.OrdinalIgnoreCase);

    private static FieldInfo? FindField(Type type, string name)
    {
        for (Type? current = type; current is not null; current = current.BaseType)
        {
            FieldInfo? field = current.GetField(name, BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.DeclaredOnly);
            if (field is not null) return field;
        }
        return null;
    }

    private sealed class ProbeConfig
    {
        public string Role { get; set; } = "";
        public string Name { get; set; } = "TideProbe";
        public string Farm { get; set; } = "TideProbe";
        public string? SaveFolder { get; set; }
        public string Address { get; set; } = "127.0.0.1";
    }

    private sealed class ProbeCommand
    {
        public long Id { get; set; }
        public string Kind { get; set; } = "";
        public float X { get; set; }
        public float Y { get; set; }
        public float SailX { get; set; }
        public float SailY { get; set; }
    }
}
