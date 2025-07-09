/**
 * Logger 类 - 支持事件监听的日志系统
 * 可以通过 on() 方法监听所有日志输出
 */
class Logger {
  private listeners: ((level: string, ...args: any[]) => void)[] = [];

  /**
   * 添加日志监听器
   * @param callback 监听回调函数，接收日志级别和参数
   */
  on(callback: (level: string, ...args: any[]) => void) {
    if (typeof callback === "function") {
      this.listeners.push(callback);
    }
  }

  /**
   * 通用的日志处理方法
   * 通知所有监听器，传递日志级别和参数
   * @param level 日志级别
   * @param args 日志参数
   */
  private _emit(level: string, ...args: any[]) {
    // 通知所有监听器，传递日志级别和参数
    this.listeners.forEach((listener) => {
      try {
        listener(level, ...args);
      } catch (e) {
        // 防止监听器错误影响主流程
        console.error("Logger listener error:", e);
      }
    });
  }

  /**
   * 发送错误级别日志
   * @param args 日志参数
   */
  error(...args: any[]) {
    this._emit("error", ...args);
  }

  /**
   * 发送警告级别日志
   * @param args 日志参数
   */
  warn(...args: any[]) {
    this._emit("warn", ...args);
  }

  /**
   * 发送信息级别日志
   * @param args 日志参数
   */
  info(...args: any[]) {
    this._emit("info", ...args);
  }
}

export const logger = new Logger();

/**
 * 从对象中获取指定路径的值
 * 支持点分割和方括号语法，如 "a.b[0].c[1]"
 * @param data 数据对象
 * @param path 路径字符串
 * @param defaultValue 默认值，当路径不存在时返回
 * @returns 获取到的值或默认值
 */
export function getValue(
  data: any,
  path: string,
  defaultValue: any = null
): any {
  if (!path) return data === undefined ? defaultValue : data;

  // 统一把路径转成数组形式的 key 列表
  // 支持 a.b[0].c[1] 这种混合写法
  const keys: (string | number)[] = [];

  // 正则匹配点分割和方括号里的键名
  const regex = /[^.\[\]]+|\[(\d+|".*?"|'.*?')\]/g;
  let match: RegExpExecArray | null;

  while ((match = regex.exec(path)) !== null) {
    let key: string | number = match[0];

    if (key.startsWith("[")) {
      // 去掉方括号和引号
      key = key.slice(1, -1);

      if (
        (key.startsWith('"') && key.endsWith('"')) ||
        (key.startsWith("'") && key.endsWith("'"))
      ) {
        key = key.slice(1, -1);
      }
    }

    // 数字字符串转数字
    if (/^\d+$/.test(key as string)) key = Number(key);
    keys.push(key);
  }

  let result = data;

  for (const key of keys) {
    if (result == null || !(key in result)) {
      return defaultValue;
    }
    result = result[key];
  }

  return result === undefined ? defaultValue : result;
}
