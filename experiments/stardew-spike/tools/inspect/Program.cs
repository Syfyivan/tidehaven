using System.Reflection;
using System.Runtime.Loader;
using System.Text.RegularExpressions;
var root = args[0];
AssemblyLoadContext.Default.Resolving += (_, name) => {
    foreach (var directory in new[] { root, Path.Combine(root, "smapi-internal") }) {
        var file = Path.Combine(directory, name.Name + ".dll");
        if (File.Exists(file)) return AssemblyLoadContext.Default.LoadFromAssemblyPath(file);
    }
    return null;
};
var assembly = AssemblyLoadContext.Default.LoadFromAssemblyPath(Path.Combine(root, args[1]));
var type = assembly.GetType(args[2], true)!;
var pattern = args.Length > 3 ? args[3] : ".";
const BindingFlags flags = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.Static;
foreach (var member in type.GetMembers(flags).Where(m => Regex.IsMatch(m.Name, pattern, RegexOptions.IgnoreCase)))
    Console.WriteLine($"{member.MemberType} {member}");
