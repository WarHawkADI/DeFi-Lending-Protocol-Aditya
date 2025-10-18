"""
Simple Contract Verification Script
Author: Aditya Rai

This script performs basic syntax validation on the Vyper contracts
without requiring full compilation.
"""

import re
import os
from pathlib import Path


class VyperValidator:
    """Simple Vyper contract validator"""
    
    def __init__(self, contract_path: str):
        self.contract_path = Path(contract_path)
        self.contract_name = self.contract_path.stem
        self.errors = []
        self.warnings = []
        
    def validate(self) -> bool:
        """Run all validation checks"""
        print(f"\n{'='*60}")
        print(f"Validating: {self.contract_name}.vy")
        print(f"{'='*60}")
        
        if not self.contract_path.exists():
            print(f"❌ Error: File not found")
            return False
        
        with open(self.contract_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Run checks
        self._check_version(content)
        self._check_imports(content)
        self._check_events(content)
        self._check_functions(content)
        self._check_state_variables(content)
        self._check_basic_syntax(content)
        
        # Report results
        self._print_results()
        
        return len(self.errors) == 0
    
    def _check_version(self, content: str):
        """Check version declaration"""
        version_pattern = r'# @version\s+\d+\.\d+\.\d+'
        if re.search(version_pattern, content):
            print("✅ Version declaration found")
        else:
            self.errors.append("Missing or invalid version declaration")
    
    def _check_imports(self, content: str):
        """Check import statements"""
        if 'from vyper.interfaces import ERC20' in content:
            print("✅ ERC20 interface imported")
        else:
            self.warnings.append("ERC20 interface not imported")
    
    def _check_events(self, content: str):
        """Check event definitions"""
        events = re.findall(r'event\s+(\w+):', content)
        if events:
            print(f"✅ Found {len(events)} event(s): {', '.join(events)}")
        else:
            self.warnings.append("No events defined")
    
    def _check_functions(self, content: str):
        """Check function definitions"""
        # External functions
        external_funcs = re.findall(r'@external\s+def\s+(\w+)\(', content)
        print(f"✅ Found {len(external_funcs)} external function(s)")
        
        # Internal functions
        internal_funcs = re.findall(r'@internal\s+def\s+(\w+)\(', content)
        print(f"✅ Found {len(internal_funcs)} internal function(s)")
    
    def _check_state_variables(self, content: str):
        """Check state variable declarations"""
        # Look for HashMap declarations
        hashmaps = re.findall(r'(\w+):\s+(?:public\()?HashMap\[', content)
        if hashmaps:
            print(f"✅ Found {len(hashmaps)} HashMap state variable(s)")
        
        # Look for simple state variables
        simple_vars = re.findall(r'^\s*(\w+):\s+(?:public\()?(?:uint256|address|bool|ERC20)', content, re.MULTILINE)
        if simple_vars:
            print(f"✅ Found {len(simple_vars)} simple state variable(s)")
    
    def _check_basic_syntax(self, content: str):
        """Basic syntax checks"""
        lines = content.split('\n')
        
        for i, line in enumerate(lines, 1):
            # Check for common syntax errors
            if re.search(r'def\s+\w+\([^)]*\)\s*$', line) and '@external' not in lines[i-2] and '@internal' not in lines[i-2]:
                self.warnings.append(f"Line {i}: Function without decorator")
            
            # Check for proper indentation (basic)
            if line.startswith(' ') and not line.startswith('    ') and line.strip():
                # Allow some flexibility for comments and docstrings
                if not line.strip().startswith('#') and not line.strip().startswith('"""'):
                    self.warnings.append(f"Line {i}: Inconsistent indentation")
        
        print("✅ Basic syntax check completed")
    
    def _print_results(self):
        """Print validation results"""
        print(f"\n{'='*60}")
        print("Validation Results:")
        print(f"{'='*60}")
        
        if self.errors:
            print(f"\n❌ Errors ({len(self.errors)}):")
            for error in self.errors:
                print(f"   - {error}")
        
        if self.warnings:
            print(f"\n⚠️  Warnings ({len(self.warnings)}):")
            for warning in self.warnings:
                print(f"   - {warning}")
        
        if not self.errors and not self.warnings:
            print("\n✅ All checks passed!")
        elif not self.errors:
            print("\n✅ No errors found (warnings can be ignored)")
        else:
            print("\n❌ Validation failed!")


def main():
    """Main validation function"""
    print("="*60)
    print("DeFi Lending Protocol - Contract Validation")
    print("="*60)
    
    contracts = [
        'LendingProtocol.vy',
        'AdvancedLendingProtocol.vy'
    ]
    
    results = {}
    
    for contract in contracts:
        validator = VyperValidator(contract)
        results[contract] = validator.validate()
    
    # Final summary
    print(f"\n{'='*60}")
    print("Final Summary:")
    print(f"{'='*60}")
    
    for contract, passed in results.items():
        status = "✅ PASSED" if passed else "❌ FAILED"
        print(f"{contract}: {status}")
    
    all_passed = all(results.values())
    
    if all_passed:
        print(f"\n{'='*60}")
        print("🎉 All contracts validated successfully!")
        print(f"{'='*60}")
        return 0
    else:
        print(f"\n{'='*60}")
        print("⚠️  Some contracts have errors")
        print(f"{'='*60}")
        return 1


if __name__ == '__main__':
    exit(main())
