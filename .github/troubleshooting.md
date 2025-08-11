# 构建问题排查指南

## 常见问题及解决方案

### 1. 系统依赖问题

#### 问题: "No usable m4 in $PATH"
```
configure: error: No usable m4 in $PATH or /usr/5bin (see config.log for reasons).
```
**解决方案**: 安装 m4 包
```bash
sudo apt-get install m4
```

#### 问题: 缺少编译工具
**解决方案**: 安装完整的构建环境
```bash
sudo apt-get install build-essential m4 libtool wget
```

### 2. 构建顺序问题

#### 问题: "riscv32-linux-musl-gcc: not found"
**原因**: musl 需要交叉编译器，但交叉编译器又需要 C 库头文件
**解决方案**: 采用分阶段构建
1. 构建 binutils (汇编器和链接器)
2. 构建 GCC 依赖库 (GMP, MPFR, MPC, ISL)
3. 构建 GCC Stage 1 (基础编译器，无 C 库依赖)
4. 构建 musl (使用 Stage 1 编译器)
5. 构建 GCC Stage 2 (完整编译器，包含 C++ 支持)

### 3. 内存和磁盘空间问题

#### 问题: 编译过程中内存不足
**解决方案**: 
- 减少并发编译数: `make -j1` 而不是 `make -j$(nproc)`
- 增加交换空间

#### 问题: 磁盘空间不足
**解决方案**: 
- 清理不需要的文件
- 挂载更大的存储设备

### 4. 网络下载问题

#### 问题: 源码下载失败
**解决方案**: 使用镜像站点
- GNU 镜像: https://mirrors.tuna.tsinghua.edu.cn/gnu/
- musl 镜像: https://mirrors.tuna.tsinghua.edu.cn/musl/releases/

### 5. 配置问题

#### 问题: configure 脚本找不到依赖库
**解决方案**: 确保库安装在正确位置
- 使用 `--with-gmp`, `--with-mpfr` 等选项指定库的位置
- 设置 `PKG_CONFIG_PATH` 环境变量

## 调试技巧

### 1. 查看详细错误日志
```bash
# 查看最新的构建日志
ls -t build_riscv32/logs/ | head -1
tail -50 build_riscv32/logs/最新日志目录/组件_configure.log
```

### 2. 检查构建状态
```bash
./.github/context.sh status
```

### 3. 清理并重新构建
```bash
./.github/context.sh clean
./build.sh
```

### 4. 手动运行单个构建步骤
```bash
# 进入构建目录
cd build_riscv32/gcc-build

# 手动运行 configure
/path/to/gcc-source/configure [options]

# 查看具体错误
make 2>&1 | tee make_output.log
```

## 环境要求

### 最小系统要求
- CPU: 2 核心
- 内存: 4GB
- 磁盘空间: 10GB
- 操作系统: Ubuntu 20.04+ 或类似的 Linux 发行版

### 推荐系统配置
- CPU: 4+ 核心
- 内存: 8GB+
- 磁盘空间: 20GB+
- SSD 存储

## 构建时间估算

根据系统配置，预计构建时间：
- 单核系统: 3-4 小时
- 双核系统: 1.5-2 小时
- 四核系统: 45-60 分钟
- 八核系统: 20-30 分钟

## 验证构建结果

### 检查工具链是否正确安装
```bash
# 检查编译器
build_riscv32/install/bin/riscv32-linux-musl-gcc --version

# 检查汇编器
build_riscv32/install/bin/riscv32-linux-musl-as --version

# 检查链接器
build_riscv32/install/bin/riscv32-linux-musl-ld --version
```

### 编译测试程序
```bash
export PATH="$PWD/build_riscv32/install/bin:$PATH"

# 创建简单的 C 程序
cat > hello.c << 'EOF'
#include <stdio.h>
int main() {
    printf("Hello from RISC-V!\n");
    return 0;
}
EOF

# 编译测试
riscv32-linux-musl-gcc -o hello hello.c

# 检查目标文件格式
file hello
```
