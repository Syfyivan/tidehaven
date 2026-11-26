using System.Reflection;
using System.Runtime.CompilerServices;
using HarmonyLib;

internal static class Program
{
    private static string Session = "";
    private static string DataRoot => Path.Combine(Session, "appdata");
    private static string LocalRoot => Path.Combine(Session, "local");
    private static string[] Forward = Array.Empty<string>();
    public static int Main(string[] args)
    {
        try
        {
            var index = Array.IndexOf(args, "--session-root");
            if (index < 0 || index + 1 >= args.Length) throw new ArgumentException("--session-root is required; personal data paths are never allowed.");
            Session = Path.GetFullPath(args[index + 1]);
            var allowed = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "sessions")) + Path.DirectorySeparatorChar;
            if (!Session.StartsWith(allowed, StringComparison.OrdinalIgnoreCase)) throw new ArgumentException("Session must be a child of artifacts/stardew-spike/sessions.");
            Forward = args.Where((_, i) => i != index && i != index + 1).ToArray();
            Environment.SetEnvironmentVariable("TIDEHAVEN_SPIKE_SESSION", Session);
            Directory.CreateDirectory(Session);
            AppDomain.CurrentDomain.AssemblyResolve += (_, e) =>
            {
                var name = new AssemblyName(e.Name).Name + ".dll";
                foreach (var dir in new[] { AppContext.BaseDirectory, Path.Combine(AppContext.BaseDirectory, "smapi-internal") })
                {
                    var file = Path.Combine(dir, name);
                    if (File.Exists(file)) return Assembly.LoadFrom(file);
                }
                return null;
            };
            Start();
            return 0;
        }
        catch (Exception ex) { Console.Error.WriteLine("ISOLATED START FAILED: " + ex); return 1; }
    }

    [MethodImpl(MethodImplOptions.NoInlining)]
    private static void Start()
    {
        var game = Assembly.LoadFrom(Path.Combine(AppContext.BaseDirectory, "Stardew Valley.dll"));
        var smapi = Assembly.LoadFrom(Path.Combine(AppContext.BaseDirectory, "StardewModdingAPI.dll"));
        var gameProgram = game.GetType("StardewValley.Program", true)!;
        var constants = smapi.GetType("StardewModdingAPI.Constants", true)!;
        var harmony = new Harmony("Syfyivan.TidehavenSpike.IsolatedPaths");
        void Prefix(MethodInfo? original, string replacement)
        {
            if (original == null) throw new MissingMethodException(replacement);
            harmony.Patch(original, prefix: new HarmonyMethod(typeof(Program).GetMethod(replacement, BindingFlags.Static | BindingFlags.NonPublic)!));
        }
        const BindingFlags flags = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static;
        Prefix(gameProgram.GetMethod("GetAppDataFolder", flags, null, new[] { typeof(string), typeof(bool) }, null), nameof(AppData));
        Prefix(gameProgram.GetMethod("GetLocalAppDataFolder", flags, null, new[] { typeof(string), typeof(bool) }, null), nameof(LocalData));
        Prefix(gameProgram.GetMethod("GetSavesFolder", flags), nameof(Saves));
        Prefix(constants.GetProperty("DataPath", flags)?.GetMethod, nameof(SmapiData));
        Prefix(constants.GetProperty("LogDir", flags)?.GetMethod, nameof(Logs));
        Prefix(constants.GetProperty("SavesPath", flags)?.GetMethod, nameof(Saves));
        foreach (var name in new[] { "DataPath", "LogDir", "SavesPath" })
        {
            var value = (string)constants.GetProperty(name, flags)!.GetValue(null)!;
            AssertInside(value);
        }
        var actual = (string)gameProgram.GetMethod("GetSavesFolder", flags)!.Invoke(null, null)!;
        AssertInside(actual);
        File.WriteAllText(Path.Combine(Session, "isolation.txt"), "All game and SMAPI path guards active.\nSaves=" + actual);
        Console.WriteLine("ISOLATION_OK " + Session);
        smapi.GetType("StardewModdingAPI.Program", true)!.GetMethod("Main", flags)!.Invoke(null, new object[] { Forward });
    }
    private static void AssertInside(string path)
    {
        var value = Path.GetFullPath(path);
        if (!value.StartsWith(Session + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase)) throw new InvalidOperationException("Path guard rejected a non-session path.");
    }
    private static string Folder(string root, string? subfolder, bool create)
    {
        var result = Path.GetFullPath(Path.Combine(root, subfolder ?? ""));
        AssertInside(result);
        if (create) Directory.CreateDirectory(result);
        return result;
    }
    private static bool AppData(string __0, bool __1, ref string __result) { __result = Folder(DataRoot, __0, __1); return false; }
    private static bool LocalData(string __0, bool __1, ref string __result) { __result = Folder(LocalRoot, __0, __1); return false; }
    private static bool Saves(ref string __result) { __result = Folder(DataRoot, "Saves", true); return false; }
    private static bool SmapiData(ref string __result) { __result = Folder(DataRoot, "", true); return false; }
    private static bool Logs(ref string __result) { __result = Folder(DataRoot, "ErrorLogs", true); return false; }
}
