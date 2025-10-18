"""
Interaction script for DeFi Lending Protocol
Author: Aditya Rai

Provides convenient functions to interact with deployed contracts
"""

from web3 import Web3
from eth_account import Account
import json
from pathlib import Path


class ProtocolInterface:
    """Interface for interacting with lending protocol"""
    
    def __init__(self, provider_url: str, private_key: str, contract_address: str, abi_path: str):
        """Initialize protocol interface"""
        self.w3 = Web3(Web3.HTTPProvider(provider_url))
        self.account = Account.from_key(private_key)
        
        with open(abi_path, 'r') as f:
            deployment_data = json.load(f)
            abi = deployment_data['abi']
        
        self.contract = self.w3.eth.contract(address=contract_address, abi=abi)
        self.w3.eth.default_account = self.account.address
    
    def create_loan(self, amount: int, collateral: int, interest_rate: int, duration: int):
        """
        Create a new loan
        
        Args:
            amount: Loan amount
            collateral: Collateral amount
            interest_rate: Interest rate percentage
            duration: Duration in days
        """
        print(f"\n📋 Creating loan:")
        print(f"   Amount: {amount}")
        print(f"   Collateral: {collateral}")
        print(f"   Interest Rate: {interest_rate}%")
        print(f"   Duration: {duration} days")
        
        tx = self.contract.functions.create_loan(
            amount,
            collateral,
            interest_rate,
            duration
        ).build_transaction({
            'from': self.account.address,
            'nonce': self.w3.eth.get_transaction_count(self.account.address),
            'gas': 500000,
            'gasPrice': self.w3.eth.gas_price
        })
        
        signed_tx = self.w3.eth.account.sign_transaction(tx, self.account.key)
        tx_hash = self.w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        
        receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash)
        
        if receipt['status'] == 1:
            print(f"✅ Loan created! TX: {tx_hash.hex()}")
            return receipt
        else:
            print(f"❌ Transaction failed")
            return None
    
    def get_loan_details(self, loan_id: int):
        """Get details of a specific loan"""
        print(f"\n🔍 Fetching loan {loan_id} details...")
        
        loan = self.contract.functions.get_loan_details(loan_id).call()
        
        print(f"\n📊 Loan #{loan_id} Details:")
        print(f"   Borrower: {loan[0]}")
        print(f"   Amount: {loan[1]}")
        print(f"   Collateral: {loan[2]}")
        print(f"   Interest Rate: {loan[3]}%")
        print(f"   Duration: {loan[4]} days")
        print(f"   Status: {loan[5]}")
        print(f"   Start Time: {loan[6]}")
        print(f"   End Time: {loan[7]}")
        print(f"   Repayment Amount: {loan[8]}")
        
        return loan
    
    def repay_loan(self, loan_id: int):
        """Repay a loan"""
        print(f"\n💳 Repaying loan #{loan_id}...")
        
        tx = self.contract.functions.repay_loan(loan_id).build_transaction({
            'from': self.account.address,
            'nonce': self.w3.eth.get_transaction_count(self.account.address),
            'gas': 300000,
            'gasPrice': self.w3.eth.gas_price
        })
        
        signed_tx = self.w3.eth.account.sign_transaction(tx, self.account.key)
        tx_hash = self.w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        
        receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash)
        
        if receipt['status'] == 1:
            print(f"✅ Loan repaid! TX: {tx_hash.hex()}")
            return receipt
        else:
            print(f"❌ Repayment failed")
            return None
    
    def liquidate_loan(self, loan_id: int):
        """Liquidate a loan"""
        print(f"\n⚠️  Liquidating loan #{loan_id}...")
        
        tx = self.contract.functions.liquidate_loan(loan_id).build_transaction({
            'from': self.account.address,
            'nonce': self.w3.eth.get_transaction_count(self.account.address),
            'gas': 300000,
            'gasPrice': self.w3.eth.gas_price
        })
        
        signed_tx = self.w3.eth.account.sign_transaction(tx, self.account.key)
        tx_hash = self.w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        
        receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash)
        
        if receipt['status'] == 1:
            print(f"✅ Loan liquidated! TX: {tx_hash.hex()}")
            return receipt
        else:
            print(f"❌ Liquidation failed")
            return None
    
    def get_protocol_stats(self):
        """Get overall protocol statistics"""
        print("\n📈 Protocol Statistics:")
        
        stats = self.contract.functions.get_protocol_stats().call()
        
        print(f"   Total Loans Created: {stats[0]}")
        print(f"   Total Loans Repaid: {stats[1]}")
        print(f"   Total Loans Liquidated: {stats[2]}")
        
        return stats
    
    def calculate_interest(self, loan_id: int):
        """Calculate interest for a loan"""
        interest = self.contract.functions.calculate_interest(loan_id).call()
        print(f"\n💵 Interest accrued on loan #{loan_id}: {interest}")
        return interest
    
    def assess_loan_risk(self, loan_id: int):
        """Assess risk level of a loan"""
        risk = self.contract.functions.assess_loan_risk(loan_id).call()
        
        risk_levels = {1: "Low", 2: "Medium", 3: "High"}
        print(f"\n⚖️  Loan #{loan_id} Risk Level: {risk_levels.get(risk, 'Unknown')}")
        
        return risk


def demo_basic_workflow():
    """Demonstrate basic protocol workflow"""
    import os
    
    print("=" * 60)
    print("🎬 DeFi Lending Protocol Demo")
    print("=" * 60)
    
    # Configuration
    PROVIDER_URL = os.getenv('PROVIDER_URL', 'http://127.0.0.1:8545')
    PRIVATE_KEY = os.getenv('PRIVATE_KEY')
    CONTRACT_ADDRESS = os.getenv('CONTRACT_ADDRESS')
    ABI_PATH = 'deployments/LendingProtocol_1337.json'
    
    if not PRIVATE_KEY or not CONTRACT_ADDRESS:
        print("\n❌ Please set PROVIDER_URL, PRIVATE_KEY, and CONTRACT_ADDRESS environment variables")
        return
    
    # Initialize interface
    interface = ProtocolInterface(PROVIDER_URL, PRIVATE_KEY, CONTRACT_ADDRESS, ABI_PATH)
    
    # Step 1: Create a loan
    print("\n" + "=" * 60)
    print("Step 1: Create a loan")
    print("=" * 60)
    
    interface.create_loan(
        amount=1000,
        collateral=1500,
        interest_rate=5,
        duration=30
    )
    
    # Step 2: Get loan details
    print("\n" + "=" * 60)
    print("Step 2: Check loan details")
    print("=" * 60)
    
    interface.get_loan_details(loan_id=1)
    
    # Step 3: Calculate interest
    print("\n" + "=" * 60)
    print("Step 3: Calculate interest")
    print("=" * 60)
    
    interface.calculate_interest(loan_id=1)
    
    # Step 4: Assess risk
    print("\n" + "=" * 60)
    print("Step 4: Assess loan risk")
    print("=" * 60)
    
    interface.assess_loan_risk(loan_id=1)
    
    # Step 5: Get protocol stats
    print("\n" + "=" * 60)
    print("Step 5: Protocol statistics")
    print("=" * 60)
    
    interface.get_protocol_stats()
    
    print("\n" + "=" * 60)
    print("✅ Demo completed!")
    print("=" * 60)


if __name__ == '__main__':
    demo_basic_workflow()
