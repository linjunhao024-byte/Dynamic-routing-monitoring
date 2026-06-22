#!/bin/bash
# 路由监测管理菜单
# 用法: monitor

chmod +x "$0" 2>/dev/null

SERVICE="route-monitor"
INSTALL_DIR="/root/route-monitor"
CONFIG_FILE="$INSTALL_DIR/config.local.json"

ESC=$(printf '\033')
R="${ESC}[0;31m"
G="${ESC}[0;32m"
Y="${ESC}[1;33m"
C="${ESC}[0;36m"
B="${ESC}[1;37m"
D="${ESC}[2;37m"
NC="${ESC}[0m"

get_server_name() {
    if [ -f "$CONFIG_FILE" ]; then
        grep -o '"server_name"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4
    else
        echo "未配置"
    fi
}

get_uptime() {
    if systemctl is-active --quiet $SERVICE 2>/dev/null; then
        local start=$(systemctl show $SERVICE --property=ActiveEnterTimestamp --value 2>/dev/null)
        if [ -n "$start" ]; then
            local start_ts=$(date -d "$start" +%s 2>/dev/null)
            local now_ts=$(date +%s)
            local diff=$((now_ts - start_ts))
            if [ "$diff" -lt 60 ]; then
                echo "${diff}秒"
            elif [ "$diff" -lt 3600 ]; then
                echo "$((diff/60))分$((diff%60))秒"
            elif [ "$diff" -lt 86400 ]; then
                echo "$((diff/3600))小时$(((diff%3600)/60))分"
            else
                echo "$((diff/86400))天$(((diff%86400)/3600))小时"
            fi
        fi
    fi
}

c() {
    printf '%b\n' "$*"
}

show_menu() {
    clear
    local name=$(get_server_name)
    local running=false
    systemctl is-active --quiet $SERVICE 2>/dev/null && running=true

    echo ""
    c "${C}+===============================================+${NC}"
    c "${C}|          AWS Route Monitor  v1.0              |${NC}"
    c "${C}+===============================================+${NC}"

    if $running; then
        local uptime=$(get_uptime)
        c "${C}|${NC}  ${G}[RUNNING]${NC} ${D}已运行 ${uptime}${NC}"
    else
        c "${C}|${NC}  ${R}[STOPPED]${NC}"
    fi

    c "${C}|${NC}  服务器: ${B}${name}${NC}"
    c "${C}+===============================================+${NC}"
    c "${C}|                                               |${NC}"
    c "${C}|${NC}  ${Y} 1${NC}  查看状态"
    c "${C}|${NC}  ${Y} 2${NC}  查看实时日志"
    c "${C}|${NC}  ${Y} 3${NC}  重启服务"
    c "${C}|${NC}  ${Y} 4${NC}  停止服务"
    c "${C}|${NC}  ${Y} 5${NC}  重新配置"
    c "${C}|${NC}  ${Y} 6${NC}  测试告警"
    c "${C}|${NC}  ${Y} 7${NC}  更新程序"
    c "${C}|${NC}  ${R} 8${NC}  一键卸载"
    c "${C}|${NC}  ${Y} 0${NC}  退出"
    c "${C}|                                               |${NC}"
    c "${C}+===============================================+${NC}"
    echo ""
}

press_enter() {
    echo ""
    read -p "  按回车返回菜单..." _
}

test_alert() {
    echo ""
    c "  ${C}[..] 正在发送测试消息...${NC}"
    PYTHON="$INSTALL_DIR/venv/bin/python3"
    result=$($PYTHON -c "
import sys, os
sys.path.insert(0, '$INSTALL_DIR/src')
os.chdir('$INSTALL_DIR')
from config import load_config
from alerter import send_alert
config = load_config()
msg = '路由监测测试消息\n\n服务器: ' + config['server_name'] + '\n状态: 告警通道配置正常\n\n如果你看到这条消息，说明配置成功！'
ok = send_alert(config, msg)
print('ok' if ok else 'fail')
" 2>/dev/null)
    if [ "$result" = "ok" ]; then
        c "  ${G}[OK] 测试消息已发送，请检查 TG 和钉钉${NC}"
    else
        c "  ${R}[FAIL] 发送失败，请检查配置${NC}"
    fi
    press_enter
}

update_program() {
    echo ""
    c "  ${C}[..] 正在检查更新...${NC}"

    latest_hash=$(curl -s "https://api.github.com/repos/linjunhao024-byte/Dynamic-routing-monitoring/commits/main" 2>/dev/null | grep -o '"sha":"[^"]*"' | head -1 | cut -d'"' -f4)
    current_hash=""
    if [ -f "$INSTALL_DIR/.git_hash" ]; then
        current_hash=$(cat "$INSTALL_DIR/.git_hash")
    fi

    if [ -n "$latest_hash" ] && [ "$current_hash" = "$latest_hash" ]; then
        c "  ${G}[OK] 已是最新版本${NC}"
        press_enter
        return
    fi

    c "  ${Y}[..] 发现新版本，正在更新...${NC}"

    TMP_BACKUP="/tmp/route-monitor-backup"
    rm -rf "$TMP_BACKUP"
    mkdir -p "$TMP_BACKUP"
    cp "$INSTALL_DIR/config.local.json" "$TMP_BACKUP/" 2>/dev/null
    cp "$INSTALL_DIR/monitor.db" "$TMP_BACKUP/" 2>/dev/null
    [ -f "$INSTALL_DIR/.git_hash" ] && cp "$INSTALL_DIR/.git_hash" "$TMP_BACKUP/" 2>/dev/null

    cd /tmp
    rm -rf route-monitor.new main.zip
    wget -q https://github.com/linjunhao024-byte/Dynamic-routing-monitoring/archive/refs/heads/main.zip
    unzip -qo main.zip
    mv Dynamic-routing-monitoring-main route-monitor.new

    cp "$TMP_BACKUP/config.local.json" route-monitor.new/ 2>/dev/null
    cp "$TMP_BACKUP/monitor.db" route-monitor.new/ 2>/dev/null
    echo "$latest_hash" > route-monitor.new/.git_hash
    rm -rf "$TMP_BACKUP"

    rm -rf "$INSTALL_DIR"
    mv route-monitor.new "$INSTALL_DIR"
    rm -f main.zip

    chmod +x "$INSTALL_DIR/monitor.sh"
    ln -sf "$INSTALL_DIR/monitor.sh" /usr/local/bin/monitor

    cd "$INSTALL_DIR"
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt --quiet 2>/dev/null
    deactivate

    systemctl restart $SERVICE
    cd /root
    c "  ${G}[OK] 更新完成，服务已重启${NC}"
    press_enter
}

uninstall() {
    echo ""
    c "  ${R}+===============================================+${NC}"
    c "  ${R}|  WARNING: 此操作将完全删除路由监测工具       |${NC}"
    c "  ${R}+===============================================+${NC}"
    echo ""
    read -p "  输入 yes 确认卸载: " confirm
    if [ "$confirm" != "yes" ]; then
        c "  ${Y}已取消${NC}"
        press_enter
        return
    fi

    echo ""
    c "  ${Y}[..] 正在卸载...${NC}"
    systemctl stop $SERVICE 2>/dev/null
    systemctl disable $SERVICE 2>/dev/null
    rm -f /etc/systemd/system/$SERVICE.service
    systemctl daemon-reload
    rm -f /usr/local/bin/monitor
    rm -rf $INSTALL_DIR
    echo ""
    c "  ${G}[OK] 卸载完成${NC}"
    echo ""
    exit 0
}

while true; do
    show_menu
    read -p "  选择操作 [0-8]: " choice
    case $choice in
        1)
            echo ""
            systemctl status $SERVICE --no-pager
            press_enter
            ;;
        2)
            echo ""
            c "  ${C}按 Ctrl+C 停止查看日志，返回菜单${NC}"
            echo ""
            journalctl -u $SERVICE -f --no-pager
            ;;
        3)
            systemctl restart $SERVICE
            echo ""
            c "  ${G}[OK] 服务已重启${NC}"
            press_enter
            ;;
        4)
            systemctl stop $SERVICE
            echo ""
            c "  ${Y}[OK] 服务已停止${NC}"
            press_enter
            ;;
        5)
            cd $INSTALL_DIR && bash deploy.sh
            press_enter
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
            echo ""
            c "  ${G}Bye!${NC}"
            echo ""
            exit 0
            ;;
        *)
            echo ""
            c "  ${R}无效选择${NC}"
            sleep 1
            ;;
    esac
done
