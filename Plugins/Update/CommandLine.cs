// 极简命令行解析：只认 --key value 与 --flag 两种形式，够用就行。
using System;
using System.Collections.Generic;

namespace RmtUpdate
{
    internal sealed class CommandLine
    {
        private readonly Dictionary<string, string> _map =
            new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        public static CommandLine Parse(string[] args, int start)
        {
            CommandLine cl = new CommandLine();
            for (int i = start; i < args.Length; i++)
            {
                string a = args[i];
                if (a == null || !a.StartsWith("--", StringComparison.Ordinal))
                    continue;

                string key = a.Substring(2);
                string value = "1";
                if (i + 1 < args.Length && !args[i + 1].StartsWith("--", StringComparison.Ordinal))
                {
                    value = args[i + 1];
                    i++;
                }
                cl._map[key] = value;
            }
            return cl;
        }

        public bool Has(string key)
        {
            return _map.ContainsKey(key);
        }

        public string Get(string key, string fallback)
        {
            string v;
            return _map.TryGetValue(key, out v) && !string.IsNullOrEmpty(v) ? v : fallback;
        }

        public string Required(string key)
        {
            string v = Get(key, "");
            if (string.IsNullOrEmpty(v))
                throw new ArgumentException("缺少参数 --" + key);
            return v;
        }

        public int GetInt(string key, int fallback)
        {
            int v;
            return int.TryParse(Get(key, ""), out v) ? v : fallback;
        }
    }
}
