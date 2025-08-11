# RISC-V 32-bit GCC 7.3.0 交叉编译工具链构建项目

## 项目概述

本项目用于构建基于 musl libc 的 RISC-V 32-bit GCC 7.3.0 交叉编译工具链。

## 构建状态

### 目标配置
- **目标架构**: RISC-V 32-bit (rv32imfc)
- **ABI**: ilp32f  
- **C库**: musl 1.2.2
- **编译器**: GCC 7.3.0
- **汇编器/链接器**: binutils 2.30

### 版本信息
- GCC: 7.3.0
- binutils: 2.30
- musl: 1.2.2
- GMP: 6.1.2
- MPFR: 3.1.6
- MPC: 1.0.3
- ISL: 0.18

## 构建流程

1. **系统依赖安装**: 安装必要的构建工具 (m4, make, gcc, wget 等)
2. **binutils**: 交叉汇编器和链接器
3. **GCC 依赖库**: GMP, MPFR, MPC, ISL
4. **GCC 第一阶段**: 基础编译器 (仅 C 语言支持)
5. **musl libc**: C 标准库
6. **GCC 第二阶段**: 完整编译器 (C/C++ 支持)

## 已测试编译环境

本项目已在以下环境中测试通过：

### 主机环境
- **操作系统**: Ubuntu 24.04.2 LTS x86_64
- **内核版本**: 6.8.0-60-generic
- **CPU**: Intel Xeon Platinum 8378C
- **内存**: 22.9GB
- **Shell**: bash 5.2.21
- **用户**: root

### 构建工具版本
- **GCC (Host)**: gcc (Ubuntu 13.3.0-6ubuntu2~24.04) 13.3.0
- **Make**: GNU Make 4.3
- **m4**: m4 (GNU M4) 1.4.19
- **Binutils**: GNU binutils 2.42

### 系统依赖
- build-essential
- m4
- texinfo  
- wget
- tar
- gzip/bzip2
- libtool
- libgmp-dev (用于 GDB 构建)

### 磁盘空间要求
- **最小要求**: 4GB 可用空间
- **推荐**: 8GB+ 可用空间
- **构建时间**: 约 10-15 分钟 (取决于 CPU 性能)

## 目录结构

```
gcc7.3/
├── build.sh              # 主构建脚本
├── src/                   # 源码目录
│   ├── gcc-7.3.0/        # GCC 源码
│   ├── binutils-2.30/     # binutils 源码
│   ├── musl-1.2.2/       # musl 源码
│   └── ...               # 其他依赖库源码
├── build_riscv32/        # 构建目录
│   ├── install/          # 安装目录
│   ├── logs/             # 构建日志
│   ├── host-libs/        # 宿主依赖库
│   └── ...              # 各组件构建目录
└── .github/              # 项目配置和文档
```

## 最近更新

### 2025-08-12
- 修复了 GCC 依赖库构建问题
- 添加了系统依赖自动安装
- 优化了构建顺序，解决了 musl 配置时找不到编译器的问题
- 实现了两阶段 GCC 构建流程

## 已知问题与解决方案

### 问题 1: musl 配置失败 - "riscv32-linux-musl-gcc: not found"
**原因**: 构建顺序问题，musl 需要 GCC 编译器，但 GCC 又需要 C 库头文件
**解决**: 采用两阶段构建方式:
1. 先构建基础 GCC (不依赖 C 库)
2. 使用基础 GCC 构建 musl
3. 使用 musl 构建完整的 GCC

### 问题 2: GMP 配置失败 - "No usable m4"
**原因**: 系统缺少 m4 宏处理器
**解决**: 在构建脚本中添加系统依赖安装

## 使用方法

### 构建工具链
```bash
chmod +x build.sh
./build.sh
```

### 使用工具链
构建完成后，工具链将安装在 `build_riscv32/install/` 目录中。

```bash
# 设置环境变量
export PATH="/root/gcc7.3/build_riscv32/install/bin:$PATH"

# 编译 C 程序
riscv32-linux-musl-gcc -march=rv32imfc -mabi=ilp32f -o hello hello.c

# 查看生成的二进制文件信息
file hello
# 输出: hello: ELF 32-bit LSB executable, UCB RISC-V, RVC, single-float ABI, version 1 (SYSV), dynamically linked, interpreter /lib/ld-musl-riscv32-sp.so.1, not stripped

# 使用 GDB 调试
riscv32-linux-musl-gdb hello
```

### 工具链组件
构建完成后可用的工具包括：
- `riscv32-linux-musl-gcc` - C/C++ 编译器
- `riscv32-linux-musl-gdb` - 调试器
- `riscv32-linux-musl-as` - 汇编器
- `riscv32-linux-musl-ld` - 链接器
- `riscv32-linux-musl-objdump` - 反汇编器
- `riscv32-linux-musl-strip` - 符号剥离器
- 更多工具...
