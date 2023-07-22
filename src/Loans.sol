//
import "./ext/LoanCoordinator.sol";
import {VoteContract} from "./VoteContract.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Loans is Lender, Ownable {

    VoteContract public Vote = VoteContract(0x000000000000000000000000000000000000dEaD);
    ERC20 public constant NAL = ERC20(0x000000000000000000000000000000000000dEaD);

    uint256 borrowCap = 1000000 * 1e18;

    mapping(address => bool) public whitelisted;
    mapping(address => uint256) public borrows;

    constructor(LoanCoordinator coord) Lender(coord) {}
    
    /*
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
}*/

    function verifyLoan(
        Loan memory loan,
        bytes32 data
    ) external override returns (bool) {
        require(whitelisted[address(loan.collateralToken)], "collateral not wl");
        require(address(loan.debtToken) == address(NAL), "not NAL");
        // require HF
        borrows[address(loan.collateralToken)] += loan.debtAmount;
        uint256 epoch = Vote.epoch();
        VoteContract.VoteSegment storage voteSegment = Vote.VoteSegments[epoch][address(loan.collateralToken)];
        require(borrows[loan.collateralToken] <= borrowCap * voteSegment.votes / Vote.totalVotes[epoch], "above borrow cap");
        NAL.mint(loan.borrower, loan.debtAmount);
        return true;
    }

    function borrowAPR() internal returns (bool) {

    }

    function auctionSettledHook(
        Loan memory loan,
        uint256 lenderReturn,
        uint256 borrowerReturn
    ) external override {

    }

    function loanRepaidHook(Loan memory loan) external override {
        NAL.transferFrom(loan.lender, address(this), loan);
        NAL.burn();
    }

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
    ) external view override returns (uint256, uint256, uint256) {
        return (0,0,0);
    } 
}