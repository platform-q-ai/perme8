# Documentation Index

Welcome to the Jarga project documentation. This directory contains comprehensive guides for understanding and working with the codebase.

## 📚 Available Documentation

### [ARCHITECTURE.md](ARCHITECTURE.md)
**Complete architectural documentation**

Comprehensive guide covering:
- Core vs Interface separation principles
- Boundary configuration and enforcement
- Layer responsibilities and patterns
- Cross-context communication
- Internal organization (Query Objects, Policy Objects)
- Adding new features
- Troubleshooting and best practices

**Read this if you want to**:
- Understand the overall architecture
- Learn why the code is organized this way
- Add new contexts or major features
- Understand the philosophy behind the design

### [BOUNDARY_QUICK_REFERENCE.md](BOUNDARY_QUICK_REFERENCE.md)
**Quick reference for common patterns**

Practical examples covering:
- ✅ DO and ❌ DON'T patterns
- Common boundary violations and fixes
- Quick troubleshooting guide
- Code snippets for adding new features

**Read this if you want to**:
- Quick answers while coding
- See examples of correct patterns
- Troubleshoot boundary warnings
- Copy-paste boilerplate for new code

## 🚀 Quick Start

### For New Developers

1. **Read**: [ARCHITECTURE.md](ARCHITECTURE.md) - Start here to understand the big picture
2. **Reference**: [BOUNDARY_QUICK_REFERENCE.md](BOUNDARY_QUICK_REFERENCE.md) - Keep this handy while coding
3. **Check**: Run `mix compile` frequently to catch boundary violations early

### For Experienced Developers

Jump to [BOUNDARY_QUICK_REFERENCE.md](BOUNDARY_QUICK_REFERENCE.md) for quick patterns and examples.

## 🎯 Key Concepts

### The Architecture in 30 Seconds

```
┌─────────────────────────────────────┐
│   Interface Layer (JargaWeb)        │
│   - Controllers, LiveViews           │
│   - Can call ↓ contexts              │
│   - Cannot be called by contexts     │
└─────────────────────────────────────┘
              ↓ depends on
┌─────────────────────────────────────┐
│   Core Layer (Contexts)              │
│   - Accounts, Workspaces, Projects   │
│   - Business logic and rules         │
│   - Can call ↓ infrastructure        │
└─────────────────────────────────────┘
              ↓ depends on
┌─────────────────────────────────────┐
│   Infrastructure (Repo, Mailer)      │
│   - Shared technical services        │
│   - Available to all layers          │
└─────────────────────────────────────┘
```

### The Golden Rules

1. **Dependencies flow inward** - Interface → Core → Infrastructure
2. **Public APIs only** - Never access internal modules across boundaries
3. **Compile-time enforcement** - Violations caught during `mix compile`
4. **Context independence** - Each context is self-contained

## 🔧 Common Tasks

### Checking Your Code

```bash
# Compile and check for boundary violations
mix compile

# Run full pre-commit checks (includes boundary)
mix precommit
```

### Adding a New Feature

1. Determine which layer: Web (Interface) or Context (Core)?
2. Follow patterns in [BOUNDARY_QUICK_REFERENCE.md](BOUNDARY_QUICK_REFERENCE.md)
3. If crossing boundaries, use public APIs only
4. Verify with `mix compile` - no "forbidden reference" warnings

### Fixing a Boundary Violation

```
warning: forbidden reference to Jarga.Workspaces.Policies.Authorization
```

See the [Troubleshooting section](BOUNDARY_QUICK_REFERENCE.md#troubleshooting) in the Quick Reference.

## 📖 Additional Resources

### Project Documentation

- **[../CLAUDE.md](../CLAUDE.md)** - Development guidelines and TDD practices
- **[../README.md](../README.md)** - Project overview and setup instructions

### External Resources

- [Boundary Library Docs](https://hexdocs.pm/boundary) - Official Boundary documentation
- [VBT: The Development Process](https://www.veribigthings.com/posts/towards-maintainable-elixir-the-development-process)
- [VBT: The Core and the Interface](https://www.veribigthings.com/posts/towards-maintainable-elixir-the-core-and-the-interface)
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html) - Original concept by Robert C. Martin

## 🤝 Contributing

When making architectural changes:

1. **Discuss first** - Major changes should be discussed with the team
2. **Update docs** - Keep this documentation in sync with code
3. **Verify tests** - All tests must pass after architectural changes
4. **Check boundaries** - Ensure no new violations are introduced

## ❓ Questions

If you're unsure about:
- Where to put new code → See [ARCHITECTURE.md - Adding New Features](ARCHITECTURE.md#adding-new-features)
- How to call another context → See [BOUNDARY_QUICK_REFERENCE.md - Cross-Context Communication](BOUNDARY_QUICK_REFERENCE.md#-cross-context-communication)
- Why a boundary violation occurs → See [BOUNDARY_QUICK_REFERENCE.md - Troubleshooting](BOUNDARY_QUICK_REFERENCE.md#troubleshooting)

## 📝 Documentation Status

- ✅ **ARCHITECTURE.md** - Comprehensive architectural guide
- ✅ **BOUNDARY_QUICK_REFERENCE.md** - Quick reference and patterns
- ✅ **README.md** (this file) - Documentation index

Last updated: 2025-11-04
