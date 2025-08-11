#!/bin/bash
# 上下文管理和状态检查脚本

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
CONFIG_FILE="$SCRIPT_DIR/workspace.toml"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查构建状态
check_build_status() {
    local build_dir="$ROOT_DIR/build_riscv32"
    
    echo "=== 构建状态检查 ==="
    
    # 检查各组件的构建标记
    if [ -f "$build_dir/.binutils_built_2.30" ]; then
        log_success "Binutils 2.30 - 已完成"
    else
        log_warning "Binutils 2.30 - 未完成"
    fi
    
    if [ -f "$build_dir/.gcc_deps_built" ]; then
        log_success "GCC 依赖库 - 已完成"
    else
        log_warning "GCC 依赖库 - 未完成"
    fi
    
    if [ -f "$build_dir/.gcc_stage1_built_7.3.0" ]; then
        log_success "GCC Stage 1 - 已完成"
    else
        log_warning "GCC Stage 1 - 未完成"
    fi
    
    if [ -f "$build_dir/.musl_built_1.2.2" ]; then
        log_success "musl 1.2.2 - 已完成"
    else
        log_warning "musl 1.2.2 - 未完成"
    fi
    
    if [ -f "$build_dir/.gcc_stage2_built_7.3.0" ]; then
        log_success "GCC Stage 2 - 已完成"
    else
        log_warning "GCC Stage 2 - 未完成"
    fi
}

# 检查系统依赖
check_system_deps() {
    echo "=== 系统依赖检查 ==="
    
    local deps=("m4" "make" "gcc" "g++" "wget" "tar" "gzip" "bzip2")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if command -v "$dep" >/dev/null 2>&1; then
            log_success "$dep - 已安装"
        else
            log_error "$dep - 未安装"
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_warning "缺少依赖: ${missing_deps[*]}"
        log_info "可运行以下命令安装: sudo apt-get install ${missing_deps[*]}"
    fi
}

# 检查磁盘空间
check_disk_space() {
    echo "=== 磁盘空间检查 ==="
    
    local available=$(df "$ROOT_DIR" | tail -1 | awk '{print $4}')
    local available_gb=$((available / 1024 / 1024))
    
    if [ $available_gb -gt 10 ]; then
        log_success "可用空间: ${available_gb}GB (充足)"
    elif [ $available_gb -gt 5 ]; then
        log_warning "可用空间: ${available_gb}GB (可能不足)"
    else
        log_error "可用空间: ${available_gb}GB (空间不足)"
    fi
}

# 检查源码文件
check_source_files() {
    echo "=== 源码文件检查 ==="
    
    local src_dir="$ROOT_DIR/src"
    local sources=(
        "gcc-7.3.0"
        "binutils-2.30"
        "musl-1.2.2"
        "gmp-6.1.2"
        "mpfr-3.1.6"
        "mpc-1.0.3"
        "isl-0.18"
    )
    
    for src in "${sources[@]}"; do
        if [ -d "$src_dir/$src" ] && [ "$(ls -A "$src_dir/$src" 2>/dev/null)" ]; then
            log_success "$src - 已下载并解压"
        else
            log_warning "$src - 未就绪"
        fi
    done
}

# 显示最新日志
show_recent_logs() {
    echo "=== 最新构建日志 ==="
    
    local logs_dir="$ROOT_DIR/build_riscv32/logs"
    if [ -d "$logs_dir" ]; then
        local latest_log=$(ls -t "$logs_dir" | head -1)
        if [ -n "$latest_log" ] && [ -d "$logs_dir/$latest_log" ]; then
            log_info "最新日志目录: $latest_log"
            echo "日志文件:"
            ls -la "$logs_dir/$latest_log" | tail -5
        fi
    else
        log_warning "日志目录不存在"
    fi
}

# 清理构建缓存
clean_build() {
    echo "=== 清理构建缓存 ==="
    
    local build_dir="$ROOT_DIR/build_riscv32"
    
    log_warning "这将删除所有构建进度，是否继续? [y/N]"
    read -r answer
    
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        rm -rf "$build_dir"/{*-build,host-libs,.gcc*,.binutils*,.musl*}
        log_success "构建缓存已清理"
    else
        log_info "取消清理操作"
    fi
}

# 更新配置文件
update_config() {
    local current_date=$(date +%Y-%m-%d)
    sed -i "s/updated = .*/updated = \"$current_date\"/" "$CONFIG_FILE"
    log_success "配置文件已更新"
}

# 主函数
main() {
    case "${1:-status}" in
        "status"|"check")
            check_system_deps
            echo
            check_disk_space
            echo
            check_source_files
            echo
            check_build_status
            echo
            show_recent_logs
            ;;
        "clean")
            clean_build
            ;;
        "update")
            update_config
            ;;
        "help"|"-h"|"--help")
            echo "用法: $0 [command]"
            echo "命令:"
            echo "  status, check  - 检查构建状态和环境 (默认)"
            echo "  clean          - 清理构建缓存"
            echo "  update         - 更新配置文件"
            echo "  help           - 显示此帮助信息"
            ;;
        *)
            log_error "未知命令: $1"
            echo "运行 '$0 help' 查看可用命令"
            exit 1
            ;;
    esac
}

main "$@"
