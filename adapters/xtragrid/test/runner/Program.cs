using System;
using System.CodeDom.Compiler;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;
using Microsoft.CSharp;

namespace VolvoxGrid.DotNet.ScriptRunner
{
    internal static class Program
    {
        [STAThread]
        private static int Main(string[] args)
        {
            try
            {
                Application.SetUnhandledExceptionMode(UnhandledExceptionMode.ThrowException);
                var options = RunnerOptions.Parse(args);
                var runner = new ScriptRunner(options);
                return runner.Run();
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine("ERROR: " + ex);
                return 1;
            }
        }
    }

    internal sealed class RunnerOptions
    {
        public string Engine { get; private set; }
        public string Suffix { get; private set; }
        public string GridAssemblyPath { get; private set; }
        public string ScriptsDir { get; private set; }
        public string OutDir { get; private set; }
        public string PluginPath { get; private set; }
        public string TestsFilter { get; private set; }
        public int Width { get; private set; }
        public int Height { get; private set; }
        public int SettleMs { get; private set; }
        public bool Verbose { get; private set; }

        private RunnerOptions()
        {
            Width = 1024;
            Height = 640;
            SettleMs = 350;
            Suffix = "vv";
            PluginPath = string.Empty;
            TestsFilter = string.Empty;
        }

        public static RunnerOptions Parse(string[] args)
        {
            var options = new RunnerOptions();
            for (int i = 0; i < args.Length; i++)
            {
                string arg = args[i];
                if (arg == "--engine")
                {
                    options.Engine = RequireValue(args, ref i, "--engine");
                }
                else if (arg.StartsWith("--engine=", StringComparison.Ordinal))
                {
                    options.Engine = arg.Substring("--engine=".Length);
                }
                else if (arg == "--suffix")
                {
                    options.Suffix = RequireValue(args, ref i, "--suffix");
                }
                else if (arg.StartsWith("--suffix=", StringComparison.Ordinal))
                {
                    options.Suffix = arg.Substring("--suffix=".Length);
                }
                else if (arg == "--grid-assembly")
                {
                    options.GridAssemblyPath = RequireValue(args, ref i, "--grid-assembly");
                }
                else if (arg.StartsWith("--grid-assembly=", StringComparison.Ordinal))
                {
                    options.GridAssemblyPath = arg.Substring("--grid-assembly=".Length);
                }
                else if (arg == "--scripts-dir")
                {
                    options.ScriptsDir = RequireValue(args, ref i, "--scripts-dir");
                }
                else if (arg.StartsWith("--scripts-dir=", StringComparison.Ordinal))
                {
                    options.ScriptsDir = arg.Substring("--scripts-dir=".Length);
                }
                else if (arg == "--out-dir")
                {
                    options.OutDir = RequireValue(args, ref i, "--out-dir");
                }
                else if (arg.StartsWith("--out-dir=", StringComparison.Ordinal))
                {
                    options.OutDir = arg.Substring("--out-dir=".Length);
                }
                else if (arg == "--plugin-path")
                {
                    options.PluginPath = RequireValue(args, ref i, "--plugin-path");
                }
                else if (arg.StartsWith("--plugin-path=", StringComparison.Ordinal))
                {
                    options.PluginPath = arg.Substring("--plugin-path=".Length);
                }
                else if (arg == "--tests")
                {
                    options.TestsFilter = RequireValue(args, ref i, "--tests");
                }
                else if (arg.StartsWith("--tests=", StringComparison.Ordinal))
                {
                    options.TestsFilter = arg.Substring("--tests=".Length);
                }
                else if (arg == "--width")
                {
                    options.Width = ParseInt(RequireValue(args, ref i, "--width"), "--width");
                }
                else if (arg.StartsWith("--width=", StringComparison.Ordinal))
                {
                    options.Width = ParseInt(arg.Substring("--width=".Length), "--width");
                }
                else if (arg == "--height")
                {
                    options.Height = ParseInt(RequireValue(args, ref i, "--height"), "--height");
                }
                else if (arg.StartsWith("--height=", StringComparison.Ordinal))
                {
                    options.Height = ParseInt(arg.Substring("--height=".Length), "--height");
                }
                else if (arg == "--settle-ms")
                {
                    options.SettleMs = ParseInt(RequireValue(args, ref i, "--settle-ms"), "--settle-ms");
                }
                else if (arg.StartsWith("--settle-ms=", StringComparison.Ordinal))
                {
                    options.SettleMs = ParseInt(arg.Substring("--settle-ms=".Length), "--settle-ms");
                }
                else if (arg == "--verbose")
                {
                    options.Verbose = true;
                }
                else
                {
                    throw new ArgumentException("Unknown argument: " + arg);
                }
            }

            if (string.IsNullOrEmpty(options.Engine))
            {
                throw new ArgumentException("--engine is required (vv|ref).");
            }

            if (string.IsNullOrEmpty(options.GridAssemblyPath))
            {
                throw new ArgumentException("--grid-assembly is required.");
            }

            if (string.IsNullOrEmpty(options.ScriptsDir))
            {
                throw new ArgumentException("--scripts-dir is required.");
            }

            if (string.IsNullOrEmpty(options.OutDir))
            {
                throw new ArgumentException("--out-dir is required.");
            }

            if (options.Width < 64 || options.Height < 64)
            {
                throw new ArgumentException("--width/--height must be >= 64.");
            }

            if (options.SettleMs < 0)
            {
                throw new ArgumentException("--settle-ms must be >= 0.");
            }

            return options;
        }

        private static string RequireValue(string[] args, ref int index, string name)
        {
            if (index + 1 >= args.Length)
            {
                throw new ArgumentException(name + " requires a value.");
            }

            index++;
            return args[index];
        }

        private static int ParseInt(string value, string name)
        {
            if (!int.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out int parsed))
            {
                throw new ArgumentException(name + " must be an integer.");
            }

            return parsed;
        }
    }

    internal sealed class ScriptRunner
    {
        private static readonly Regex CaseFilePattern = new Regex(@"^(?<num>\d+)[_\- ](?<name>.+)\.(csx|cs)$", RegexOptions.Compiled | RegexOptions.IgnoreCase);
        private static readonly Regex TestFilterPattern = new Regex(@"^\d+(\s*-\s*\d+)?$", RegexOptions.Compiled);
        private static readonly Regex DosPathPattern = new Regex(@"^[A-Za-z]:[\\/]", RegexOptions.Compiled);

        private readonly RunnerOptions _options;
        private readonly List<string> _assemblySearchDirs;

        public ScriptRunner(RunnerOptions options)
        {
            _options = options;
            _assemblySearchDirs = new List<string>();
        }

        public int Run()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            string gridAssemblyPath = NormalizePath(_options.GridAssemblyPath);
            string scriptsDir = NormalizePath(_options.ScriptsDir);
            string outDir = NormalizePath(_options.OutDir);
            string pluginPath = string.IsNullOrEmpty(_options.PluginPath) ? string.Empty : NormalizePath(_options.PluginPath);

            if (!File.Exists(gridAssemblyPath))
            {
                throw new FileNotFoundException("Grid assembly not found: " + gridAssemblyPath);
            }

            if (!Directory.Exists(scriptsDir))
            {
                throw new DirectoryNotFoundException("Scripts directory not found: " + scriptsDir);
            }

            Directory.CreateDirectory(outDir);

            var cases = DiscoverCases(scriptsDir, _options.TestsFilter);
            if (cases.Count == 0)
            {
                Console.WriteLine("No script cases selected.");
                return 0;
            }

            _assemblySearchDirs.Clear();
            AddAssemblySearchDir(Path.GetDirectoryName(gridAssemblyPath));

            AppDomain.CurrentDomain.AssemblyResolve += OnAssemblyResolve;

            var gridAssembly = LoadGridAssembly(gridAssemblyPath);
            if (string.Equals(_options.Engine, "ref", StringComparison.OrdinalIgnoreCase))
            {
                LoadDevExpressNeighbors(Path.GetDirectoryName(gridAssemblyPath));
            }

            var results = new List<CaseResult>();
            foreach (var testCase in cases)
            {
                string baseName = string.Format(CultureInfo.InvariantCulture, "test_{0:D2}_{1}", testCase.Number, testCase.SafeName);
                string imagePath = Path.Combine(outDir, baseName + "_" + _options.Suffix + ".png");
                string scriptCopyPath = Path.Combine(outDir, baseName + "_script.csx");
                File.Copy(testCase.Path, scriptCopyPath, true);

                try
                {
                    if (_options.Verbose)
                    {
                        Console.WriteLine("[{0:00}] compiling {1}", testCase.Number, testCase.FileName);
                    }

                    var method = CompileCaseMethod(testCase);
                    RunSingleCase(testCase, method, gridAssembly, pluginPath, imagePath);

                    Console.WriteLine("[{0:00}] {1} / OK", testCase.Number, testCase.Name);
                    results.Add(CaseResult.FromSuccess(testCase, imagePath));
                }
                catch (Exception ex)
                {
                    string message = FlattenException(ex);
                    Console.WriteLine("[{0:00}] {1} / FAIL: {2}", testCase.Number, testCase.Name, message);
                    results.Add(CaseResult.FromFailure(testCase, imagePath, message));
                }
            }

            WriteResultFiles(outDir, results);
            int failCount = results.Count(r => !r.Success);
            Console.WriteLine("Completed: {0} case(s), {1} failure(s).", results.Count, failCount);
            return failCount == 0 ? 0 : 2;
        }

        private static string NormalizePath(string path)
        {
            if (string.IsNullOrWhiteSpace(path))
            {
                return path;
            }

            string trimmed = path.Trim();
            if (DosPathPattern.IsMatch(trimmed) || trimmed.StartsWith(@"\\", StringComparison.Ordinal))
            {
                return trimmed.Replace('/', '\\');
            }

            string fixedPath = trimmed.Replace('\\', Path.DirectorySeparatorChar).Replace('/', Path.DirectorySeparatorChar);
            return Path.GetFullPath(fixedPath);
        }

        private Assembly LoadGridAssembly(string path)
        {
            try
            {
                return Assembly.LoadFrom(path);
            }
            catch (Exception ex)
            {
                string detail = DescribeAssemblyLoadFailure(path, ex);
                throw new InvalidOperationException(detail, ex);
            }
        }

        private static string DescribeAssemblyLoadFailure(string path, Exception ex)
        {
            var sb = new StringBuilder();
            sb.Append("Failed to load grid assembly ").Append(path).Append(". ");
            sb.Append(ex.GetType().Name).Append(": ").Append(ex.Message);
            sb.Append(". Process bitness=").Append(IntPtr.Size * 8).Append("-bit");

            if (File.Exists(path))
            {
                try
                {
                    var info = new FileInfo(path);
                    sb.Append(", size=").Append(info.Length).Append(" bytes");
                }
                catch
                {
                }

                try
                {
                    AssemblyName asmName = AssemblyName.GetAssemblyName(path);
                    sb.Append(", assembly=").Append(asmName.FullName);
                    sb.Append(", processor=").Append(asmName.ProcessorArchitecture);
                }
                catch (Exception asmEx)
                {
                    sb.Append(", metadata=").Append(asmEx.GetType().Name);
                }

                if (TryReadPeInfo(path, out ushort machine, out ushort peMagic))
                {
                    sb.Append(", pe=").Append(FormatPeMagic(peMagic));
                    sb.Append(", machine=").Append(FormatMachine(machine));
                }
            }
            else
            {
                sb.Append(", file not found");
            }

            return sb.ToString();
        }

        private static bool TryReadPeInfo(string path, out ushort machine, out ushort peMagic)
        {
            machine = 0;
            peMagic = 0;

            try
            {
                using (var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
                using (var reader = new BinaryReader(stream))
                {
                    if (stream.Length < 0x40)
                    {
                        return false;
                    }

                    if (reader.ReadUInt16() != 0x5A4D) // MZ
                    {
                        return false;
                    }

                    stream.Position = 0x3C;
                    int peOffset = reader.ReadInt32();
                    if (peOffset <= 0 || peOffset + 0x1A >= stream.Length)
                    {
                        return false;
                    }

                    stream.Position = peOffset;
                    if (reader.ReadUInt32() != 0x00004550) // PE\0\0
                    {
                        return false;
                    }

                    machine = reader.ReadUInt16();
                    stream.Position = peOffset + 0x18;
                    peMagic = reader.ReadUInt16();
                    return true;
                }
            }
            catch
            {
                return false;
            }
        }

        private static string FormatMachine(ushort machine)
        {
            switch (machine)
            {
                case 0x014C:
                    return "x86 (0x014C)";
                case 0x8664:
                    return "x64 (0x8664)";
                case 0x01C4:
                    return "ARM (0x01C4)";
                case 0xAA64:
                    return "ARM64 (0xAA64)";
                default:
                    return "0x" + machine.ToString("X4", CultureInfo.InvariantCulture);
            }
        }

        private static string FormatPeMagic(ushort peMagic)
        {
            switch (peMagic)
            {
                case 0x010B:
                    return "PE32";
                case 0x020B:
                    return "PE32+";
                default:
                    return "0x" + peMagic.ToString("X4", CultureInfo.InvariantCulture);
            }
        }

        private List<ScriptCase> DiscoverCases(string scriptsDir, string filter)
        {
            var selectedSet = ParseTestFilter(filter);
            var files = Directory.GetFiles(scriptsDir, "*.csx");
            var cases = new List<ScriptCase>();
            for (int i = 0; i < files.Length; i++)
            {
                string path = files[i];
                string name = Path.GetFileName(path);
                var match = CaseFilePattern.Match(name);
                if (!match.Success)
                {
                    continue;
                }

                int number = int.Parse(match.Groups["num"].Value, CultureInfo.InvariantCulture);
                if (selectedSet != null && !selectedSet.Contains(number))
                {
                    continue;
                }

                string displayName = match.Groups["name"].Value.Replace('_', ' ').Replace('-', ' ').Trim();
                cases.Add(new ScriptCase(number, displayName, path));
            }

            return cases
                .OrderBy(c => c.Number)
                .ThenBy(c => c.Name, StringComparer.OrdinalIgnoreCase)
                .ToList();
        }

        private static HashSet<int> ParseTestFilter(string filter)
        {
            if (string.IsNullOrWhiteSpace(filter))
            {
                return null;
            }

            var set = new HashSet<int>();
            string[] parts = filter.Split(',');
            for (int i = 0; i < parts.Length; i++)
            {
                string raw = parts[i].Trim();
                if (raw.Length == 0)
                {
                    continue;
                }

                if (!TestFilterPattern.IsMatch(raw))
                {
                    throw new ArgumentException("Invalid tests filter segment: " + raw);
                }

                int dash = raw.IndexOf('-');
                if (dash < 0)
                {
                    set.Add(int.Parse(raw, CultureInfo.InvariantCulture));
                    continue;
                }

                int start = int.Parse(raw.Substring(0, dash).Trim(), CultureInfo.InvariantCulture);
                int end = int.Parse(raw.Substring(dash + 1).Trim(), CultureInfo.InvariantCulture);
                if (end < start)
                {
                    int tmp = start;
                    start = end;
                    end = tmp;
                }

                for (int n = start; n <= end; n++)
                {
                    set.Add(n);
                }
            }

            return set;
        }

        private MethodInfo CompileCaseMethod(ScriptCase testCase)
        {
            string source = BuildCompilationUnit(testCase.Content);

            var compilerParameters = new CompilerParameters
            {
                GenerateExecutable = false,
                GenerateInMemory = true,
                TreatWarningsAsErrors = false,
                IncludeDebugInformation = false,
                CompilerOptions = "/target:library /optimize+",
            };

            AddReference(compilerParameters, "System.dll");
            AddReference(compilerParameters, "System.Core.dll");
            AddReference(compilerParameters, "System.Data.dll");
            AddReference(compilerParameters, "System.Drawing.dll");
            AddReference(compilerParameters, "System.Xml.dll");
            AddReference(compilerParameters, "System.Windows.Forms.dll");
            AddReference(compilerParameters, "Microsoft.CSharp.dll");
            AddReference(compilerParameters, Assembly.GetExecutingAssembly().Location);

            using (var provider = new CSharpCodeProvider())
            {
                CompilerResults results = provider.CompileAssemblyFromSource(compilerParameters, source);
                if (results.Errors.HasErrors)
                {
                    var sb = new StringBuilder();
                    for (int i = 0; i < results.Errors.Count; i++)
                    {
                        var err = results.Errors[i];
                        if (err.IsWarning)
                        {
                            continue;
                        }

                        if (sb.Length > 0)
                        {
                            sb.Append("; ");
                        }

                        sb.AppendFormat(
                            CultureInfo.InvariantCulture,
                            "L{0}: {1}",
                            err.Line,
                            err.ErrorText);
                    }

                    throw new InvalidOperationException("Script compile failed: " + sb);
                }

                Type entryType = results.CompiledAssembly.GetType("VolvoxGrid.ScriptCaseRuntime.ScriptEntry", true);
                MethodInfo runMethod = entryType.GetMethod("Run", BindingFlags.Public | BindingFlags.Static);
                if (runMethod == null)
                {
                    throw new InvalidOperationException("Compiled script did not contain ScriptEntry.Run.");
                }

                return runMethod;
            }
        }

        private static string BuildCompilationUnit(string body)
        {
            return
@"using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Drawing;
using System.Windows.Forms;
using VolvoxGrid.DotNet.ScriptRunner.Compat;

namespace VolvoxGrid.ScriptCaseRuntime
{
    public static class ScriptEntry
    {
        public static void Run(GridControl grid, GridView view)
        {
" + body + @"
        }
    }
}";
        }

        private static void AddReference(CompilerParameters parameters, string reference)
        {
            if (!parameters.ReferencedAssemblies.Contains(reference))
            {
                parameters.ReferencedAssemblies.Add(reference);
            }
        }

        private void RunSingleCase(
            ScriptCase testCase,
            MethodInfo method,
            Assembly gridAssembly,
            string pluginPath,
            string imagePath)
        {
            LogVerbose("[{0:00}] create environment", testCase.Number);
            using (var environment = ScriptCaseEnvironment.Create(_options.Engine, gridAssembly, pluginPath))
            using (var form = new Form())
            {
                LogVerbose("[{0:00}] environment ready", testCase.Number);
                form.Text = "ScriptCase " + testCase.Number.ToString("D2", CultureInfo.InvariantCulture);
                form.StartPosition = FormStartPosition.Manual;
                form.Left = 20;
                form.Top = 20;
                form.ClientSize = new Size(_options.Width, _options.Height);
                form.ShowInTaskbar = false;
                Control gridControl = environment.Control;
                gridControl.Dock = DockStyle.Fill;
                form.Controls.Add(gridControl);
                LogVerbose("[{0:00}] show form", testCase.Number);
                form.Show();
                PumpMessages(_options.SettleMs);

                LogVerbose("[{0:00}] invoke script", testCase.Number);
                method.Invoke(null, new object[] { environment.Grid, environment.View });
                PumpMessages(_options.SettleMs);

                LogVerbose("[{0:00}] capture", testCase.Number);
                CaptureControl(form, gridControl, imagePath);
                PumpMessages(30);
                LogVerbose("[{0:00}] close form", testCase.Number);
                form.Close();
            }
        }

        private void LogVerbose(string format, params object[] args)
        {
            if (_options.Verbose)
            {
                Console.WriteLine(format, args);
            }
        }

        private static void CaptureControl(Form form, Control control, string imagePath)
        {
            int width = Math.Max(1, control.Width);
            int height = Math.Max(1, control.Height);

            using (var bitmap = new Bitmap(width, height))
            {
                using (var g = Graphics.FromImage(bitmap))
                {
                    try
                    {
                        if (form != null)
                        {
                            form.Activate();
                        }

                        Application.DoEvents();
                        Point screenPoint = control.PointToScreen(Point.Empty);
                        g.CopyFromScreen(screenPoint, Point.Empty, new Size(width, height));
                    }
                    catch
                    {
                        // Fallback when screen-copy is unavailable in the current host.
                        control.DrawToBitmap(bitmap, new Rectangle(0, 0, width, height));
                    }
                }

                bitmap.Save(imagePath, ImageFormat.Png);
            }
        }

        private static void PumpMessages(int millis)
        {
            if (millis <= 0)
            {
                Application.DoEvents();
                return;
            }

            var sw = Stopwatch.StartNew();
            while (sw.ElapsedMilliseconds < millis)
            {
                Application.DoEvents();
                Thread.Sleep(12);
            }
        }

        private void WriteResultFiles(string outDir, List<CaseResult> results)
        {
            string resultsTsv = Path.Combine(outDir, "results.tsv");
            var sb = new StringBuilder();
            sb.AppendLine("num\tname\tsuccess\timage\tmessage");
            for (int i = 0; i < results.Count; i++)
            {
                var r = results[i];
                sb.Append(r.Number.ToString(CultureInfo.InvariantCulture)).Append('\t');
                sb.Append(r.Name).Append('\t');
                sb.Append(r.Success ? "1" : "0").Append('\t');
                sb.Append(r.ImagePath).Append('\t');
                sb.Append(r.Message ?? string.Empty);
                sb.AppendLine();
            }
            File.WriteAllText(resultsTsv, sb.ToString(), Encoding.UTF8);
        }

        private Assembly OnAssemblyResolve(object sender, ResolveEventArgs args)
        {
            string shortName = new AssemblyName(args.Name).Name + ".dll";
            for (int i = 0; i < _assemblySearchDirs.Count; i++)
            {
                string candidate = Path.Combine(_assemblySearchDirs[i], shortName);
                if (File.Exists(candidate))
                {
                    try
                    {
                        return Assembly.LoadFrom(candidate);
                    }
                    catch
                    {
                    }
                }
            }

            return null;
        }

        private void LoadDevExpressNeighbors(string baseDir)
        {
            if (string.IsNullOrEmpty(baseDir) || !Directory.Exists(baseDir))
            {
                return;
            }

            string[] files = Directory.GetFiles(baseDir, "DevExpress*.dll");
            for (int i = 0; i < files.Length; i++)
            {
                AddAssemblySearchDir(Path.GetDirectoryName(files[i]));
                try
                {
                    Assembly.LoadFrom(files[i]);
                }
                catch
                {
                    // Best effort; script compile/runtime will surface missing hard dependencies.
                }
            }
        }

        private void AddAssemblySearchDir(string dir)
        {
            if (string.IsNullOrEmpty(dir))
            {
                return;
            }

            if (!_assemblySearchDirs.Contains(dir, StringComparer.OrdinalIgnoreCase))
            {
                _assemblySearchDirs.Add(dir);
            }
        }

        private static string FlattenException(Exception ex)
        {
            if (ex is TargetInvocationException tie && tie.InnerException != null)
            {
                ex = tie.InnerException;
            }

            var parts = new List<string>();
            Exception current = ex;
            while (current != null)
            {
                parts.Add(current.GetType().Name + ": " + current.Message);
                current = current.InnerException;
            }

            return string.Join(" | ", parts.ToArray());
        }
    }

    internal sealed class ScriptCase
    {
        public int Number { get; private set; }
        public string Name { get; private set; }
        public string Path { get; private set; }
        public string FileName { get; private set; }
        public string SafeName { get; private set; }
        public string Content { get; private set; }

        public ScriptCase(int number, string name, string path)
        {
            Number = number;
            Name = name;
            Path = path;
            FileName = System.IO.Path.GetFileName(path);
            SafeName = MakeSafeName(name);
            Content = File.ReadAllText(path);
        }

        private static string MakeSafeName(string input)
        {
            var sb = new StringBuilder(input.Length);
            for (int i = 0; i < input.Length; i++)
            {
                char ch = input[i];
                if (char.IsLetterOrDigit(ch))
                {
                    sb.Append(char.ToLowerInvariant(ch));
                }
                else if (ch == '_' || ch == '-')
                {
                    sb.Append(ch);
                }
                else if (char.IsWhiteSpace(ch))
                {
                    sb.Append('_');
                }
            }

            string cleaned = sb.ToString().Trim('_');
            return cleaned.Length == 0 ? "case" : cleaned;
        }
    }

    internal sealed class CaseResult
    {
        public int Number { get; private set; }
        public string Name { get; private set; }
        public bool Success { get; private set; }
        public string ImagePath { get; private set; }
        public string Message { get; private set; }

        private CaseResult()
        {
        }

        public static CaseResult FromSuccess(ScriptCase testCase, string imagePath)
        {
            return new CaseResult
            {
                Number = testCase.Number,
                Name = testCase.Name,
                Success = true,
                ImagePath = imagePath,
                Message = string.Empty,
            };
        }

        public static CaseResult FromFailure(ScriptCase testCase, string imagePath, string message)
        {
            return new CaseResult
            {
                Number = testCase.Number,
                Name = testCase.Name,
                Success = false,
                ImagePath = imagePath,
                Message = message ?? string.Empty,
            };
        }
    }
}
