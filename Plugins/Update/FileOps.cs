// 文件与进程操作。整个更新器里只有这个文件和 Ui.cs 碰平台细节：
// 将来换 .NET 8 / 换平台，只需替换这两处的实现，上层编排（Program.cs）不用动。
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

namespace RmtUpdate
{
    internal sealed class ApplyReport
    {
        public readonly List<string> Replaced = new List<string>();
        public readonly List<string> Created = new List<string>();
        public int Total;
    }

    internal static class FileOps
    {
        // ---------- 系统对话框 ----------

        [DllImport("kernel32.dll")]
        private static extern uint SetErrorMode(uint uMode);

        private const uint SEM_FAILCRITICALERRORS = 0x0001;
        private const uint SEM_NOOPENFILEERRORBOX = 0x8000;

        /// <summary>
        /// 关掉「这个 exe 不是有效的应用程序」这类系统弹框。
        ///
        /// 不关会出人命：CreateProcess 打不开坏 exe 时，Windows 默认在**当前进程**里弹一个阻塞式
        /// 消息框，而我们是无窗口后台进程，用户根本看不到，更新就永远卡在那儿。
        /// 关掉之后 CreateProcess 直接返回错误，我们才能回退旧版更新器。
        /// </summary>
        public static void SuppressSystemErrorDialogs()
        {
            try
            {
                SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOOPENFILEERRORBOX);
            }
            catch
            {
            }
        }

        // ---------- 目录 / 权限 ----------

        public static bool CanWriteDir(string dir)
        {
            try
            {
                string probe = Path.Combine(dir, ".rmt_update_probe");
                File.WriteAllText(probe, "1");
                File.Delete(probe);
                return true;
            }
            catch
            {
                return false;
            }
        }

        /// <summary>确保 child 落在 root 之内，挡住 zip 里的 ../ 越界条目。</summary>
        public static string SafeCombine(string root, string relative)
        {
            string full = Path.GetFullPath(Path.Combine(root, relative));
            string rootFull = Path.GetFullPath(root);
            if (!rootFull.EndsWith(Path.DirectorySeparatorChar.ToString(), StringComparison.Ordinal))
                rootFull += Path.DirectorySeparatorChar;
            if (!full.StartsWith(rootFull, StringComparison.OrdinalIgnoreCase))
                throw new IOException("安装包条目越界：" + relative);
            return full;
        }

        // ---------- 进程 ----------

        /// <summary>等进程退出。等到超时也返回 false，由调用方决定是否硬着头皮继续。</summary>
        public static bool WaitForExit(int pid, int timeoutMs, Action<string> tick)
        {
            if (pid <= 0)
                return true;

            DateTime deadline = DateTime.UtcNow.AddMilliseconds(timeoutMs);
            while (DateTime.UtcNow < deadline)
            {
                if (!IsAlive(pid))
                    return true;
                if (tick != null)
                    tick(null);
                Thread.Sleep(200);
            }
            return !IsAlive(pid);
        }

        /// <summary>同目录下还活着的辅助进程（Worker）。名字匹配 + 路径前缀，避免误伤别人的进程。</summary>
        public static bool HasLiveProcessIn(string dir, string exeName)
        {
            try
            {
                foreach (Process p in Process.GetProcessesByName(Path.GetFileNameWithoutExtension(exeName)))
                {
                    try
                    {
                        if (!p.HasExited && p.MainModule.FileName.StartsWith(dir, StringComparison.OrdinalIgnoreCase))
                            return true;
                    }
                    catch
                    {
                        // 拿不到路径（权限/已退出）就当它没在跑
                    }
                }
            }
            catch
            {
            }
            return false;
        }

        private static bool IsAlive(int pid)
        {
            try
            {
                Process p = Process.GetProcessById(pid);
                return !p.HasExited;
            }
            catch (ArgumentException)
            {
                return false;
            }
            catch
            {
                return true; // 没权限判断时保守认为还活着
            }
        }

        // ---------- 解压 / 覆盖 / 回滚 ----------

        public static void Extract(string zipPath, string destDir)
        {
            if (Directory.Exists(destDir))
                Directory.Delete(destDir, true);
            Directory.CreateDirectory(destDir);
            ZipFile.ExtractToDirectory(zipPath, destDir);

            foreach (string dir in Directory.GetDirectories(destDir, "*", SearchOption.AllDirectories))
            {
                if (dir.IndexOf("__MACOSX", StringComparison.OrdinalIgnoreCase) >= 0)
                    Directory.Delete(dir, true);
            }
            string junk = Path.Combine(destDir, ".DS_Store");
            if (File.Exists(junk))
                File.Delete(junk);
        }

        public static ApplyReport Apply(string stageDir, string targetDir, string backupDir, Action<int, int> progress)
        {
            string[] files = Directory.GetFiles(stageDir, "*", SearchOption.AllDirectories);
            ApplyReport report = new ApplyReport();
            report.Total = files.Length;

            for (int i = 0; i < files.Length; i++)
            {
                string src = files[i];
                string rel = src.Substring(stageDir.Length).TrimStart(Path.DirectorySeparatorChar);
                string dst = SafeCombine(targetDir, rel);

                string parent = Path.GetDirectoryName(dst);
                if (!string.IsNullOrEmpty(parent))
                    Directory.CreateDirectory(parent);

                if (File.Exists(dst))
                {
                    string bak = Path.Combine(backupDir, rel);
                    string bakParent = Path.GetDirectoryName(bak);
                    if (!string.IsNullOrEmpty(bakParent))
                        Directory.CreateDirectory(bakParent);
                    File.Copy(dst, bak, true);
                    report.Replaced.Add(rel);
                }
                else
                {
                    report.Created.Add(rel);
                }

                CopyWithRetry(src, dst, 6);
                if (progress != null)
                    progress(i + 1, files.Length);
            }

            return report;
        }

        /// <summary>回滚：备份的还原回去，新建的删掉。回滚失败只记日志，不抛。</summary>
        public static void Rollback(string backupDir, string targetDir, ApplyReport report, List<string> errors)
        {
            if (report != null)
            {
                foreach (string rel in report.Created)
                {
                    try
                    {
                        string dst = SafeCombine(targetDir, rel);
                        if (File.Exists(dst))
                            File.Delete(dst);
                    }
                    catch (Exception ex)
                    {
                        errors.Add("删除新建文件失败 " + rel + "：" + ex.Message);
                    }
                }
            }

            if (!Directory.Exists(backupDir))
                return;

            foreach (string src in Directory.GetFiles(backupDir, "*", SearchOption.AllDirectories))
            {
                try
                {
                    string rel = src.Substring(backupDir.Length).TrimStart(Path.DirectorySeparatorChar);
                    CopyWithRetry(src, SafeCombine(targetDir, rel), 3);
                }
                catch (Exception ex)
                {
                    errors.Add("还原备份失败 " + src + "：" + ex.Message);
                }
            }
        }

        /// <summary>带重试的复制：目标被占用的那几百毫秒里重试几次，别立刻判死。</summary>
        public static void CopyWithRetry(string src, string dst, int attempts)
        {
            for (int i = 1; i <= attempts; i++)
            {
                try
                {
                    if (File.Exists(dst))
                    {
                        FileAttributes attr = File.GetAttributes(dst);
                        if ((attr & FileAttributes.ReadOnly) != 0)
                            File.SetAttributes(dst, attr & ~FileAttributes.ReadOnly);
                    }
                    File.Copy(src, dst, true);
                    return;
                }
                catch (IOException)
                {
                    if (i == attempts)
                        throw;
                    Thread.Sleep(300 * i);
                }
                catch (UnauthorizedAccessException)
                {
                    if (i == attempts)
                        throw;
                    Thread.Sleep(300 * i);
                }
            }
        }

        // ---------- 临时文件回收 ----------

        public static void TryDeleteDir(string dir)
        {
            if (string.IsNullOrEmpty(dir) || !Directory.Exists(dir))
                return;
            try
            {
                Directory.Delete(dir, true);
            }
            catch
            {
                // 被占用就留着，下一次 Relocate 还会来收
            }
        }

        public static void TryDeleteFile(string file)
        {
            if (string.IsNullOrEmpty(file) || !File.Exists(file))
                return;
            try
            {
                File.Delete(file);
            }
            catch
            {
            }
        }

        /// <summary>目录里还在跑别人的 exe 吗？判定标准：独占打开其中的 RMT.Update.exe 会失败。</summary>
        public static bool IsDirInUse(string dir)
        {
            string exe = Path.Combine(dir, "RMT.Update.exe");
            if (!File.Exists(exe))
                return false;
            try
            {
                using (FileStream fs = new FileStream(exe, FileMode.Open, FileAccess.ReadWrite, FileShare.None))
                {
                    return false;
                }
            }
            catch (IOException)
            {
                return true;
            }
            catch (UnauthorizedAccessException)
            {
                return true;
            }
            catch
            {
                return false;
            }
        }

        // ---------- 日志 ----------

        public static void AppendLog(string logPath, string line)
        {
            if (string.IsNullOrEmpty(logPath))
                return;
            try
            {
                string dir = Path.GetDirectoryName(logPath);
                if (!string.IsNullOrEmpty(dir))
                    Directory.CreateDirectory(dir);

                FileInfo fi = new FileInfo(logPath);
                if (fi.Exists && fi.Length > 512 * 1024)
                {
                    string old = logPath + ".1";
                    if (File.Exists(old))
                        File.Delete(old);
                    File.Move(logPath, old);
                }

                string text = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "  " + line + Environment.NewLine;
                File.AppendAllText(logPath, text, Encoding.UTF8);
            }
            catch
            {
            }
        }
    }
}
