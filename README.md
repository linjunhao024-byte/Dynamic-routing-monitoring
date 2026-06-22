# AWS 动态路由监测工具

监测 AWS 东京服务器的网络路由变化，检测绕路和网络质量下降，通过 Telegram/钉钉实时告警。

## 功能

- **延迟监测**: 周期性 ping 多个目标，检测延迟异常和抖动
- **丢包监测**: 检测丢包率突增
- **路径追踪**: traceroute 检测路由路径变化（绕路）
- **带宽监测**: 定期测速，检测带宽下降
- **基线对比**: 自动学习正常状态，偏离时告警
- **恢复通知**: 网络恢复正常时也会通知
- **每日报告**: 每天自动发送一份统计报告
- **自动清理**: 定期清理过期数据

## 一键部署

SSH 登录服务器后，直接执行：

```bash
wget https://github.com/linjunhao024-byte/Dynamic-routing-monitoring/archive/refs/heads/main.zip && \
unzip main.zip && \
mv Dynamic-routing-monitoring-main route-monitor && \
rm main.zip && \
cd route-monitor && \
bash deploy.sh
```

首次运行会提示你编辑配置文件：

```bash
nano ~/route-monitor/config.local.json
```

填入你的 Telegram 和钉钉信息后，再执行一次：

```bash
cd ~/route-monitor && bash deploy.sh
```

部署完成。

## 配置说明

编辑 `config.local.json`，只需要改这几项：

```json
{
  "server_name": "tokyo-aws-01",
  "telegram": {
    "enabled": true,
    "bot_token": "你的Bot Token",
    "chat_id": "你的Chat ID"
  },
  "dingtalk": {
    "enabled": true,
    "webhook_url": "你的钉钉Webhook地址"
  }
}
```

### 获取 Telegram Bot Token

1. Telegram 搜索 `@BotFather`
2. 发送 `/newbot`，按提示创建
3. 拿到 token

### 获取 Telegram Chat ID

1. 搜索 `@userinfobot`
2. 给它发任意消息
3. 拿到 Id

### 获取钉钉 Webhook

1. 钉钉群 → 群设置 → 智能群助手 → 添加机器人
2. 选自定义，安全设置选自定义关键词，填：`路由监测告警`
3. 复制 webhook 地址

## 告警触发条件

| 条件 | 级别 | 说明 |
|------|------|------|
| 延迟 > 基线 × 1.8 | warning | 连续 3 次后告警 |
| 延迟 > 80ms | critical | 连续 3 次后告警 |
| 丢包 > 3% | critical | 连续 3 次后告警 |
| 抖动 > 基线 × 3 | warning | 连续 3 次后告警 |
| 带宽下降 > 50% | warning | 触发告警 |
| 路由跳 IP 变化 | warning | 立即告警 |
| 网络恢复正常 | recovery | 自动通知 |

## 常用命令

```bash
# 查看状态
sudo systemctl status route-monitor

# 查看实时日志
sudo journalctl -u route-monitor -f

# 重启（改配置后）
sudo systemctl restart route-monitor

# 停止
sudo systemctl stop route-monitor

# 编辑配置
nano ~/route-monitor/config.local.json
```

## 更新

```bash
cd ~/route-monitor
wget -O main.zip https://github.com/linjunhao024-byte/Dynamic-routing-monitoring/archive/refs/heads/main.zip
unzip -o main.zip -d /tmp/route-update
cp /tmp/route-update/Dynamic-routing-monitoring-main/src/*.py src/
rm -rf /tmp/route-update main.zip
sudo systemctl restart route-monitor
```

## 卸载

```bash
sudo systemctl stop route-monitor
sudo systemctl disable route-monitor
sudo rm /etc/systemd/system/route-monitor.service
sudo systemctl daemon-reload
rm -rf ~/route-monitor
```
