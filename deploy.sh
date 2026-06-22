#!/bin/bash
set -e

INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$INSTALL_DIR/config.local.json"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     AWS 动态路由监测工具 - 安装程序      ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

# ========== 第一步：安装系统依赖 ==========
echo -e "${YELLOW}[1/5] 安装系统依赖...${NC}"
if command -v apt-get &> /dev/null; then
    apt-get update -qq > /dev/null 2>&1
    apt-get install -y -qq python3 python3-pip python3-venv traceroute unzip curl > /dev/null 2>&1
elif command -v yum &> /dev/null; then
    yum install -y python3 python3-pip traceroute unzip curl > /dev/null 2>&1
fi
echo -e "${GREEN}  ✓ 系统依赖安装完成${NC}"

# ========== 第二步：创建虚拟环境 ==========
echo -e "${YELLOW}[2/5] 创建 Python 虚拟环境...${NC}"
if [ ! -d "$INSTALL_DIR/venv" ]; then
    python3 -m venv "$INSTALL_DIR/venv"
fi
source "$INSTALL_DIR/venv/bin/activate"
pip install -r "$INSTALL_DIR/requirements.txt" --quiet 2>/dev/null
deactivate
echo -e "${GREEN}  ✓ Python 依赖安装完成${NC}"

# ========== 第三步：交互式配置 ==========
echo -e "${YELLOW}[3/5] 配置参数${NC}"
echo ""

# 如果已有配置，询问是否保留
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${CYAN}检测到已有配置文件${NC}"
    read -p "是否重新配置？(y/n): " reconfig
    if [ "$reconfig" != "y" ] && [ "$reconfig" != "Y" ]; then
        echo -e "${GREEN}  ✓ 使用已有配置${NC}"
    else
        rm -f "$CONFIG_FILE"
    fi
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${CYAN}── 基本信息 ──${NC}"
    read -p "服务器名称 (如 tokyo-aws-01): " server_name
    if [ -z "$server_name" ]; then
        server_name="server-$(hostname | tail -c 8)"
    fi
    echo ""

    echo -e "${CYAN}── Telegram 告警 ──${NC}"
    read -p "是否启用 Telegram 告警？(y/n): " enable_tg
    tg_token=""
    tg_chatid=""
    if [ "$enable_tg" = "y" ] || [ "$enable_tg" = "Y" ]; then
        read -p "Bot Token: " tg_token
        read -p "Chat ID: " tg_chatid
    fi
    echo ""

    echo -e "${CYAN}── 钉钉告警 ──${NC}"
    read -p "是否启用钉钉告警？(y/n): " enable_dt
    dt_webhook=""
    if [ "$enable_dt" = "y" ] || [ "$enable_dt" = "Y" ]; then
        read -p "Webhook URL: " dt_webhook
    fi
    echo ""

    # 生成配置文件
    tg_enabled="false"
    if [ "$enable_tg" = "y" ] || [ "$enable_tg" = "Y" ]; then
        tg_enabled="true"
    fi
    dt_enabled="false"
    if [ "$enable_dt" = "y" ] || [ "$enable_dt" = "Y" ]; then
        dt_enabled="true"
    fi

    cat > "$CONFIG_FILE" <<JSONEOF
{
  "server_name": "$server_name",
  "region": "tokyo",
  "mode": "full",
  "ping_targets": [
    {"host": "8.8.8.8", "name": "Google DNS"},
    {"host": "8.8.4.4", "name": "Google DNS-2"},
    {"host": "1.1.1.1", "name": "Cloudflare"},
    {"host": "1.0.0.1", "name": "Cloudflare-2"},
    {"host": "208.67.222.222", "name": "OpenDNS"},
    {"host": "168.63.129.16", "name": "Azure"},
    {"host": "13.107.42.14", "name": "Microsoft"},
    {"host": "99.86.1.150", "name": "Amazon CloudFront"}
  ],
  "traceroute_targets": [
    {"host": "8.8.8.8", "name": "Google"},
    {"host": "1.1.1.1", "name": "Cloudflare"},
    {"host": "13.107.42.14", "name": "Microsoft"}
  ],
  "speedtest": {
    "enabled": true,
    "interval_sec": 1800,
    "target_url": "http://speedtest.tele2.net/10MB.zip"
  },
  "monitoring": {
    "ping_interval_sec": 5,
    "ping_count": 10,
    "traceroute_interval_sec": 180,
    "baseline_sample_count": 100
  },
  "alert": {
    "latency_multiplier": 1.8,
    "latency_abs_threshold_ms": 80,
    "packet_loss_threshold_pct": 3.0,
    "speed_drop_threshold_pct": 50,
    "consecutive_failures": 3,
    "cooldown_sec": 300,
    "recovery_notify": true
  },
  "telegram": {
    "enabled": $tg_enabled,
    "bot_token": "$tg_token",
    "chat_id": "$tg_chatid"
  },
  "dingtalk": {
    "enabled": $dt_enabled,
    "webhook_url": "$dt_webhook",
    "secret": ""
  },
  "database": {
    "path": "monitor.db",
    "cleanup_days": 30
  },
  "log": {
    "level": "INFO",
    "file": "monitor.log",
    "max_size_mb": 50,
    "backup_count": 5
  }
}
JSONEOF
    echo -e "${GREEN}  ✓ 配置已保存${NC}"

    # 显示配置摘要
    echo ""
    echo -e "${CYAN}── 配置摘要 ──${NC}"
    echo -e "  服务器名称: ${GREEN}$server_name${NC}"
    echo -e "  Telegram:   ${GREEN}$tg_enabled${NC}"
    echo -e "  钉钉:       ${GREEN}$dt_enabled${NC}"
    echo ""
fi

# ========== 第四步：创建系统服务 ==========
echo -e "${YELLOW}[4/5] 配置系统服务...${NC}"
PYTHON_PATH="$INSTALL_DIR/venv/bin/python3"

cat > /tmp/route-monitor.service <<SVCEOF
[Unit]
Description=AWS Route Monitor
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$INSTALL_DIR
ExecStart=$PYTHON_PATH $INSTALL_DIR/src/main.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SVCEOF

mv /tmp/route-monitor.service /etc/systemd/system/route-monitor.service
systemctl daemon-reload
systemctl enable route-monitor > /dev/null 2>&1
echo -e "${GREEN}  ✓ 系统服务配置完成${NC}"

# ========== 第五步：安装管理命令 ==========
echo -e "${YELLOW}[5/6] 安装管理命令...${NC}"
if [ -f "$INSTALL_DIR/monitor.sh" ]; then
    chmod +x "$INSTALL_DIR/monitor.sh"
    ln -sf "$INSTALL_DIR/monitor.sh" /usr/local/bin/monitor
    echo -e "${GREEN}  ✓ 管理命令已安装，输入 ${CYAN}monitor${GREEN} 打开管理面板${NC}"
fi

# ========== 第六步：启动服务并测试 ==========
echo -e "${YELLOW}[6/6] 启动服务...${NC}"
systemctl restart route-monitor
sleep 2

if systemctl is-active --quiet route-monitor; then
    echo -e "${GREEN}  ✓ 服务已启动${NC}"
else
    echo -e "${RED}  ✗ 服务启动失败，查看日志: journalctl -u route-monitor -n 20${NC}"
fi

# 发送测试消息
echo ""
echo -e "${CYAN}正在发送测试消息...${NC}"
PYTHON="$INSTALL_DIR/venv/bin/python3"
$PYTHON -c "
import sys, os
sys.path.insert(0, '$INSTALL_DIR/src')
os.chdir('$INSTALL_DIR')
from config import load_config
from alerter import send_alert
config = load_config()
msg = '🔔 路由监测测试消息\n\n服务器: ' + config['server_name'] + '\n状态: 告警通道配置正常\n\n如果你看到这条消息，说明部署成功！'
ok = send_alert(config, msg)
if ok:
    print('  ✓ 测试消息发送成功')
else:
    print('  ✗ 测试消息发送失败，请检查配置')
" 2>/dev/null

# ========== 完成 ==========
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           部署完成！                      ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "输入 ${CYAN}monitor${NC} 打开管理面板"
echo ""
