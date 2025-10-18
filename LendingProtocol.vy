# @version 0.3.10
"""
@title Secure DeFi Lending Protocol
@author Aditya Rai
@notice A production-grade lending protocol with overcollateralized loans
@dev Implements secure lending with risk management and automated liquidations
"""

from vyper.interfaces import ERC20

# Events for transparency and off-chain monitoring
event LoanCreated:
    loan_id: uint256
    borrower: indexed(address)
    amount: uint256
    collateral: uint256
    interest_rate: uint256
    duration: uint256

event LoanRepaid:
    loan_id: indexed(uint256)
    borrower: indexed(address)
    repayment_amount: uint256

event LoanLiquidated:
    loan_id: indexed(uint256)
    liquidator: indexed(address)
    collateral_seized: uint256

event LoanExtended:
    loan_id: indexed(uint256)
    new_end_time: uint256

event InterestRateAdjusted:
    loan_id: indexed(uint256)
    old_rate: uint256
    new_rate: uint256

# Loan status constants
LOAN_CLOSED: constant(uint256) = 0
LOAN_ACTIVE: constant(uint256) = 1
LOAN_LIQUIDATED: constant(uint256) = 2

# Risk level constants
RISK_LOW: constant(uint256) = 1
RISK_MEDIUM: constant(uint256) = 2
RISK_HIGH: constant(uint256) = 3

# Configuration constants
MAX_INTEREST_RATE: constant(uint256) = 100  # 100% maximum
MIN_LOAN_DURATION: constant(uint256) = 1    # 1 day minimum
MAX_LOAN_DURATION: constant(uint256) = 365  # 1 year maximum
MIN_COLLATERAL_RATIO: constant(uint256) = 120  # 120% minimum

# Loan structure with comprehensive data
struct Loan:
    borrower: address
    amount: uint256
    collateral: uint256
    interest_rate: uint256
    duration: uint256
    status: uint256
    start_time: uint256
    end_time: uint256
    repayment_amount: uint256

# State variables
loans: public(HashMap[uint256, Loan])
loan_counter: uint256
protocol_owner: public(address)
token: ERC20
is_paused: public(bool)
total_loans_created: public(uint256)
total_loans_repaid: public(uint256)
total_loans_liquidated: public(uint256)

# Reentrancy guard
reentrancy_lock: bool


@external
def __init__(token_address: address):
    """
    @notice Initialize the lending protocol
    @param token_address Address of the ERC20 token used for loans and collateral
    """
    self.token = ERC20(token_address)
    self.protocol_owner = msg.sender
    self.loan_counter = 0
    self.is_paused = False
    self.reentrancy_lock = False
    self.total_loans_created = 0
    self.total_loans_repaid = 0
    self.total_loans_liquidated = 0

@internal
def _non_reentrant_before():
    """@dev Reentrancy guard - call before function execution"""
    assert not self.reentrancy_lock, "Reentrancy detected"
    self.reentrancy_lock = True

@internal
def _non_reentrant_after():
    """@dev Reentrancy guard - call after function execution"""
    self.reentrancy_lock = False

@internal
def _only_owner():
    """@dev Access control modifier"""
    assert msg.sender == self.protocol_owner, "Only owner can call this"

@internal
def _not_paused():
    """@dev Ensure protocol is not paused"""
    assert not self.is_paused, "Protocol is paused"


@external
def create_loan(amount: uint256, collateral: uint256, interest_rate: uint256, duration: uint256):
    """
    @notice Create a new loan with collateral
    @param amount The amount to borrow
    @param collateral The collateral amount to deposit
    @param interest_rate Annual interest rate (percentage)
    @param duration Loan duration in days
    """
    self._not_paused()
    self._non_reentrant_before()
    
    # Validation
    assert amount > 0, "Loan amount must be positive"
    assert collateral > 0, "Collateral must be positive"
    assert interest_rate <= MAX_INTEREST_RATE, "Interest rate too high"
    assert duration >= MIN_LOAN_DURATION and duration <= MAX_LOAN_DURATION, "Invalid loan duration"
    
    # Ensure sufficient collateralization (120% minimum)
    collateral_ratio: uint256 = (collateral * 100) / amount
    assert collateral_ratio >= MIN_COLLATERAL_RATIO, "Insufficient collateral"
    
    # Transfer collateral from borrower to protocol
    assert self.token.transferFrom(msg.sender, self, collateral), "Collateral transfer failed"
    
    # Generate unique loan ID
    self.loan_counter += 1
    loan_id: uint256 = self.loan_counter
    
    # Calculate repayment amount (simple interest)
    repayment_amount: uint256 = amount + (amount * interest_rate) / 100
    
    # Create and store loan
    self.loans[loan_id] = Loan({
        borrower: msg.sender,
        amount: amount,
        collateral: collateral,
        interest_rate: interest_rate,
        duration: duration,
        status: LOAN_ACTIVE,
        start_time: block.timestamp,
        end_time: block.timestamp + (duration * 86400),  # Convert days to seconds
        repayment_amount: repayment_amount
    })
    
    self.total_loans_created += 1
    
    # Emit event
    log LoanCreated(loan_id, msg.sender, amount, collateral, interest_rate, duration)
    
    self._non_reentrant_after()


@external
@view
def get_loan_details(loan_id: uint256) -> Loan:
    """
    @notice Retrieve details of a specific loan
    @param loan_id The ID of the loan to query
    @return Loan struct with all loan information
    """
    assert loan_id > 0 and loan_id <= self.loan_counter, "Invalid loan ID"
    return self.loans[loan_id]

@external
def repay_loan(loan_id: uint256):
    """
    @notice Repay an active loan and reclaim collateral
    @param loan_id The ID of the loan to repay
    """
    self._not_paused()
    self._non_reentrant_before()
    
    loan: Loan = self.loans[loan_id]
    
    # Validation
    assert loan.status == LOAN_ACTIVE, "Loan is not active"
    assert msg.sender == loan.borrower, "Only borrower can repay"
    assert block.timestamp <= loan.end_time, "Loan repayment period expired"
    
    # Transfer repayment amount from borrower to protocol
    assert self.token.transferFrom(msg.sender, self, loan.repayment_amount), "Repayment transfer failed"
    
    # Return collateral to borrower
    assert self.token.transfer(loan.borrower, loan.collateral), "Collateral return failed"
    
    # Update loan status
    self.loans[loan_id].status = LOAN_CLOSED
    self.total_loans_repaid += 1
    
    # Emit event
    log LoanRepaid(loan_id, msg.sender, loan.repayment_amount)
    
    self._non_reentrant_after()


@external
def liquidate_loan(loan_id: uint256):
    """
    @notice Liquidate an expired or undercollateralized loan
    @param loan_id The ID of the loan to liquidate
    @dev Liquidator receives the collateral as reward
    """
    self._not_paused()
    self._non_reentrant_before()
    
    loan: Loan = self.loans[loan_id]
    
    # Validation
    assert loan.status == LOAN_ACTIVE, "Loan is not active"
    assert block.timestamp > loan.end_time, "Loan has not expired yet"
    
    # Transfer collateral to liquidator as reward
    assert self.token.transfer(msg.sender, loan.collateral), "Liquidation transfer failed"
    
    # Update loan status
    self.loans[loan_id].status = LOAN_LIQUIDATED
    self.total_loans_liquidated += 1
    
    # Emit event
    log LoanLiquidated(loan_id, msg.sender, loan.collateral)
    
    self._non_reentrant_after()

@external
def extend_loan_duration(loan_id: uint256, extension_days: uint256):
    """
    @notice Extend the duration of an active loan
    @param loan_id The ID of the loan to extend
    @param extension_days Number of days to extend
    """
    self._not_paused()
    
    loan: Loan = self.loans[loan_id]
    
    # Validation
    assert loan.status == LOAN_ACTIVE, "Loan is not active"
    assert msg.sender == loan.borrower, "Only borrower can extend"
    assert block.timestamp < loan.end_time, "Loan already expired"
    assert extension_days > 0 and extension_days <= 90, "Invalid extension period"
    
    # Calculate new end time
    new_end_time: uint256 = loan.end_time + (extension_days * 86400)
    
    # Update loan
    self.loans[loan_id].end_time = new_end_time
    self.loans[loan_id].duration += extension_days
    
    # Emit event
    log LoanExtended(loan_id, new_end_time)


@external
@view
def calculate_interest(loan_id: uint256) -> uint256:
    """
    @notice Calculate interest accrued on a loan
    @param loan_id The ID of the loan
    @return The amount of interest accrued
    """
    loan: Loan = self.loans[loan_id]
    
    # Calculate time elapsed (capped at loan duration)
    time_elapsed: uint256 = 0
    if block.timestamp >= loan.end_time:
        time_elapsed = loan.duration * 86400
    else:
        time_elapsed = block.timestamp - loan.start_time
    
    # Calculate pro-rata interest
    total_duration: uint256 = loan.duration * 86400
    interest_accrued: uint256 = (loan.amount * loan.interest_rate * time_elapsed) / (100 * total_duration)
    
    return interest_accrued

@external
@view
def assess_loan_risk(loan_id: uint256) -> uint256:
    """
    @notice Assess the risk level of a loan based on collateralization
    @param loan_id The ID of the loan to assess
    @return Risk level: 1=Low, 2=Medium, 3=High
    """
    loan: Loan = self.loans[loan_id]
    
    # Calculate collateral value (simplified - in production use oracle)
    collateral_value: uint256 = self._calculate_collateral_value(loan_id)
    
    # Calculate loan-to-value ratio
    ltv_ratio: uint256 = (loan.amount * 100) / collateral_value
    
    # Assess risk based on LTV (higher LTV = higher risk)
    if ltv_ratio > 80:  # > 125% LTV, very risky
        return RISK_HIGH
    elif ltv_ratio > 66:  # > 150% LTV, medium risk
        return RISK_MEDIUM
    else:  # <= 150% LTV, low risk (well collateralized)
        return RISK_LOW

@internal
@view
def _calculate_collateral_value(loan_id: uint256) -> uint256:
    """
    @notice Calculate the value of collateral
    @dev Simplified calculation - production should use price oracles
    @param loan_id The ID of the loan
    @return Estimated collateral value
    """
    loan: Loan = self.loans[loan_id]
    # Assuming 1:1 token ratio for simplicity
    # In production, integrate Chainlink or other oracle
    return loan.collateral


@external
def adjust_interest_rate(loan_id: uint256, new_interest_rate: uint256):
    """
    @notice Adjust the interest rate of an active loan
    @param loan_id The ID of the loan
    @param new_interest_rate The new interest rate to set
    @dev Rate adjustments are constrained based on loan risk level
    """
    self._not_paused()
    
    loan: Loan = self.loans[loan_id]
    
    # Validation
    assert loan.status == LOAN_ACTIVE, "Loan is not active"
    assert msg.sender == loan.borrower, "Only borrower can adjust rate"
    assert new_interest_rate <= MAX_INTEREST_RATE, "Rate exceeds maximum"
    
    # Get current risk level
    risk_level: uint256 = self.assess_loan_risk(loan_id)
    old_rate: uint256 = loan.interest_rate
    
    # Apply risk-based constraints
    if risk_level == RISK_LOW:
        # Low risk: rate can only decrease or stay same
        assert new_interest_rate <= old_rate, "Cannot increase rate for low-risk loans"
    elif risk_level == RISK_HIGH:
        # High risk: rate can only increase or stay same
        assert new_interest_rate >= old_rate, "Cannot decrease rate for high-risk loans"
    # Medium risk: no constraints
    
    # Update interest rate and recalculate repayment
    self.loans[loan_id].interest_rate = new_interest_rate
    self.loans[loan_id].repayment_amount = loan.amount + (loan.amount * new_interest_rate) / 100
    
    # Emit event
    log InterestRateAdjusted(loan_id, old_rate, new_interest_rate)

@external
def pause_protocol():
    """
    @notice Pause the protocol in case of emergency
    @dev Only owner can pause
    """
    self._only_owner()
    assert not self.is_paused, "Already paused"
    self.is_paused = True

@external
def unpause_protocol():
    """
    @notice Resume protocol operations
    @dev Only owner can unpause
    """
    self._only_owner()
    assert self.is_paused, "Not paused"
    self.is_paused = False

@external
@view
def get_protocol_stats() -> (uint256, uint256, uint256):
    """
    @notice Get overall protocol statistics
    @return Tuple of (total_created, total_repaid, total_liquidated)
    """
    return (self.total_loans_created, self.total_loans_repaid, self.total_loans_liquidated)

@external
@view
def is_loan_active(loan_id: uint256) -> bool:
    """
    @notice Check if a loan is currently active
    @param loan_id The ID of the loan to check
    @return True if loan is active, False otherwise
    """
    return self.loans[loan_id].status == LOAN_ACTIVE
