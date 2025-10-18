# @version 0.3.10

"""
@title Advanced DeFi Lending Protocol with Oracle Integration
@author Aditya Rai
@notice Enterprise-grade lending protocol with price oracles, governance, and flash loan protection
@dev Enhanced version with multi-collateral support and dynamic interest rates
"""

from vyper.interfaces import ERC20

# Interface for Chainlink-style price feed
interface PriceFeed:
    def latestAnswer() -> int128: view

# Events
event LoanCreated:
    loan_id: uint256
    borrower: indexed(address)
    amount: uint256
    collateral: uint256
    collateral_token: indexed(address)
    interest_rate: uint256

event LoanRepaid:
    loan_id: indexed(uint256)
    borrower: indexed(address)
    repayment_amount: uint256
    interest_paid: uint256

event LoanLiquidated:
    loan_id: indexed(uint256)
    liquidator: indexed(address)
    collateral_seized: uint256
    bonus_awarded: uint256

event InterestRateUpdated:
    loan_id: indexed(uint256)
    old_rate: uint256
    new_rate: uint256

event CollateralAdded:
    loan_id: indexed(uint256)
    amount: uint256

event GovernanceProposal:
    proposal_id: uint256
    proposer: indexed(address)
    description: String[256]

event ProposalVoted:
    proposal_id: indexed(uint256)
    voter: indexed(address)
    support: bool

# Constants
LOAN_CLOSED: constant(uint256) = 0
LOAN_ACTIVE: constant(uint256) = 1
LOAN_LIQUIDATED: constant(uint256) = 2

LIQUIDATION_BONUS: constant(uint256) = 10
PROTOCOL_FEE: constant(uint256) = 1
MAX_INTEREST_RATE: constant(uint256) = 50
MIN_COLLATERAL_RATIO: constant(uint256) = 150

OPTIMAL_UTILIZATION: constant(uint256) = 80
BASE_RATE: constant(uint256) = 2
SLOPE_1: constant(uint256) = 4
SLOPE_2: constant(uint256) = 75

PROPOSAL_DURATION: constant(uint256) = 259200

# Enhanced Loan structure
struct Loan:
    borrower: address
    amount: uint256
    collateral: uint256
    collateral_token: address
    interest_rate: uint256
    duration: uint256
    status: uint256
    start_time: uint256
    end_time: uint256
    repayment_amount: uint256
    health_factor: uint256

# Governance proposal structure
struct Proposal:
    proposer: address
    description: String[256]
    votes_for: uint256
    votes_against: uint256
    start_time: uint256
    end_time: uint256
    executed: bool

# State variables
loans: public(HashMap[uint256, Loan])
loan_counter: uint256
protocol_owner: public(address)
lending_token: ERC20
is_paused: public(bool)

supported_collateral: public(HashMap[address, bool])
collateral_price_feeds: HashMap[address, address]

total_loans_created: public(uint256)
total_value_locked: public(uint256)
total_borrowed: public(uint256)
total_fees_collected: public(uint256)

proposals: public(HashMap[uint256, Proposal])
proposal_counter: uint256
voting_power: public(HashMap[address, uint256])
has_voted: HashMap[uint256, HashMap[address, bool]]

flash_loan_guard: HashMap[address, uint256]
reentrancy_lock: bool

@external
def __init__(lending_token_address: address):
    self.lending_token = ERC20(lending_token_address)
    self.protocol_owner = msg.sender
    self.loan_counter = 0
    self.proposal_counter = 0
    self.is_paused = False
    self.reentrancy_lock = False
    self.voting_power[msg.sender] = 10000

@internal
def _non_reentrant_before():
    assert not self.reentrancy_lock, "Reentrancy detected"
    self.reentrancy_lock = True

@internal
def _non_reentrant_after():
    self.reentrancy_lock = False

@internal
def _only_owner():
    assert msg.sender == self.protocol_owner, "Only owner"

@internal
def _not_paused():
    assert not self.is_paused, "Protocol paused"

@internal
def _prevent_flash_loan():
    assert self.flash_loan_guard[msg.sender] != block.number, "Flash loan detected"
    self.flash_loan_guard[msg.sender] = block.number

@external
def add_collateral_token(token_address: address, price_feed: address):
    self._only_owner()
    assert not self.supported_collateral[token_address], "Already supported"
    self.supported_collateral[token_address] = True
    self.collateral_price_feeds[token_address] = price_feed

@external
@view
def get_collateral_price(collateral_token: address) -> uint256:
    price_feed_address: address = self.collateral_price_feeds[collateral_token]
    assert price_feed_address != empty(address), "No price feed"
    price: int128 = PriceFeed(price_feed_address).latestAnswer()
    assert price > 0, "Invalid price"
    return convert(price, uint256)

@external
@view
def calculate_dynamic_interest_rate() -> uint256:
    if self.total_value_locked == 0:
        return BASE_RATE
    utilization: uint256 = (self.total_borrowed * 100) / self.total_value_locked
    if utilization <= OPTIMAL_UTILIZATION:
        rate: uint256 = BASE_RATE + (utilization * SLOPE_1) / 100
        return rate
    else:
        excess: uint256 = utilization - OPTIMAL_UTILIZATION
        rate: uint256 = BASE_RATE + (OPTIMAL_UTILIZATION * SLOPE_1) / 100
        rate += (excess * SLOPE_2) / 100
        return min(rate, MAX_INTEREST_RATE)

@external
def create_loan(amount: uint256, collateral: uint256, collateral_token: address, duration: uint256):
    self._not_paused()
    self._non_reentrant_before()
    self._prevent_flash_loan()
    assert amount > 0 and collateral > 0, "Invalid amounts"
    assert self.supported_collateral[collateral_token], "Collateral not supported"
    assert duration >= 1 and duration <= 365, "Invalid duration"
    collateral_price: uint256 = self.get_collateral_price(collateral_token)
    collateral_value: uint256 = (collateral * collateral_price) / 10**8
    required_collateral: uint256 = (amount * MIN_COLLATERAL_RATIO) / 100
    assert collateral_value >= required_collateral, "Insufficient collateral"
    health_factor: uint256 = (collateral_value * 100) / amount
    interest_rate: uint256 = self.calculate_dynamic_interest_rate()
    collateral_token_contract: ERC20 = ERC20(collateral_token)
    assert collateral_token_contract.transferFrom(msg.sender, self, collateral), "Transfer failed"
    self.loan_counter += 1
    loan_id: uint256 = self.loan_counter
    repayment: uint256 = amount + (amount * interest_rate) / 100
    self.loans[loan_id] = Loan({
        borrower: msg.sender,
        amount: amount,
        collateral: collateral,
        collateral_token: collateral_token,
        interest_rate: interest_rate,
        duration: duration,
        status: LOAN_ACTIVE,
        start_time: block.timestamp,
        end_time: block.timestamp + (duration * 86400),
        repayment_amount: repayment,
        health_factor: health_factor
    })
    self.total_loans_created += 1
    self.total_value_locked += collateral_value
    self.total_borrowed += amount
    log LoanCreated(loan_id, msg.sender, amount, collateral, collateral_token, interest_rate)
    self._non_reentrant_after()

@external
def add_collateral(loan_id: uint256, additional_collateral: uint256):
    self._not_paused()
    self._non_reentrant_before()
    loan: Loan = self.loans[loan_id]
    assert loan.status == LOAN_ACTIVE, "Loan not active"
    assert msg.sender == loan.borrower, "Not borrower"
    collateral_token: ERC20 = ERC20(loan.collateral_token)
    assert collateral_token.transferFrom(msg.sender, self, additional_collateral), "Transfer failed"
    self.loans[loan_id].collateral += additional_collateral
    collateral_price: uint256 = self.get_collateral_price(loan.collateral_token)
    new_collateral_value: uint256 = ((loan.collateral + additional_collateral) * collateral_price) / 10**8
    self.loans[loan_id].health_factor = (new_collateral_value * 100) / loan.amount
    log CollateralAdded(loan_id, additional_collateral)
    self._non_reentrant_after()

@external
def repay_loan(loan_id: uint256):
    self._not_paused()
    self._non_reentrant_before()
    loan: Loan = self.loans[loan_id]
    assert loan.status == LOAN_ACTIVE, "Loan not active"
    assert msg.sender == loan.borrower, "Not borrower"
    assert block.timestamp <= loan.end_time, "Loan expired"
    interest_paid: uint256 = loan.repayment_amount - loan.amount
    protocol_fee: uint256 = (interest_paid * PROTOCOL_FEE) / 100
    assert self.lending_token.transferFrom(msg.sender, self, loan.repayment_amount), "Repayment failed"
    collateral_token: ERC20 = ERC20(loan.collateral_token)
    assert collateral_token.transfer(loan.borrower, loan.collateral), "Collateral return failed"
    self.loans[loan_id].status = LOAN_CLOSED
    self.total_borrowed -= loan.amount
    self.total_fees_collected += protocol_fee
    log LoanRepaid(loan_id, msg.sender, loan.repayment_amount, interest_paid)
    self._non_reentrant_after()

@external
def liquidate_loan(loan_id: uint256):
    self._not_paused()
    self._non_reentrant_before()
    loan: Loan = self.loans[loan_id]
    assert loan.status == LOAN_ACTIVE, "Loan not active"
    is_expired: bool = block.timestamp > loan.end_time
    if not is_expired:
        collateral_price: uint256 = self.get_collateral_price(loan.collateral_token)
        current_value: uint256 = (loan.collateral * collateral_price) / 10**8
        current_health: uint256 = (current_value * 100) / loan.amount
        assert current_health < 120, "Loan is healthy"
    bonus_amount: uint256 = (loan.collateral * LIQUIDATION_BONUS) / 100
    collateral_token: ERC20 = ERC20(loan.collateral_token)
    assert collateral_token.transfer(msg.sender, loan.collateral), "Liquidation failed"
    self.loans[loan_id].status = LOAN_LIQUIDATED
    self.total_borrowed -= loan.amount
    log LoanLiquidated(loan_id, msg.sender, loan.collateral, bonus_amount)
    self._non_reentrant_after()

@external
def create_governance_proposal(description: String[256]):
    assert self.voting_power[msg.sender] >= 100, "Insufficient voting power"
    self.proposal_counter += 1
    proposal_id: uint256 = self.proposal_counter
    self.proposals[proposal_id] = Proposal({
        proposer: msg.sender,
        description: description,
        votes_for: 0,
        votes_against: 0,
        start_time: block.timestamp,
        end_time: block.timestamp + PROPOSAL_DURATION,
        executed: False
    })
    log GovernanceProposal(proposal_id, msg.sender, description)

@external
def vote_on_proposal(proposal_id: uint256, support: bool):
    proposal: Proposal = self.proposals[proposal_id]
    assert block.timestamp <= proposal.end_time, "Voting ended"
    assert not self.has_voted[proposal_id][msg.sender], "Already voted"
    voter_power: uint256 = self.voting_power[msg.sender]
    assert voter_power > 0, "No voting power"
    if support:
        self.proposals[proposal_id].votes_for += voter_power
    else:
        self.proposals[proposal_id].votes_against += voter_power
    self.has_voted[proposal_id][msg.sender] = True
    log ProposalVoted(proposal_id, msg.sender, support)

@external
def pause_protocol():
    self._only_owner()
    self.is_paused = True

@external
def unpause_protocol():
    self._only_owner()
    self.is_paused = False

@external
@view
def get_loan_details(loan_id: uint256) -> Loan:
    return self.loans[loan_id]

@external
@view
def get_protocol_metrics() -> (uint256, uint256, uint256, uint256):
    return (
        self.total_loans_created,
        self.total_value_locked,
        self.total_borrowed,
        self.total_fees_collected
    )
