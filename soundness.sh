#!/bin/bash

echo "--- Soundness CLI 项目设置向导 ---"
echo ""

# 1. 询问项目名称
read -p "请输入项目名称（这将作为文件夹名）： " PROJECT_NAME
if [ -z "$PROJECT_NAME" ]; then
    echo "项目名称不能为空！"
    exit 1
fi

if [ -d "$PROJECT_NAME" ]; then
    read -p "文件夹 '$PROJECT_NAME' 已存在。是否要覆盖？(y/N) " OVERWRITE_CHOICE
    if [[ ! "$OVERWRITE_CHOICE" =~ ^[Yy]$ ]]; then
        echo "操作取消。"
        exit 0
    fi
    echo "正在移除现有文件夹..."
    rm -rf "$PROJECT_NAME"
fi

mkdir -p "$PROJECT_NAME"
if [ $? -ne 0 ]; then
    echo "创建文件夹 '$PROJECT_NAME' 失败！"
    exit 1
fi
echo "已创建项目文件夹： $PROJECT_NAME/"

# 2. 检查并安装 Rust 工具链 (如果未安装)
echo ""
echo "--- 检查 Rust 工具链 ---"
if ! command -v rustc &> /dev/null
then
    echo "Rust 工具链未检测到。Soundness CLI 需要 Rust。"
    read -p "是否现在安装 Rust？(y/N) (这将运行 'curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh') " INSTALL_RUST_CHOICE
    if [[ "$INSTALL_RUST_CHOICE" =~ ^[Yy]$ ]]; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
        # 尝试更新当前 shell 的 PATH，以便识别 rustc
        source "$HOME/.cargo/env"
        echo "Rust 安装完成。请注意，您可能需要重启终端以使 PATH 完全生效。"
    else
        echo "未安装 Rust。Soundness CLI 可能无法正常工作。请手动安装 Rust 后再试。"
        exit 1
    fi
else
    echo "Rust 工具链已安装。"
fi

# 3. 检查并安装 Soundness CLI (通过 soundnessup)
echo ""
echo "--- 检查并安装 Soundness CLI ---"
if ! command -v soundnessup &> /dev/null; then
    echo "soundnessup (Soundness CLI 安装器) 未检测到。"
    read -p "是否现在安装 soundnessup？(y/N) " INSTALL_SOUNDNESSUP_CHOICE
    if [[ "$INSTALL_SOUNDNESSUP_CHOICE" =~ ^[Yy]$ ]]; then
        # 强制将 Rust/Cargo 的 bin 目录添加到 PATH，确保 curl 和其他 Rust 工具可用
        export PATH="$HOME/.cargo/bin:$PATH" # <--- 重要新增行

        curl -sSL https://raw.githubusercontent.com/soundnesslabs/soundness-layer/main/soundnessup/install | bash
        # 尝试更新用户shell的PATH (非强制，辅助性质)
        if [ -f "$HOME/.bashrc" ]; then
            source "$HOME/.bashrc"
        elif [ -f "$HOME/.zshenv" ]; then
            source "$HOME/.zshenv"
        fi
        
        echo "soundnessup 安装完成。尝试安装 Soundness CLI..."
        
        # 直接使用完整路径来调用 soundnessup，确保找到它
        /root/.soundness/bin/soundnessup install # <-- 这是之前修复的绝对路径

        if [ $? -ne 0 ]; then
            echo "Soundness CLI 安装失败。请手动检查并安装。"
            exit 1
        fi
    else
        echo "未安装 soundnessup。Soundness CLI 可能无法正常工作。请手动安装后再试。"
        exit 1
    fi
else # soundnessup 已安装的情况
    echo "soundnessup 已安装。"
    if ! command -v soundness-cli &> /dev/null; then
        echo "Soundness CLI 未检测到，但 soundnessup 已安装。尝试通过 soundnessup 安装 Soundness CLI..."
        # 同样，在这里也使用完整路径调用 soundnessup
        /root/.soundness/bin/soundnessup install # <-- 确保这里也是绝对路径
        if [ $? -ne 0 ]; then
            echo "Soundness CLI 安装失败。请手动检查并安装。"
            exit 1
        fi
    else
        echo "Soundness CLI 已安装。"
    fi
fi

# 4. 在项目文件夹中创建 run_cli.sh (密钥生成/导入逻辑已移除)
# 这一行必须在 cat << EOF 结构外部被定义！
RUN_CLI_SCRIPT="$PROJECT_NAME/run_cli.sh"

echo ""
echo "--- 创建 run_cli.sh 脚本 ---"
cat << EOF > "$RUN_CLI_SCRIPT"
#!/bin/bash

# 确保 soundness-cli 的安装路径在 PATH 中
export PATH="/root/.soundness/bin:\$PATH" # <--- 关键修改

# 运行 Soundness CLI 命令
# 请确保您的 Soundness CLI 已安装并位于 PATH 中
# 示例：
# soundness-cli generate-key --name my-key
# soundness-cli list-keys
# soundness-cli send --proof-file <proof-blob-id> --game <game-name> --key-name my-key --proving-system ligetron --payload '{}'

# 将所有传入参数传递给 soundness-cli
soundness-cli "\$@"
EOF

chmod +x "$RUN_CLI_SCRIPT"
echo "已在 '$RUN_CLI_SCRIPT' 中创建 'run_cli.sh' 脚本。"
echo "请记住，Soundness CLI 会在当前目录下创建 'key_store.json' 来保存密钥。"
# 移除关于助记词的提醒，因为脚本不再处理密钥生成/导入

echo ""
echo "--- 设置完成！ ---"
echo "要开始使用，请执行以下操作："
echo "cd $PROJECT_NAME"
echo "./run_cli.sh [您的 Soundness CLI 命令]"
echo ""
echo "您现在需要手动生成或导入密钥："
echo "例如，生成新密钥："
echo "  ./run_cli.sh generate-key --name my-new-key"
echo "或导入现有密钥："
echo "  ./run_cli.sh import-key --name my-imported-key --mnemonic \"your actual mnemonic phrase here\""
echo ""
echo "之后，您可以运行任何 Soundness CLI 命令，例如："
echo "./run_cli.sh send --proof-file <proof-id> --game mygame --key-name \"your-key-name\" --proving-system ligetron --payload '{}'"
echo "或"
echo "./run_cli.sh list-keys"
