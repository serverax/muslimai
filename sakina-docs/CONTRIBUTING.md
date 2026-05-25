# Contributing to Project Sakina

## Code of Conduct

Be respectful, inclusive, and focused on creating a high-quality Islamic AI system.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/sakina-al.git`
3. Create a feature branch: `git checkout -b feat/your-feature`
4. Set up development environment: `make setup-k8s`

## Development Guidelines

### Commit Messages

Use conventional commits:
```
feat: add semantic router implementation
fix: correct similarity threshold logic
docs: update architecture guide
test: add integration tests for RAG engine
chore: update dependencies
```

### Code Style

- **Rust**: Follow `rustfmt` standards (`cargo fmt`)
- **Flutter**: Follow Dart conventions (`dart format`)
- **Python**: Follow PEP 8

### Testing

```bash
# Run all tests
make test

# Backend tests
cd sakina-backend && cargo test

# Frontend tests
cd sakina-frontend && flutter test
```

### Pull Request Process

1. Update documentation if needed
2. Add tests for new functionality
3. Run full test suite locally
4. Submit PR with clear description
5. Wait for code review
6. Address feedback and iterate
7. Merge after approval

## Theological Review

For features involving Islamic knowledge:
1. Submit for theological review by domain experts
2. Ensure sources are authenticated
3. Include madhhab coverage
4. Document authenticity grades

## Reporting Issues

Include:
- **Description**: What's the problem?
- **Steps**: How to reproduce
- **Expected**: What should happen
- **Actual**: What actually happens
- **Environment**: OS, Kubernetes version, etc.

## Questions?

Ask in GitHub Discussions or open an issue.

Thank you for contributing! 🙏
