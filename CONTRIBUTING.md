# Contributing to DeFi Lending Protocol

Thank you for your interest in contributing to the DeFi Lending Protocol! This document provides guidelines for contributing to the project.

## 🤝 How to Contribute

### Reporting Issues

If you find a bug or have a suggestion:

1. Check if the issue already exists in the [Issues](https://github.com/yourusername/DeFi-Lending-Protocol/issues)
2. If not, create a new issue with a clear title and description
3. Include steps to reproduce (for bugs)
4. Include your environment details (OS, Python version, etc.)

### Submitting Changes

1. **Fork the Repository**
   ```bash
   git clone https://github.com/yourusername/DeFi-Lending-Protocol.git
   cd DeFi-Lending-Protocol
   ```

2. **Create a Feature Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make Your Changes**
   - Write clean, documented code
   - Follow the existing code style
   - Add tests for new features
   - Update documentation as needed

4. **Test Your Changes**
   ```bash
   pytest tests/
   ```

5. **Commit Your Changes**
   ```bash
   git add .
   git commit -m "Add feature: brief description"
   ```

6. **Push to Your Fork**
   ```bash
   git push origin feature/your-feature-name
   ```

7. **Create a Pull Request**
   - Go to the original repository
   - Click "New Pull Request"
   - Select your feature branch
   - Provide a clear description of changes

## 📋 Code Standards

### Python Code Style
- Follow PEP 8 guidelines
- Use meaningful variable names
- Add docstrings to all functions
- Keep functions focused and concise

### Vyper Smart Contracts
- Use clear, descriptive function names
- Add comprehensive comments
- Include NatSpec documentation
- Follow security best practices

### Testing
- Write tests for all new features
- Aim for >80% code coverage
- Include both positive and negative test cases
- Test edge cases and boundary conditions

## 🔒 Security

- Never commit private keys or secrets
- Report security vulnerabilities privately
- Follow smart contract security best practices
- Consider gas optimization

## 📝 Commit Message Guidelines

Use clear, descriptive commit messages:

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `test:` Adding/updating tests
- `refactor:` Code refactoring
- `style:` Code style changes
- `chore:` Maintenance tasks

Example:
```
feat: Add multi-collateral support to lending protocol
```

## 🎯 Development Setup

1. **Install Dependencies**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: .\venv\Scripts\activate
   pip install -r requirements.txt
   ```

2. **Run Tests**
   ```bash
   pytest tests/ -v
   ```

3. **Format Code**
   ```bash
   black .
   flake8 .
   ```

## 🌟 Areas for Contribution

We welcome contributions in these areas:

- **Smart Contract Features**: New lending mechanisms, risk models
- **Testing**: Expand test coverage, add integration tests
- **Documentation**: Improve guides, add examples
- **Security**: Audit code, suggest improvements
- **Frontend**: Build user interface (future)
- **Tooling**: Deployment scripts, monitoring tools

## ❓ Questions?

Feel free to open an issue for questions or join our community discussions.

## 📄 License

By contributing, you agree that your contributions will be licensed under the GNU GPL v3.0 License.

---

Thank you for contributing to the DeFi Lending Protocol! 🙏
