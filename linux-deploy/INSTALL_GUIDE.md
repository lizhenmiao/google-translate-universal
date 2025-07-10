# Google翻译服务一键安装脚本

## 🚀 快速安装

### 方法1：直接下载运行
```bash
# 下载安装脚本
curl -fsSL https://raw.githubusercontent.com/lizhenmiao/google-translate-universal/master/linux-deploy/install.sh -o install.sh

# 添加执行权限
chmod +x install.sh

# 运行脚本
sudo ./install.sh
```

### 方法2：一键安装
```bash
curl -fsSL https://raw.githubusercontent.com/lizhenmiao/google-translate-universal/master/linux-deploy/install.sh | sudo bash
```

## 📋 功能特性

### 🔧 安装功能
- **自动检测系统** - 支持 Alpine、Ubuntu/Debian、CentOS/RHEL
- **依赖安装** - 自动安装 Node.js、npm 等必需组件
- **交互式配置** - 引导设置端口、TOKEN、开机自启等
- **安全配置** - 自动配置防火墙和文件权限

### 📊 服务管理
- **启动/停止/重启** - 完整的服务生命周期管理
- **开机自启控制** - 启用/禁用开机自动启动
- **服务状态监控** - 实时查看服务运行状态
- **健康检查** - 自动测试服务可用性

### 📝 日志管理
- **今天日志** - 查看当天的服务日志
- **昨天日志** - 查看昨天的历史日志
- **系统日志** - 查看 systemd 服务日志
- **实时日志** - 实时跟踪日志输出
- **自动轮转** - 系统级日志轮转，按天分割

### 🛠️ 维护功能
- **完整卸载** - 彻底删除服务和相关文件
- **重新安装** - 支持覆盖安装和配置更新
- **配置管理** - 灵活的参数配置

## 🎯 使用流程

### 操作说明
- **0** - 统一用于退出、返回上级或返回主菜单
- **1-9** - 用于具体功能选项

### 1. 首次安装
```bash
sudo ./install.sh
```

**安装向导会询问：**
- 监听端口（默认3000）
- 访问TOKEN（可选）
- 是否开机自启

### 2. 服务管理
脚本提供完整的菜单界面：

```
Google翻译服务管理工具
版本: 1.0.0
作者: lizhenmiao

主菜单:

1) 服务管理
2) 健康检查
3) 重新安装
4) 切换语言
0) 退出脚本
```

### 3. 日志查看
```
选择要查看的日志:
1) 今天的日志
2) 昨天的日志
3) 系统服务日志
4) 实时日志
0) 返回主菜单
```

### 4. 服务管理
```
服务管理:

1) 启动服务
2) 停止服务
3) 重启服务
4) 查看状态
5) 查看日志
6) 启用开机自启
7) 禁用开机自启
8) 卸载服务
0) 返回主菜单
```

## 🔒 安全特性

- **Root权限检查** - 确保有足够权限执行安装
- **文件权限设置** - 合理的文件和目录权限
- **防火墙配置** - 自动开放必要端口
- **环境文件保护** - .env文件设置为只读权限

## 📁 安装位置

- **应用目录**: `/opt/google-translate-service/`
- **服务文件**: `/etc/systemd/system/google-translate-service.service`
- **日志文件**: `/opt/google-translate-service/logs/`
- **配置文件**: `/opt/google-translate-service/.env`

## 🔍 故障排除

### 服务无法启动
```bash
# 查看详细错误信息
sudo ./install.sh
# 选择 "1) 服务管理" -> "4) 查看状态"
```

### 端口被占用
```bash
# 查看端口占用
lsof -i :端口号

# 或重新安装选择新端口
sudo ./install.sh
# 选择 "3) 重新安装"
```

### 健康检查失败
```bash
# 执行健康检查
sudo ./install.sh
# 选择 "2) 健康检查"
```

## 🚀 API使用

安装完成后，服务将在指定端口提供以下接口：

- **GET /** - API文档
- **GET /health** - 健康检查
- **POST /translate** - 翻译接口

### 翻译接口示例
```bash
# GET请求
curl "http://localhost:3000/translate?text=Hello&source_lang=en&target_lang=zh"

# POST请求
curl -X POST http://localhost:3000/translate \
  -H "Content-Type: application/json" \
  -d '{"text":"Hello","source_lang":"en","target_lang":"zh"}'

# 带TOKEN的请求
curl "http://localhost:3000/translate?token=your-token&text=Hello&source_lang=en&target_lang=zh"
```

## 📞 技术支持

- **项目地址**: https://github.com/lizhenmiao/google-translate-universal
- **问题反馈**: https://github.com/lizhenmiao/google-translate-universal/issues

---

**一键安装，开箱即用！** 🎉