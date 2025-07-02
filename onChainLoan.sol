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
    mapping(address => uint256[]) public borrowerLoanWindows; // borrower => list of windowIds

    // Events
    event LoanIssued(uint256 indexed windowId, address indexed borrower, uint256 amount);
    event LoanWindowRepaid(uint256 indexed windowId);

    // Issue a loan under a specific window
    function issueLoan(
        uint256 windowId,
        address borrower,
        uint256 amount
    ) external onlyIssuer {
        LoanWindow storage window = loanWindows[windowId];

        // If this is the first time issuing in this window
        if (window.createdAt == 0) {
            window.createdAt = block.timestamp;
        }

        // Update total in LoanWindow
        window.totalAmount += amount;

        // Add the loan to the loan array
        loansPerWindow[windowId].push(Loan({
            borrower: borrower,
            amount: amount,
            issuedAt: block.timestamp
        }));

        // Track that this borrower has a loan in this window
        // Only push if this is their first loan in this window
        bool alreadyTracked = false;
        uint256[] storage windows = borrowerLoanWindows[borrower];
        for (uint i = 0; i < windows.length; i++) {
            if (windows[i] == windowId) {
                alreadyTracked = true;
                break;
            }
        }
        if (!alreadyTracked) {
            windows.push(windowId);
        }

        emit LoanIssued(windowId, borrower, amount);
    }

    // Repay and clean up the loan window and its loans
    function repayLoanWindow(uint256 windowId) external onlyIssuer {
        require(loanWindows[windowId].totalAmount > 0, "Loan window does not exist or already repaid");

        // Remove borrower references
        Loan[] storage loans = loansPerWindow[windowId];
        for (uint i = 0; i < loans.length; i++) {
            address borrower = loans[i].borrower;
            uint256[] storage windows = borrowerLoanWindows[borrower];

            // Remove this windowId from borrowerLoanWindows[borrower]
            for (uint j = 0; j < windows.length; j++) {
                if (windows[j] == windowId) {
                    windows[j] = windows[windows.length - 1]; // swap with last
                    windows.pop(); // remove last
                    break;
                }
            }
        }

        // Delete stored data
        delete loanWindows[windowId];
        delete loansPerWindow[windowId];

        emit LoanWindowRepaid(windowId);
    }

    // View functions
    function getLoans(uint256 windowId) external view returns (Loan[] memory) {
        return loansPerWindow[windowId];
    }

    function getLoanWindow(uint256 windowId) external view returns (LoanWindow memory) {
        return loanWindows[windowId];
    }

    function getLoanWindowsByBorrower(address borrower) external view returns (uint256[] memory) {
        return borrowerLoanWindows[borrower];
    }
}
