#!/bin/bash
# 一键部署脚本
# 用法: bash deploy.sh

set -e

INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== AWS 路由监测工具 部署 ==="

# 安装依赖
echo "[1/4] 安装系统依赖..."
if command -v apt-get &> /dev/null; then
    sudo apt-get update -qq
    sudo apt-get install -y -qq python3 python3-pip traceroute > /dev/null 2>&1
elif command -v yum &> /dev/null; then
    sudo yum install -y python3 python3-pip traceroute > /dev/null 2>&1
fi

# 安装 Python 依赖
echo "[2/4] 安装 Python 依赖..."
pip3 install -r requirements.txt --quiet 2>/dev/null || pip install -r requirements.txt --quiet

# 配置
echo "[3/4] 检查配置..."
if [ ! -f "$INSTALL_DIR/config.local.json" ]; then
    cp "$INSTALL_DIR/config.json" "$INSTALL_DIR/config.local.json"
    echo ""
    echo "已创建 config.local.json，请编辑填入你的配置:"
    echo "  nano $INSTALL_DIR/config.local.json"
    echo ""
    echo "需要填写:"
    echo "  - server_name (服务器名称)"
    echo "  - telegram bot_token 和 chat_id"
    echo "  - dingtalk webhook_url"
    echo ""
    echo "填完后重新运行: bash $INSTALL_DIR/deploy.sh"
    exit 0
fi

# 创建 systemd 服务
echo "[4/4] 配置系统服务..."
PYTHON_PATH=$(which python3 || which python)
sudo tee /etc/systemd/system/route-monitor.service > /dev/null <<EOF
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
EOF

sudo systemctl daemon-reload
sudo systemctl enable route-monitor
sudo systemctl restart route-monitor

echo ""
echo "=== 部署完成 ==="
echo ""
echo "常用命令:"
echo "  查看状态: sudo systemctl status route-monitor"
echo "  查看日志: sudo journalctl -u route-monitor -f"
echo "  重启:     sudo systemctl restart route-monitor"
echo "  停止:     sudo systemctl stop route-monitor"
echo "  编辑配置: nano $INSTALL_DIR/config.local.json"
