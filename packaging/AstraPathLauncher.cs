using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Security.Cryptography;
using System.Windows.Forms;

[assembly: AssemblyTitle("AstraPathing")]
[assembly: AssemblyDescription("Single-file launcher for AstraPathing")]
[assembly: AssemblyProduct("AstraPathing")]
[assembly: AssemblyVersion("2.9.0.0")]

internal static class AstraPathLauncher
{
    private const string PayloadResource = "AstraPathPayload.zip";
    private const string AppName = "AstraPathing.exe";

    [STAThread]
    private static void Main()
    {
        try
        {
            byte[] payload = ReadPayload();
            string hash;
            using (SHA256 sha = SHA256.Create())
            {
                hash = BitConverter.ToString(sha.ComputeHash(payload)).Replace("-", "").ToLowerInvariant();
            }

            string root = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "AstraPathing", "runtime");
            string install = Path.Combine(root, hash.Substring(0, 16));
            if (!IsComplete(install, hash))
            {
                Install(payload, root, install, hash);
            }

            Process.Start(new ProcessStartInfo(Path.Combine(install, AppName))
            {
                WorkingDirectory = install,
                UseShellExecute = false
            });
        }
        catch (Exception error)
        {
            MessageBox.Show(
                "AstraPathing could not start.\n\n" + error.Message,
                "AstraPathing", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private static byte[] ReadPayload()
    {
        using (Stream source = Assembly.GetExecutingAssembly().GetManifestResourceStream(PayloadResource))
        {
            if (source == null) throw new InvalidDataException("The app bundle is missing.");
            using (MemoryStream copy = new MemoryStream())
            {
                source.CopyTo(copy);
                return copy.ToArray();
            }
        }
    }

    private static bool IsComplete(string directory, string hash)
    {
        string marker = Path.Combine(directory, ".complete");
        return File.Exists(marker)
            && File.ReadAllText(marker) == hash
            && File.Exists(Path.Combine(directory, AppName))
            && File.Exists(Path.Combine(directory, "flutter_windows.dll"))
            && File.Exists(Path.Combine(directory, "vcruntime140.dll"))
            && File.Exists(Path.Combine(directory, "data", "app.so"));
    }

    private static void Install(byte[] payload, string root, string install, string hash)
    {
        Directory.CreateDirectory(root);
        string staging = Path.Combine(root, "_extract-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(staging);
        try
        {
            using (MemoryStream input = new MemoryStream(payload, false))
            using (ZipArchive archive = new ZipArchive(input, ZipArchiveMode.Read))
            {
                foreach (ZipArchiveEntry entry in archive.Entries)
                {
                    string name = entry.FullName.Replace('/', Path.DirectorySeparatorChar)
                        .Replace('\\', Path.DirectorySeparatorChar);
                    string destination = Path.GetFullPath(Path.Combine(staging, name));
                    EnsureUnder(staging, destination);
                    if (name.EndsWith(Path.DirectorySeparatorChar.ToString()))
                    {
                        Directory.CreateDirectory(destination);
                        continue;
                    }
                    Directory.CreateDirectory(Path.GetDirectoryName(destination));
                    using (Stream source = entry.Open())
                    using (FileStream output = File.Create(destination))
                    {
                        source.CopyTo(output);
                    }
                }
            }

            File.WriteAllText(Path.Combine(staging, ".complete"), hash);
            if (!IsComplete(staging, hash)) throw new InvalidDataException("The app bundle is incomplete.");

            if (Directory.Exists(install) && !IsComplete(install, hash))
            {
                EnsureUnder(root, install);
                Directory.Delete(install, true);
            }
            if (!Directory.Exists(install)) Directory.Move(staging, install);
            if (!IsComplete(install, hash)) throw new InvalidDataException("The app could not be installed.");
        }
        finally
        {
            if (Directory.Exists(staging))
            {
                EnsureUnder(root, staging);
                Directory.Delete(staging, true);
            }
        }
    }

    private static void EnsureUnder(string root, string path)
    {
        string prefix = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar)
            + Path.DirectorySeparatorChar;
        if (!Path.GetFullPath(path).StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidDataException("The app bundle contains an invalid path.");
        }
    }
}
