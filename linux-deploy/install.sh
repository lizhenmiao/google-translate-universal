#!/bin/bash

# Google翻译服务一键安装管理脚本
# 作者: lizhenmiao
# 版本: 1.0.0

set -e

# 配置变量
APP_NAME="google-translate-service"
APP_DIR="/opt/google-translate-service"
SERVICE_FILE="/etc/systemd/system/${APP_NAME}.service"
LOGROTATE_FILE="/etc/logrotate.d/${APP_NAME}"
SCRIPT_VERSION="1.0.2"
GITHUB_RAW_URL="https://raw.githubusercontent.com/lizhenmiao/google-translate-universal/master/linux-deploy"

# 语言配置
LANG_CN="cn"
LANG_EN="en"
CURRENT_LANG="${LANG_CN}"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 多语言支持
get_text() {
    local key="$1"
    case "$key" in
        "banner_title")
            if [ "$CURRENT_LANG" = "$LANG_EN" ]; then
                echo "Google Translation Service Management Tool"
            else
                echo "Google翻译服务管理工具"
            fi
            ;;
        "banner_version")
            if [ "$CURRENT_LANG" = "$LANG_EN" ]; then
                echo "Version: ${SCRIPT_VERSION}"
            else
                echo "版本: ${SCRIPT_VERSION}"
            fi
            ;;
        "banner_author")
            if [ "$CURRENT_LANG" = "$LANG_EN" ]; then
                echo "Author: lizhenmiao"
            else
                echo "作者: lizhenmiao"
            fi
            ;;
        "service_status")
            if [ "$CURRENT_LANG" = "$LANG_EN" ]; then
                echo "Service Status:"
            else
                echo "服务状态:"
            fi
            ;;
        "running")
            if [ "$CURRENT_LANG" = "$LANG_EN" ]; then
                echo "Running"
            else
                echo "运行中"
            fi
            ;;
        "stopped")
            if [ "$CURRENT_LANG" = "$LANG_EN" ]; then
                echo "Stopped"
            else
                echo "已停止"
            fi
            ;;
        "port_listening")
            if [ "$CURRENT_LANG" = "$LANG_EN" ]; then
                echo "Port Listening Status:"
            else
                echo "端口监听状态:"
            fi
            ;;
        "service_management")
            if [ "$CURRENT_LANG" = "$LANG_EN" ]; then
                echo "Service Management:"
            else
                echo "服务管理:"
            fi
            ;;
        *)
            echo "$key"
            ;;
    esac
}

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${CYAN}[SUCCESS]${NC} $1"
}

# 显示横幅
show_banner() {
    clear
    echo -e "${PURPLE}"
    echo "$(get_text 'banner_title')"
    echo "$(get_text 'banner_version')"
    echo "$(get_text 'banner_author')"
    echo -e "${NC}"
    echo
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        log_info "请使用: sudo $0"
        exit 1
    fi
}

# 检测操作系统
detect_os() {
    if [ -f /etc/alpine-release ]; then
        OS="alpine"
        PKG_MANAGER="apk"
        INIT_SYSTEM="openrc"
        log_info "检测到 Alpine Linux"
    elif [ -f /etc/lsb-release ] || [ -f /etc/debian_version ]; then
        OS="ubuntu"
        PKG_MANAGER="apt"
        INIT_SYSTEM="systemd"
        log_info "检测到 Ubuntu/Debian"
    elif [ -f /etc/centos-release ] || [ -f /etc/redhat-release ] || [ -f /etc/rocky-release ] || [ -f /etc/almalinux-release ]; then
        OS="centos"
        # 检测是否有 dnf，如果有则优先使用 dnf
        if command -v dnf &> /dev/null; then
            PKG_MANAGER="dnf"
            log_info "检测到 Fedora/CentOS 8+，使用 dnf"
        else
            PKG_MANAGER="yum"
            log_info "检测到 CentOS/RHEL，使用 yum"
        fi
        INIT_SYSTEM="systemd"
    elif [ -f /etc/fedora-release ]; then
        OS="fedora"
        PKG_MANAGER="dnf"
        INIT_SYSTEM="systemd"
        log_info "检测到 Fedora"
    elif [ -f /etc/arch-release ]; then
        OS="arch"
        PKG_MANAGER="pacman"
        INIT_SYSTEM="systemd"
        log_info "检测到 Arch Linux"
    elif [ -f /etc/SUSE-brand ] || [ -f /etc/SuSE-release ]; then
        OS="suse"
        PKG_MANAGER="zypper"
        INIT_SYSTEM="systemd"
        log_info "检测到 openSUSE/SLES"
    else
        log_warn "未知的操作系统，将使用通用安装方式"
        OS="generic"
        PKG_MANAGER="unknown"
        INIT_SYSTEM="unknown"
    fi
}

# 安装系统依赖
install_dependencies() {
    log_info "安装系统依赖..."
    
    # 检查Node.js是否已安装
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        log_info "检测到已安装的 Node.js 版本: $NODE_VERSION"
        
        # 检查版本是否符合要求
        if [[ ${NODE_VERSION:1:2} -ge 16 ]]; then
            log_success "Node.js 版本符合要求，跳过安装"
            return
        else
            log_warn "Node.js 版本过低，需要升级到16.0.0或更高版本"
        fi
    fi
    
    case $PKG_MANAGER in
        "apk")
            apk update
            apk add --no-cache nodejs npm curl bash logrotate openrc
            ;;
        "apt")
            apt update
            apt install -y nodejs npm curl bash logrotate
            ;;
        "yum")
            yum update -y
            yum install -y nodejs npm curl bash logrotate
            ;;
        "dnf")
            dnf update -y
            dnf install -y nodejs npm curl bash logrotate
            ;;
        "pacman")
            pacman -Sy --noconfirm nodejs npm curl bash logrotate
            ;;
        "zypper")
            zypper refresh
            zypper install -y nodejs npm curl bash logrotate
            ;;
        *)
            log_warn "不支持的包管理器: $PKG_MANAGER"
            log_warn "请手动安装以下依赖："
            echo "- Node.js (>=16.0.0)"
            echo "- npm"
            echo "- curl"
            echo "- bash"
            echo "- logrotate"
            read -p "安装完成后按Enter继续..." -r
            ;;
    esac
    
    # 验证Node.js版本
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        log_success "Node.js版本: $NODE_VERSION"
        
        # 检查版本是否符合要求
        if [[ ${NODE_VERSION:1:2} -lt 16 ]]; then
            log_error "Node.js版本过低，需要16.0.0或更高版本"
            exit 1
        fi
    else
        log_error "Node.js安装失败"
        exit 1
    fi
}

# 下载应用文件
download_app_files() {
    if [ -d "$APP_DIR" ]; then
        log_info "检测到应用目录已存在，是否覆盖？"
        read -p "覆盖现有应用文件? [y/N]: " overwrite
        case $overwrite in
            [Yy]* )
                log_info "覆盖现有应用文件..."
                rm -rf $APP_DIR
                ;;
            * )
                log_info "跳过应用文件下载"
                return
                ;;
        esac
    else
        log_info "下载应用文件..."
    fi
    
    # 创建应用目录
    mkdir -p $APP_DIR
    cd $APP_DIR
    
    # 下载主服务文件
    if curl -fsSL "${GITHUB_RAW_URL}/translate-service.js" -o translate-service.js; then
        log_success "下载 translate-service.js 成功"
    else
        log_error "下载 translate-service.js 失败"
        exit 1
    fi
    
    # 创建package.json
    cat > package.json << 'EOF'
{
  "name": "google-translate-service",
  "version": "1.0.2",
  "type": "module",
  "dependencies": {
    "fastify": "^4.24.3",
    "@fastify/cors": "^8.4.0",
    "google-translate-universal": "^1.0.2",
    "dotenv": "^16.3.1",
    "pino-pretty": "^10.2.3"
  }
}
EOF
    
    # 创建日志目录
    mkdir -p logs
    
    log_success "应用文件下载完成"
}

# 安装项目依赖
install_node_dependencies() {
    log_info "安装项目依赖..."
    cd $APP_DIR
    
    if npm install --production; then
        log_success "依赖安装完成"
    else
        log_error "依赖安装失败"
        exit 1
    fi
}

# 获取用户配置
get_user_config() {
    echo
    log_info "请配置服务参数:"
    echo
    
    # 端口配置
    while true; do
        read -p "$(echo -e ${BLUE}请输入监听端口 [默认: 3000]: ${NC})" PORT
        PORT=${PORT:-3000}
        
        if [[ $PORT =~ ^[0-9]+$ ]] && [ $PORT -ge 1 ] && [ $PORT -le 65535 ]; then
            break
        else
            log_error "无效的端口号，请输入1-65535之间的数字"
        fi
    done
    
    # TOKEN配置
    while true; do
        read -p "$(echo -e ${BLUE}请输入访问TOKEN [留空表示无需验证]: ${NC})" ACCESS_TOKEN
        break
    done
    
    # 开机自启
    while true; do
        read -p "$(echo -e ${BLUE}是否设置开机自启? [Y/n]: ${NC})" AUTO_START
        AUTO_START=${AUTO_START:-Y}
        case $AUTO_START in
            [Yy]* ) ENABLE_AUTOSTART=true; break;;
            [Nn]* ) ENABLE_AUTOSTART=false; break;;
            * ) log_error "请输入 Y 或 n";;
        esac
    done
    
    echo
    log_info "配置信息:"
    echo "  端口: $PORT"
    echo "  TOKEN: ${ACCESS_TOKEN:-未设置}"
    echo "  开机自启: $ENABLE_AUTOSTART"
    echo
}

# 创建环境配置文件
create_env_file() {
    log_info "创建环境配置文件..."
    
    cat > $APP_DIR/.env << EOF
NODE_ENV=production
PORT=$PORT
HOST=0.0.0.0
ACCESS_TOKEN=$ACCESS_TOKEN
EOF
    
    chmod 600 $APP_DIR/.env
    log_success "环境配置文件创建完成"
}

# 创建服务配置
create_service() {
    if [ "$INIT_SYSTEM" = "openrc" ]; then
        create_openrc_service
    elif [ "$INIT_SYSTEM" = "systemd" ]; then
        create_systemd_service
    else
        log_error "不支持的初始化系统"
        exit 1
    fi
}

# 创建OpenRC服务 (Alpine Linux)
create_openrc_service() {
    local openrc_file="/etc/init.d/$APP_NAME"
    
    if [ -f "$openrc_file" ]; then
        log_info "检测到已存在的OpenRC服务，是否覆盖？"
        read -p "覆盖现有服务? [y/N]: " overwrite
        case $overwrite in
            [Yy]* )
                log_info "覆盖现有OpenRC服务..."
                ;;
            * )
                log_info "跳过OpenRC服务创建"
                return
                ;;
        esac
    else
        log_info "创建OpenRC服务..."
    fi
    
    cat > "$openrc_file" << EOF
#!/sbin/openrc-run

name="Google Translate Service"
description="Google Translate Universal Service"
command="/usr/bin/node"
command_args="translate-service.js"
command_background=true
pidfile="/run/\${RC_SVCNAME}.pid"
directory="$APP_DIR"
command_user="root"

depend() {
    need net
    after firewall
}

start_pre() {
    checkpath --directory --owner root:root --mode 0755 /run
    
    # 加载环境变量
    if [ -f "$APP_DIR/.env" ]; then
        export \$(grep -v '^#' "$APP_DIR/.env" | xargs)
    fi
}
EOF
    
    chmod +x "$openrc_file"
    
    # 检查是否已在开机自启列表中
    if rc-update show default | grep -q "$APP_NAME"; then
        log_info "服务已在开机自启列表中"
    elif [ "$ENABLE_AUTOSTART" = true ]; then
        rc-update add "$APP_NAME" default
        log_success "服务已设置为开机自启"
    fi
    
    log_success "OpenRC服务创建完成"
}

# 创建systemd服务
create_systemd_service() {
    if [ -f "$SERVICE_FILE" ]; then
        log_info "检测到已存在的systemd服务，是否覆盖？"
        read -p "覆盖现有服务? [y/N]: " overwrite
        case $overwrite in
            [Yy]* )
                log_info "覆盖现有systemd服务..."
                ;;
            * )
                log_info "跳过systemd服务创建"
                return
                ;;
        esac
    else
        log_info "创建systemd服务..."
    fi
    
    cat > $SERVICE_FILE << EOF
[Unit]
Description=Google Translate Service
After=network.target
Documentation=https://github.com/lizhenmiao/google-translate-universal

[Service]
Type=simple
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/node translate-service.js
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$APP_NAME
Environment=NODE_ENV=production
EnvironmentFile=-$APP_DIR/.env

# 资源限制
LimitNOFILE=65535
LimitNPROC=65535
LimitAS=134217728

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    
    # 检查是否已启用开机自启
    if systemctl is-enabled --quiet $APP_NAME; then
        log_info "服务已启用开机自启"
    elif [ "$ENABLE_AUTOSTART" = true ]; then
        systemctl enable $APP_NAME
        log_success "服务已设置为开机自启"
    fi
    
    log_success "systemd服务创建完成"
}

# 配置日志轮转
setup_logrotate() {
    if [ -f "$LOGROTATE_FILE" ]; then
        log_info "检测到已存在的logrotate配置，是否覆盖？"
        read -p "覆盖现有logrotate配置? [y/N]: " overwrite
        case $overwrite in
            [Yy]* )
                log_info "覆盖现有logrotate配置..."
                ;;
            * )
                log_info "跳过logrotate配置"
                return
                ;;
        esac
    else
        log_info "配置日志轮转..."
    fi
    
    cat > $LOGROTATE_FILE << EOF
$APP_DIR/logs/translate-service.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    dateext
    dateformat -%Y%m%d
    postrotate
        echo "日志已轮转: \$(date)" >> $APP_DIR/logs/rotate.log
    endscript
}
EOF
    
    # 测试配置
    if logrotate -d $LOGROTATE_FILE &>/dev/null; then
        log_success "日志轮转配置完成"
    else
        log_warn "日志轮转配置可能有问题，但不影响服务运行"
    fi
}

# 配置防火墙
setup_firewall() {
    log_info "配置防火墙..."
    
    if command -v ufw &> /dev/null; then
        if ufw allow $PORT/tcp &>/dev/null; then
            log_success "UFW防火墙已配置"
        fi
    elif command -v firewall-cmd &> /dev/null; then
        if firewall-cmd --permanent --add-port=$PORT/tcp &>/dev/null && firewall-cmd --reload &>/dev/null; then
            log_success "firewalld防火墙已配置"
        fi
    else
        log_warn "未检测到防火墙，请手动开放端口 $PORT"
    fi
}

# 启动服务
start_service() {
    log_info "启动服务..."
    
    if [ "$INIT_SYSTEM" = "openrc" ]; then
        if rc-service $APP_NAME start; then
            sleep 2
            if rc-service $APP_NAME status | grep -q "started"; then
                log_success "服务启动成功!"
                show_service_info
            else
                log_error "服务启动失败"
                show_service_status
            fi
        else
            log_error "服务启动失败"
        fi
    elif [ "$INIT_SYSTEM" = "systemd" ]; then
        if systemctl start $APP_NAME; then
            sleep 2
            if systemctl is-active --quiet $APP_NAME; then
                log_success "服务启动成功!"
                show_service_info
            else
                log_error "服务启动失败"
                show_service_status
            fi
        else
            log_error "服务启动失败"
        fi
    fi
}

# 显示服务信息
show_service_info() {
    echo
    log_info "服务信息:"
    echo "  访问地址: http://localhost:$PORT"
    echo "  健康检查: http://localhost:$PORT/health"
    echo "  API文档: http://localhost:$PORT"
    if [ -n "$ACCESS_TOKEN" ]; then
        echo "  访问TOKEN: $ACCESS_TOKEN"
    fi
}

# 检查服务状态
check_service_status() {
    if [ "$INIT_SYSTEM" = "openrc" ]; then
        rc-service $APP_NAME status | grep -q "started"
    elif [ "$INIT_SYSTEM" = "systemd" ]; then
        systemctl is-active --quiet $APP_NAME
    else
        return 1
    fi
}

# 显示服务状态
show_service_status() {
    # 获取端口号
    local current_port=""
    if [ -f "$APP_DIR/.env" ]; then
        current_port=$(grep "^PORT=" "$APP_DIR/.env" 2>/dev/null | cut -d'=' -f2)
    fi
    current_port=${current_port:-3000}
    
    # 获取访问TOKEN
    local access_token=""
    if [ -f "$APP_DIR/.env" ]; then
        access_token=$(grep "^ACCESS_TOKEN=" "$APP_DIR/.env" 2>/dev/null | cut -d'=' -f2)
    fi
    
    # 获取运行环境
    local node_env=""
    if [ -f "$APP_DIR/.env" ]; then
        node_env=$(grep "^NODE_ENV=" "$APP_DIR/.env" 2>/dev/null | cut -d'=' -f2)
    fi
    node_env=${node_env:-production}
    
    echo
    log_info "$(get_text 'service_status')"
    
    if [ "$INIT_SYSTEM" = "openrc" ]; then
        if rc-service $APP_NAME status 2>/dev/null; then
            echo " * 状态: $(get_text 'running')"
        else
            echo " * 状态: $(get_text 'stopped')"
        fi
    elif [ "$INIT_SYSTEM" = "systemd" ]; then
        if systemctl is-active --quiet $APP_NAME 2>/dev/null; then
            echo " * 状态: $(get_text 'running')"
            echo " * 开机自启: $(systemctl is-enabled $APP_NAME 2>/dev/null || echo '未启用')"
        else
            echo " * 状态: $(get_text 'stopped')"
        fi
    fi
    
    echo
    log_info "服务配置信息:"
    echo " * 监听端口: $current_port"
    echo " * 运行环境: $node_env"
    if [ -n "$access_token" ]; then
        echo " * 访问TOKEN: ${access_token}"
    else
        echo " * 访问TOKEN: 未配置"
    fi
    echo " * 安装目录: $APP_DIR"
    echo " * 日志目录: $APP_DIR/logs"
    
    echo
    
    log_info "$(get_text 'port_listening')"
    local port_status=""
    if command -v netstat &> /dev/null; then
        port_status=$(netstat -tlnp 2>/dev/null | grep ":$current_port ")
    elif command -v ss &> /dev/null; then
        port_status=$(ss -tlnp 2>/dev/null | grep ":$current_port ")
    fi
    
    if [ -n "$port_status" ]; then
        echo "端口 $current_port 正在监听"
        echo "$port_status"
    else
        echo "端口 $current_port 未监听"
    fi
    
    # 尝试获取服务健康状态
    echo
    log_info "服务健康检查:"
    if command -v curl &> /dev/null; then
        local health_check=$(curl -s --max-time 3 "http://localhost:$current_port/health" 2>/dev/null)
        if [ $? -eq 0 ] && echo "$health_check" | grep -q '"status":"ok"'; then
            echo " * 健康状态: 正常"
            echo " * 服务版本: $(echo "$health_check" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)"
            echo " * 运行时间: $(echo "$health_check" | grep -o '"uptime":"[^"]*"' | cut -d'"' -f4)"
        else
            echo " * 健康状态: 异常或无响应"
        fi
    else
        echo " * 健康状态: 无法检查（curl命令不可用）"
    fi
}

# 查看日志
show_logs() {
    local log_date=""
    local log_file=""
    
    echo
    echo "选择要查看的日志:"
    echo "1) 今天的日志"
    echo "2) 昨天的日志"
    echo "3) 系统服务日志"
    echo "4) 实时日志"
    echo "5) 列出所有日志文件"
    echo "0) 返回主菜单"
    echo
    
    read -p "请选择 [0-5]: " choice
    
    case $choice in
        1)
            log_date=$(date +%Y-%m-%d)
            log_file="$APP_DIR/logs/translate-service.log"
            ;;
        2)
            # 使用兼容的方式获取昨天日期
            if date -d "yesterday" +%Y%m%d >/dev/null 2>&1; then
                # GNU date 支持 -d 参数 (Ubuntu/Debian/CentOS)
                log_date=$(date -d "yesterday" +%Y%m%d)
            else
                # BusyBox date 不支持 -d 参数 (Alpine Linux)
                log_date=$(date -D "%s" -d "$(( $(date +%s) - 86400 ))" +%Y%m%d 2>/dev/null || \
                          date -r "$(( $(date +%s) - 86400 ))" +%Y%m%d 2>/dev/null || \
                          date -d "1 day ago" +%Y%m%d 2>/dev/null || \
                          date +%Y%m%d)
            fi
            # 先尝试未压缩的文件，再尝试压缩的文件
            if [ -f "$APP_DIR/logs/translate-service.log-$log_date" ]; then
                log_file="$APP_DIR/logs/translate-service.log-$log_date"
            elif [ -f "$APP_DIR/logs/translate-service.log-$log_date.gz" ]; then
                log_file="$APP_DIR/logs/translate-service.log-$log_date.gz"
            else
                log_file="$APP_DIR/logs/translate-service.log-$log_date"
            fi
            ;;
        3)
            log_info "显示系统服务日志:"
            if [ "$INIT_SYSTEM" = "systemd" ]; then
                journalctl -u $APP_NAME --no-pager
            elif [ "$INIT_SYSTEM" = "openrc" ]; then
                if [ -f "/var/log/messages" ]; then
                    grep "$APP_NAME" /var/log/messages | tail -50
                elif [ -f "/var/log/syslog" ]; then
                    grep "$APP_NAME" /var/log/syslog | tail -50
                else
                    log_warn "未找到系统日志文件"
                fi
            else
                log_warn "不支持的初始化系统"
            fi
            echo
            read -p "按Enter键返回..." -r
            return
            ;;
        4)
            log_info "显示实时日志 (按Ctrl+C退出):"
            if [ -f "$APP_DIR/logs/translate-service.log" ]; then
                tail -f "$APP_DIR/logs/translate-service.log"
            elif [ "$INIT_SYSTEM" = "systemd" ]; then
                journalctl -u $APP_NAME -f
            else
                log_warn "未找到日志文件"
            fi
            return
            ;;
        5)
            log_info "所有日志文件列表:"
            echo "----------------------------------------"
            if [ -d "$APP_DIR/logs" ]; then
                ls -la "$APP_DIR/logs/"translate-service.log* 2>/dev/null | while read -r line; do
                    # 提取文件名和大小信息
                    file_info=$(echo "$line" | awk '{print $9, "(" $5 " bytes)", $6, $7, $8}')
                    echo "$file_info"
                done
                echo "----------------------------------------"
                echo
                echo "轮转操作日志:"
                if [ -f "$APP_DIR/logs/rotate.log" ]; then
                    tail -10 "$APP_DIR/logs/rotate.log"
                else
                    echo "暂无轮转日志"
                fi
            else
                log_warn "日志目录不存在: $APP_DIR/logs"
            fi
            echo
            read -p "按Enter键返回..." -r
            return
            ;;
        0)
            return
            ;;
        *)
            log_error "无效选择"
            return
            ;;
    esac
    
    if [ -f "$log_file" ]; then
        log_info "显示 $log_date 的日志:"
        echo "----------------------------------------"
        if [[ $log_file == *.gz ]]; then
            zcat "$log_file"
        else
            cat "$log_file"
        fi
        echo "----------------------------------------"
    else
        log_warn "日志文件不存在: $log_file"
    fi
    
    echo
    read -p "按Enter键返回..." -r
}

# 服务管理菜单
service_management() {
    # 确保操作系统已检测
    if [ -z "$INIT_SYSTEM" ]; then
        detect_os
    fi
    
    while true; do
        clear
        show_banner
        
        echo "$(get_text 'service_management')"
        echo
        
        if check_service_status; then
            echo -e "$(get_text 'service_status') ${GREEN}$(get_text 'running')${NC}"
        else
            echo -e "$(get_text 'service_status') ${RED}$(get_text 'stopped')${NC}"
        fi
        
        echo
        echo "1) 启动服务"
        echo "2) 停止服务"
        echo "3) 重启服务"
        echo "4) 查看状态"
        echo "5) 查看日志"
        echo "6) 启用开机自启"
        echo "7) 禁用开机自启"
        echo "8) 卸载服务"
        echo "0) 返回主菜单"
        echo
        
        read -p "请选择 [0-8]: " choice
        
        case $choice in
            1)
                log_info "启动服务..."
                if [ "$INIT_SYSTEM" = "openrc" ]; then
                    if rc-service $APP_NAME start; then
                        log_success "服务启动成功"
                    else
                        log_error "服务启动失败"
                    fi
                elif [ "$INIT_SYSTEM" = "systemd" ]; then
                    if systemctl start $APP_NAME; then
                        log_success "服务启动成功"
                    else
                        log_error "服务启动失败"
                    fi
                fi
                read -p "按Enter键继续..." -r
                ;;
            2)
                log_info "停止服务..."
                if [ "$INIT_SYSTEM" = "openrc" ]; then
                    if rc-service $APP_NAME stop; then
                        log_success "服务停止成功"
                    else
                        log_error "服务停止失败"
                    fi
                elif [ "$INIT_SYSTEM" = "systemd" ]; then
                    if systemctl stop $APP_NAME; then
                        log_success "服务停止成功"
                    else
                        log_error "服务停止失败"
                    fi
                fi
                read -p "按Enter键继续..." -r
                ;;
            3)
                log_info "重启服务..."
                if [ "$INIT_SYSTEM" = "openrc" ]; then
                    if rc-service $APP_NAME restart; then
                        log_success "服务重启成功"
                    else
                        log_error "服务重启失败"
                    fi
                elif [ "$INIT_SYSTEM" = "systemd" ]; then
                    if systemctl restart $APP_NAME; then
                        log_success "服务重启成功"
                    else
                        log_error "服务重启失败"
                    fi
                fi
                read -p "按Enter键继续..." -r
                ;;
            4)
                show_service_status
                read -p "按Enter键继续..." -r
                ;;
            5)
                show_logs
                ;;
            6)
                log_info "启用开机自启..."
                if [ "$INIT_SYSTEM" = "openrc" ]; then
                    if rc-update add $APP_NAME default; then
                        log_success "开机自启已启用"
                    else
                        log_error "开机自启启用失败"
                    fi
                elif [ "$INIT_SYSTEM" = "systemd" ]; then
                    if systemctl enable $APP_NAME; then
                        log_success "开机自启已启用"
                    else
                        log_error "开机自启启用失败"
                    fi
                fi
                read -p "按Enter键继续..." -r
                ;;
            7)
                log_info "禁用开机自启..."
                if [ "$INIT_SYSTEM" = "openrc" ]; then
                    if rc-update del $APP_NAME default; then
                        log_success "开机自启已禁用"
                    else
                        log_error "开机自启禁用失败"
                    fi
                elif [ "$INIT_SYSTEM" = "systemd" ]; then
                    if systemctl disable $APP_NAME; then
                        log_success "开机自启已禁用"
                    else
                        log_error "开机自启禁用失败"
                    fi
                fi
                read -p "按Enter键继续..." -r
                ;;
            8)
                uninstall_service
                return
                ;;
            0)
                return
                ;;
            *)
                log_error "无效选择"
                read -p "按Enter键继续..." -r
                ;;
        esac
    done
}

# 卸载服务
uninstall_service() {
    echo
    log_warn "确定要卸载Google翻译服务吗?"
    log_warn "这将删除所有相关文件和配置!"
    echo
    read -p "请输入 'YES' 确认卸载: " confirm
    
    if [ "$confirm" = "YES" ]; then
        log_info "正在卸载服务..."
        
        # 停止并禁用服务
        if [ "$INIT_SYSTEM" = "openrc" ]; then
            rc-service $APP_NAME stop &>/dev/null || true
            rc-update del $APP_NAME default &>/dev/null || true
            rm -f "/etc/init.d/$APP_NAME"
        elif [ "$INIT_SYSTEM" = "systemd" ]; then
            systemctl stop $APP_NAME &>/dev/null || true
            systemctl disable $APP_NAME &>/dev/null || true
            rm -f $SERVICE_FILE
            systemctl daemon-reload
        fi
        
        # 获取端口号（在删除文件之前）
        local current_port=3000
        if [ -f "$APP_DIR/.env" ]; then
            current_port=$(grep "^PORT=" "$APP_DIR/.env" 2>/dev/null | cut -d'=' -f2)
            current_port=${current_port:-3000}
        fi
        
        # 删除文件和配置
        rm -f $LOGROTATE_FILE
        rm -rf $APP_DIR
        
        # 删除防火墙规则
        log_info "清理防火墙规则..."
        if command -v ufw &>/dev/null; then
            ufw --force delete allow $current_port &>/dev/null || true
            log_info "已删除 ufw 防火墙规则"
        elif command -v firewall-cmd &>/dev/null; then
            firewall-cmd --permanent --remove-port=$current_port/tcp &>/dev/null || true
            firewall-cmd --reload &>/dev/null || true
            log_info "已删除 firewall-cmd 防火墙规则"
        fi
        
        # 清理可能的其他残留文件
        rm -f /var/log/translate-service-rotate.log &>/dev/null || true
        
        log_success "服务卸载完成"
    else
        log_info "取消卸载"
    fi
    
    read -p "按Enter键继续..." -r
}

# 安装服务
install_service() {
    log_info "开始安装Google翻译服务..."
    echo
    
    detect_os
    install_dependencies
    download_app_files
    install_node_dependencies
    get_user_config
    create_env_file
    create_service
    setup_logrotate
    setup_firewall
    start_service
    
    echo
    log_success "安装完成!"
    echo
    read -p "按Enter键进入管理菜单..." -r
    service_management
}

# 健康检查
health_check() {
    local port=""
    
    # 从配置文件读取端口
    if [ -f "$APP_DIR/.env" ]; then
        port=$(grep "^PORT=" "$APP_DIR/.env" | cut -d'=' -f2)
    fi
    
    if [ -z "$port" ]; then
        port=3000
    fi
    
    log_info "执行健康检查..."
    
    if curl -f -s "http://localhost:$port/health" > /dev/null; then
        log_success "健康检查通过"
        
        echo
        log_info "服务响应:"
        curl -s "http://localhost:$port/health" | python3 -m json.tool 2>/dev/null || curl -s "http://localhost:$port/health"
    else
        log_error "健康检查失败"
        echo
        log_info "可能的原因:"
        echo "1. 服务未启动"
        echo "2. 端口配置错误"
        echo "3. 防火墙阻止访问"
    fi
    
    echo
    read -p "按Enter键继续..." -r
}

# 切换语言
switch_language() {
    echo
    if [ "$CURRENT_LANG" = "$LANG_CN" ]; then
        echo "当前语言: 中文"
        echo "Current Language: Chinese"
        echo
        echo "1) 保持中文 / Keep Chinese"
        echo "2) 切换到英文 / Switch to English"
        echo "0) 返回主菜单 / Return to Main Menu"
    else
        echo "当前语言: 英文"
        echo "Current Language: English"
        echo
        echo "1) 切换到中文 / Switch to Chinese"
        echo "2) 保持英文 / Keep English"
        echo "0) 返回主菜单 / Return to Main Menu"
    fi
    echo
    
    read -p "请选择 / Please select [0-2]: " choice
    
    case $choice in
        1)
            if [ "$CURRENT_LANG" = "$LANG_EN" ]; then
                CURRENT_LANG="$LANG_CN"
                log_success "语言已切换为中文"
            else
                log_success "继续使用中文 / Continue using Chinese"
            fi
            ;;
        2)
            if [ "$CURRENT_LANG" = "$LANG_CN" ]; then
                CURRENT_LANG="$LANG_EN"
                log_success "Language switched to English"
            else
                log_success "继续使用英文 / Continue using English"
            fi
            ;;
        0)
            return
            ;;
        *)
            log_error "无效选择 / Invalid choice"
            ;;
    esac
    
    read -p "按Enter键继续... / Press Enter to continue..." -r
}

# 主菜单
main_menu() {
    while true; do
        clear
        show_banner
        
        echo "主菜单:"
        echo
        
        if [ -f "$SERVICE_FILE" ] || [ -f "/etc/init.d/$APP_NAME" ]; then
            echo "1) 服务管理 / Service Management"
            echo "2) 健康检查 / Health Check"
            echo "3) 重新安装 / Reinstall"
            echo "4) 切换语言 / Switch Language"
            echo "0) 退出脚本 / Exit Script"
            echo
            read -p "请选择 / Please select [0-4]: " choice
            
            case $choice in
                1)
                    service_management
                    ;;
                2)
                    health_check
                    ;;
                3)
                    install_service
                    ;;
                4)
                    switch_language
                    ;;
                0)
                    log_info "退出脚本 / Exit script"
                    exit 0
                    ;;
                *)
                    log_error "无效选择 / Invalid choice"
                    read -p "按Enter键继续... / Press Enter to continue..." -r
                    ;;
            esac
        else
            echo "1) 安装翻译服务 / Install Translation Service"
            echo "2) 切换语言 / Switch Language"
            echo "0) 退出脚本 / Exit Script"
            echo
            read -p "请选择 / Please select [0-2]: " choice
            
            case $choice in
                1)
                    install_service
                    ;;
                2)
                    switch_language
                    ;;
                0)
                    log_info "退出脚本 / Exit script"
                    exit 0
                    ;;
                *)
                    log_error "无效选择 / Invalid choice"
                    read -p "按Enter键继续... / Press Enter to continue..." -r
                    ;;
            esac
        fi
    done
}

# 主函数
main() {
    check_root
    main_menu
}

# 运行主函数
main "$@"