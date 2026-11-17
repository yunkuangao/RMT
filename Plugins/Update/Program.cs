// RMT.Update.exe —— 独立更新器。
//
// 为什么要独立进程：RMT 的主程序、Thread\Work.exe 和 Plugins 下的 dll 在运行时都被占用，
// 自己替换自己是不可能的。所以由 RMT 拉起本进程后立刻退出，本进程在 RMT 消失后完成
// 下载、替换、重启，全程不依赖 RMT 是否还活着。
//
// 两种模式（由宿主 RMT 调用）：
//   check   --repo <owner/name> --current <ver> --arch x64|x86 --lang zh|en --out <file>
//           [--channel stable|test] [--api <base>] [--proxy <prefix>] [--release-file <json>]
//           读 GitHub Release、比对版本、把结果写成 JSON 给宿主读，自身不显示界面。
//           正式版通道读 /releases/latest；测试版通道读 /releases 列表，按版本号取最高的
//           （列表里正式版也在，所以正式版发布后测试版用户不会卡在最后一个 F 版）。
//           --release-file 是离线/自测入口：直接读一个 GitHub API 形状的 JSON。
//   install --target <dir> --url <zip> [--sha256 <hash>] --arch ... --wait-pid <n> [--launch <exe>]
//           [--zip <本地包>] [--version <ver>] [--log <file>] [--lang ...]
//           显示进度窗 → 下载 → 校验 → 等 RMT 退出 → 备份替换 → 重启 RMT。
//
// 发布侧不产出额外清单：版本、说明、下载地址、sha256 全部来自 Release 本身。
//
// 参数与文案都从外部给，方便宿主切换语言；本进程不带任何 RMT 的业务知识。
//
// 自更新（本文件最容易踩坑的地方，改动前先看完）：
//   1. 安装包里有新版 RMT.Update.exe 时，要从 %TEMP% 的副本里跑，否则替换自己必失败——见 Relocate。
//   2. 命令行参数是与宿主的唯一契约：宿主只会用「旧参数」调「新 exe」。所以 --key 只能增不能删改，
//      未知参数必须忽略（CommandLine.Parse 已经这么做）。改语义等于让老版本 RMT 更新不了。
//   3. 换上新 exe 后要跑一次自检（VerifySelf），跑不起来就回退旧版：宁可更新器不升级，
//      也不能让下一次更新彻底没入口。
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading;
using System.Windows.Forms;

namespace RmtUpdate
{
    internal static class Program
    {
        [STAThread]
        private static int Main(string[] args)
        {
            Net.ConfigureTls();
            // 先关系统错误弹框：后面可能要启动一个坏掉的 exe，不能让它把我们挂住
            FileOps.SuppressSystemErrorDialogs();

            if (args.Length < 1)
                return Fail("用法: RMT.Update.exe check|install [--key value]");

            string mode = args[0].ToLowerInvariant();
            CommandLine cl = CommandLine.Parse(args, 1);

            try
            {
                if (mode == "check")
                    return DoCheck(cl);
                if (mode == "install")
                    return DoInstall(args, cl);
                return Fail("未知命令: " + mode);
            }
            catch (Exception ex)
            {
                return Fail(ex.Message);
            }
        }

        // ---------- check ----------

        private static int DoCheck(CommandLine cl)
        {
            string lang = cl.Get("lang", "zh");
            CheckResult result = new CheckResult();
            result.ok = false;

            string outPath;
            try
            {
                outPath = cl.Required("out");
            }
            catch (Exception ex)
            {
                return Fail(ex.Message);
            }

            try
            {
                string channel = cl.Get("channel", "stable");
                Release best = PickBest(LoadReleases(cl), channel);
                AppVersion current = AppVersion.Parse(cl.Get("current", "0"));

                result.current = current.ToString();
                result.latest = best.Version.ToString();
                result.notes = best.Notes;
                result.tag = best.Tag;
                result.channel = channel;
                result.has_update = best.Version.IsNewerThan(current);

                string arch = cl.Get("arch", "x64");
                AssetInfo asset = best.FindAsset(arch);
                if (asset == null && best.FromFeed && cl.Get("repo", "") != "")
                {
                    // atom 里没有 assets：按打包命名约定拼下载地址。
                    // 代价是拿不到 sha256（宿主会跳过校验）和体积，但总比「有更新装不了」强。
                    string repo = cl.Get("repo", "").Trim('/');
                    string zip = "RMTv" + best.Version + "_" + arch + ".zip";
                    string url = "https://github.com/" + repo + "/releases/download/" + best.Tag + "/" + zip;
                    result.url = WithProxy(url, cl);
                }
                else if (asset == null)
                {
                    // 有新版但没有对应架构的包：当成错误报出去，别让用户看到一个点不动的「有更新」
                    if (result.has_update)
                        throw new Exception(Strings.Format(Strings.L(lang, "no_asset"), arch));
                }
                else
                {
                    result.url = WithProxy(asset.url, cl);
                    result.sha256 = asset.sha256;
                    result.size = asset.size;
                }

                result.ok = true;
                result.checked_at = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
            }
            catch (Exception ex)
            {
                result.error = ex.Message;
            }

            try
            {
                string dir = Path.GetDirectoryName(outPath);
                if (!string.IsNullOrEmpty(dir))
                    Directory.CreateDirectory(dir);
                // 不带 BOM：宿主按 UTF-8 读，某些 JSON 解析器见到 BOM 会报错
                File.WriteAllText(outPath, result.ToJson(), new UTF8Encoding(false));
            }
            catch { }

            return result.ok ? 0 : 1;
        }

        // ---------- 取 Release ----------

        /// <summary>
        /// 数据来源：--release-file 优先（离线/自测），否则按 --repo 请求 GitHub API。
        /// 正式版读 /releases/latest，测试版读 /releases 列表（两种版本都在里面）。
        ///
        /// API 走不通时退回 releases.atom，见 ParseAtom 的注释——主要防 gh-proxy 的共享
        /// token 被打满导致测试版通道整个查不了（列表接口没有 CDN 缓存，latest 有）。
        /// </summary>
        private static List<Release> LoadReleases(CommandLine cl)
        {
            string file = cl.Get("release-file", "");
            if (!string.IsNullOrEmpty(file))
            {
                if (!File.Exists(file))
                    throw new FileNotFoundException("找不到 Release JSON：" + file);
                return Release.ParseList(File.ReadAllText(file, Encoding.UTF8));
            }

            string repo = cl.Required("repo").Trim('/');
            string channel = cl.Get("channel", "stable");
            string api = cl.Get("api", "https://api.github.com").TrimEnd('/');
            string path = channel == "test"
                ? "/releases?per_page=10"
                : "/releases/latest";
            int timeout = cl.GetInt("timeout", 15);

            try
            {
                string json = Net.GetString(api + "/repos/" + repo + path, timeout);
                return Release.ParseList(json);
            }
            catch (Exception apiError)
            {
                try
                {
                    string feedUrl = WithProxy("https://github.com/" + repo + "/releases.atom", cl);
                    List<Release> feed = Release.ParseAtom(Net.GetString(feedUrl, timeout), 10);
                    if (feed.Count > 0)
                        return feed;
                }
                catch
                {
                    // 两条路都断了：把 API 的原始错误抛出去，宿主日志里能看到具体原因
                }
                throw apiError;
            }
        }

        /// <summary>
        /// 挑出这一通道该看的那个 Release。
        /// 正式版跳过 prerelease；测试版不跳过（列表里正式版也在，按版本号谁大用谁）。
        /// </summary>
        private static Release PickBest(List<Release> list, string channel)
        {
            bool allowPre = channel == "test";
            Release best = null;
            foreach (Release r in list)
            {
                if (r.Draft)
                    continue;
                if (!allowPre && r.Prerelease)
                    continue;
                if (best == null || r.Version.CompareTo(best.Version) > 0)
                    best = r;
            }
            if (best == null)
                throw new InvalidDataException(allowPre ? "没有可用的 Release" : "还没有正式版 Release");
            return best;
        }

        /// <summary>给下载地址套加速前缀（国内直连 github.com 太慢）。已经不带头的不重复加。</summary>
        private static string WithProxy(string url, CommandLine cl)
        {
            string prefix = cl.Get("proxy", "");
            if (string.IsNullOrEmpty(url) || string.IsNullOrEmpty(prefix))
                return url;
            if (url.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
                return url;
            return prefix + url;
        }

        private static int DoInstall(string[] rawArgs, CommandLine cl)
        {
            string lang = cl.Get("lang", "zh");
            string target = Path.GetFullPath(cl.Required("target"));

            if (!Directory.Exists(target))
                return Fail("目标目录不存在: " + target);

            // 装在 Program Files 之类的位置时无写权限：不冒险提权，直接让用户手动下载。
            if (!FileOps.CanWriteDir(target))
                return Fail(Strings.Format(Strings.L(lang, "no_write"), target));

            // 先把自己搬到 %TEMP%：安装包里可能带新版 RMT.Update.exe，
            // 从安装目录跑的话替换自己会失败。
            if (!cl.Has("relocated"))
                return Relocate(rawArgs);

            ProgressForm form = new ProgressForm(lang);
            form.Shown += delegate
            {
                Thread worker = new Thread(delegate()
                {
                    form.ExitCode = Job(cl, form);
                });
                worker.IsBackground = true;
                worker.Start();
            };

            Application.Run(form);
            return form.ExitCode;
        }

        private static int Job(CommandLine cl, ProgressForm form)
        {
            string lang = cl.Get("lang", "zh");
            string target = Path.GetFullPath(cl.Required("target"));
            string arch = cl.Get("arch", "x64");
            string work = cl.Get("relocated", Path.Combine(Path.GetTempPath(), "RMTUpdate", "work"));
            string log = cl.Get("log", Path.Combine(target, "Log", "Update.log"));
            string launch = cl.Get("launch", "");
            int waitPid = cl.GetInt("wait-pid", 0);

            string zip = cl.Get("zip", Path.Combine(work, "package.zip"));
            string stage = Path.Combine(work, "stage");
            string backup = Path.Combine(work, "backup");
            ApplyReport report = null;

            try
            {
                FileOps.AppendLog(log, "开始更新：目标=" + target + " 架构=" + arch + " work=" + work);

                // 1) 包地址由宿主从 check 结果直接给，install 不再请求网络
                string url = cl.Get("url", "");
                string sha256 = cl.Get("sha256", "");
                string version = cl.Get("version", "");
                if (string.IsNullOrEmpty(url) && !File.Exists(zip))
                    throw new Exception(Strings.L(lang, "no_url"));

                // 2) 下载（可取消）
                form.AllowCancel(true);
                if (File.Exists(zip))
                {
                    FileOps.AppendLog(log, "使用本地安装包：" + zip);
                }
                else
                {
                    form.Report(0, Strings.L(lang, "downloading_unknown"));
                    bool ok = Net.Download(url, zip,
                        delegate(long done, long total)
                        {
                            if (total > 0)
                            {
                                int percent = (int)(done * 100 / total);
                                form.Report((int)(done * 70 / total),
                                    Strings.Format(Strings.L(lang, "downloading"), percent));
                            }
                            else
                            {
                                form.Report(-1, Strings.L(lang, "downloading_unknown"));
                            }
                        },
                        delegate { return form.CancelRequested; });
                    if (!ok)
                        throw new OperationCanceledException();
                }
                form.AllowCancel(false);

                // 3) 校验
                form.Report(72, Strings.L(lang, "verifying"));
                if (!string.IsNullOrEmpty(sha256))
                {
                    string got = Net.Sha256File(zip);
                    if (!string.Equals(got, sha256.Trim(), StringComparison.OrdinalIgnoreCase))
                        throw new Exception("安装包校验失败（sha256 不匹配）");
                }
                else
                {
                    FileOps.AppendLog(log, "没有 sha256 可校验（老 release 可能没有 digest），跳过");
                }

                // 4) 解压
                form.Report(78, Strings.L(lang, "extracting"));
                FileOps.Extract(zip, stage);

                // 5) 等 RMT 和它的 Worker 退出，文件才不会被占用
                form.Report(82, Strings.L(lang, "waiting"));
                if (!FileOps.WaitForExit(waitPid, 90000, null))
                    FileOps.AppendLog(log, "警告：等待进程 " + waitPid + " 超时，仍继续尝试替换");
                for (int i = 0; i < 25 && FileOps.HasLiveProcessIn(target, "Work.exe"); i++)
                    Thread.Sleep(200);

                // 6) 备份 + 覆盖
                if (Directory.Exists(backup))
                    Directory.Delete(backup, true);
                report = FileOps.Apply(stage, target, backup,
                    delegate(int done, int total)
                    {
                        int percent = 85 + (int)(done * 14.0 / Math.Max(1, total));
                        form.Report(percent, Strings.Format(Strings.L(lang, "applying"), done, total));
                    });
                FileOps.AppendLog(log, "已覆盖 " + report.Replaced.Count + " 个文件，新建 " + report.Created.Count + " 个");

                CleanupOldExe(target, stage, log);

                // 6.5) 自己也被换了？确认新 exe 真的能跑，跑不起来就退回旧版
                VerifySelf(target, backup, log);

                // 7) 重启
                form.Report(100, Strings.L(lang, "restarting"));
                if (cl.Has("no-launch"))
                {
                    FileOps.AppendLog(log, "按参数要求不自动启动主程序");
                    form.Finish(true, Strings.L(lang, "done"));
                }
                else
                {
                    StartTarget(target, launch, stage, log);
                    form.Finish(true, Strings.L(lang, "restarting"));
                }
                // 8) 收尾：stage、安装包、备份加起来能到两三百 MB，留着就是白占盘
                FileOps.TryDeleteDir(stage);
                FileOps.TryDeleteDir(backup);
                FileOps.TryDeleteFile(zip);
                FileOps.AppendLog(log, "更新完成：" + version);
                return 0;
            }
            catch (OperationCanceledException)
            {
                FileOps.AppendLog(log, "用户取消");
                form.Finish(false, Strings.L(lang, "cancelled"));
                return 2;
            }
            catch (Exception ex)
            {
                FileOps.AppendLog(log, "更新失败：" + ex.Message);

                List<string> errors = new List<string>();
                if (report != null)
                {
                    FileOps.Rollback(backup, target, report, errors);
                    foreach (string e in errors)
                        FileOps.AppendLog(log, e);
                }

                string message = Strings.Format(Strings.L(lang, "failed"), ex.Message);
                if (report != null && errors.Count == 0)
                    message += "\r\n" + Strings.L(lang, "rolledback");

                form.Finish(false, message);
                return 1;
            }
        }

        /// <summary>新版本的主程序名带版本号，旧的那份留着会越攒越大。</summary>
        private static void CleanupOldExe(string target, string stage, string log)
        {
            string[] staged = Directory.GetFiles(stage, "RMTv*.exe", SearchOption.TopDirectoryOnly);
            if (staged.Length == 0)
                return;

            HashSet<string> keep = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (string s in staged)
                keep.Add(Path.GetFileName(s));

            foreach (string f in Directory.GetFiles(target, "RMTv*.exe", SearchOption.TopDirectoryOnly))
            {
                string name = Path.GetFileName(f);
                if (keep.Contains(name))
                    continue;
                try
                {
                    File.Delete(f);
                    FileOps.AppendLog(log, "清理旧主程序 " + name);
                }
                catch (Exception ex)
                {
                    FileOps.AppendLog(log, "清理旧主程序失败 " + name + "：" + ex.Message);
                }
            }
        }

        private static void StartTarget(string target, string launch, string stage, string log)
        {
            string exe = launch;
            if (string.IsNullOrEmpty(exe) || !File.Exists(exe))
            {
                string[] staged = Directory.GetFiles(stage, "RMTv*.exe", SearchOption.TopDirectoryOnly);
                if (staged.Length > 0)
                    exe = Path.Combine(target, Path.GetFileName(staged[0]));
            }

            if (string.IsNullOrEmpty(exe) || !File.Exists(exe))
            {
                FileOps.AppendLog(log, "没有找到可启动的主程序，跳过自动启动");
                return;
            }

            try
            {
                ProcessStartInfo psi = new ProcessStartInfo(exe);
                psi.WorkingDirectory = target;
                psi.UseShellExecute = true;
                Process.Start(psi);
                FileOps.AppendLog(log, "已启动 " + exe);
            }
            catch (Exception ex)
            {
                FileOps.AppendLog(log, "启动失败：" + ex.Message);
            }
        }

        /// <summary>
        /// 装完之后先确认装进去的那个 RMT.Update.exe 能跑。
        ///
        /// 探针用 check + 一个不存在的 --release-file：正常实现会「写结果文件、以非 0 退出」，
        /// 所以判断标准是「进程按时结束 + 结果文件出现」，不依赖退出码。
        /// 这也意味着 check 在失败时也必须写出 --out，这条行为不能改。
        ///
        /// 探针不过就把备份里的旧 exe 盖回去：本次其它文件照常更新，只是更新器停在旧版，
        /// 下次还能更新——总好过换上一个跑不起来的 exe，从此再没有更新入口。
        /// </summary>
        private static void VerifySelf(string target, string backup, string log)
        {
            string rel = Path.Combine("Plugins", "Update", "RMT.Update.exe");
            string exe = Path.Combine(target, rel);
            if (!File.Exists(exe))
                return;

            string probeDir = Path.Combine(Path.GetTempPath(), "RMTUpdate");
            string probeOut = Path.Combine(probeDir, "selfcheck.json");
            try
            {
                Directory.CreateDirectory(probeDir);
                if (File.Exists(probeOut))
                    File.Delete(probeOut);
            }
            catch { }

            bool ok = false;
            Process p = null;
            try
            {
                string cmd = "check --release-file \"" + Path.Combine(probeDir, "no-such-release.json") +
                             "\" --out \"" + probeOut + "\" --lang en";
                ProcessStartInfo psi = new ProcessStartInfo(exe, cmd);
                psi.UseShellExecute = false;
                psi.CreateNoWindow = true;
                psi.WorkingDirectory = target;
                p = Process.Start(psi);
                ok = p.WaitForExit(15000) && File.Exists(probeOut);
            }
            catch (Exception ex)
            {
                FileOps.AppendLog(log, "更新器自检无法启动：" + ex.Message);
            }
            finally
            {
                if (p != null)
                {
                    try
                    {
                        if (!p.HasExited)
                            p.Kill();
                    }
                    catch { }
                }
                try { File.Delete(probeOut); } catch { }
            }

            if (ok)
            {
                FileOps.AppendLog(log, "更新器自检通过");
                return;
            }

            string bak = Path.Combine(backup, rel);
            if (!File.Exists(bak))
            {
                FileOps.AppendLog(log, "新版更新器自检失败，且没有旧版可回退");
                return;
            }

            try
            {
                FileOps.CopyWithRetry(bak, exe, 3);
                FileOps.AppendLog(log, "新版更新器自检失败，已回退旧版更新器");
            }
            catch (Exception ex)
            {
                FileOps.AppendLog(log, "回退旧版更新器失败：" + ex.Message);
            }
        }

        // ---------- 自我搬运 ----------

        private static int Relocate(string[] rawArgs)
        {
            string root = Path.Combine(Path.GetTempPath(), "RMTUpdate");
            string work = Path.Combine(root, Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(work);
            SweepWorkDirs(root, work);

            string self = Environment.GetCommandLineArgs()[0];
            string copy = Path.Combine(work, "RMT.Update.exe");
            File.Copy(self, copy, true);

            List<string> list = new List<string>(rawArgs);
            list.Add("--relocated");
            list.Add(work);

            StringBuilder sb = new StringBuilder();
            foreach (string a in list)
            {
                if (sb.Length > 0)
                    sb.Append(' ');
                sb.Append(Quote(a));
            }

            ProcessStartInfo psi = new ProcessStartInfo(copy, sb.ToString());
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            psi.WorkingDirectory = work;
            Process.Start(psi);

            return 0;
        }

        /// <summary>
        /// 每次搬运前把上次遗留的工作目录收掉（成功那轮已清 stage/package/backup，
        /// 只剩一个 exe 副本，但中途崩掉的会留下整包）。正在被别的实例占用的目录跳过。
        /// </summary>
        private static void SweepWorkDirs(string root, string current)
        {
            try
            {
                foreach (string dir in Directory.GetDirectories(root))
                {
                    if (string.Equals(dir, current, StringComparison.OrdinalIgnoreCase))
                        continue;
                    // 刚建出来的是别的实例（还没把 exe 拷进去，独占检测不出来），别动
                    try
                    {
                        if (DateTime.UtcNow - Directory.GetCreationTimeUtc(dir) < TimeSpan.FromMinutes(2))
                            continue;
                    }
                    catch { }
                    if (FileOps.IsDirInUse(dir))
                        continue;
                    FileOps.TryDeleteDir(dir);
                }
            }
            catch
            {
            }
        }

        private static string Quote(string value)
        {
            if (string.IsNullOrEmpty(value))
                return "\"\"";
            if (value.IndexOf(' ') < 0 && value.IndexOf('\t') < 0 && value.IndexOf('"') < 0)
                return value;
            return "\"" + value.Replace("\"", "\\\"") + "\"";
        }
        private static int Fail(string message)
        {
            try
            {
                MessageBox.Show(message, "RMT Update", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            catch { }
            return 1;
        }
    }
}
