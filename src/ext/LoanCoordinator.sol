// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";

struct Loan {
    uint256 id;
    address borrower;
    address lender;
    ERC20 collateralToken;
    ERC20 debtToken;
    uint256 collateralAmount;
    uint256 debtAmount;
    uint256 interestRate;
    uint256 startingTime;
    uint256 duration;
    uint256 terms;
}

struct Terms {
    uint256 liquidationBonus;
    uint256 dutchAuctionMultiplier;
    uint256 settlementMultiplier;
    uint256 auctionLength;
}

struct Auction {
    uint256 id;
    uint256 loanId;
    uint256 duration;
    uint256 startingPrice;
    uint256 startingTime;
    uint256 endingPrice;
}

uint256 constant SCALAR = 1e6;

// Use the autocompounding or simple interest, above is the autocompounding
// Calculate notional accrued interest
function calculateInterest(
    uint256 _interestRate,
    uint256 _debtAmount,
    uint256 _startTime,
    uint256 _endTime
) pure returns (uint256 interest) {
    uint256 timeElapsed = _endTime - _startTime;
    interest =
        (_interestRate * _debtAmount * timeElapsed) /
        (365 days * SCALAR);
}

abstract contract Lender {
    constructor(LoanCoordinator _coordinator) {
        coordinator = _coordinator;
    }

    LoanCoordinator public immutable coordinator;

    function verifyLoan(
        Loan memory loan,
        bytes32 data
    ) external virtual returns (bool);

    function auctionSettledHook(
        Loan memory loan,
        uint256 lenderReturn,
        uint256 borrowerReturn
    ) external virtual;

    function loanRepaidHook(Loan memory loan) external virtual;

    /**
     * @dev Could be optimized
     * @param loan Pass in a loan struct.
     *      loan.debtAmount == Max Uint -> Max borrowable
     *      loan.collateralAmount == Max Uint -> Min Collateral required
     * @return _interest Provide the interest rate for given params
     * @return _lendAmount Provide the amount that can be borrowed
     * @return _collateral Provide the amount of collateral required
     */
    function getQuote(
        Loan memory loan
    ) external view virtual returns (uint256, uint256, uint256);
}

// Optional interface for borrowers to implement
abstract contract Borrower {
    constructor(LoanCoordinator _coordinator) {
        coordinator = _coordinator;
    }

    LoanCoordinator public immutable coordinator;

    function liquidationHook(Loan memory loan) external virtual;

    function auctionSettledHook(
        Loan memory loan,
        uint256 lenderReturn,
        uint256 borrowerReturn
    ) external virtual;
}

contract LoanCoordinator {
    using SafeTransferLib for ERC20;

    uint256 public loanCount;

    uint256[] public durations = [8 hours, 1 days, 2 days, 7 days, 0];

    Auction[] public auctions;
    Terms[] public loanTerms;
    mapping(uint256 => uint256) public loanIdToAuction;
    mapping(uint256 => Loan) public loans;
    mapping(address => uint256[]) public borrowerLoans;
    mapping(address => uint256[]) public lenderLoans;

    event LoanRepaid(
        uint256 indexed id,
        address indexed borrower,
        address indexed lender,
        uint256 amount
    );
    event LoanCreated(
        uint256 indexed id,
        address indexed borrower,
        address indexed lender,
        ERC20 collateralToken,
        ERC20 debtToken,
        uint256 collateralAmount,
        uint256 debtAmount,
        uint256 interestRate,
        uint256 startingTime,
        uint256 duration,
        uint256 terms
    );

    event AuctionCreated(
        uint256 indexed id,
        uint256 indexed loanId,
        uint256 duration,
        uint256 startingPrice,
        uint256 startingTime,
        uint256 endingPrice
    );
    event AuctionSettled(
        uint256 indexed auction,
        address bidder,
        uint256 price
    );
    event AuctionReclaimed(uint256 indexed loanId, uint256 amount);

    event TermsSet(uint256 termId, Terms term);

    constructor() {}

    function createLoan(
        address _lender,
        ERC20 _collateral,
        ERC20 _debt,
        uint256 _collateralAmount,
        uint256 _debtAmount,
        uint256 _interestRate,
        uint256 _duration,
        uint256 _terms
    ) external {
        createLoan(
            _lender,
            msg.sender,
            _collateral,
            _debt,
            _collateralAmount,
            _debtAmount,
            _interestRate,
            _duration,
            _terms,
            ""
        );
    }

    /**
     * @dev User initiates the loan
     * @param _lender Lender contract
     * @param _borrower Borrower address
     * @param _collateral ERC20 Collateral
     * @param _debt ERC20 debt token
     * @param _collateralAmount the amount of collateral, denominated in _collateral
     * @param _debtAmount the amount of debt denominated in _debt
     * @param _interestRate the APR on the loan, scaled by SCALAR (noncompounding)
     * @param _duration the duration of the loan a selection of one of the durations array
     * @param _terms terms of the loan
     * @param _data data to be passed to the lender contract
     */
    function createLoan(
        address _lender,
        address _borrower,
        ERC20 _collateral,
        ERC20 _debt,
        uint256 _collateralAmount,
        uint256 _debtAmount,
        uint256 _interestRate,
        uint256 _duration,
        uint256 _terms,
        bytes32 _data
    ) public {
        loanCount++;
        Loan memory newLoan = Loan(
            loanCount,
            _borrower,
            _lender,
            _collateral,
            _debt,
            _collateralAmount,
            _debtAmount,
            _interestRate,
            block.timestamp,
            durations[_duration],
            _terms
        );

        loans[loanCount] = newLoan;

        // Lender Hook to verify loan details
        require(
            Lender(_lender).verifyLoan(newLoan, _data),
            "Loan not verified"
        );
        _collateral.safeTransferFrom(
            msg.sender,
            address(this),
            _collateralAmount
        );
        _debt.safeTransferFrom(_lender, address(this), _debtAmount);
        _debt.safeTransfer(msg.sender, _debtAmount);

        borrowerLoans[msg.sender].push(loanCount);
        lenderLoans[_lender].push(loanCount);
    }

    function liquidateLoan(uint256 _loanId) external {
        Loan storage loan = loans[_loanId];
        require(loan.lender == msg.sender, "Only lender can liquidate");
        if (
            loan.duration + loan.startingTime > block.timestamp ||
            loan.duration == 0
        ) {
            revert("Loan not yet liquidatable");
        }
        uint256 interest = calculateInterest(
            loan.interestRate,
            loan.debtAmount,
            loan.startingTime,
            block.timestamp
        );
        uint256 totalDebt = loan.debtAmount + interest;
        startAuction(_loanId, totalDebt, interest, loan.terms);

        loan.duration = 0; // Auction off loan

        // Borrower Hook
        if (isContract(loan.borrower)) {
            try Borrower(loan.borrower).liquidationHook(loan) {} catch {}
        }
    }

    function repayLoan(uint256 _loanId) external {
        repayLoan(_loanId, msg.sender);
    }

    function repayLoan(uint256 _loanId, address onBehalfof) public {
        Loan memory loan = loans[_loanId];
        uint256 interest = calculateInterest(
            loan.interestRate,
            loan.debtAmount,
            loan.startingTime,
            block.timestamp
        );
        uint256 totalDebt = loan.debtAmount + interest;
        loan.debtToken.safeTransferFrom(onBehalfof, loan.lender, totalDebt);
        emit LoanRepaid(_loanId, loan.borrower, loan.lender, totalDebt);

        // Prevent lender hook from reverting
        try Lender(loan.lender).loanRepaidHook(loan) {} catch {}

        if (loan.duration == 0) delete auctions[loanIdToAuction[_loanId]];
    }

    // AUCTION LOGIC

    function startAuction(
        uint256 _loanId,
        uint256 _amount,
        uint256 _interestRate,
        uint256 _terms
    ) internal {
        Terms memory terms = loanTerms[_terms];
        uint256 startPrice = ((_amount + _interestRate) *
            terms.dutchAuctionMultiplier) / SCALAR;
        uint256 endPrice = (_amount * _interestRate) /
            (terms.settlementMultiplier * SCALAR);
        Auction memory newAuction = Auction(
            auctions.length,
            _loanId,
            terms.auctionLength,
            startPrice,
            block.timestamp,
            endPrice
        );
        auctions.push(newAuction);
    }

    function bid(uint256 _auctionId) external {
        Auction memory auction = auctions[_auctionId];
        Loan memory loan = loans[auction.loanId];
        Terms memory terms = loanTerms[loan.terms];
        require(
            auction.startingTime + auction.duration > block.timestamp,
            "Auction has ended"
        );
        uint256 currentPrice = getCurrentPrice(_auctionId);
        loan.debtToken.safeTransferFrom(
            msg.sender,
            address(this),
            currentPrice
        );
        loan.collateralToken.safeTransfer(msg.sender, loan.collateralAmount);

        uint256 interest = calculateInterest(
            loan.interestRate,
            loan.debtAmount,
            loan.startingTime,
            block.timestamp
        );
        uint256 _lenderClearing = ((loan.debtAmount + interest) *
            terms.liquidationBonus) / SCALAR;

        uint256 lenderReturn = (_lenderClearing > currentPrice)
            ? currentPrice
            : _lenderClearing;
        uint256 borrowerReturn = currentPrice - lenderReturn;

        loan.debtToken.safeTransfer(loan.lender, lenderReturn);

        // Prevent lender hook from reverting
        try
            Lender(loan.lender).auctionSettledHook(
                loan,
                lenderReturn,
                borrowerReturn
            )
        {} catch {}

        // Borrower Hook
        if (isContract(loan.borrower)) {
            try
                Borrower(loan.borrower).auctionSettledHook(
                    loan,
                    lenderReturn,
                    borrowerReturn
                )
            {} catch {}
        }

        if (borrowerReturn > 0) {
            loan.debtToken.safeTransfer(loan.borrower, borrowerReturn);
        }
        emit AuctionSettled(_auctionId, msg.sender, currentPrice);
    }

    function reclaim(uint256 _auctionId) external {
        // reclaim collateral is auction is lapsed
        Auction memory auction = auctions[_auctionId];
        require(
            auction.startingTime + auction.duration < block.timestamp,
            "Auction has not ended"
        );
        require(
            auction.endingPrice == auction.startingPrice,
            "Auction has not ended"
        );
        Loan memory loan = loans[auction.loanId];
        loan.collateralToken.safeTransfer(loan.lender, loan.collateralAmount);

        delete auctions[_auctionId];
        delete loanIdToAuction[auction.loanId];

        emit AuctionReclaimed(_auctionId, loan.collateralAmount);
    }

    function getCurrentPrice(uint256 _auctionId) public view returns (uint256) {
        Auction memory auction = auctions[_auctionId];
        uint256 startPrice = auction.startingPrice;
        uint256 endPrice = auction.endingPrice;
        uint256 startTime = auction.startingTime;
        uint256 duration = auction.duration;
        if (block.timestamp >= startTime + duration) {
            return endPrice;
        } else {
            uint256 elapsed = block.timestamp - startTime;
            uint256 remaining = duration - elapsed;
            return startPrice - ((startPrice - endPrice) * elapsed) / remaining;
        }
    }

    function setTerms(Terms memory _terms) external returns (uint256) {
        loanTerms.push(_terms);
        emit TermsSet(loanTerms.length - 1, _terms);
        return loanTerms.length - 1;
    }

    // VIEW FUNCTIONS

    function getLoan(uint256 _loanId) external view returns (Loan memory loan) {
        loan = loans[_loanId];

        // Account for pending interest for this loan
        loan.debtAmount += calculateInterest(
            loan.interestRate,
            loan.debtAmount,
            loan.startingTime,
            block.timestamp
        );
    }

    function getBorrowerLoans(
        address _borrower
    ) external view returns (uint256[] memory) {
        return borrowerLoans[_borrower];
    }

    function getLenderLoans(
        address _lender
    ) external view returns (uint256[] memory) {
        return lenderLoans[_lender];
    }

    function isContract(address _addr) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }
}
