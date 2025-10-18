# Makefile for DeFi Lending Protocol
# Author: Aditya Rai

.PHONY: help install compile test deploy clean format lint

help:
	@echo "DeFi Lending Protocol - Available Commands"
	@echo "==========================================="
	@echo "make install    - Install all dependencies"
	@echo "make compile    - Compile smart contracts"
	@echo "make test       - Run test suite"
	@echo "make deploy     - Deploy contracts to network"
	@echo "make clean      - Clean build artifacts"
	@echo "make format     - Format Python code"
	@echo "make lint       - Run linters"
	@echo "make coverage   - Generate test coverage report"

install:
	@echo "📦 Installing dependencies..."
	python -m pip install --upgrade pip
	pip install -r requirements.txt
	@echo "✅ Installation complete!"

compile:
	@echo "🔨 Compiling smart contracts..."
	vyper LendingProtocol.vy
	vyper AdvancedLendingProtocol.vy
	@echo "✅ Compilation complete!"

test:
	@echo "🧪 Running tests..."
	pytest tests/ -v --tb=short
	@echo "✅ Tests complete!"

test-coverage:
	@echo "📊 Running tests with coverage..."
	pytest tests/ --cov=. --cov-report=html --cov-report=term
	@echo "✅ Coverage report generated in htmlcov/"

deploy-basic:
	@echo "🚀 Deploying basic lending protocol..."
	python deploy.py basic
	@echo "✅ Deployment complete!"

deploy-advanced:
	@echo "🚀 Deploying advanced lending protocol..."
	python deploy.py advanced
	@echo "✅ Deployment complete!"

deploy-all:
	@echo "🚀 Deploying all contracts..."
	python deploy.py both
	@echo "✅ All deployments complete!"

clean:
	@echo "🧹 Cleaning build artifacts..."
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	find . -type f -name "*.pyo" -delete
	find . -type d -name "*.egg-info" -exec rm -rf {} +
	find . -type d -name ".pytest_cache" -exec rm -rf {} +
	find . -type d -name "htmlcov" -exec rm -rf {} +
	rm -f .coverage
	@echo "✅ Clean complete!"

format:
	@echo "✨ Formatting code..."
	black . --line-length 100
	@echo "✅ Formatting complete!"

lint:
	@echo "🔍 Running linters..."
	flake8 . --max-line-length=100 --exclude=venv,build,dist
	@echo "✅ Linting complete!"

security-check:
	@echo "🔒 Running security checks..."
	@echo "Note: Install slither-analyzer for comprehensive checks"
	@echo "pip install slither-analyzer"
	@echo "slither ."

setup-dev:
	@echo "🛠️  Setting up development environment..."
	python -m venv venv
	@echo "📝 Activate virtual environment:"
	@echo "   On Windows: .\\venv\\Scripts\\activate"
	@echo "   On Unix:    source venv/bin/activate"
	@echo "Then run: make install"

demo:
	@echo "🎬 Running demo..."
	python interact.py
	@echo "✅ Demo complete!"

all: clean install compile test
	@echo "✅ Full build complete!"
