# GitHub Copilot Instructions for RISC-V WS63 GCC 7.3.0 Cross-Compiler Project

## Project Overview

This project builds a GCC 7.3.0 cross-compilation toolchain targeting `riscv32-linux-musl` specifically for WS63 chip platform. The toolchain is designed for embedded RISC-V development with the following specifications:

- **Target**: `riscv32-linux-musl`
- **Architecture**: `rv32imfc` (RV32I base + M/F/C extensions)
- **ABI**: `ilp32f` (32-bit integers, longs, pointers; single-precision floats in FPU registers)
- **C Library**: musl libc 1.2.5 (updated to support riscv32)
- **Debugger**: GDB 12.1 (cross-debugging support)
- **Build System**: Custom bash script with staged compilation and hybrid build strategy

**Current Architecture Configuration (FIXED - DO NOT MODIFY):**
- **Target**: `riscv32-linux-musl`
- **Architecture**: `rv32imfc` (RV32I + M/F/C extensions)
- **ABI**: `ilp32f` (32-bit integers, longs, pointers; single-precision floats in FPU registers)
- **C Library**: musl libc 1.2.5 (updated to support riscv32)

**Known Issues & Solutions:**
- musl 1.2.5 setjmp/longjmp assembly uses double-precision FP instructions incompatible with rv32imfc
- Solution: Hybrid build strategy - use prebuilt musl libraries when source compilation fails
- Architecture and ABI settings are FIXED and must not be changed

Use `.github/context.sh` to get current project status and build progress.

## Architecture & Build Process

### Build Stages (Critical Order)

1. **System Dependencies**: Install required build tools (m4, texinfo, libgmp-dev, etc.)
2. **Binutils 2.30**: Cross-assembler and linker
3. **GCC Dependencies**: GMP, MPFR, MPC, ISL (built as static host libraries)
4. **GCC Stage 1**: Bare-metal compiler (C only, no libc headers)
5. **musl C Library**: Built using Stage 1 GCC (with fallback to prebuilt libraries)
6. **GCC Stage 2**: Full compiler (C/C++, with libc support)
7. **GDB 12.1**: Cross-debugger for target debugging

### Key Technical Details

- **Sysroot**: `$INSTALL_PREFIX/$TARGET/sysroot`
- **Host Libraries**: Built in `build_riscv32/host-libs/` (static linking)
- **Install Prefix**: `build_riscv32/install/`
- **Build Logs**: Timestamped in `build_riscv32/logs/YYYYMMDD_HHMMSS/`

## File Structure & Components

### Critical Files
- `build.sh`: Main build orchestration script
- `src/`: Source archives and extracted sources
- `build_riscv32/`: All build artifacts and intermediate files
- `.github/`: Project documentation and tooling

### Build State Management
- Build progress tracked via marker files (`.component_built_version`)
- Resumable builds - rerun `./build.sh` to continue from last successful stage
- Comprehensive logging for debugging build failures

## Common Issues & Solutions

### Dependency Problems
- **m4 missing**: Install via `apt-get install m4`
- **texinfo missing**: Install via `apt-get install texinfo`
- **Build-essential**: Required for host compilation tools

### Cross-Compilation Challenges
- **Bootstrap Problem**: GCC needs libc, but libc needs GCC
  - Solution: Two-stage GCC build (bare-metal → full toolchain)
- **Sysroot Configuration**: Must be consistent across all build stages
- **Path Management**: Cross-tools must be in PATH during dependent builds

### RISC-V Specific Considerations
- **Architecture String**: `rv32imfc` must match across binutils/GCC/musl
- **ABI Consistency**: `ilp32f` must be used throughout the toolchain
- **Extension Support**: I(nteger), M(ultiply), F(loat), C(ompressed)

## Development Guidelines

### Code Style
- Bash scripts: Use `set -e -o pipefail` for error handling
- Logging: Prefix with timestamp using `log()` function
- Error handling: Explicit checks with descriptive error messages

### Testing & Validation
- Verify each stage completes before proceeding
- Test cross-compilation with simple programs
- Validate target executable format (RISC-V ELF32)

### Debugging Build Failures
1. Check latest log directory for specific component failures
2. Review `config.log` files for configure-time issues
3. Verify all dependencies are installed
4. Ensure consistent target/arch/ABI across all components

## Environment Configuration

### Required Environment
- Linux host system (tested on Ubuntu 24.04.2 LTS)
- Internet connectivity for source downloads
- Minimum 4GB free disk space
- 4+ CPU cores recommended for parallel builds

### Tested Build Environment
- **OS**: Ubuntu 24.04.2 LTS x86_64
- **Kernel**: 6.8.0-60-generic  
- **CPU**: Intel Xeon Platinum 8378C
- **Memory**: 22.9GB
- **Host GCC**: 13.3.0
- **Shell**: bash 5.2.21

### Build Variables
```bash
TARGET=riscv32-linux-musl
ARCH=rv32imfc
ABI=ilp32f
GCC_VERSION=7.3.0
BINUTILS_VERSION=2.30
MUSL_VERSION=1.2.5
GDB_VERSION=12.1
```

## Integration with GitHub Copilot

### Context Awareness
- Always consider the cross-compilation nature of this project
- Be aware of the two-stage GCC build requirement
- Understand that this is a bare-metal/embedded toolchain
- Consider RISC-V architecture specifics when suggesting code

### Suggestions Priority
1. **Safety First**: Never suggest changes that could break the delicate build order
2. **RISC-V Expertise**: Prefer RISC-V-specific solutions over generic approaches
3. **Build System**: Understand the custom bash-based build orchestration
4. **Error Recovery**: Focus on making builds more robust and resumable

### Common Tasks to Assist With
- Adding new source packages to the build
- Improving error handling and logging
- Optimizing build parallelization with hybrid build strategy
- Adding validation steps for WS63 compatibility
- Extending the toolchain (GDB features, profiling tools, etc.)
- Troubleshooting musl compatibility issues
- Managing prebuilt toolchain fallback mechanisms

## Current Status Tracking

The project maintains its build state through:
- Marker files indicating completed stages
- Comprehensive logging with timestamps
- Git-trackable configuration files in `.github/`

Use `.github/context.sh` to get current project status and build progress.

## Version Compatibility Notes

- **GCC 7.3.0**: Specific version for compatibility with WS63 embedded projects
- **musl 1.2.5**: Updated version with riscv32 support (uses prebuilt when source fails)
- **Binutils 2.30**: Compatible with GCC 7.3.0 and RISC-V target
- **GDB 12.1**: Cross-debugging support for WS63 development
- **RISC-V ISA**: RV32I base instruction set with M/F/C standard extensions

## Future Enhancements

Potential areas for development:
- Enhanced GDB integration and debugging features
- QEMU integration for WS63 emulation and testing
- Additional RISC-V extensions (Vector, Atomic, etc.)
- CMake/pkg-config integration for easier project setup
- Docker containerization for reproducible builds
- CI/CD pipeline integration

---

*This file is maintained as part of the project documentation. Update it when making significant changes to the build system or project structure.*
