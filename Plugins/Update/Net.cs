// 网络访问：版本信息拉取、安装包下载、SHA256 校验。
// 平台无关（.NET Framework / .NET 都有的 HttpWebRequest），只有 TLS 开关是 Windows 侧的历史包袱。
using System;
using System.IO;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Threading;

namespace RmtUpdate
{
    internal static class Net
    {
        private const string UserAgent = "RMT-Update/1.0";

        /// <summary>Win7 默认只开 TLS 1.0，站点普遍要求 TLS 1.2；3072 = Tls12。</summary>
        public static void ConfigureTls()
        {
            try { ServicePointManager.SecurityProtocol |= (SecurityProtocolType)3072; }
            catch { }
        }

        public static string GetString(string url, int timeoutSec)
        {
            Exception last = null;
            for (int attempt = 1; attempt <= 3; attempt++)
            {
                try
                {
                    HttpWebRequest req = Create(url, timeoutSec);
                    using (WebResponse resp = req.GetResponse())
                    using (Stream s = resp.GetResponseStream())
                    using (StreamReader r = new StreamReader(s, Encoding.UTF8))
                    {
                        return r.ReadToEnd();
                    }
                }
                catch (WebException we)
                {
                    // 404 是仓库或 Release 不存在：重试没用，直接报清楚。
                    // 403/429 是限流（走 gh-proxy 时它给 API 注入了 token，额度 5000/h，
                    // 撞到的多是瞬时限流），等一会儿再来，三次都不行才认输。
                    HttpWebResponse er = we.Response as HttpWebResponse;
                    int code = er == null ? 0 : (int)er.StatusCode;
                    if (code == 404)
                        throw new IOException("找不到仓库或 Release，请检查仓库名", we);

                    last = we;
                    if (attempt < 3)
                        Thread.Sleep(code == 403 || code == 429 ? 1500 * attempt : 600 * attempt);
                    if (attempt == 3 && (code == 403 || code == 429))
                        throw new IOException("GitHub 接口限流，请稍后再试", we);
                }
                catch (Exception ex)
                {
                    last = ex;
                    if (attempt < 3)
                        Thread.Sleep(600 * attempt);
                }
            }
            throw new IOException("获取版本信息失败：" + last.Message, last);
        }

        /// <summary>下载到 dest；返回 false 表示被调用方取消。</summary>
        public static bool Download(string url, string dest, Action<long, long> progress, Func<bool> cancelled)
        {
            Exception last = null;
            for (int attempt = 1; attempt <= 3; attempt++)
            {
                if (cancelled != null && cancelled())
                    return false;
                try
                {
                    DownloadOnce(url, dest, progress, cancelled);
                    return true;
                }
                catch (OperationCanceledException)
                {
                    return false;
                }
                catch (Exception ex)
                {
                    last = ex;
                    try { if (File.Exists(dest)) File.Delete(dest); }
                    catch { }
                    if (attempt < 3)
                        Thread.Sleep(800 * attempt);
                }
            }
            throw new IOException("下载安装包失败：" + last.Message, last);
        }

        private static void DownloadOnce(string url, string dest, Action<long, long> progress, Func<bool> cancelled)
        {
            HttpWebRequest req = Create(url, 0);
            using (WebResponse resp = req.GetResponse())
            using (Stream input = resp.GetResponseStream())
            using (FileStream output = new FileStream(dest, FileMode.Create, FileAccess.Write, FileShare.None))
            {
                long total = resp.ContentLength;
                long done = 0;
                byte[] buf = new byte[81920];
                int lastReport = Environment.TickCount;

                while (true)
                {
                    if (cancelled != null && cancelled())
                        throw new OperationCanceledException();

                    int read = input.Read(buf, 0, buf.Length);
                    if (read <= 0)
                        break;

                    output.Write(buf, 0, read);
                    done += read;

                    if (progress != null && Environment.TickCount - lastReport >= 150)
                    {
                        lastReport = Environment.TickCount;
                        progress(done, total);
                    }
                }

                if (progress != null)
                    progress(done, total > 0 ? total : done);
            }
        }

        private static HttpWebRequest Create(string url, int timeoutSec)
        {
            HttpWebRequest req = (HttpWebRequest)WebRequest.Create(url);
            req.UserAgent = UserAgent;
            req.Method = "GET";
            req.AllowAutoRedirect = true;
            req.Timeout = timeoutSec > 0 ? timeoutSec * 1000 : 30000;
            req.ReadWriteTimeout = timeoutSec > 0 ? timeoutSec * 1000 : 120000;
            req.Proxy = WebRequest.DefaultWebProxy;
            return req;
        }

        public static string Sha256File(string path)
        {
            using (SHA256 sha = SHA256.Create())
            using (FileStream fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read))
            {
                byte[] hash = sha.ComputeHash(fs);
                StringBuilder sb = new StringBuilder(hash.Length * 2);
                foreach (byte b in hash)
                    sb.Append(b.ToString("x2"));
                return sb.ToString();
            }
        }
    }
}
