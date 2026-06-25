#!/bin/bash
# 路由监测管理菜单
# 用法: monitor (或自定义命令名)

SERVICE="route-monitor"
INSTALL_DIR="/root/route-monitor"
CONFIG_FILE="$INSTALL_DIR/config.local.json"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ============================================================================
# 辅助函数
# ============================================================================

get_config_value() {
    local key="$1"
    python3 -c "
import json
try:
    with open('$CONFIG_FILE') as f:
        cfg = json.load(f)
    keys = '$key'.split('.')
    val = cfg
    for k in keys:
        val = val[k]
    print(val)
except:
    print('')
" 2>/dev/null
}

set_config_value() {
    local key="$1"
    local value="$2"
    python3 -c "
import json
with open('$CONFIG_FILE') as f:
    cfg = json.load(f)
keys = '$key'.split('.')
d = cfg
for k in keys[:-1]:
    d = d[k]
d[keys[-1]] = '$value'
with open('$CONFIG_FILE', 'w') as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
" 2>/dev/null
}

get_server_name() {
    get_config_value "server_name"
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

wait_key() {
    echo ""
    echo -ne "${DIM}  按 Enter 返回菜单...${NC}"
    read -r
}

# ============================================================================
# 主菜单
# ============================================================================

show_header() {
    clear
    local name=$(get_server_name)
    local running=false
    systemctl is-active --quiet $SERVICE 2>/dev/null && running=true

    echo -e "${CYAN}+===========================================================================+${NC}"
    echo -e "${CYAN}|${NC}  ${BOLD}🚦 Dynamic Routing Monitor${NC}                                          ${CYAN}|${NC}"
    echo -e "${CYAN}+===========================================================================+${NC}"

    if $running; then
        local uptime=$(get_uptime)
        printf "${CYAN}|${NC}  ${GREEN}● 运行中${NC}   自启: ${GREEN}已启用${NC}   运行时间: ${GREEN}%-25s${NC}${CYAN}|${NC}\n" "$uptime"
    else
        printf "${CYAN}|${NC}  ${RED}● 已停止${NC}   自启: ${YELLOW}未启用${NC}                                         ${CYAN}|${NC}\n"
    fi

    printf "${CYAN}|${NC}  服务器: ${BOLD}%-59s${NC}${CYAN}|${NC}\n" "$name"
    echo -e "${CYAN}+===========================================================================+${NC}"
}

show_menu() {
    echo -e "${CYAN}+===========================================================================+${NC}"
    echo -e "${CYAN}|${NC}  ${BOLD}服务控制${NC}                                                               ${CYAN}|${NC}"
    echo -e "${CYAN}+---------------------------------------------------------------------------+${NC}"
    echo -e "${CYAN}|${NC}  ${CYAN}[1]${NC} 查看状态         ${CYAN}[5]${NC} 编辑配置         ${CYAN}[9]${NC} 测试告警         ${CYAN}|${NC}"
    echo -e "${CYAN}|${NC}  ${CYAN}[2]${NC} 实时日志         ${CYAN}[6]${NC} 更新程序         ${CYAN}[10]${NC} 查看基线          ${CYAN}|${NC}"
    echo -e "${CYAN}|${NC}  ${CYAN}[3]${NC} 重启服务         ${CYAN}[7]${NC} 一键卸载         ${CYAN}[11]${NC} Web 面板          ${CYAN}|${NC}"
    echo -e "${CYAN}|${NC}  ${CYAN}[4]${NC} 停止服务         ${CYAN}[8]${NC} 查看日志         ${CYAN}[12]${NC} 登录自动进入菜单  ${CYAN}|${NC}"
    echo -e "${CYAN}+---------------------------------------------------------------------------+${NC}"
    echo -e "${CYAN}|${NC}  ${BOLD}快速操作${NC}                                                               ${CYAN}|${NC}"
    echo -e "${CYAN}+---------------------------------------------------------------------------+${NC}"
    echo -e "${CYAN}|${NC}  ${GREEN}[s]${NC} 立即测速         ${GREEN}[r]${NC} 路由追踪         ${GREEN}[d]${NC} 每日报告          ${CYAN}|${NC}"
    echo -e "${CYAN}+---------------------------------------------------------------------------+${NC}"
    echo -e "${CYAN}|${NC}  ${CYAN}[0]${NC} 退出                                                                     ${CYAN}|${NC}"
    echo -e "${CYAN}+===========================================================================+${NC}"
    echo ""
    echo -ne "  请选择 [0-12/s/r/d]: "
}

# ============================================================================
# 功能实现
# ============================================================================

do_status() {
    echo ""
    local is_active=$(systemctl is-active $SERVICE 2>/dev/null)
    local is_enabled=$(systemctl is-enabled $SERVICE 2>/dev/null)
    local pid=$(systemctl show -p MainPID $SERVICE 2>/dev/null | cut -d= -f2)
    local memory=$(systemctl show -p MemoryCurrent $SERVICE 2>/dev/null | cut -d= -f2)
    local uptime=$(get_uptime)

    # 格式化内存
    if [[ -n "$memory" && "$memory" != "[not set]" ]]; then
        memory="$(( memory / 1024 / 1024 )) MB"
    else
        memory="N/A"
    fi

    # 状态颜色
    local status_color="${RED}"
    [[ "$is_active" == "active" ]] && status_color="${GREEN}"
    local boot_color="${YELLOW}"
    [[ "$is_enabled" == "enabled" ]] && boot_color="${GREEN}"

    echo -e "${CYAN}+===========================================================================+${NC}"
    printf "${CYAN}|${NC}  ${BOLD}%-69s${NC}${CYAN}|${NC}\n" "服务状态"
    echo -e "${CYAN}+---------------------------------------------------------------------------+${NC}"
    printf "${CYAN}|${NC}  状态: ${status_color}%-10s${NC}  自启: ${boot_color}%-10s${NC}  PID: %-10s       ${CYAN}|${NC}\n" "$is_active" "$is_enabled" "$pid"
    printf "${CYAN}|${NC}  内存: %-10s  运行时间: %-30s   ${CYAN}|${NC}\n" "$memory" "$uptime"
    echo -e "${CYAN}+---------------------------------------------------------------------------+${NC}"

    # 最近统计
    PYTHON="$INSTALL_DIR/venv/bin/python3"
    local stats=$($PYTHON -c "
import sys, os
sys.path.insert(0, '$INSTALL_DIR/src')
os.chdir('$INSTALL_DIR')
from config import load_config
from db import Database
config = load_config()
db = Database(config['database']['path'])
stats = db.get_stats_summary(hours=1)
if stats:
    for row in stats:
        host, name, avg, mn, mx, loss, cnt = row
        print(f'{name}|{avg:.1f}|{mn:.1f}|{mx:.1f}|{loss:.1f}|{cnt}')
else:
    print('no_data')
" 2>/dev/null)

    if [[ -n "$stats" && "$stats" != "no_data" ]]; then
        printf "${CYAN}|${NC}  ${BOLD}%-69s${NC}${CYAN}|${NC}\n" "过去1小时统计"
        echo -e "${CYAN}+---------------------------------------------------------------------------+${NC}"
        printf "${CYAN}|${NC}  %-16s %-10s %-10s %-10s %-10s ${CYAN}|${NC}\n" "目标" "平均延迟" "最低" "最高" "丢包"
        echo -e "${CYAN}+---------------------------------------------------------------------------+${NC}"
        echo "$stats" | while IFS='|' read -r name avg mn mx loss cnt; do
            printf "${CYAN}|${NC}  %-16s ${GREEN}%-10s${NC} %-10s %-10s %-10s ${CYAN}|${NC}\n" "$name" "${avg}ms" "${mn}ms" "${mx}ms" "${loss}%"
        done
    else
        printf "${CYAN}|${NC}  ${DIM}%-69s${NC}${CYAN}|${NC}\n" "暂无统计数据"
    fi

    echo -e "${CYAN}+===========================================================================+${NC}"
    wait_key
}

do_log() {
    echo ""
    echo -e "${CYAN}+===========================================================================+${NC}"
    printf "${CYAN}|${NC}  ${BOLD}%-69s${NC}${CYAN}|${NC}\n" "实时日志"
    echo -e "${CYAN}+---------------------------------------------------------------------------+${NC}"
    echo -e "${YELLOW}  按 Enter 返回菜单...${NC}"
    echo ""

    journalctl -u $SERVICE -f --no-pager -o cat | while IFS= read -r line; do
        local time=$(date '+%H:%M:%S')
        local color="${NC}"
        if echo "$line" | grep -q "ERROR"; then
            color="${RED}"
        elif echo "$line" | grep -q "WARNING"; then
            color="${YELLOW}"
        elif echo "$line" | grep -q "INFO"; then
            color="${GREEN}"
        fi
        printf "  ${CYAN}│${NC}  %-10s ${color}%-58s${NC} ${CYAN}│${NC}\n" "$time" "$line"
    done &
    local jctl_pid=$!
    read -r
    kill $jctl_pid 2>/dev/null
    wait $jctl_pid 2>/dev/null
}

do_restart() {
    echo ""
    systemctl restart $SERVICE
    sleep 1
    if systemctl is-active --quiet $SERVICE; then
        echo -e "  ${GREEN}[✓]${NC} 服务已重启"
    else
        echo -e "  ${RED}[✗]${NC} 服务重启失败"
    fi
    wait_key
}

do_stop() {
    echo ""
    systemctl stop $SERVICE
    echo -e "  ${YELLOW}[✓]${NC} 服务已停止"
    wait_key
}

do_edit_config() {
    while true; do
        clear
        local name=$(get_config_value "server_name")
        local tg_enabled=$(get_config_value "telegram.enabled")
        local dt_enabled=$(get_config_value "dingtalk.enabled")
        local ping_interval=$(get_config_value "monitoring.ping_interval_sec")
        local latency_ms=$(get_config_value "alert.latency_abs_threshold_ms")
        local loss_pct=$(get_config_value "alert.packet_loss_threshold_pct")

        # 检测自动菜单状态
        local auto_menu_status="未启用"
        if grep -q "# route-monitor-auto-menu" "$HOME/.bashrc" 2>/dev/null; then
            auto_menu_status="已启用"
        fi

        echo -e "${CYAN}+===========================================================================+${NC}"
        printf "${CYAN}|${NC}  ${BOLD}%-69s${NC}${CYAN}|${NC}\n" "编辑配置"
        echo -e "${CYAN}+---------------------------------------------------------------------------+${NC}"
        echo -e "${CYAN}|${NC}  ${BOLD}基本设置${NC}                                                               ${CYAN}|${NC}"
        printf "${CYAN}|${NC}    ${CYAN}[1]${NC} 服务器名称    ${GREEN}%-51s${NC}${CYAN}|${NC}\n" "$name"
        printf "${CYAN}|${NC}    ${CYAN}[7]${NC} 登录自动菜单  ${GREEN}%-51s${NC}${CYAN}|${NC}\n" "$auto_menu_status"
        echo -e "${CYAN}|${NC}                                                              ${CYAN}|${NC}"
        echo -e "${CYAN}|${NC}  ${BOLD}告警渠道${NC}                                                               ${CYAN}|${NC}"
        printf "${CYAN}|${NC}    ${CYAN}[2]${NC} Telegram      ${GREEN}%-51s${NC}${CYAN}|${NC}\n" "$tg_enabled"
        printf "${CYAN}|${NC}    ${CYAN}[3]${NC} 钉钉          ${GREEN}%-51s${NC}${CYAN}|${NC}\n" "$dt_enabled"
        echo -e "${CYAN}|${NC}                                                              ${CYAN}|${NC}"
        echo -e "${CYAN}|${NC}  ${BOLD}监测参数${NC}                                                               ${CYAN}|${NC}"
        printf "${CYAN}|${NC}    ${CYAN}[4]${NC} Ping间隔(秒)  ${GREEN}%-51s${NC}${CYAN}|${NC}\n" "$ping_interval"
        printf "${CYAN}|${NC}    ${CYAN}[5]${NC} 延迟阈值(ms)  ${GREEN}%-51s${NC}${CYAN}|${NC}\n" "$latency_ms"
        printf "${CYAN}|${NC}    ${CYAN}[6]${NC} 丢包阈值(%)   ${GREEN}%-51s${NC}${CYAN}|${NC}\n" "$loss_pct"
        echo -e "${CYAN}|${NC}                                                              ${CYAN}|${NC}"
        echo -e "${CYAN}|${NC}    ${GREEN}[s]${NC} 保存并重启      ${RED}[q]${NC} 不保存返回                            ${CYAN}|${NC}"
        echo -e "${CYAN}+===========================================================================+${NC}"
        echo ""
        echo -ne "  选择要编辑的项目: "
        read edit_choice

        case $edit_choice in
            1)
                echo -ne "  服务器名称: "
                read val
                [ -n "$val" ] && set_config_value "server_name" "$val"
                ;;
            2)
                echo -ne "  启用 Telegram? (true/false): "
                read val
                [ "$val" = "true" ] || [ "$val" = "false" ] && set_config_value "telegram.enabled" "$val"
                ;;
            3)
                echo -ne "  启用钉钉? (true/false): "
                read val
                [ "$val" = "true" ] || [ "$val" = "false" ] && set_config_value "dingtalk.enabled" "$val"
                ;;
            4)
                echo -ne "  Ping间隔(秒): "
                read val
                [[ "$val" =~ ^[0-9]+$ ]] && set_config_value "monitoring.ping_interval_sec" "$val"
                ;;
            5)
                echo -ne "  延迟阈值(ms): "
                read val
                [[ "$val" =~ ^[0-9]+$ ]] && set_config_value "alert.latency_abs_threshold_ms" "$val"
                ;;
            6)
                echo -ne "  丢包阈值(%): "
                read val
                [[ "$val" =~ ^[0-9]+$ ]] && set_config_value "alert.packet_loss_threshold_pct" "$val"
                ;;
            7)
                if grep -q "# route-monitor-auto-menu" "$HOME/.bashrc" 2>/dev/null; then
                    sed -i "/# route-monitor-auto-menu/,+1d" "$HOME/.bashrc"
                    echo -e "  ${YELLOW}[✓]${NC} 已取消登录自动进入菜单"
                else
                    echo "" >> "$HOME/.bashrc"
                    echo "# route-monitor-auto-menu" >> "$HOME/.bashrc"
                    echo "monitor" >> "$HOME/.bashrc"
                    echo -e "  ${GREEN}[✓]${NC} 已启用登录自动进入菜单"
                fi
                sleep 1
                ;;
            s|S)
                systemctl restart $SERVICE
                echo ""
                echo -e "  ${GREEN}[✓]${NC} 配置已保存，服务已重启"
                wait_key
                return
                ;;
            q|Q)
                echo ""
                echo -e "  ${YELLOW}已放弃修改${NC}"
                wait_key
                return
                ;;
            *)
                echo -e "  ${RED}无效选择${NC}"
                sleep 1
                ;;
        esac
    done
}

do_update() {
    echo ""
    echo -e "${CYAN}+===========================================================================+${NC}"
    printf "${CYAN}|${NC}  ${BOLD}%-69s${NC}${CYAN}|${NC}\n" "更新程序"
    echo -e "${CYAN}+---------------------------------------------------------------------------+${NC}"

    # ── 1. 检查最新版本 ──
    printf "${CYAN}|${NC}  %-69s${NC}${CYAN}|${NC}\n" "正在检查更新..."
    local api_resp
    api_resp=$(curl -s --max-time 10 "https://api.github.com/repos/linjunhao024-byte/Dynamic-routing-monitoring/commits/main" 2>/dev/null)
    local latest_hash
    latest_hash=$(echo "$api_resp" | grep -o '"sha":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -z "$latest_hash" ]; then
        printf "${CYAN}|${NC}  ${RED}[✗]${NC} 无法获取版本信息（GitHub API 限流或网络问题）              ${CYAN}|${NC}\n"
        printf "${CYAN}|${NC}  ${YELLOW}[!]${NC} 提示: 等几分钟后重试，或手动下载更新                       ${CYAN}|${NC}\n"
        echo -e "${CYAN}+===========================================================================+${NC}"
        wait_key
        return
    fi

    local current_hash=""
    if [ -f "$INSTALL_DIR/.git_hash" ]; then
        current_hash=$(cat "$INSTALL_DIR/.git_hash")
    fi

    if [ "$current_hash" = "$latest_hash" ]; then
        printf "${CYAN}|${NC}  ${GREEN}[✓]${NC} 已是最新版本 (${latest_hash:0:8})                              ${CYAN}|${NC}\n"
        echo -e "${CYAN}+===========================================================================+${NC}"
        wait_key
        return
    fi

    printf "${CYAN}|${NC}  ${YELLOW}[!]${NC} 发现新版本，正在更新...                                    ${CYAN}|${NC}\n"
    printf "${CYAN}|${NC}  当前: ${DIM}${current_hash:0:8}${NC}  →  最新: ${GREEN}${latest_hash:0:8}${NC}                          ${CYAN}|${NC}\n"

    # ── 2. 备份 ──
    local TMP_BACKUP="/tmp/route-monitor-backup-$$"
    rm -rf "$TMP_BACKUP"
    mkdir -p "$TMP_BACKUP"
    cp "$CONFIG_FILE" "$TMP_BACKUP/" 2>/dev/null
    cp "$INSTALL_DIR/monitor.db" "$TMP_BACKUP/" 2>/dev/null
    cp "$INSTALL_DIR/requirements.txt" "$TMP_BACKUP/" 2>/dev/null
    printf "${CYAN}|${NC}  ${GREEN}[✓]${NC} 配置和数据已备份                                          ${CYAN}|${NC}\n"

    # ── 3. 下载到临时目录（不影响原安装）──
    local TMP_WORK="/tmp/route-monitor-update-$$"
    rm -rf "$TMP_WORK"
    mkdir -p "$TMP_WORK"
    cd "$TMP_WORK"

    printf "${CYAN}|${NC}  %-69s${CYAN}|${NC}\n" "正在下载..."
    if ! wget -q --timeout=30 -O main.zip \
        "https://github.com/linjunhao024-byte/Dynamic-routing-monitoring/archive/refs/heads/main.zip"; then
        printf "${CYAN}|${NC}  ${RED}[✗]${NC} 下载失败，原版本未受影响                                  ${CYAN}|${NC}\n"
        rm -rf "$TMP_WORK" "$TMP_BACKUP"
        echo -e "${CYAN}+===========================================================================+${NC}"
        wait_key
        return
    fi

    printf "${CYAN}|${NC}  %-69s${CYAN}|${NC}\n" "正在解压..."
    if ! unzip -qo main.zip; then
        printf "${CYAN}|${NC}  ${RED}[✗]${NC} 解压失败，原版本未受影响                                  ${CYAN}|${NC}\n"
        rm -rf "$TMP_WORK" "$TMP_BACKUP"
        echo -e "${CYAN}+===========================================================================+${NC}"
        wait_key
        return
    fi

    if [ ! -d "Dynamic-routing-monitoring-main" ]; then
        printf "${CYAN}|${NC}  ${RED}[✗]${NC} 解压目录异常，原版本未受影响                              ${CYAN}|${NC}\n"
        rm -rf "$TMP_WORK" "$TMP_BACKUP"
        echo -e "${CYAN}+===========================================================================+${NC}"
        wait_key
        return
    fi

    mv Dynamic-routing-monitoring-main route-monitor.new

    # ── 4. 恢复配置和数据 ──
    cp "$TMP_BACKUP/config.local.json" route-monitor.new/ 2>/dev/null
    cp "$TMP_BACKUP/monitor.db" route-monitor.new/ 2>/dev/null
    echo "$latest_hash" > route-monitor.new/.git_hash

    # ── 5. 替换安装目录 ──
    printf "${CYAN}|${NC}  %-69s${CYAN}|${NC}\n" "正在替换文件..."
    rm -rf "$INSTALL_DIR"
    mv "$TMP_WORK/route-monitor.new" "$INSTALL_DIR"
    rm -rf "$TMP_WORK"

    # ── 6. 重新安装依赖（仅在变化时）──
    chmod +x "$INSTALL_DIR/monitor.sh"
    local cmd_name=$(basename "$0")
    ln -sf "$INSTALL_DIR/monitor.sh" "/usr/local/bin/$cmd_name"

    local need_pip=true
    if [ -f "$TMP_BACKUP/requirements.txt" ] && [ -f "$INSTALL_DIR/requirements.txt" ]; then
        if diff -q "$TMP_BACKUP/requirements.txt" "$INSTALL_DIR/requirements.txt" > /dev/null 2>&1; then
            need_pip=false
            printf "${CYAN}|${NC}  ${GREEN}[✓]${NC} 依赖未变化，跳过 pip install                               ${CYAN}|${NC}\n"
        fi
    fi
    rm -rf "$TMP_BACKUP"

    if $need_pip; then
        printf "${CYAN}|${NC}  %-69s${CYAN}|${NC}\n" "正在安装依赖..."
        cd "$INSTALL_DIR"
        python3 -m venv venv
        source venv/bin/activate
        if ! pip install -r requirements.txt --quiet 2>&1; then
            printf "${CYAN}|${NC}  ${YELLOW}[!]${NC} 依赖安装可能不完整，服务可能无法启动                      ${CYAN}|${NC}\n"
        fi
        deactivate
    fi

    # ── 7. 完成，等待用户确认重启 ──
    echo -e "${CYAN}+---------------------------------------------------------------------------+${NC}"
    printf "${CYAN}|${NC}  ${GREEN}[✓]${NC} 更新完成！                                                ${CYAN}|${NC}\n"
    echo -e "${CYAN}+---------------------------------------------------------------------------+${NC}"
    echo ""
    echo -ne "  按回车重启服务..."
    read _
    systemctl restart $SERVICE
    sleep 1
    if systemctl is-active --quiet $SERVICE; then
        printf "  ${GREEN}[✓]${NC} 服务已重启\n"
    else
        printf "  ${RED}[✗]${NC} 服务启动失败，请检查日志: journalctl -u $SERVICE -n 20\n"
    fi
    echo -e "${CYAN}+===========================================================================+${NC}"
    wait_key
}

do_uninstall() {
    echo ""
    echo -e "${RED}+===========================================================================+${NC}"
    printf "${RED}|${NC}  ${RED}%-69s${NC}${RED}|${NC}\n" "⚠️  警告: 此操作将完全删除路由监测工具"
    echo -e "${RED}+===========================================================================+${NC}"
    echo ""
    echo -ne "  输入 ${RED}yes${NC} 确认卸载: "
    read confirm
    if [ "$confirm" != "yes" ]; then
        echo -e "  ${YELLOW}已取消${NC}"
        wait_key
        return
    fi

    echo ""
    echo -e "  ${YELLOW}[..] 正在卸载...${NC}"
    systemctl stop $SERVICE 2>/dev/null
    systemctl disable $SERVICE 2>/dev/null
    rm -f /etc/systemd/system/$SERVICE.service
    systemctl daemon-reload
    rm -f /usr/local/bin/monitor
    rm -rf $INSTALL_DIR
    echo ""
    echo -e "  ${GREEN}[✓]${NC} 卸载完成"
    echo ""
    exit 0
}

do_test_alert() {
    echo ""
    echo -e "  ${CYAN}[..]${NC} 正在发送测试消息..."
    PYTHON="$INSTALL_DIR/venv/bin/python3"
    result=$($PYTHON -c "
import sys, os
sys.path.insert(0, '$INSTALL_DIR/src')
os.chdir('$INSTALL_DIR')
from config import load_config
from alerter import send_alert
config = load_config()
msg = '🔔 路由监测测试消息\n\n服务器: ' + config['server_name'] + '\n状态: 告警通道配置正常\n\n如果你看到这条消息，说明配置成功！'
ok = send_alert(config, msg)
print('ok' if ok else 'fail')
" 2>/dev/null)

    if [ "$result" = "ok" ]; then
        echo -e "  ${GREEN}[✓]${NC} 测试消息已发送，请检查钉钉是否收到"
    else
        echo -e "  ${RED}[✗]${NC} 发送失败，请检查配置"
    fi
    wait_key
}

do_baseline() {
    echo ""
    PYTHON="$INSTALL_DIR/venv/bin/python3"
    $PYTHON -c "
import sys, os
sys.path.insert(0, '$INSTALL_DIR/src')
os.chdir('$INSTALL_DIR')
from config import load_config
from db import Database
config = load_config()
db = Database(config['database']['path'])

print('  📈 基线数据')
print('  服务器: ' + config['server_name'])
print('')
for t in config['ping_targets']:
    host = t['host']
    name = t['name']
    bl = db.get_baseline(host)
    if bl:
        avg, std, mn, mx = bl[0], bl[1], bl[2], bl[3]
        print(f'  {name} ({host})')
        print(f'    平均: {avg:.1f}ms | 抖动: {std:.1f}ms')
        print(f'    范围: {mn:.1f}ms ~ {mx:.1f}ms')
        print('')
    else:
        print(f'  {name}: 暂无基线')
" 2>/dev/null
    wait_key
}

do_speed() {
    echo ""
    echo -e "  ${CYAN}[..]${NC} 正在测速，请稍候..."
    PYTHON="$INSTALL_DIR/venv/bin/python3"
    $PYTHON -c "
import sys, os
sys.path.insert(0, '$INSTALL_DIR/src')
os.chdir('$INSTALL_DIR')
from config import load_config
from speedtest import test_download_speed
config = load_config()
url = config.get('speedtest', {}).get('target_url')
if not url:
    print('  ❌ 未配置测速目标')
else:
    result = test_download_speed(url)
    if result['success']:
        print(f'  🚀 测速结果')
        print(f'')
        print(f'  速度: {result[\"speed_mbps\"]:.1f} Mbps')
        print(f'  下载: {result[\"downloaded_bytes\"]/1024/1024:.1f} MB')
        print(f'  耗时: {result[\"elapsed_sec\"]:.1f}s')
    else:
        print('  ❌ 测速失败')
" 2>/dev/null
    wait_key
}

do_traceroute() {
    echo ""
    echo -e "  ${CYAN}[..]${NC} 正在执行路由追踪..."
    PYTHON="$INSTALL_DIR/venv/bin/python3"
    $PYTHON -c "
import sys, os
sys.path.insert(0, '$INSTALL_DIR/src')
os.chdir('$INSTALL_DIR')
from config import load_config
from tracer import traceroute
from geoip import format_traceroute_result, get_path_countries
config = load_config()
for t in config.get('traceroute_targets', [])[:2]:
    result = traceroute(t['host'])
    if result['success'] and result['hops']:
        print('')
        print(format_traceroute_result(t['name'], result['hops']))
        countries = get_path_countries(result['hops'])
        if countries:
            print(f'\n  🌍 经过: {\" → \".join(countries)}')
    else:
        print(f'  ❌ {t[\"name\"]} 追踪失败')
" 2>/dev/null
    wait_key
}

do_daily_report() {
    echo ""
    PYTHON="$INSTALL_DIR/venv/bin/python3"
    $PYTHON -c "
import sys, os
sys.path.insert(0, '$INSTALL_DIR/src')
os.chdir('$INSTALL_DIR')
from config import load_config
from db import Database
from alerter import build_daily_report
config = load_config()
db = Database(config['database']['path'])
stats = db.get_stats_summary(hours=24)
if stats:
    report = build_daily_report(config, stats)
    print(report)
else:
    print('  暂无数据，无法生成报告')
" 2>/dev/null
    wait_key
}

do_auto_menu() {
    echo ""
    echo -e "${CYAN}+===========================================================================+${NC}"
    printf "${CYAN}|${NC}  ${BOLD}%-69s${NC}${CYAN}|${NC}\n" "登录自动进入菜单"
    echo -e "${CYAN}+---------------------------------------------------------------------------+${NC}"

    local bashrc="$HOME/.bashrc"
    local marker="# route-monitor-auto-menu"

    if grep -q "$marker" "$bashrc" 2>/dev/null; then
        printf "${CYAN}|${NC}  ${GREEN}[✓]${NC} 已启用（SSH 登录后自动进入管理菜单）                      ${CYAN}|${NC}\n"
        echo -e "${CYAN}|${NC}                                                              ${CYAN}|${NC}\n"
        echo -ne "  是否取消自动进入？(y/N): "
        read disable
        if [ "$disable" = "y" ] || [ "$disable" = "Y" ]; then
            # 删除 marker 及下一行
            sed -i "/$marker/,+1d" "$bashrc"
            printf "${CYAN}|${NC}  ${YELLOW}[✓]${NC} 已取消自动进入菜单                                        ${CYAN}|${NC}\n"
        fi
    else
        printf "${CYAN}|${NC}  ${DIM}%-69s${NC}${CYAN}|${NC}\n" "当前未启用"
        echo -e "${CYAN}|${NC}                                                              ${CYAN}|${NC}\n"
        echo -ne "  是否启用 SSH 登录后自动进入菜单？(y/N): "
        read enable
        if [ "$enable" = "y" ] || [ "$enable" = "Y" ]; then
            echo "" >> "$bashrc"
            echo "$marker" >> "$bashrc"
            echo "monitor" >> "$bashrc"
            printf "${CYAN}|${NC}  ${GREEN}[✓]${NC} 已启用，下次 SSH 登录将自动进入菜单                        ${CYAN}|${NC}\n"
        fi
    fi

    echo -e "${CYAN}+===========================================================================+${NC}"
    wait_key
}

# ============================================================================
# 主循环
# ============================================================================

main() {
    while true; do
        show_header
        show_menu
        read choice

        case $choice in
            1) do_status ;;
            2) do_log ;;
            3) do_restart ;;
            4) do_stop ;;
            5) do_edit_config ;;
            6) do_update ;;
            7) do_uninstall ;;
            8)
                echo ""
                journalctl -u $SERVICE -n 50 --no-pager
                wait_key
                ;;
            9) do_test_alert ;;
            10) do_baseline ;;
            11)
                echo ""
                local web_port=$(get_config_value "web.port")
                web_port=${web_port:-8080}
                echo -e "  Web 面板地址: ${CYAN}http://$(hostname -I | awk '{print $1}'):${web_port}${NC}"
                echo ""
                echo -e "  ${YELLOW}提示: 确保防火墙已开放 ${web_port} 端口${NC}"
                wait_key
                ;;
            12) do_auto_menu ;;
            s|S) do_speed ;;
            r|R) do_traceroute ;;
            d|D) do_daily_report ;;
            0)
                echo ""
                echo -e "  ${GREEN}Bye!${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "  ${RED}无效选择${NC}"
                sleep 1
                ;;
        esac
    done
}

main
