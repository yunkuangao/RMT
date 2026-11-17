// 界面与文案。
// 这里也是平台相关的一层：现在用 WinForms（.NET Framework 自带，零依赖）；
// 将来换 .NET 8 / 跨平台时，只要替换 ProgressForm 的实现，其他文件不用动。
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;

namespace RmtUpdate
{
    internal static class Strings
    {
        private static readonly Dictionary<string, string> Zh = new Dictionary<string, string>
        {
            { "title", "RMT 更新" },
            { "preparing", "准备中…" },
            { "downloading", "正在下载 {0}%" },
            { "downloading_unknown", "正在下载…" },
            { "verifying", "正在校验安装包…" },
            { "waiting", "正在等待 RMT 退出…" },
            { "extracting", "正在解压…" },
            { "applying", "正在替换文件 {0}/{1}" },
            { "restarting", "更新完成，正在启动 RMT…" },
            { "done", "更新完成。" },
            { "failed", "更新失败：{0}" },
            { "rolledback", "已还原到更新前的文件。" },
            { "cancel", "取消" },
            { "close", "关闭" },
            { "busy", "更新正在进行，请不要关闭这个窗口。" },
            { "no_write", "没有写入权限：{0}\n请把 RMT 放到有写权限的目录，或手动下载完整包。" },
            { "no_asset", "这个版本没有适用于当前架构的安装包：{0}" },
            { "no_url", "没有拿到安装包地址，无法更新。" },
            { "cancelled", "已取消更新。" },
            { "detail_size", "{0} / {1}" }
        };

        private static readonly Dictionary<string, string> En = new Dictionary<string, string>
        {
            { "title", "RMT Update" },
            { "preparing", "Preparing…" },
            { "downloading", "Downloading {0}%" },
            { "downloading_unknown", "Downloading…" },
            { "verifying", "Verifying package…" },
            { "waiting", "Waiting for RMT to exit…" },
            { "extracting", "Extracting…" },
            { "applying", "Applying files {0}/{1}" },
            { "restarting", "Update complete, starting RMT…" },
            { "done", "Update complete." },
            { "failed", "Update failed: {0}" },
            { "rolledback", "Previous files have been restored." },
            { "cancel", "Cancel" },
            { "close", "Close" },
            { "busy", "Update in progress, please keep this window open." },
            { "no_write", "No write permission: {0}\nMove RMT to a writable folder or download the full package manually." },
            { "no_asset", "No package for this architecture: {0}" },
            { "no_url", "No download URL available, cannot update." },
            { "cancelled", "Update cancelled." },
            { "detail_size", "{0} / {1}" }
        };

        public static string L(string lang, string key)
        {
            Dictionary<string, string> map = (lang != null && lang.StartsWith("en", StringComparison.OrdinalIgnoreCase)) ? En : Zh;
            string text;
            if (!map.TryGetValue(key, out text))
                text = Zh.TryGetValue(key, out text) ? text : key;
            return text;
        }

        public static string Format(string pattern, params object[] args)
        {
            try { return string.Format(pattern, args); }
            catch { return pattern; }
        }
    }

    /// <summary>跟随进度显示的小窗：无边框之外的普通对话框，深色自绘进度条。</summary>
    internal sealed class ProgressForm : Form
    {
        private readonly string _lang;
        private readonly Label _status;
        private readonly BarPanel _bar;
        private readonly Button _button;
        private volatile bool _cancelRequested;
        private volatile bool _working = true;
        private int _percent;

        /// <summary>更新结果：0 成功 / 1 失败 / 2 取消，由 Program 读取。</summary>
        public int ExitCode;

        public ProgressForm(string lang)
        {
            _lang = lang ?? "zh";

            Text = Strings.L(_lang, "title");
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            TopMost = true;
            ShowInTaskbar = true;
            BackColor = Color.FromArgb(32, 32, 32);
            ForeColor = Color.FromArgb(230, 230, 230);
            ClientSize = new Size(440, 150);
            Font = new Font("Microsoft YaHei UI", 9F);

            _status = new Label();
            _status.AutoSize = false;
            _status.SetBounds(24, 26, 392, 44);
            _status.ForeColor = Color.FromArgb(230, 230, 230);
            _status.Text = Strings.L(_lang, "preparing");
            Controls.Add(_status);

            _bar = new BarPanel();
            _bar.SetBounds(24, 74, 392, 8);
            Controls.Add(_bar);

            _button = new Button();
            _button.SetBounds(340, 100, 76, 28);
            _button.Text = Strings.L(_lang, "cancel");
            _button.FlatStyle = FlatStyle.Flat;
            _button.FlatAppearance.BorderColor = Color.FromArgb(90, 90, 90);
            _button.ForeColor = Color.FromArgb(230, 230, 230);
            _button.BackColor = Color.FromArgb(48, 48, 48);
            _button.Click += delegate { OnButton(); };
            Controls.Add(_button);

            FormClosing += OnClosing;
        }

        public bool CancelRequested { get { return _cancelRequested; } }

        public void Report(int percent, string text)
        {
            if (IsDisposed)
                return;
            if (InvokeRequired)
            {
                try { BeginInvoke(new Action<int, string>(Report), percent, text); }
                catch { }
                return;
            }
            SetProgress(percent, text);
        }

        private void SetProgress(int percent, string text)
        {
            if (percent >= 0)
            {
                _percent = Math.Max(0, Math.Min(100, percent));
                _bar.Percent = _percent;
                _bar.Invalidate();
            }
            if (!string.IsNullOrEmpty(text))
                _status.Text = text;
        }

        /// <summary>替换阶段不允许取消：文件已经动了一半，中断比跑完更危险。</summary>
        public void AllowCancel(bool allow)
        {
            if (IsDisposed)
                return;
            if (InvokeRequired)
            {
                try { BeginInvoke(new Action<bool>(AllowCancel), allow); }
                catch { }
                return;
            }
            _button.Enabled = allow;
        }

        public void Finish(bool ok, string message)
        {
            if (IsDisposed)
                return;
            if (InvokeRequired)
            {
                try { BeginInvoke(new Action<bool, string>(Finish), ok, message); }
                catch { }
                return;
            }

            _working = false;
            _percent = ok ? 100 : _percent;
            _bar.Percent = _percent;
            _bar.Invalidate();
            _status.Text = string.IsNullOrEmpty(message) ? Strings.L(_lang, "restarting") : message;
            _button.Enabled = true;
            _button.Text = Strings.L(_lang, "close");

            if (ok)
            {
                System.Windows.Forms.Timer t = new System.Windows.Forms.Timer();
                t.Interval = 1200;
                t.Tick += delegate { t.Stop(); Close(); };
                t.Start();
            }
        }

        private void OnButton()
        {
            if (_working)
            {
                _cancelRequested = true;
                _button.Enabled = false;
                _status.Text = Strings.L(_lang, "cancelled");
                return;
            }
            Close();
        }

        private void OnClosing(object sender, FormClosingEventArgs e)
        {
            if (_working && !_cancelRequested)
            {
                e.Cancel = true;
                _status.Text = Strings.L(_lang, "busy");
            }
        }

        /// <summary>自绘进度条，免得 ProgressBar 的绿色在深色窗里突兀。</summary>
        private sealed class BarPanel : Panel
        {
            public int Percent;

            public BarPanel()
            {
                DoubleBuffered = true;
                BackColor = Color.FromArgb(32, 32, 32);
            }

            protected override void OnPaint(PaintEventArgs e)
            {
                base.OnPaint(e);
                Rectangle track = new Rectangle(0, 0, Width, Height);
                using (SolidBrush bg = new SolidBrush(Color.FromArgb(60, 60, 60)))
                    e.Graphics.FillRectangle(bg, track);
                int w = (int)(Width * (Percent / 100.0));
                if (w > 0)
                {
                    using (SolidBrush fg = new SolidBrush(Color.FromArgb(0, 160, 220)))
                        e.Graphics.FillRectangle(fg, new Rectangle(0, 0, w, Height));
                }
            }
        }
    }
}
