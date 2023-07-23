// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ext/LoanCoordinator.sol";
import {VoteContract} from "./VoteContract.sol";
import {NALToken} from "./NAL.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface OptimisticOracleV3Interface {
    // Struct grouping together the settings related to the escalation manager stored in the assertion.
    struct EscalationManagerSettings {
        bool arbitrateViaEscalationManager; // False if the DVM is used as an oracle (EscalationManager on True).
        bool discardOracle; // False if Oracle result is used for resolving assertion after dispute.
        bool validateDisputers; // True if the EM isDisputeAllowed should be checked on disputes.
        address assertingCaller; // Stores msg.sender when assertion was made.
        address escalationManager; // Address of the escalation manager (zero address if not configured).
    }

    // Struct for storing properties and lifecycle of an assertion.
    struct Assertion {
        EscalationManagerSettings escalationManagerSettings; // Settings related to the escalation manager.
        address asserter; // Address of the asserter.
        uint64 assertionTime; // Time of the assertion.
        bool settled; // True if the request is settled.
        IERC20 currency; // ERC20 token used to pay rewards and fees.
        uint64 expirationTime; // Unix timestamp marking threshold when the assertion can no longer be disputed.
        bool settlementResolution; // Resolution of the assertion (false till resolved).
        bytes32 domainId; // Optional domain that can be used to relate the assertion to others in the escalationManager.
        bytes32 identifier; // UMA DVM identifier to use for price requests in the event of a dispute.
        uint256 bond; // Amount of currency that the asserter has bonded.
        address callbackRecipient; // Address that receives the callback.
        address disputer; // Address of the disputer.
    }

    // Struct for storing cached currency whitelist.
    struct WhitelistedCurrency {
        bool isWhitelisted; // True if the currency is whitelisted.
        uint256 finalFee; // Final fee of the currency.
    }

    /**
     * @notice Returns the default identifier used by the Optimistic Oracle V3.
     * @return The default identifier.
     */
    function defaultIdentifier() external view returns (bytes32);

    /**
     * @notice Fetches information about a specific assertion and returns it.
     * @param assertionId unique identifier for the assertion to fetch information for.
     * @return assertion information about the assertion.
     */
    function getAssertion(bytes32 assertionId) external view returns (Assertion memory);

    /**
     * @notice Asserts a truth about the world, using the default currency and liveness. No callback recipient or
     * escalation manager is enabled. The caller is expected to provide a bond of finalFee/burnedBondPercentage
     * (with burnedBondPercentage set to 50%, the bond is 2x final fee) of the default currency.
     * @dev The caller must approve this contract to spend at least the result of getMinimumBond(defaultCurrency).
     * @param claim the truth claim being asserted. This is an assertion about the world, and is verified by disputers.
     * @param asserter receives bonds back at settlement. This could be msg.sender or
     * any other account that the caller wants to receive the bond at settlement time.
     * @return assertionId unique identifier for this assertion.
     */
    function assertTruthWithDefaults(bytes memory claim, address asserter) external returns (bytes32);

    /**
     * @notice Asserts a truth about the world, using a fully custom configuration.
     * @dev The caller must approve this contract to spend at least bond amount of currency.
     * @param claim the truth claim being asserted. This is an assertion about the world, and is verified by disputers.
     * @param asserter receives bonds back at settlement. This could be msg.sender or
     * any other account that the caller wants to receive the bond at settlement time.
     * @param callbackRecipient if configured, this address will receive a function call assertionResolvedCallback and
     * assertionDisputedCallback at resolution or dispute respectively. Enables dynamic responses to these events. The
     * recipient _must_ implement these callbacks and not revert or the assertion resolution will be blocked.
     * @param escalationManager if configured, this address will control escalation properties of the assertion. This
     * means a) choosing to arbitrate via the UMA DVM, b) choosing to discard assertions on dispute, or choosing to
     * validate disputes. Combining these, the asserter can define their own security properties for the assertion.
     * escalationManager also _must_ implement the same callbacks as callbackRecipient.
     * @param liveness time to wait before the assertion can be resolved. Assertion can be disputed in this time.
     * @param currency bond currency pulled from the caller and held in escrow until the assertion is resolved.
     * @param bond amount of currency to pull from the caller and hold in escrow until the assertion is resolved. This
     * must be >= getMinimumBond(address(currency)).
     * @param identifier UMA DVM identifier to use for price requests in the event of a dispute. Must be pre-approved.
     * @param domainId optional domain that can be used to relate this assertion to others in the escalationManager and
     * can be used by the configured escalationManager to define custom behavior for groups of assertions. This is
     * typically used for "escalation games" by changing bonds or other assertion properties based on the other
     * assertions that have come before. If not needed this value should be 0 to save gas.
     * @return assertionId unique identifier for this assertion.
     */
    function assertTruth(
        bytes memory claim,
        address asserter,
        address callbackRecipient,
        address escalationManager,
        uint64 liveness,
        IERC20 currency,
        uint256 bond,
        bytes32 identifier,
        bytes32 domainId
    ) external returns (bytes32);

    /**
     * @notice Fetches information about a specific identifier & currency from the UMA contracts and stores a local copy
     * of the information within this contract. This is used to save gas when making assertions as we can avoid an
     * external call to the UMA contracts to fetch this.
     * @param identifier identifier to fetch information for and store locally.
     * @param currency currency to fetch information for and store locally.
     */
    function syncUmaParams(bytes32 identifier, address currency) external;

    /**
     * @notice Resolves an assertion. If the assertion has not been disputed, the assertion is resolved as true and the
     * asserter receives the bond. If the assertion has been disputed, the assertion is resolved depending on the oracle
     * result. Based on the result, the asserter or disputer receives the bond. If the assertion was disputed then an
     * amount of the bond is sent to the UMA Store as an oracle fee based on the burnedBondPercentage. The remainder of
     * the bond is returned to the asserter or disputer.
     * @param assertionId unique identifier for the assertion to resolve.
     */
    function settleAssertion(bytes32 assertionId) external;

    /**
     * @notice Settles an assertion and returns the resolution.
     * @param assertionId unique identifier for the assertion to resolve and return the resolution for.
     * @return resolution of the assertion.
     */
    function settleAndGetAssertionResult(bytes32 assertionId) external returns (bool);

    /**
     * @notice Fetches the resolution of a specific assertion and returns it. If the assertion has not been settled then
     * this will revert. If the assertion was disputed and configured to discard the oracle resolution return false.
     * @param assertionId unique identifier for the assertion to fetch the resolution for.
     * @return resolution of the assertion.
     */
    function getAssertionResult(bytes32 assertionId) external view returns (bool);

    /**
     * @notice Returns the minimum bond amount required to make an assertion. This is calculated as the final fee of the
     * currency divided by the burnedBondPercentage. If burn percentage is 50% then the min bond is 2x the final fee.
     * @param currency currency to calculate the minimum bond for.
     * @return minimum bond amount.
     */
    function getMinimumBond(address currency) external view returns (uint256);

    event AssertionMade(
        bytes32 indexed assertionId,
        bytes32 domainId,
        bytes claim,
        address indexed asserter,
        address callbackRecipient,
        address escalationManager,
        address caller,
        uint64 expirationTime,
        IERC20 currency,
        uint256 bond,
        bytes32 indexed identifier
    );

    event AssertionDisputed(bytes32 indexed assertionId, address indexed caller, address indexed disputer);

    event AssertionSettled(
        bytes32 indexed assertionId,
        address indexed bondRecipient,
        bool disputed,
        bool settlementResolution,
        address settleCaller
    );

    event AdminPropertiesSet(IERC20 defaultCurrency, uint64 defaultLiveness, uint256 burnedBondPercentage);
}

// PUSH Comm Contract Interface
interface IPUSHCommInterface {
    function sendNotification(
        address _channel,
        address _recipient,
        bytes calldata _identity
    ) external;
}

contract Loans is Lender, Ownable {
    VoteContract public Vote;
    NALToken public immutable NAL;
    NALToken public immutable NGMI;

    uint256 borrowCap = 1000000 * 1e18;

    mapping(address => bool) public whitelisted;
    mapping(address => uint256) public borrows;

    OptimisticOracleV3Interface oov3 =
        OptimisticOracleV3Interface(0x9923D42eF695B5dd9911D05Ac944d4cAca3c4EAB);
    // keccak of auctionId and timestamp => assertionId
    mapping(bytes32 => bytes32) public umaId;

    constructor(
        LoanCoordinator coord,
        VoteContract _Vote,
        ERC20 _NAL,
        ERC20 _NGMI
    ) Lender(coord) {
        Vote = _Vote;
        NAL = _NAL;
        NGMI = _NGMI;
    }

    struct Auction {
        uint256 id;
        Loan loan;
        uint256 shortfall;
        uint256 timestamp;
    }

    Auction[] public auctions;

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

    function whitelist(address _token, bool _bool) external {
        whitelisted[_token] = _bool;
    }

    function verifyLoan(
        Loan memory loan,
        bytes32 data
    ) external override returns (bool) {
        address token = address(loan.collateralToken);
        require(whitelisted[token], "collateral not wl");
        require(address(loan.debtToken) == address(NAL), "not NAL");
        // require HF
        uint256 epoch = Vote.epoch();
        bytes32 hash = (keccak256(abi.encodePacked(token, epoch - 1)));
        borrows[address(loan.collateralToken)] += loan.debtAmount;
        require(
            borrows[token] <=
                (borrowCap * Vote.votes(hash)) / Vote.totalVotes(epoch),
            "above borrow cap"
        );
        require(loan.interestRate >= borrowAPR(token));
        NAL.mint(loan.borrower, loan.debtAmount);
        return true;
    }

    // apr scales based on the cap utilization
    function borrowAPR(address token) internal view returns (uint256) {
        uint256 epoch = Vote.epoch();
        bytes32 hash = (keccak256(abi.encodePacked(token, epoch - 1)));
        uint256 max = (borrowCap * Vote.votes(hash)) / Vote.totalVotes(epoch);
        uint256 used = borrows[token];
        return (1e6 * used) / max;
    }

    function auctionSettledHook(
        Loan memory loan,
        uint256 lenderReturn,
        uint256 borrowerReturn
    ) external override {
        IPUSHCommInterface(0xb3971BCef2D791bc4027BbfedFb47319A4AAaaAa)
            .sendNotification(
                0x854022C72768AC5605A9cE742D057681f5358ab4, // from channel - recommended to set channel via dApp and put it's value -> then once contract is deployed, go back and add the contract address as delegate for your channel
                loan.borrower,
                bytes(
                    string(
                        abi.encodePacked(
                            "0",
                            "+",
                            "3",
                            "+",
                            "You have been liquidated!",
                            "+",
                            "Your ",
                            loan.collateralToken.symbol(),
                            " has been seized"
                        )
                    )
                )
            );
        address token = address(loan.collateralToken);
        borrows[token] -= loan.debtAmount;
        if (loan.debtAmount > lenderReturn) {
            // slash
            startAuction(loan, loan.debtAmount - lenderReturn);
        }
    }

    function startAuction(Loan memory loan, uint256 _shortfall) internal {
        Auction memory newAuction = Auction(
            auctions.length,
            loan,
            _shortfall,
            block.timestamp
        );
        auctions.push(newAuction);
    }

    function bid(uint256 _auctionId) external {
        Auction memory auction = auctions[_auctionId];
        Loan memory loan = auction.loan;
        address token = address(loan.collateralToken);
        uint256 epoch = Vote.epoch(auction.timestamp);
        uint256 shortfall = auction.shortfall;
        uint256 timepass = block.timestamp - auction.timestamp;
        if (timepass > 1 hours) {
            // shortfall used up
            uint256 shortfallCoverage = Vote.shortfallCoverage(token);
            Vote.coverShortfall(token, shortfallCoverage, epoch);
            NGMI.transfer(msg.sender, shortfallCoverage);
            uint256 amount = (timepass > 2 hours)
                ? 0
                : (2 hours - timepass) * shortfall;
            ERC20(token).transferFrom(msg.sender, address(this), amount);
        } else {
            uint256 shortfallCoverage = Vote.shortfallCoverage(token);
            uint256 amount = (1 hours - timepass) * shortfallCoverage;
            Vote.coverShortfall(token, amount, epoch);
            NGMI.transfer(msg.sender, amount);
            ERC20(token).transferFrom(msg.sender, address(this), shortfall);
        }
    }

    // immediately bid using UMA as resolution source
    function optimisticLiquidate(uint256 _auctionId, uint256 _amount) external {
        // add stuff
        bytes32 assertionId = oov3.assertTruthWithDefaults(bytes(string(
                        abi.encodePacked(
                            "auction id ",
                            _auctionId,
                            " on NAL is liquidatable"
                        )
                    )), address(this));
        umaId[keccak256(abi.encodePacked(_auctionId, block.timestamp))] = assertionId;
    }

    function optimisticLiquidateExecute(uint256 _auctionId, uint256 _timestamp) external {
        require(_timestamp + 1 hours < block.timestamp, "too late");
        bytes32 assertionId = umaId[keccak256(abi.encodePacked(_auctionId, block.timestamp))];
        require(oov3.getAssertionResult(assertionId), "uma failed");
        // do stuff
    }

    function loanRepaidHook(Loan memory loan) external override {
        borrows[address(loan.collateralToken)] -= loan.debtAmount;
        NAL.burn(NAL.balanceOf(address(this)));
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
        return (0, 0, 0);
    }
}
