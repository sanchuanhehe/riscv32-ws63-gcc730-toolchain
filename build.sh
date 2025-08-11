#!/bin/bash
set -e
set -o pipefail

ROOT_DIR=$(cd "$(dirname "$0")" && pwd)
SRC_ROOT=$ROOT_DIR/src
BUILD_ROOT=$ROOT_DIR/build_riscv32
INSTALL_PREFIX=$BUILD_ROOT/install
LOG_DIR=$BUILD_ROOT/logs/$(date +%Y%m%d_%H%M%S)

# 版本号定义
GCC_VERSION=7.3.0
BINUTILS_VERSION=2.30
MUSL_VERSION=1.2.2
GMP_VERSION=6.1.2
MPFR_VERSION=3.1.6
MPC_VERSION=1.0.3
ISL_VERSION=0.18

TARGET=riscv32-linux-musl
ARCH=rv32imfc
ABI=ilp32f

mkdir -p "$SRC_ROOT" "$BUILD_ROOT" "$INSTALL_PREFIX" "$LOG_DIR"

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# 安装必要的系统工具
install_dependencies() {
  log "Installing system dependencies..."
  
  # 检查并安装必要的工具
  local missing_tools=""
  
  # 检查 m4
  if ! command -v m4 >/dev/null 2>&1; then
    missing_tools="$missing_tools m4"
  fi
  
  # 检查 autoconf
  if ! command -v autoconf >/dev/null 2>&1; then
    missing_tools="$missing_tools autoconf"
  fi
  
  # 检查 automake
  if ! command -v automake >/dev/null 2>&1; then
    missing_tools="$missing_tools automake"
  fi
  
  # 检查 libtool
  if ! command -v libtool >/dev/null 2>&1; then
    missing_tools="$missing_tools libtool"
  fi
  
  # 检查 pkg-config
  if ! command -v pkg-config >/dev/null 2>&1; then
    missing_tools="$missing_tools pkg-config"
  fi
  
  # 检查 bison
  if ! command -v bison >/dev/null 2>&1; then
    missing_tools="$missing_tools bison"
  fi
  
  # 检查 flex
  if ! command -v flex >/dev/null 2>&1; then
    missing_tools="$missing_tools flex"
  fi
  
  # 检查 texinfo
  if ! command -v makeinfo >/dev/null 2>&1; then
    missing_tools="$missing_tools texinfo"
  fi
  
  if [ -n "$missing_tools" ]; then
    log "Installing missing tools:$missing_tools"
    
    # 检测包管理器并安装
    if command -v apt-get >/dev/null 2>&1; then
      # Debian/Ubuntu
      apt-get update
      apt-get install -y $missing_tools build-essential
    elif command -v yum >/dev/null 2>&1; then
      # RHEL/CentOS
      yum install -y $missing_tools gcc gcc-c++ make
    elif command -v dnf >/dev/null 2>&1; then
      # Fedora
      dnf install -y $missing_tools gcc gcc-c++ make
    elif command -v apk >/dev/null 2>&1; then
      # Alpine
      apk add --no-cache $missing_tools build-base
    else
      log "ERROR: Unknown package manager. Please install these tools manually:$missing_tools"
      exit 1
    fi
  else
    log "All required tools are already installed."
  fi
}

mirror_url() {
  local url=$1
  if [[ "$url" =~ ^https?://ftp.gnu.org/gnu/ ]]; then
    echo "${url/https:\/\/ftp.gnu.org\/gnu\//https://mirrors.tuna.tsinghua.edu.cn/gnu/}"
  elif [[ "$url" =~ ^https?://musl.libc.org/releases/ ]]; then
    echo "${url/https:\/\/musl.libc.org\/releases\//https://mirrors.tuna.tsinghua.edu.cn/musl/releases/}"
  else
    echo "$url"
  fi
}

download_and_extract() {
  local url=$1
  local dest_dir=$2
  local archive_name=$(basename "$url")
  local download_url=$(mirror_url "$url")

  if [ -d "$dest_dir" ] && [ "$(ls -A "$dest_dir")" ]; then
    log "$dest_dir already exists and is not empty, skipping download and extract."
    return
  fi

  log "Downloading $archive_name from $download_url ..."
  if ! wget -c --show-progress --timeout=30 --tries=5 "$download_url" -P "$SRC_ROOT" 2>&1 | tee -a "$LOG_DIR/download_$archive_name.log"; then
    log "ERROR: Failed to download $archive_name"
    exit 1
  fi

  log "Extracting $archive_name ..."
  case "$archive_name" in
    *.tar.gz|*.tgz) tar -xzf "$SRC_ROOT/$archive_name" -C "$SRC_ROOT" ;;
    *.tar.bz2)      tar -xjf "$SRC_ROOT/$archive_name" -C "$SRC_ROOT" ;;
    *.tar.xz)       tar -xJf "$SRC_ROOT/$archive_name" -C "$SRC_ROOT" ;;
    *) log "Unsupported archive format: $archive_name"; exit 1 ;;
  esac
}

get_nproc() {
  if command -v nproc >/dev/null 2>&1; then
    nproc
  else
    echo 1
  fi
}

build_binutils() {
  local mark_file=$BUILD_ROOT/.binutils_built_$BINUTILS_VERSION
  if [ -f "$mark_file" ]; then
    log "Binutils $BINUTILS_VERSION already built, skipping."
    return
  fi

  log "Building binutils $BINUTILS_VERSION..."
  mkdir -p "$BUILD_ROOT/binutils-build"
  cd "$BUILD_ROOT/binutils-build"
  "$SRC_ROOT/binutils-$BINUTILS_VERSION/configure" --prefix="$INSTALL_PREFIX" --target="$TARGET" --disable-multilib --disable-werror \
    >"$LOG_DIR/binutils_configure.log" 2>&1
  make -j"$(get_nproc)" >"$LOG_DIR/binutils_make.log" 2>&1
  make install >"$LOG_DIR/binutils_install.log" 2>&1

  touch "$mark_file"
  log "Binutils build complete."
}

build_musl() {
  local mark_file=$BUILD_ROOT/.musl_built_$MUSL_VERSION
  if [ -f "$mark_file" ]; then
    log "musl $MUSL_VERSION already built, skipping."
    return
  fi

  log "Building musl $MUSL_VERSION..."
  mkdir -p "$BUILD_ROOT/musl-build"
  cd "$BUILD_ROOT/musl-build"

  local old_path=$PATH
  export PATH="$INSTALL_PREFIX/bin:$PATH"
  if ! CC="$TARGET-gcc" AR="$TARGET-ar" RANLIB="$TARGET-ranlib" \
    "$SRC_ROOT/musl-$MUSL_VERSION/configure" --prefix="$INSTALL_PREFIX/$TARGET/sysroot/usr" --host="$TARGET" \
    >"$LOG_DIR/musl_configure.log" 2>&1; then
    log "ERROR: musl configure failed"
    exit 1
  fi

  if ! make -j"$(get_nproc)" >"$LOG_DIR/musl_make.log" 2>&1; then
    log "ERROR: musl make failed"
    exit 1
  fi

  if ! make install >"$LOG_DIR/musl_install.log" 2>&1; then
    log "ERROR: musl install failed"
    exit 1
  fi
  export PATH=$old_path

  touch "$mark_file"
  log "musl build complete."
}

# 构建 GMP, MPFR, MPC, ISL 依赖库
build_gcc_deps() {
  local mark_file=$BUILD_ROOT/.gcc_deps_built
  if [ -f "$mark_file" ]; then
    log "GCC dependencies already built, skipping."
    return
  fi

  log "Building GCC dependencies..."
  
  # 构建 GMP
  log "Building GMP $GMP_VERSION..."
  mkdir -p "$BUILD_ROOT/gmp-build"
  cd "$BUILD_ROOT/gmp-build"
  "$SRC_ROOT/gmp-$GMP_VERSION/configure" --prefix="$BUILD_ROOT/host-libs" --disable-shared >"$LOG_DIR/gmp_configure.log" 2>&1
  make -j"$(get_nproc)" >"$LOG_DIR/gmp_make.log" 2>&1
  make install >"$LOG_DIR/gmp_install.log" 2>&1

  # 构建 MPFR
  log "Building MPFR $MPFR_VERSION..."
  mkdir -p "$BUILD_ROOT/mpfr-build"
  cd "$BUILD_ROOT/mpfr-build"
  "$SRC_ROOT/mpfr-$MPFR_VERSION/configure" --prefix="$BUILD_ROOT/host-libs" --with-gmp="$BUILD_ROOT/host-libs" --disable-shared >"$LOG_DIR/mpfr_configure.log" 2>&1
  make -j"$(get_nproc)" >"$LOG_DIR/mpfr_make.log" 2>&1
  make install >"$LOG_DIR/mpfr_install.log" 2>&1

  # 构建 MPC
  log "Building MPC $MPC_VERSION..."
  mkdir -p "$BUILD_ROOT/mpc-build"
  cd "$BUILD_ROOT/mpc-build"
  "$SRC_ROOT/mpc-$MPC_VERSION/configure" --prefix="$BUILD_ROOT/host-libs" --with-gmp="$BUILD_ROOT/host-libs" --with-mpfr="$BUILD_ROOT/host-libs" --disable-shared >"$LOG_DIR/mpc_configure.log" 2>&1
  make -j"$(get_nproc)" >"$LOG_DIR/mpc_make.log" 2>&1
  make install >"$LOG_DIR/mpc_install.log" 2>&1

  # 构建 ISL
  log "Building ISL $ISL_VERSION..."
  mkdir -p "$BUILD_ROOT/isl-build"
  cd "$BUILD_ROOT/isl-build"
  "$SRC_ROOT/isl-$ISL_VERSION/configure" --prefix="$BUILD_ROOT/host-libs" --with-gmp-prefix="$BUILD_ROOT/host-libs" --disable-shared >"$LOG_DIR/isl_configure.log" 2>&1
  make -j"$(get_nproc)" >"$LOG_DIR/isl_make.log" 2>&1
  make install >"$LOG_DIR/isl_install.log" 2>&1

  touch "$mark_file"
  log "GCC dependencies build complete."
}

# 构建 GCC 第一阶段（仅编译器）
build_gcc_stage1() {
  local mark_file=$BUILD_ROOT/.gcc_stage1_built_$GCC_VERSION
  if [ -f "$mark_file" ]; then
    log "GCC stage 1 already built, skipping."
    return
  fi

  log "Building GCC stage 1..."
  mkdir -p "$BUILD_ROOT/gcc-build"
  cd "$BUILD_ROOT/gcc-build"

  local old_path=$PATH
  export PATH="$INSTALL_PREFIX/bin:$PATH"

  if ! "$SRC_ROOT/gcc-$GCC_VERSION/configure" \
    --prefix="$INSTALL_PREFIX" \
    --target="$TARGET" \
    --with-arch="$ARCH" \
    --with-abi="$ABI" \
    --disable-multilib \
    --disable-threads \
    --disable-shared \
    --disable-libmudflap \
    --disable-libitm \
    --disable-libssp \
    --disable-libgomp \
    --disable-libquadmath \
    --disable-decimal-float \
    --disable-fixed-point \
    --enable-languages=c \
    --without-headers \
    --with-newlib \
    --with-gmp="$BUILD_ROOT/host-libs" \
    --with-mpfr="$BUILD_ROOT/host-libs" \
    --with-mpc="$BUILD_ROOT/host-libs" \
    --with-isl="$BUILD_ROOT/host-libs" \
    --with-gnu-as \
    --with-gnu-ld \
    >"$LOG_DIR/gcc_stage1_configure.log" 2>&1; then
    log "ERROR: GCC stage 1 configure failed"
    exit 1
  fi

  if ! make -j"$(get_nproc)" all-gcc >"$LOG_DIR/gcc_stage1_all-gcc.log" 2>&1; then
    log "ERROR: GCC stage 1 all-gcc build failed"
    exit 1
  fi

  if ! make -j"$(get_nproc)" all-target-libgcc >"$LOG_DIR/gcc_stage1_all-target-libgcc.log" 2>&1; then
    log "ERROR: GCC stage 1 all-target-libgcc build failed"
    exit 1
  fi

  if ! make install-gcc >"$LOG_DIR/gcc_stage1_install-gcc.log" 2>&1; then
    log "ERROR: GCC stage 1 install-gcc failed"
    exit 1
  fi

  if ! make install-target-libgcc >"$LOG_DIR/gcc_stage1_install-target-libgcc.log" 2>&1; then
    log "ERROR: GCC stage 1 install-target-libgcc failed"
    exit 1
  fi

  export PATH=$old_path
  touch "$mark_file"
  log "GCC stage 1 build complete."
}

# 构建 GCC 第二阶段（完整版本）
build_gcc_stage2() {
  local mark_file=$BUILD_ROOT/.gcc_stage2_built_$GCC_VERSION
  if [ -f "$mark_file" ]; then
    log "GCC stage 2 already built, skipping."
    return
  fi

  log "Building GCC stage 2..."
  rm -rf "$BUILD_ROOT/gcc-build"
  mkdir -p "$BUILD_ROOT/gcc-build"
  cd "$BUILD_ROOT/gcc-build"

  local old_path=$PATH
  export PATH="$INSTALL_PREFIX/bin:$PATH"

  if ! "$SRC_ROOT/gcc-$GCC_VERSION/configure" \
    --prefix="$INSTALL_PREFIX" \
    --target="$TARGET" \
    --with-arch="$ARCH" \
    --with-abi="$ABI" \
    --disable-multilib \
    --enable-threads=posix \
    --enable-shared \
    --enable-libssp \
    --enable-libgomp \
    --enable-languages=c,c++ \
    --enable-poison-system-directories \
    --enable-symvers=gnu \
    --with-sysroot="$INSTALL_PREFIX/$TARGET/sysroot" \
    --with-headers="$INSTALL_PREFIX/$TARGET/sysroot/usr/include" \
    --with-build-sysroot="$INSTALL_PREFIX/$TARGET/sysroot" \
    --with-gmp="$BUILD_ROOT/host-libs" \
    --with-mpfr="$BUILD_ROOT/host-libs" \
    --with-mpc="$BUILD_ROOT/host-libs" \
    --with-isl="$BUILD_ROOT/host-libs" \
    --with-gnu-as \
    --with-gnu-ld \
    >"$LOG_DIR/gcc_stage2_configure.log" 2>&1; then
    log "ERROR: GCC stage 2 configure failed"
    exit 1
  fi

  if ! make -j"$(get_nproc)" >"$LOG_DIR/gcc_stage2_make.log" 2>&1; then
    log "ERROR: GCC stage 2 build failed"
    exit 1
  fi

  if ! make install >"$LOG_DIR/gcc_stage2_install.log" 2>&1; then
    log "ERROR: GCC stage 2 install failed"
    exit 1
  fi

  export PATH=$old_path
  touch "$mark_file"
  log "GCC stage 2 build complete."
}

main() {
  install_dependencies
  
  download_and_extract "https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.gz" "$SRC_ROOT/gcc-$GCC_VERSION"
  download_and_extract "https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.gz" "$SRC_ROOT/binutils-$BINUTILS_VERSION"
  download_and_extract "https://musl.libc.org/releases/musl-$MUSL_VERSION.tar.gz" "$SRC_ROOT/musl-$MUSL_VERSION"
  download_and_extract "https://ftp.gnu.org/gnu/gmp/gmp-$GMP_VERSION.tar.bz2" "$SRC_ROOT/gmp-$GMP_VERSION"
  download_and_extract "https://ftp.gnu.org/gnu/mpfr/mpfr-$MPFR_VERSION.tar.gz" "$SRC_ROOT/mpfr-$MPFR_VERSION"
  download_and_extract "https://ftp.gnu.org/gnu/mpc/mpc-$MPC_VERSION.tar.gz" "$SRC_ROOT/mpc-$MPC_VERSION"
  download_and_extract "https://libisl.sourceforge.io/isl-$ISL_VERSION.tar.gz" "$SRC_ROOT/isl-$ISL_VERSION"

  build_binutils
  build_gcc_deps
  build_gcc_stage1
  build_musl
  build_gcc_stage2

  log "Build complete. Toolchain installed at $INSTALL_PREFIX"
}

main "$@"
