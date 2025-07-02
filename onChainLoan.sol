// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract LoanManager {
    address public issuer;

    constructor(address _issuer) {
        issuer = _issuer;
    }

    modifier onlyIssuer() {
        require(msg.sender == issuer, "Not authorized");
        _;
    }

    struct Loan {
        address borrower;
        uint256 amount;
        uint256 issuedAt;
    }

    struct LoanWindow {
        uint256 totalAmount;
        uint256 createdAt;
    }

    // Mappings
    mapping(uint256 => LoanWindow) public loanWindows; // windowId => LoanWindow
    mapping(uint256 => Loan[]) public loansPerWindow;  // windowId => list of Loans

    // Events
    event LoanIssued(uint256 indexed windowId, address indexed borrower, uint256 amount);
    event LoanWindowRepaid(uint256 indexed windowId);

    // Issue a loan under a specific window
    function issueLoan(
        uint256 windowId,
        address borrower,
        uint256 amount
    ) external onlyIssuer {
        // If this is the first time issuing in this window
        if (loanWindows[windowId].createdAt == 0) {
            loanWindows[windowId].createdAt = block.timestamp;
        }

        // Update total in LoanWindow
        loanWindows[windowId].totalAmount += amount;

        // Store individual loan
        loansPerWindow[windowId].push(Loan({
            borrower: borrower,
            amount: amount,
            issuedAt: block.timestamp
        }));

        emit LoanIssued(windowId, borrower, amount);
    }

    // Repay and clean up the loan window and its loans
    function repayLoanWindow(uint256 windowId) external onlyIssuer {
        require(loanWindows[windowId].totalAmount > 0, "Loan window does not exist or already repaid");

        // Delete stored data
        delete loanWindows[windowId];
        delete loansPerWindow[windowId];

        emit LoanWindowRepaid(windowId);
    }

    // Get all loans for a window
    function getLoans(uint256 windowId) external view returns (Loan[] memory) {
        return loansPerWindow[windowId];
    }

    // Get loan window info
    function getLoanWindow(uint256 windowId) external view returns (LoanWindow memory) {
        return loanWindows[windowId];
    }
}
