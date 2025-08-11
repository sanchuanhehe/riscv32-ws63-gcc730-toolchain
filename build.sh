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

mirror_url() {
  local url=$1
  if [[ "$url" =~ ^https?://ftp.gnu.org/gnu/ ]]; then
    echo "${url/https:\/\/ftp.gnu.org\/gnu\//https://mirrors.tuna.tsinghua.edu.cn/gnu/}"
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
    local mode=${1:-full}
    local mark_file=$BUILD_ROOT/.gcc_built_$GCC_VERSION
    if [ "$mode" = "full" ] && [ -f "$mark_file" ]; then
      log "GCC $GCC_VERSION already built, skipping."
      return
    fi

    log "Building GCC $GCC_VERSION ($mode)..."
    mkdir -p "$BUILD_ROOT/gcc-build"
    cd "$BUILD_ROOT/gcc-build"

    local old_path=$PATH
    export PATH="$INSTALL_PREFIX/bin:$PATH"

    if [ ! -f "config.status" ]; then
      if ! "$SRC_ROOT/gcc-$GCC_VERSION/configure" \
        --prefix="$INSTALL_PREFIX" \
        --target="$TARGET" \
        --with-arch="$ARCH" \
        --with-abi="$ABI" \
        --disable-multilib \
        --disable-threads \
        --disable-libmudflap \
        --disable-libitm \
        --enable-languages=c,c++ \
        --enable-shared \
        --enable-libssp \
        --enable-libgomp \
        --enable-poison-system-directories \
        --enable-symvers=gnu \
        --with-sysroot="$INSTALL_PREFIX/$TARGET/sysroot" \
        --with-headers="$INSTALL_PREFIX/$TARGET/sysroot/usr/include" \
        --with-build-sysroot="$INSTALL_PREFIX/$TARGET/sysroot" \
        --with-gmp="$SRC_ROOT/gmp-$GMP_VERSION" \
        --with-mpfr="$SRC_ROOT/mpfr-$MPFR_VERSION" \
        --with-mpc="$SRC_ROOT/mpc-$MPC_VERSION" \
        --with-isl="$SRC_ROOT/isl-$ISL_VERSION" \
        --with-gnu-as \
        --with-gnu-ld \
        >"$LOG_DIR/gcc_configure.log" 2>&1; then
        log "ERROR: GCC configure failed"
        exit 1
      fi
    fi

    if [ "$mode" = "bootstrap" ]; then
      if ! make -j"$(get_nproc)" all-gcc >"$LOG_DIR/gcc_all-gcc.log" 2>&1; then
        log "ERROR: GCC all-gcc build failed"
        exit 1
      fi
      if ! make install-gcc >"$LOG_DIR/gcc_install-gcc.log" 2>&1; then
        log "ERROR: GCC install-gcc failed"
        exit 1
      fi
      if ! make -j"$(get_nproc)" all-target-libgcc >"$LOG_DIR/gcc_all-target-libgcc.log" 2>&1; then
        log "ERROR: GCC all-target-libgcc build failed"
        exit 1
      fi
      if ! make install-target-libgcc >"$LOG_DIR/gcc_install-target-libgcc.log" 2>&1; then
        log "ERROR: GCC install-target-libgcc failed"
        exit 1
      fi
      export PATH=$old_path
      log "GCC bootstrap build complete."
      return
    fi

    # 完整构建
    if ! make -j"$(get_nproc)" all-target-libstdc++-v3 >"$LOG_DIR/gcc_all-target_libstdc++.log" 2>&1; then
      log "ERROR: GCC all-target-libstdc++-v3 build failed"
      exit 1
    fi
    if ! make install-target-libstdc++-v3 >"$LOG_DIR/gcc_install-target-libstdc++.log" 2>&1; then
      log "ERROR: GCC install-target-libstdc++-v3 failed"
      exit 1
    fi
    export PATH=$old_path
    touch "$mark_file"
    log "GCC build complete."
    >"$LOG_DIR/gcc_configure.log" 2>&1; then
    log "ERROR: GCC configure failed"
    exit 1
  fi

  if ! make -j"$(get_nproc)" all-gcc >"$LOG_DIR/gcc_all-gcc.log" 2>&1; then
    log "ERROR: GCC all-gcc build failed"
    exit 1
  fi

  if ! make install-gcc >"$LOG_DIR/gcc_install-gcc.log" 2>&1; then
    log "ERROR: GCC install-gcc failed"
    exit 1
  fi

  if ! make -j"$(get_nproc)" all-target-libgcc >"$LOG_DIR/gcc_all-target-libgcc.log" 2>&1; then
    log "ERROR: GCC all-target-libgcc build failed"
    exit 1
  fi

  if ! make install-target-libgcc >"$LOG_DIR/gcc_install-target-libgcc.log" 2>&1; then
    log "ERROR: GCC install-target-libgcc failed"
    exit 1
  fi

  if ! make -j"$(get_nproc)" all-target-libstdc++-v3 >"$LOG_DIR/gcc_all-target-libstdc++.log" 2>&1; then
    log "ERROR: GCC all-target-libstdc++-v3 build failed"
    exit 1
  fi

  if ! make install-target-libstdc++-v3 >"$LOG_DIR/gcc_install-target-libstdc++.log" 2>&1; then
    log "ERROR: GCC install-target-libstdc++-v3 failed"
    exit 1
  fi

  export PATH=$old_path
  touch "$mark_file"
  log "GCC build complete."
}

main() {
  download_and_extract "https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.gz" "$SRC_ROOT/gcc-$GCC_VERSION"
  download_and_extract "https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.gz" "$SRC_ROOT/binutils-$BINUTILS_VERSION"
  download_and_extract "https://musl.libc.org/releases/musl-$MUSL_VERSION.tar.gz" "$SRC_ROOT/musl-$MUSL_VERSION"
  download_and_extract "https://ftp.gnu.org/gnu/gmp/gmp-$GMP_VERSION.tar.bz2" "$SRC_ROOT/gmp-$GMP_VERSION"
  download_and_extract "https://ftp.gnu.org/gnu/mpfr/mpfr-$MPFR_VERSION.tar.gz" "$SRC_ROOT/mpfr-$MPFR_VERSION"
  download_and_extract "https://ftp.gnu.org/gnu/mpc/mpc-$MPC_VERSION.tar.gz" "$SRC_ROOT/mpc-$MPC_VERSION"
  download_and_extract "https://libisl.sourceforge.io/isl-$ISL_VERSION.tar.gz" "$SRC_ROOT/isl-$ISL_VERSION"

  build_binutils
  build_gcc bootstrap   # 只编译 gcc 和 libgcc
  build_musl            # 用交叉 gcc 编译 musl
  build_gcc full        # 完整编译 gcc（libstdc++等）

  log "Build complete. Toolchain installed at $INSTALL_PREFIX"
}

main "$@"
