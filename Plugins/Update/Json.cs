// 极简 JSON：只做 Release JSON 解析和 check 结果输出，不引第三方库，也不依赖 DataContract。
// （之所以不用 DataContractJsonSerializer：它把 Dictionary 表现成 [{"Key":..,"Value":..}]，
//   和手写的 update.json 对不上，改格式比换解析器更亏。）
// 平台无关，跨平台时可原样搬走。
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace RmtUpdate
{
    internal static class Json
    {
        // ---------- 读 ----------

        public static object Parse(string text)
        {
            if (!string.IsNullOrEmpty(text) && text[0] == '\uFEFF')
                text = text.Substring(1); // 别人用带 BOM 的编辑器改过 JSON 也认
            int i = 0;
            object value = ParseValue(text, ref i);
            SkipWs(text, ref i);
            if (i < text.Length)
                throw new FormatException("JSON 尾部有多余内容（位置 " + i + "）");
            return value;
        }

        public static Dictionary<string, object> AsObject(object value)
        {
            Dictionary<string, object> dict = value as Dictionary<string, object>;
            if (dict == null)
                throw new FormatException("期望 JSON 对象");
            return dict;
        }

        public static Dictionary<string, object> GetObject(Dictionary<string, object> obj, string key)
        {
            object v;
            if (obj == null || !obj.TryGetValue(key, out v) || v == null)
                return null;
            return v as Dictionary<string, object>;
        }

        public static string GetString(Dictionary<string, object> obj, string key)
        {
            object v;
            if (obj == null || !obj.TryGetValue(key, out v) || v == null)
                return null;
            string s = v as string;
            return s ?? v.ToString();
        }

        public static long GetLong(Dictionary<string, object> obj, string key)
        {
            object v;
            if (obj == null || !obj.TryGetValue(key, out v) || v == null)
                return 0;
            if (v is double)
                return (long)(double)v;
            long n;
            return long.TryParse(v.ToString(), out n) ? n : 0;
        }

        public static bool GetBool(Dictionary<string, object> obj, string key)
        {
            object v;
            if (obj == null || !obj.TryGetValue(key, out v) || v == null)
                return false;
            if (v is bool)
                return (bool)v;
            return string.Equals(v.ToString(), "true", StringComparison.OrdinalIgnoreCase);
        }

        public static List<object> GetArray(Dictionary<string, object> obj, string key)
        {
            object v;
            if (obj == null || !obj.TryGetValue(key, out v) || v == null)
                return null;
            return v as List<object>;
        }

        private static object ParseValue(string s, ref int i)
        {
            SkipWs(s, ref i);
            if (i >= s.Length)
                throw new FormatException("JSON 意外结束");

            char c = s[i];
            if (c == '{') return ParseObject(s, ref i);
            if (c == '[') return ParseArray(s, ref i);
            if (c == '"') return ParseString(s, ref i);
            if (c == 't') { Expect(s, ref i, "true"); return true; }
            if (c == 'f') { Expect(s, ref i, "false"); return false; }
            if (c == 'n') { Expect(s, ref i, "null"); return null; }
            return ParseNumber(s, ref i);
        }

        private static Dictionary<string, object> ParseObject(string s, ref int i)
        {
            Dictionary<string, object> dict = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
            i++; // {
            SkipWs(s, ref i);
            if (i < s.Length && s[i] == '}') { i++; return dict; }

            while (true)
            {
                SkipWs(s, ref i);
                if (i >= s.Length || s[i] != '"')
                    throw new FormatException("JSON 对象的键必须是字符串（位置 " + i + "）");
                string key = ParseString(s, ref i);

                SkipWs(s, ref i);
                if (i >= s.Length || s[i] != ':')
                    throw new FormatException("JSON 缺少冒号（位置 " + i + "）");
                i++;

                dict[key] = ParseValue(s, ref i);

                SkipWs(s, ref i);
                if (i >= s.Length)
                    throw new FormatException("JSON 对象未闭合");
                if (s[i] == ',') { i++; continue; }
                if (s[i] == '}') { i++; return dict; }
                throw new FormatException("JSON 对象里出现意外字符 '" + s[i] + "'（位置 " + i + "）");
            }
        }

        private static List<object> ParseArray(string s, ref int i)
        {
            List<object> list = new List<object>();
            i++; // [
            SkipWs(s, ref i);
            if (i < s.Length && s[i] == ']') { i++; return list; }

            while (true)
            {
                list.Add(ParseValue(s, ref i));
                SkipWs(s, ref i);
                if (i >= s.Length)
                    throw new FormatException("JSON 数组未闭合");
                if (s[i] == ',') { i++; continue; }
                if (s[i] == ']') { i++; return list; }
                throw new FormatException("JSON 数组里出现意外字符 '" + s[i] + "'（位置 " + i + "）");
            }
        }

        private static string ParseString(string s, ref int i)
        {
            StringBuilder sb = new StringBuilder();
            i++; // "
            while (i < s.Length)
            {
                char c = s[i++];
                if (c == '"')
                    return sb.ToString();
                if (c != '\\')
                {
                    sb.Append(c);
                    continue;
                }

                if (i >= s.Length)
                    break;
                char e = s[i++];
                switch (e)
                {
                    case '"': sb.Append('"'); break;
                    case '\\': sb.Append('\\'); break;
                    case '/': sb.Append('/'); break;
                    case 'b': sb.Append('\b'); break;
                    case 'f': sb.Append('\f'); break;
                    case 'n': sb.Append('\n'); break;
                    case 'r': sb.Append('\r'); break;
                    case 't': sb.Append('\t'); break;
                    case 'u':
                        if (i + 4 > s.Length)
                            throw new FormatException("JSON \\u 转义不完整");
                        sb.Append((char)int.Parse(s.Substring(i, 4), NumberStyles.HexNumber, CultureInfo.InvariantCulture));
                        i += 4;
                        break;
                    default:
                        sb.Append(e);
                        break;
                }
            }
            throw new FormatException("JSON 字符串未闭合");
        }

        private static double ParseNumber(string s, ref int i)
        {
            int start = i;
            while (i < s.Length && ("+-0123456789.eE".IndexOf(s[i]) >= 0))
                i++;
            if (start == i)
                throw new FormatException("JSON 数字格式不对（位置 " + start + "）");
            return double.Parse(s.Substring(start, i - start), CultureInfo.InvariantCulture);
        }

        private static void Expect(string s, ref int i, string literal)
        {
            if (i + literal.Length > s.Length || string.CompareOrdinal(s, i, literal, 0, literal.Length) != 0)
                throw new FormatException("JSON 期望 " + literal + "（位置 " + i + "）");
            i += literal.Length;
        }

        private static void SkipWs(string s, ref int i)
        {
            while (i < s.Length && (s[i] == ' ' || s[i] == '\t' || s[i] == '\r' || s[i] == '\n'))
                i++;
        }

        // ---------- 写 ----------

        public static string Quote(string value)
        {
            if (value == null)
                return "null";

            StringBuilder sb = new StringBuilder(value.Length + 2);
            sb.Append('"');
            foreach (char c in value)
            {
                switch (c)
                {
                    case '"': sb.Append("\\\""); break;
                    case '\\': sb.Append("\\\\"); break;
                    case '\n': sb.Append("\\n"); break;
                    case '\r': sb.Append("\\r"); break;
                    case '\t': sb.Append("\\t"); break;
                    default:
                        if (c < 0x20)
                            sb.Append("\\u").Append(((int)c).ToString("x4"));
                        else
                            sb.Append(c);
                        break;
                }
            }
            sb.Append('"');
            return sb.ToString();
        }
    }
}
