// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function burnFrom(address account, uint256 amount) external;
}

contract LoanStorage {

    struct Loan {
        uint256 issuanceDate;
        uint256 maturityDate;
        uint256 amount;
        uint256 interestRate; // in basis points, e.g., 500 = 5%
        address borrower;
        bool repaid;
    }

struct LoanWindow {
    uint256 issuanceDate;
    uint256 maturityDate;
    uint256 amount;
    bool repaid;
    // Add fields like interestRate, status, notes, etc. as needed
}

    // branch -> loanWindows -> 
    mapping(address => mapping(uint256 => LoanWindow)) public loans;
    
    
    function issueLoan(
        address branch,
        uint256 windowId,
        uint256 amount,
        uint256 issuanceDate,
        uint256 maturityDate
    ) external onlyIssuer {
        LoanWindow storage lw = loans[branch][windowId];
    
        // If this is the first issuance in this window
        if (lw.amount == 0) {
            lw.issuanceDate = issuanceDate;
            lw.maturityDate = maturityDate;
        }
    
        lw.amount += amount;
    
        emit LoanIssued(branch, windowId, amount, issuanceDate, maturityDate);
    }
    
    function getLoan(address branch, uint256 windowId) external view returns (LoanWindow memory) {
        return loans[branch][windowId];
    }



    IERC20 public principalToken;
    IERC20 public interestToken;

    uint256 private loanCounter;

    mapping(uint256 => Loan) public loans;

    mapping(address => uint256) public principalBalances;
    mapping(address => uint256) public interestBalances;

    event LoanIssued(uint256 loanId, address borrower, uint256 amount, uint256 interestRate, uint256 issuanceDate, uint256 maturityDate);
    event LoanRepaid(uint256 loanId, address borrower, uint256 principalAmount, uint256 interestAmount);

    constructor(address _principalToken, address _interestToken) {
        principalToken = IERC20(_principalToken);
        interestToken = IERC20(_interestToken);
    }

    function issueLoan(address borrower, uint256 amount, uint256 interestRate, uint256 maturityDate) external returns (uint256) {
        require(maturityDate > block.timestamp, "Maturity must be future");
        require(amount > 0, "Amount must be positive");

        loanCounter += 1;
        uint256 loanId = loanCounter;

        loans[loanId] = Loan({
            issuanceDate: block.timestamp,
            maturityDate: maturityDate,
            amount: amount,
            interestRate: interestRate,
            borrower: borrower,
            repaid: false
        });

        principalBalances[borrower] += amount;

        uint256 interestAmount = (amount * interestRate) / 10000;
        interestBalances[borrower] += interestAmount;

        emit LoanIssued(loanId, borrower, amount, interestRate, block.timestamp, maturityDate);

        return loanId;
    }

    function getLoan(uint256 loanId) external view returns (Loan memory) {
        return loans[loanId];
    }

    function repayLoan(uint256 loanId) external {
        Loan storage loan = loans[loanId];
        require(!loan.repaid, "Loan already repaid");
        require(loan.borrower == msg.sender, "Only borrower can repay");

        uint256 principalAmount = loan.amount;
        uint256 interestAmount = (loan.amount * loan.interestRate) / 10000;

        require(principalBalances[msg.sender] >= principalAmount, "Insufficient principal balance");
        require(interestBalances[msg.sender] >= interestAmount, "Insufficient interest balance");

        principalToken.burnFrom(msg.sender, principalAmount);
        interestToken.transferFrom(msg.sender, address(this), interestAmount);

        principalBalances[msg.sender] -= principalAmount;
        interestBalances[msg.sender] -= interestAmount;

        loan.repaid = true;
        emit LoanRepaid(loanId, msg.sender, principalAmount, interestAmount);

        delete loans[loanId];
    }
}
