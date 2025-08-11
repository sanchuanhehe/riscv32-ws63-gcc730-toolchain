# GitHub Copilot Instructions for GCC 7.3.0 RISC-V Cross-Compiler Project

## Project Overview

This project builds a complete GCC 7.3.0 cross-compilation toolchain targeting `riscv32-linux-musl`. The toolchain is designed for embedded RISC-V development with the following specifications:

- **Target**: `riscv32-linux-musl`
- **Architecture**: `rv32imfc` (RV32I base + M/F/C extensions)
- **ABI**: `ilp32f` (32-bit integers, longs, pointers; single-precision floats in FPU registers)
- **C Library**: musl libc 1.2.2
- **Build System**: Custom bash script with staged compilation

## Architecture & Build Process

### Build Stages (Critical Order)

1. **System Dependencies**: Install required build tools (m4, texinfo, etc.)
2. **Binutils 2.30**: Cross-assembler and linker
3. **GCC Dependencies**: GMP, MPFR, MPC, ISL (built as static host libraries)
4. **GCC Stage 1**: Bare-metal compiler (C only, no libc headers)
5. **musl C Library**: Built using Stage 1 GCC
6. **GCC Stage 2**: Full compiler (C/C++, with libc support)

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
- Linux host system (tested on Ubuntu/Debian)
- Internet connectivity for source downloads
- Minimum 4GB free disk space
- 4+ CPU cores recommended for parallel builds

### Build Variables
```bash
TARGET=riscv32-linux-musl
ARCH=rv32imfc
ABI=ilp32f
GCC_VERSION=7.3.0
BINUTILS_VERSION=2.30
MUSL_VERSION=1.2.2
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
- Optimizing build parallelization
- Adding validation steps
- Extending the toolchain (debugger, profiling tools, etc.)

## Current Status Tracking

The project maintains its build state through:
- Marker files indicating completed stages
- Comprehensive logging with timestamps
- Git-trackable configuration files in `.github/`

Use `.github/context.sh` to get current project status and build progress.

## Version Compatibility Notes

- **GCC 7.3.0**: Specific version for compatibility with legacy embedded projects
- **musl 1.2.2**: Modern, lightweight C library suitable for embedded systems
- **Binutils 2.30**: Compatible with GCC 7.3.0 and RISC-V target
- **RISC-V ISA**: RV32I base instruction set with M/F/C standard extensions

## Future Enhancements

Potential areas for development:
- GDB integration for cross-debugging
- Newlib alternative to musl
- Additional RISC-V extensions (Vector, Atomic, etc.)
- QEMU integration for testing
- CMake/pkg-config integration
- Docker containerization

---

*This file is maintained as part of the project documentation. Update it when making significant changes to the build system or project structure.*
