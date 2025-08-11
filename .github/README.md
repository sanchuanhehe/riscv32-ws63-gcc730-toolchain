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

## Files in this Directory

- `copilot-instructions.md`: Comprehensive GitHub Copilot context and project guidelines
- `workspace.yml`: VS Code workspace configuration
- `context.sh`: Script to analyze and report current build status
- `dependencies.txt`: List of required system packages and tools
- `build-status.md`: Current build progress and status information

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

```bash
chmod +x build.sh
./build.sh
```

构建完成后，工具链将安装在 `build_riscv32/install/` 目录中。
