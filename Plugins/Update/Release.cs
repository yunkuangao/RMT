// GitHub Release 模型、版本号、check 结果。
//
// 更新信息全部取自 GitHub REST API，发布侧不产出任何额外清单文件：
//   tag_name            → 版本号
//   body                → 更新说明（原文是 markdown，这里剥成纯文本给弹窗用）
//   prerelease          → 通道
//   assets[].digest     → sha256（GitHub 上传时自动算，等价于我们自己算一遍）
//   assets[].browser_download_url / size → 下载地址与体积
//
// 老版本号（1.3F4）不是 semver，GitHub 的 latest 只按 prerelease 标记筛，所以：
//   正式版通道读 /releases/latest（API 自带非预发布过滤）
//   测试版通道读 /releases 列表，自己按版本号取最高的（正式版也在里面，谁新用谁）
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Xml;

namespace RmtUpdate
{
    /// <summary>版本号：1.2.3 或 1.2.3F4（F 后缀 = 预发布）。</summary>
    internal sealed class AppVersion : IComparable<AppVersion>
    {
        private readonly int[] _nums;
        private readonly int _pre; // -1 = 正式版；>=0 = 预发布序号

        private AppVersion(int[] nums, int pre)
        {
            _nums = nums;
            _pre = pre;
        }

        public static AppVersion Parse(string text)
        {
            AppVersion v;
            if (!TryParse(text, out v))
                throw new FormatException("无法识别的版本号：" + text);
            return v;
        }

        public static bool TryParse(string text, out AppVersion version)
        {
            version = null;
            if (string.IsNullOrEmpty(text))
                return false;

            // tag 有 v1.3F4 / RMTv1.3F4 / 1.3F4 三种写法，统一剥掉前缀
            string s = text.Trim();
            if (s.StartsWith("RMT", StringComparison.OrdinalIgnoreCase))
                s = s.Substring(3);
            if (s.Length > 0 && (s[0] == 'v' || s[0] == 'V'))
                s = s.Substring(1);

            int pre = -1;
            int f = s.IndexOf('F');
            if (f < 0)
                f = s.IndexOf('f');
            if (f >= 0)
            {
                string tail = s.Substring(f + 1);
                if (!int.TryParse(tail, NumberStyles.Integer, CultureInfo.InvariantCulture, out pre))
                    return false;
                s = s.Substring(0, f);
            }

            string[] parts = s.Split('.');
            if (parts.Length == 0 || parts.Length > 4)
                return false;

            int[] nums = new int[parts.Length];
            for (int i = 0; i < parts.Length; i++)
            {
                if (!int.TryParse(parts[i], NumberStyles.Integer, CultureInfo.InvariantCulture, out nums[i]))
                    return false;
            }

            version = new AppVersion(nums, pre);
            return true;
        }

        public int CompareTo(AppVersion other)
        {
            if (other == null)
                return 1;

            int main = CompareMain(other);
            if (main != 0)
                return main;

            // 同一主版本下：正式版高于任何预发布版，预发布之间比序号
            if (_pre < 0 && other._pre < 0)
                return 0;
            if (_pre < 0)
                return 1;
            if (other._pre < 0)
                return -1;
            return _pre == other._pre ? 0 : (_pre < other._pre ? -1 : 1);
        }

        /// <summary>只比数字段、忽略 F 后缀。min_version 用它判断「版本太老」，不能把 1.3F3 判成比 1.3 老。</summary>
        public int CompareMain(AppVersion other)
        {
            if (other == null)
                return 1;

            int len = Math.Max(_nums.Length, other._nums.Length);
            for (int i = 0; i < len; i++)
            {
                int a = i < _nums.Length ? _nums[i] : 0;
                int b = i < other._nums.Length ? other._nums[i] : 0;
                if (a != b)
                    return a < b ? -1 : 1;
            }
            return 0;
        }

        public bool IsNewerThan(AppVersion other)
        {
            return CompareTo(other) > 0;
        }

        /// <summary>带 F 后缀 = 预发布。atom feed 里没有 prerelease 字段，只能靠版本号自己判断。</summary>
        public bool IsPrerelease
        {
            get { return _pre >= 0; }
        }

        public override string ToString()
        {
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < _nums.Length; i++)
            {
                if (i > 0)
                    sb.Append('.');
                sb.Append(_nums[i]);
            }
            if (_pre >= 0)
            {
                sb.Append('F');
                sb.Append(_pre);
            }
            return sb.ToString();
        }
    }

    internal sealed class AssetInfo
    {
        public string name;
        public string url;
        public string sha256;
        public long size;
    }

    /// <summary>一个 GitHub Release。字段缺失一律按「没有」处理，不抛异常。</summary>
    internal sealed class Release
    {
        public string Tag;
        public AppVersion Version;
        public string Notes;
        public bool Prerelease;
        public bool Draft;
        /// <summary>来自 releases.atom 而不是 API：没有 assets，下载地址只能按命名约定拼。</summary>
        public bool FromFeed;
        public readonly List<AssetInfo> Assets = new List<AssetInfo>();

        /// <summary>找当前架构的安装包：先按 RMTv&lt;版本&gt;_&lt;arch&gt;.zip 精确匹配，再退回后缀匹配。</summary>
        public AssetInfo FindAsset(string arch)
        {
            if (string.IsNullOrEmpty(arch))
                return null;

            string exact = "RMTv" + Version + "_" + arch + ".zip";
            foreach (AssetInfo a in Assets)
            {
                if (string.Equals(a.name, exact, StringComparison.OrdinalIgnoreCase))
                    return a;
            }

            string suffix = "_" + arch + ".zip";
            foreach (AssetInfo a in Assets)
            {
                if (a.name != null && a.name.EndsWith(suffix, StringComparison.OrdinalIgnoreCase))
                    return a;
            }
            return null;
        }

        public static Release FromJson(Dictionary<string, object> obj)
        {
            string tag = Json.GetString(obj, "tag_name");
            if (string.IsNullOrEmpty(tag))
                tag = Json.GetString(obj, "name");

            AppVersion ver;
            if (!AppVersion.TryParse(tag, out ver))
            {
                // 版本号不一定在 tag 里：RMT 的测试版用过固定 tag（RMT-Pre）反复覆盖同一个
                // Release，真正的版本号只写在标题上。tag_name 解析不了就退回标题再试一次。
                if (!AppVersion.TryParse(Json.GetString(obj, "name"), out ver))
                    throw new InvalidDataException("无法识别的 Release 版本号：" + (tag ?? "(空)"));
            }

            Release r = new Release();
            r.Tag = tag;
            r.Version = ver;
            r.Prerelease = Json.GetBool(obj, "prerelease");
            r.Draft = Json.GetBool(obj, "draft");
            r.Notes = PlainNotes(Json.GetString(obj, "body"), 10);

            List<object> assets = Json.GetArray(obj, "assets");
            if (assets != null)
            {
                foreach (object o in assets)
                {
                    Dictionary<string, object> d = o as Dictionary<string, object>;
                    if (d == null)
                        continue;
                    AssetInfo info = new AssetInfo();
                    info.name = Json.GetString(d, "name");
                    info.url = Json.GetString(d, "browser_download_url");
                    info.size = Json.GetLong(d, "size");
                    // digest 形如 "sha256:abc..."，老 release 可能没有这个字段
                    string digest = Json.GetString(d, "digest");
                    if (!string.IsNullOrEmpty(digest))
                    {
                        info.sha256 = digest.StartsWith("sha256:", StringComparison.OrdinalIgnoreCase)
                            ? digest.Substring(7)
                            : digest;
                    }
                    r.Assets.Add(info);
                }
            }
            return r;
        }

        /// <summary>既能吃 /releases/latest 的单个对象，也能吃 /releases 的数组。</summary>
        public static List<Release> ParseList(string json)
        {
            if (string.IsNullOrEmpty(json))
                throw new InvalidDataException("Release 数据为空");

            List<Release> list = new List<Release>();
            object root = Json.Parse(json);
            List<object> arr = root as List<object>;
            if (arr != null)
            {
                foreach (object o in arr)
                {
                    Dictionary<string, object> d = o as Dictionary<string, object>;
                    if (d == null)
                        continue;
                    try { list.Add(FromJson(d)); }
                    catch { } // 单个 release 坏了不该让整次检查失败
                }
            }
            else
            {
                list.Add(FromJson(Json.AsObject(root)));
            }

            if (list.Count == 0)
                throw new InvalidDataException("没有可用的 Release");
            return list;
        }

        /// <summary>
        /// 解析 https://github.com/&lt;repo&gt;/releases.atom。
        ///
        /// 只在 API 被限流时用：gh-proxy 注入的是它自己的共享 token（5000/h），很容易被打满，
        /// 而 /releases 列表接口没有 CDN 缓存，打满就 403。/releases.atom 由 github.com 直接提供，
        /// 不占 API 额度、也能被缓存，代价是拿不到 assets——没有 sha256、没有体积，
        /// 下载地址只能按 RMTv&lt;版本&gt;_&lt;架构&gt;.zip 的命名约定拼。
        /// 所以这条路只保证「知道有没有新版」。
        /// </summary>
        public static List<Release> ParseAtom(string xml, int maxLines)
        {
            List<Release> list = new List<Release>();
            if (string.IsNullOrEmpty(xml))
                return list;

            XmlDocument doc = new XmlDocument();
            doc.XmlResolver = null;
            doc.LoadXml(xml);

            foreach (XmlNode entry in doc.GetElementsByTagName("entry"))
            {
                string tag = "";
                string title = "";
                string html = "";

                foreach (XmlNode child in entry.ChildNodes)
                {
                    if (child.Name == "title")
                    {
                        title = (child.InnerText ?? "").Trim();
                    }
                    else if (child.Name == "content")
                    {
                        html = child.InnerText ?? "";
                    }
                    else if (child.Name == "link")
                    {
                        XmlAttribute rel = child.Attributes["rel"];
                        XmlAttribute hrefAttr = child.Attributes["href"];
                        string href = hrefAttr == null ? "" : hrefAttr.Value;
                        if (href != "" && (rel == null || rel.Value == "alternate"))
                            tag = TagFromHref(href);
                    }
                }

                // tag 才是发布标识，标题只是兜底（固定 tag 发预览版时版本号只在标题里）
                AppVersion ver;
                if (!AppVersion.TryParse(tag, out ver) && !AppVersion.TryParse(title, out ver))
                    continue;

                Release r = new Release();
                r.Tag = tag != "" ? tag : title;
                r.Version = ver;
                r.Prerelease = ver.IsPrerelease;
                r.FromFeed = true;
                r.Notes = HtmlToText(html, maxLines);
                list.Add(r);
            }

            return list;
        }

        /// <summary>.../releases/tag/RMTv1.3F2 → RMTv1.3F2</summary>
        private static string TagFromHref(string href)
        {
            int i = href.LastIndexOf('/');
            return (i >= 0 && i + 1 < href.Length) ? href.Substring(i + 1) : href;
        }

        /// <summary>release body 在 atom 里是转义过的 HTML，剥成弹窗能直接显示的纯文本。</summary>
        private static string HtmlToText(string html, int maxLines)
        {
            if (string.IsNullOrEmpty(html))
                return "";

            string s = html.Replace("\r\n", "\n").Replace('\r', '\n');
            s = Regex.Replace(s, "<h[1-6][^>]*>", "\n【");
            s = Regex.Replace(s, "</h[1-6]>", "】\n");
            s = Regex.Replace(s, "<li[^>]*>", "\n· ");
            s = Regex.Replace(s, "<br\\s*/?>", "\n");
            s = Regex.Replace(s, "</(p|div|ul|ol|blockquote)>", "\n");
            s = Regex.Replace(s, "<[^>]+>", "");
            s = s.Replace("&lt;", "<").Replace("&gt;", ">").Replace("&quot;", "\"")
                 .Replace("&#39;", "'").Replace("&nbsp;", " ").Replace("&amp;", "&");

            List<string> buf = new List<string>();
            foreach (string raw in s.Split('\n'))
            {
                if (buf.Count >= maxLines)
                    break;

                string t = CleanInline(raw).Trim();
                if (t.Length == 0)
                    continue;

                // 标题行："【RMTv1.3F2更新内容】" 剥掉版本号就只剩「更新内容」，整行丢
                if (t.Length > 3 && t.StartsWith("【", StringComparison.Ordinal) && t.EndsWith("】", StringComparison.Ordinal))
                {
                    string inner = StripVersion(t.Substring(1, t.Length - 2));
                    if (inner.Length == 0 || IsNoiseHeading(inner))
                        continue;
                    buf.Add("【" + inner + "】");
                    continue;
                }

                t = CleanInline(StripVersion(t));
                if (t.Length > 0 && !IsNoiseHeading(t))
                    buf.Add(t);
            }

            return string.Join("\n", buf.ToArray());
        }

        /// <summary>
        /// 把 release body 的 markdown 剥成弹窗能直接显示的纯文本：
        /// 标题转【小节】、去掉加粗/行内代码、列表项换成「· 」，最多 maxLines 行。
        /// </summary>
        public static string PlainNotes(string markdown, int maxLines)
        {
            if (string.IsNullOrEmpty(markdown))
                return "";

            string[] lines = markdown.Replace("\r\n", "\n").Replace('\r', '\n').Split('\n');
            List<string> buf = new List<string>();

            foreach (string raw in lines)
            {
                if (buf.Count >= maxLines)
                    break;

                string t = raw.Trim();
                if (t.Length == 0 || t.StartsWith("<!--", StringComparison.Ordinal))
                    continue;

                int h = 0;
                while (h < t.Length && t[h] == '#')
                    h++;
                if (h > 0)
                {
                    string title = StripVersion(t.Substring(h).Trim());
                    if (title.Length > 0 && !IsNoiseHeading(title))
                        buf.Add("【" + CleanInline(title) + "】");
                    continue;
                }

                if (t.StartsWith("- ") || t.StartsWith("* ") || t.StartsWith("+ "))
                    t = "· " + t.Substring(2).Trim();

                t = CleanInline(t);
                if (t.Length > 0)
                    buf.Add(t);
            }

            return string.Join("\n", buf.ToArray());
        }

        /// <summary>「## RMTv1.3F3更新内容」这种标题里只剩版本号，剥完为空就该整行丢掉。</summary>
        private static string StripVersion(string text)
        {
            int i = 0;
            if (text.StartsWith("RMT", StringComparison.OrdinalIgnoreCase))
                i = 3;
            if (i < text.Length && (text[i] == 'v' || text[i] == 'V'))
                i++;

            int start = i;
            while (i < text.Length && (char.IsDigit(text[i]) || text[i] == '.' || text[i] == 'F' || text[i] == 'f'))
                i++;

            // 至少像个版本号（有点号）才剥，避免把「更新」这类正常标题吃掉
            if (i > start && text.Substring(start, i - start).IndexOf('.') > 0)
                return text.Substring(i).Trim();
            return text;
        }

        private static bool IsNoiseHeading(string title)
        {
            string s = title.Trim();
            if (s.Length == 0)
                return true;
            string[] noise = { "更新内容", "更新", "更新说明", "更新日志", "release notes", "changelog", "changes" };
            foreach (string n in noise)
            {
                if (string.Equals(s, n, StringComparison.OrdinalIgnoreCase))
                    return true;
            }
            return false;
        }

        private static string CleanInline(string t)
        {
            t = t.Replace("**", "").Replace("__", "").Replace("`", "");
            // [文字](链接) → 文字；找不到配对就原样保留，不能死循环
            while (true)
            {
                int lb = t.IndexOf('[');
                if (lb < 0)
                    break;
                int rb = t.IndexOf(']', lb + 1);
                if (rb < 0)
                    break;
                if (rb + 1 >= t.Length || t[rb + 1] != '(')
                    break;
                int rp = t.IndexOf(')', rb + 2);
                if (rp < 0)
                    break;
                t = t.Substring(0, lb) + t.Substring(lb + 1, rb - lb - 1) + t.Substring(rp + 1);
            }
            return t.Trim();
        }
    }

    /// <summary>check 模式写给宿主的 JSON（字段名给 AHK 用，保持小写下划线）。</summary>
    internal sealed class CheckResult
    {
        public bool ok;
        public string error;
        public string current;
        public string latest;
        public bool has_update;
        public string notes;
        public string url;
        public string sha256;
        public long size;
        /// <summary>命中的 Release tag。宿主拿它当安装参数，不再需要清单地址。</summary>
        public string tag;
        public string channel;
        public string checked_at;

        public string ToJson()
        {
            StringBuilder sb = new StringBuilder();
            sb.Append("{\"ok\":").Append(ok ? "true" : "false");
            sb.Append(",\"error\":").Append(Json.Quote(error));
            sb.Append(",\"current\":").Append(Json.Quote(current));
            sb.Append(",\"latest\":").Append(Json.Quote(latest));
            sb.Append(",\"has_update\":").Append(has_update ? "true" : "false");
            sb.Append(",\"notes\":").Append(Json.Quote(notes));
            sb.Append(",\"url\":").Append(Json.Quote(url));
            sb.Append(",\"sha256\":").Append(Json.Quote(sha256));
            sb.Append(",\"size\":").Append(size.ToString(CultureInfo.InvariantCulture));
            sb.Append(",\"tag\":").Append(Json.Quote(tag));
            sb.Append(",\"channel\":").Append(Json.Quote(channel));
            sb.Append(",\"checked_at\":").Append(Json.Quote(checked_at));
            sb.Append('}');
            return sb.ToString();
        }
    }
}
