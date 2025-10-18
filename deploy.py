"""
Deployment script for DeFi Lending Protocol
Author: Aditya Rai
"""

from vyper import compile_code
from web3 import Web3
from eth_account import Account
import json
import os
from pathlib import Path

class LendingProtocolDeployer:
    """Deployment manager for lending protocol contracts"""
    
    def __init__(self, provider_url: str, private_key: str):
        """
        Initialize deployer
        
        Args:
            provider_url: RPC endpoint (e.g., Infura, Alchemy)
            private_key: Private key for deployment account
        """
        self.w3 = Web3(Web3.HTTPProvider(provider_url))
        self.account = Account.from_key(private_key)
        self.w3.eth.default_account = self.account.address
        
        print(f"🔗 Connected to network: {self.w3.is_connected()}")
        print(f"📍 Deployer address: {self.account.address}")
        print(f"💰 Balance: {self.w3.eth.get_balance(self.account.address) / 10**18} ETH")
    
    def compile_contract(self, contract_path: str):
        """
        Compile Vyper contract
        
        Args:
            contract_path: Path to .vy file
            
        Returns:
            Compiled contract bytecode and ABI
        """
        print(f"\n📝 Compiling {contract_path}...")
        
        with open(contract_path, 'r') as f:
            contract_code = f.read()
        
        compiled = compile_code(
            contract_code,
            output_formats=['bytecode', 'abi']
        )
        
        print("✅ Compilation successful")
        return compiled['bytecode'], compiled['abi']
    
    def deploy_contract(self, bytecode: str, abi: list, constructor_args: list = None):
        """
        Deploy contract to blockchain
        
        Args:
            bytecode: Compiled contract bytecode
            abi: Contract ABI
            constructor_args: Arguments for constructor
            
        Returns:
            Deployed contract instance
        """
        print("\n🚀 Deploying contract...")
        
        contract = self.w3.eth.contract(abi=abi, bytecode=bytecode)
        
        # Build transaction
        if constructor_args:
            tx = contract.constructor(*constructor_args).build_transaction({
                'from': self.account.address,
                'nonce': self.w3.eth.get_transaction_count(self.account.address),
                'gas': 5000000,
                'gasPrice': self.w3.eth.gas_price
            })
        else:
            tx = contract.constructor().build_transaction({
                'from': self.account.address,
                'nonce': self.w3.eth.get_transaction_count(self.account.address),
                'gas': 5000000,
                'gasPrice': self.w3.eth.gas_price
            })
        
        # Sign and send
        signed_tx = self.w3.eth.account.sign_transaction(tx, self.account.key)
        tx_hash = self.w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        
        print(f"⏳ Transaction hash: {tx_hash.hex()}")
        print("⏳ Waiting for confirmation...")
        
        # Wait for receipt
        tx_receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash)
        
        if tx_receipt['status'] == 1:
            print(f"✅ Contract deployed at: {tx_receipt['contractAddress']}")
            return self.w3.eth.contract(
                address=tx_receipt['contractAddress'],
                abi=abi
            )
        else:
            raise Exception("❌ Deployment failed")
    
    def save_deployment_info(self, contract_name: str, address: str, abi: list):
        """Save deployment information to JSON file"""
        
        deployment_dir = Path('deployments')
        deployment_dir.mkdir(exist_ok=True)
        
        network_id = self.w3.eth.chain_id
        deployment_file = deployment_dir / f'{contract_name}_{network_id}.json'
        
        deployment_data = {
            'contract_name': contract_name,
            'address': address,
            'network_id': network_id,
            'deployer': self.account.address,
            'abi': abi
        }
        
        with open(deployment_file, 'w') as f:
            json.dump(deployment_data, f, indent=2)
        
        print(f"💾 Deployment info saved to {deployment_file}")


def deploy_basic_protocol():
    """Deploy the basic lending protocol"""
    
    # Configuration
    PROVIDER_URL = os.getenv('PROVIDER_URL', 'http://127.0.0.1:8545')
    PRIVATE_KEY = os.getenv('PRIVATE_KEY', '0x' + '0' * 64)
    TOKEN_ADDRESS = os.getenv('TOKEN_ADDRESS', '0x' + '0' * 40)
    
    # Initialize deployer
    deployer = LendingProtocolDeployer(PROVIDER_URL, PRIVATE_KEY)
    
    # Compile contract
    bytecode, abi = deployer.compile_contract('LendingProtocol.vy')
    
    # Deploy
    contract = deployer.deploy_contract(
        bytecode,
        abi,
        constructor_args=[TOKEN_ADDRESS]
    )
    
    # Save deployment info
    deployer.save_deployment_info(
        'LendingProtocol',
        contract.address,
        abi
    )
    
    return contract


def deploy_advanced_protocol():
    """Deploy the advanced lending protocol"""
    
    PROVIDER_URL = os.getenv('PROVIDER_URL', 'http://127.0.0.1:8545')
    PRIVATE_KEY = os.getenv('PRIVATE_KEY', '0x' + '0' * 64)
    TOKEN_ADDRESS = os.getenv('TOKEN_ADDRESS', '0x' + '0' * 40)
    
    deployer = LendingProtocolDeployer(PROVIDER_URL, PRIVATE_KEY)
    
    bytecode, abi = deployer.compile_contract('AdvancedLendingProtocol.vy')
    
    contract = deployer.deploy_contract(
        bytecode,
        abi,
        constructor_args=[TOKEN_ADDRESS]
    )
    
    deployer.save_deployment_info(
        'AdvancedLendingProtocol',
        contract.address,
        abi
    )
    
    return contract


if __name__ == '__main__':
    print("=" * 60)
    print("🏦 DeFi Lending Protocol Deployment Script")
    print("=" * 60)
    
    import sys
    
    if len(sys.argv) < 2:
        print("\nUsage:")
        print("  python deploy.py basic    - Deploy basic protocol")
        print("  python deploy.py advanced - Deploy advanced protocol")
        print("  python deploy.py both     - Deploy both protocols")
        sys.exit(1)
    
    deployment_type = sys.argv[1].lower()
    
    try:
        if deployment_type == 'basic':
            contract = deploy_basic_protocol()
            print(f"\n✅ Basic Protocol deployed at: {contract.address}")
        
        elif deployment_type == 'advanced':
            contract = deploy_advanced_protocol()
            print(f"\n✅ Advanced Protocol deployed at: {contract.address}")
        
        elif deployment_type == 'both':
            basic = deploy_basic_protocol()
            print(f"\n✅ Basic Protocol: {basic.address}")
            
            advanced = deploy_advanced_protocol()
            print(f"\n✅ Advanced Protocol: {advanced.address}")
        
        else:
            print("❌ Invalid deployment type")
            sys.exit(1)
        
        print("\n" + "=" * 60)
        print("🎉 Deployment completed successfully!")
        print("=" * 60)
    
    except Exception as e:
        print(f"\n❌ Deployment failed: {str(e)}")
        sys.exit(1)
