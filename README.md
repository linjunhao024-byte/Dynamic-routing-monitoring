# AWS 动态路由监测工具

监测服务器网络路由变化，检测绕路和网络质量下降，通过 Telegram/钉钉告警。

## 一键部署

SSH 登录服务器后执行：

```bash
# 安装 git（如果没有）
sudo apt install -y git

# 克隆仓库
git clone https://github.com/你的用户名/仓库名.git ~/route-monitor
cd ~/route-monitor

# 运行部署脚本
bash deploy.sh
```

首次运行会生成 `config.local.json`，编辑它填入你的配置：

```bash
nano config.local.json
```

填完后再次运行 `bash deploy.sh` 完成部署。

## 配置说明

编辑 `config.local.json`：

```json
{
  "server_name": "给这台服务器起个名字",

  "mode": "lite",

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

其他配置一般不用改。

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

## 模式选择

在 `config.local.json` 中设置 `"mode"`:

| 模式 | 内存 | 功能 | 适用 |
|------|------|------|------|
| `lite` | ~15MB | ping + 丢包 | NAT/小内存服务器 |
| `normal` | ~35MB | ping + 丢包 + traceroute | 普通服务器 |

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

## 告警触发条件

| 条件 | 说明 |
|------|------|
| 延迟 > 基线 × 2 | 连续 3 次后告警 |
| 延迟 > 100ms | 连续 3 次后告警 |
| 丢包 > 5% | 连续 3 次后告警 |
| 路由跳 IP 变化 | 立即告警（仅 normal 模式） |

## 更新

```bash
cd ~/route-monitor
git pull
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
