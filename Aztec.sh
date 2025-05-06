#!/bin/bash
# Aztec Sequencer 一键部署脚本 - by K2 节点教程分享
# Telegram: https://t.me/+EaCiFDOghoM3Yzll
# Twitter: https://x.com/BtcK241918

clear

function install_dependencies() {
  echo -e "\n[1/4] 安装依赖..."

  if ! command -v curl &>/dev/null; then
    echo "安装 curl..."
    sudo apt update && sudo apt install -y curl
  fi

  if ! command -v docker &>/dev/null; then
    echo "安装 Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
  fi

  if ! command -v nvm &>/dev/null; then
    echo "安装 nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  fi

  if ! command -v node &>/dev/null || [[ $(node -v | cut -d. -f1 | tr -d v) -lt 18 ]]; then
    echo "安装 Node.js 18..."
    nvm install 18
    nvm use 18
  fi
}

function install_aztec() {
  echo -e "\n[2/4] 安装 Aztec CLI..."

  if ! command -v aztec &>/dev/null; then
    bash -i <(curl -s https://install.aztec.network)

    AZTEC_LOCAL="$HOME/.aztec/bin/aztec"
    if [ -f "$AZTEC_LOCAL" ]; then
      echo "复制 Aztec 到系统全局路径 /usr/local/bin..."
      sudo cp "$AZTEC_LOCAL" /usr/local/bin/aztec
      sudo chmod +x /usr/local/bin/aztec
    fi
  else
    echo "Aztec 已安装，跳过。"
  fi

  if command -v aztec &>/dev/null && [[ "$(which aztec)" == "/usr/local/bin/aztec" ]]; then
    echo "✅ Aztec CLI 安装成功：$(which aztec)"
  else
    echo "❌ Aztec 安装失败，请检查 ~/.aztec/bin/aztec 是否存在"
    exit 1
  fi
}

function run_sequencer() {
  echo -e "\n[3/4] 启动 Sequencer..."

  read -p "请输入以太坊私钥（0x开头）: " VALIDATOR_PRIVATE_KEY
  read -p "请输入验证者地址（0x开头）: " VALIDATOR_ADDRESS
  read -p "请输入 L1 RPC 地址: " L1_RPC
  read -p "请输入 L1 共识 RPC 地址: " L1_CONSENSUS_RPC

  PUBLIC_IP=$(curl -s ifconfig.me)
  echo "公网 IP 检测为: $PUBLIC_IP"

  docker run -d \
    --name aztec-sequencer \
    --restart unless-stopped \
    -e ETHEREUM_HOSTS="$L1_RPC" \
    -e L1_CONSENSUS_HOST_URLS="$L1_CONSENSUS_RPC" \
    -e VALIDATOR_PRIVATE_KEY="$VALIDATOR_PRIVATE_KEY" \
    -e P2P_IP="$PUBLIC_IP" \
    -p 40400:40400/tcp -p 40400:40400/udp -p 8080:8080 \
    aztecprotocol/aztec:0.85.0-alpha-testnet.5 \
    sh -c "node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start \
      --network alpha-testnet --node --archiver --sequencer \
      --sequencer.coinbase=$VALIDATOR_ADDRESS \
      --sequencer.validatorPrivateKey=$VALIDATOR_PRIVATE_KEY \
      --p2p.p2pIp=$PUBLIC_IP"

  echo -e "\n✅ Sequencer 启动完成。"
}

function show_logs() {
  echo -e "\n[日志] 正在输出日志..."
  docker logs -f aztec-sequencer
}

function uninstall_node() {
  echo -e "\n[卸载] 停止并删除容器..."
  docker stop aztec-sequencer && docker rm aztec-sequencer
  echo "✅ 节点已卸载（数据仍保留在 Docker 卷中）"
}

function register_validator() {
  echo -e "\n[注册验证者]"

  read -p "是否继续注册验证者？(y/n): " confirm
  if [[ "$confirm" != "y" ]]; then return; fi

  read -p "请输入以太坊私钥（0x...）: " L1_PRIVATE_KEY
  read -p "请输入钱包地址: " VALIDATOR_ADDRESS
  read -p "请输入 L1 RPC 地址: " L1_RPC

  # 更新 staking-asset-handler 地址
  STAKING_ASSET_HANDLER="0xb82381a3fbd3fafa77b3a7be693342618240067b"

  aztec add-l1-validator \
    --l1-rpc-urls "$L1_RPC" \
    --private-key "$L1_PRIVATE_KEY" \
    --attester "$VALIDATOR_ADDRESS" \
    --proposer-eoa "$VALIDATOR_ADDRESS" \
    --staking-asset-handler "$STAKING_ASSET_HANDLER" \
    --l1-chain-id 11155111

  echo -e "\n✅ 注册命令已执行。请检查链上状态确认是否成功。"
  echo -e "请访问 Sepolia 测试网查看您的验证者状态：\nhttps://sepolia.etherscan.io/address/$VALIDATOR_ADDRESS"
}

function main_menu() {
  while true; do
    clear
    echo "=========== Aztec 一键部署脚本 ==========="
    echo "📌 作者: K2 节点教程分享"
    echo "🔗 Telegram: https://t.me/+EaCiFDOghoM3Yzll"
    echo "🐦 Twitter:  https://x.com/BtcK241918"
    echo "=========================================="
    echo "1. 安装依赖并启动 Sequencer"
    echo "2. 查看节点日志"
    echo "3. 卸载 Sequencer 节点"
    echo "4. 注册为验证者"
    echo "5. 退出脚本"
    echo "=========================================="
    read -p "请输入选项 [1-5]: " CHOICE
    case $CHOICE in
      1) install_dependencies; install_aztec; run_sequencer; read -n 1 -s -r ;;
      2) show_logs; read -n 1 -s -r ;;
      3) uninstall_node; read -n 1 -s -r ;;
      4) register_validator; read -n 1 -s -r ;;
      5) echo "退出脚本"; exit 0 ;;
      *) echo "无效输入"; sleep 1 ;;
    esac
  done
}

main_menu
