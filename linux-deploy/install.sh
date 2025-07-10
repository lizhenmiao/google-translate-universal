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
SCRIPT_VERSION="1.0.0"
GITHUB_RAW_URL="https://raw.githubusercontent.com/lizhenmiao/google-translate-universal/master/linux-deploy"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    Google翻译服务管理工具                    ║"
    echo "║                         版本: ${SCRIPT_VERSION}              ║"
    echo "║                       作者: lizhenmiao                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
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
        log_info "检测到 Alpine Linux"
    elif [ -f /etc/ubuntu-release ] || [ -f /etc/debian_version ]; then
        OS="ubuntu"
        PKG_MANAGER="apt"
        log_info "检测到 Ubuntu/Debian"
    elif [ -f /etc/centos-release ] || [ -f /etc/redhat-release ]; then
        OS="centos"
        PKG_MANAGER="yum"
        log_info "检测到 CentOS/RHEL"
    else
        log_warn "未知的操作系统，将使用通用安装方式"
        OS="generic"
        PKG_MANAGER="unknown"
    fi
}

# 安装系统依赖
install_dependencies() {
    log_info "安装系统依赖..."
    
    case $PKG_MANAGER in
        "apk")
            apk update
            apk add --no-cache nodejs npm curl bash logrotate
            ;;
        "apt")
            apt update
            apt install -y nodejs npm curl bash logrotate
            ;;
        "yum")
            yum update -y
            yum install -y nodejs npm curl bash logrotate
            ;;
        *)
            log_warn "请手动安装 Node.js, npm, curl, bash, logrotate"
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
    log_info "下载应用文件..."
    
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

# 安装Node.js依赖
install_node_dependencies() {
    log_info "安装Node.js依赖..."
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

# 创建systemd服务
create_systemd_service() {
    log_info "创建systemd服务..."
    
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
    
    if [ "$ENABLE_AUTOSTART" = true ]; then
        systemctl enable $APP_NAME
        log_success "服务已设置为开机自启"
    fi
    
    log_success "systemd服务创建完成"
}

# 配置日志轮转
setup_logrotate() {
    log_info "配置日志轮转..."
    
    cat > $LOGROTATE_FILE << EOF
$APP_DIR/logs/translate-service.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    postrotate
        echo "日志已轮转: \$(date)" >> /var/log/translate-service-rotate.log
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
    
    if systemctl start $APP_NAME; then
        sleep 2
        if systemctl is-active --quiet $APP_NAME; then
            log_success "服务启动成功!"
            echo
            log_info "服务信息:"
            echo "  访问地址: http://localhost:$PORT"
            echo "  健康检查: http://localhost:$PORT/health"
            echo "  API文档: http://localhost:$PORT"
            if [ -n "$ACCESS_TOKEN" ]; then
                echo "  访问TOKEN: $ACCESS_TOKEN"
            fi
        else
            log_error "服务启动失败"
            show_service_status
        fi
    else
        log_error "服务启动失败"
    fi
}

# 检查服务状态
check_service_status() {
    if systemctl is-active --quiet $APP_NAME; then
        return 0
    else
        return 1
    fi
}

# 显示服务状态
show_service_status() {
    echo
    log_info "服务状态信息:"
    systemctl status $APP_NAME --no-pager -l
    echo
    
    log_info "端口监听状态:"
    if command -v netstat &> /dev/null; then
        netstat -tlnp | grep ":$PORT " || echo "端口 $PORT 未监听"
    elif command -v ss &> /dev/null; then
        ss -tlnp | grep ":$PORT " || echo "端口 $PORT 未监听"
    else
        log_warn "无法检查端口状态"
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
    echo "5) 返回主菜单"
    echo
    
    read -p "请选择 [1-5]: " choice
    
    case $choice in
        1)
            log_date=$(date +%Y-%m-%d)
            log_file="$APP_DIR/logs/translate-service.log"
            ;;
        2)
            log_date=$(date -d "yesterday" +%Y-%m-%d)
            log_file="$APP_DIR/logs/translate-service.log.1"
            ;;
        3)
            log_info "显示系统服务日志 (按q退出):"
            journalctl -u $APP_NAME --no-pager
            return
            ;;
        4)
            log_info "显示实时日志 (按Ctrl+C退出):"
            if [ -f "$APP_DIR/logs/translate-service.log" ]; then
                tail -f "$APP_DIR/logs/translate-service.log"
            else
                journalctl -u $APP_NAME -f
            fi
            return
            ;;
        5)
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
    while true; do
        clear
        show_banner
        
        echo "服务管理:"
        echo
        
        if check_service_status; then
            echo -e "服务状态: ${GREEN}运行中${NC}"
        else
            echo -e "服务状态: ${RED}已停止${NC}"
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
        echo "9) 返回主菜单"
        echo
        
        read -p "请选择 [1-9]: " choice
        
        case $choice in
            1)
                log_info "启动服务..."
                if systemctl start $APP_NAME; then
                    log_success "服务启动成功"
                else
                    log_error "服务启动失败"
                fi
                read -p "按Enter键继续..." -r
                ;;
            2)
                log_info "停止服务..."
                if systemctl stop $APP_NAME; then
                    log_success "服务停止成功"
                else
                    log_error "服务停止失败"
                fi
                read -p "按Enter键继续..." -r
                ;;
            3)
                log_info "重启服务..."
                if systemctl restart $APP_NAME; then
                    log_success "服务重启成功"
                else
                    log_error "服务重启失败"
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
                if systemctl enable $APP_NAME; then
                    log_success "开机自启已启用"
                else
                    log_error "开机自启启用失败"
                fi
                read -p "按Enter键继续..." -r
                ;;
            7)
                log_info "禁用开机自启..."
                if systemctl disable $APP_NAME; then
                    log_success "开机自启已禁用"
                else
                    log_error "开机自启禁用失败"
                fi
                read -p "按Enter键继续..." -r
                ;;
            8)
                uninstall_service
                return
                ;;
            9)
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
        systemctl stop $APP_NAME &>/dev/null || true
        systemctl disable $APP_NAME &>/dev/null || true
        
        # 删除文件
        rm -f $SERVICE_FILE
        rm -f $LOGROTATE_FILE
        rm -rf $APP_DIR
        
        # 重新加载systemd
        systemctl daemon-reload
        
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
    create_systemd_service
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

# 主菜单
main_menu() {
    while true; do
        clear
        show_banner
        
        echo "主菜单:"
        echo
        
        if [ -f "$SERVICE_FILE" ]; then
            echo "1) 服务管理"
            echo "2) 健康检查"
            echo "3) 重新安装"
            echo "4) 退出"
            echo
            read -p "请选择 [1-4]: " choice
            
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
                    log_info "退出脚本"
                    exit 0
                    ;;
                *)
                    log_error "无效选择"
                    read -p "按Enter键继续..." -r
                    ;;
            esac
        else
            echo "1) 安装翻译服务"
            echo "2) 退出"
            echo
            read -p "请选择 [1-2]: " choice
            
            case $choice in
                1)
                    install_service
                    ;;
                2)
                    log_info "退出脚本"
                    exit 0
                    ;;
                *)
                    log_error "无效选择"
                    read -p "按Enter键继续..." -r
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