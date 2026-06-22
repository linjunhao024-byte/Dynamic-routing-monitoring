#!/bin/bash
# 路由监测管理菜单
# 用法: monitor

SERVICE="route-monitor"
INSTALL_DIR="/root/route-monitor"
CONFIG_FILE="$INSTALL_DIR/config.local.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

show_menu() {
    clear
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║        AWS 路由监测 - 管理面板           ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
    echo ""

    # 显示服务状态
    if systemctl is-active --quiet $SERVICE 2>/dev/null; then
        echo -e "  服务状态: ${GREEN}● 运行中${NC}"
    else
        echo -e "  服务状态: ${RED}● 已停止${NC}"
    fi

    # 显示服务器名称
    if [ -f "$CONFIG_FILE" ]; then
        name=$(grep -o '"server_name"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
        echo -e "  服务器:   ${CYAN}$name${NC}"
    fi

    echo ""
    echo -e "  ${YELLOW}1)${NC} 查看状态"
    echo -e "  ${YELLOW}2)${NC} 查看实时日志"
    echo -e "  ${YELLOW}3)${NC} 重启服务"
    echo -e "  ${YELLOW}4)${NC} 停止服务"
    echo -e "  ${YELLOW}5)${NC} 重新配置"
    echo -e "  ${YELLOW}6)${NC} 测试告警"
    echo -e "  ${YELLOW}7)${NC} 更新程序"
    echo -e "  ${RED}8)${NC} 一键卸载"
    echo -e "  ${YELLOW}0)${NC} 退出"
    echo ""
}

test_alert() {
    echo -e "${CYAN}正在发送测试消息...${NC}"

    PYTHON="$INSTALL_DIR/venv/bin/python3"
    $PYTHON -c "
import sys
sys.path.insert(0, '$INSTALL_DIR/src')
from config import load_config
from alerter import send_alert
config = load_config('$CONFIG_FILE')
msg = '🔔 路由监测测试消息\n\n服务器: ' + config['server_name'] + '\n状态: 告警通道配置正常\n\n如果你看到这条消息，说明配置成功！'
if send_alert(config, msg):
    print('发送成功')
else:
    print('发送失败，请检查配置')
"
    echo ""
    read -p "按回车返回菜单..." _
}

update_program() {
    echo -e "${CYAN}正在更新...${NC}"
    cd ~
    rm -rf route-monitor.new main.zip
    wget -q https://github.com/linjunhao024-byte/Dynamic-routing-monitoring/archive/refs/heads/main.zip
    unzip -qo main.zip
    mv Dynamic-routing-monitoring-main route-monitor.new

    # 保留配置和数据
    cp $INSTALL_DIR/config.local.json route-monitor.new/config.local.json 2>/dev/null
    cp $INSTALL_DIR/monitor.db route-monitor.new/monitor.db 2>/dev/null

    # 替换
    rm -rf $INSTALL_DIR
    mv route-monitor.new $INSTALL_DIR
    rm -f main.zip

    # 重建 venv
    cd $INSTALL_DIR
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt --quiet 2>/dev/null
    deactivate

    systemctl restart $SERVICE
    echo -e "${GREEN}更新完成，服务已重启${NC}"
    echo ""
    read -p "按回车返回菜单..." _
}

uninstall() {
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════╗${NC}"
    echo -e "${RED}║           确认卸载？                     ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════╝${NC}"
    echo ""
    read -p "确定要卸载路由监测工具吗？(y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}已取消${NC}"
        read -p "按回车返回菜单..." _
        return
    fi

    echo -e "${YELLOW}正在卸载...${NC}"
    systemctl stop $SERVICE 2>/dev/null
    systemctl disable $SERVICE 2>/dev/null
    rm -f /etc/systemd/system/$SERVICE.service
    systemctl daemon-reload
    rm -f /usr/local/bin/monitor
    rm -rf $INSTALL_DIR
    echo -e "${GREEN}卸载完成${NC}"
    exit 0
}

while true; do
    show_menu
    read -p "请选择操作 [0-8]: " choice
    case $choice in
        1)
            systemctl status $SERVICE --no-pager
            echo ""
            read -p "按回车返回菜单..." _
            ;;
        2)
            echo -e "${CYAN}按 Ctrl+C 退出日志${NC}"
            journalctl -u $SERVICE -f --no-pager
            ;;
        3)
            systemctl restart $SERVICE
            echo -e "${GREEN}服务已重启${NC}"
            sleep 1
            read -p "按回车返回菜单..." _
            ;;
        4)
            systemctl stop $SERVICE
            echo -e "${YELLOW}服务已停止${NC}"
            sleep 1
            read -p "按回车返回菜单..." _
            ;;
        5)
            cd $INSTALL_DIR && bash deploy.sh
            read -p "按回车返回菜单..." _
            ;;
        6)
            test_alert
            ;;
        7)
            update_program
            ;;
        8)
            uninstall
            ;;
        0)
            echo -e "${GREEN}退出${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            sleep 1
            ;;
    esac
done
