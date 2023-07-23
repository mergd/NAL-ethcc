pragma solidity ^0.8.17;

import {IAllocatorConduit} from "src/ext/IArrangerConduit.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Loans} from "src/Loans.sol";

contract PSMArranger is IAllocatorConduit {
    address public daiAddress;
    address public NAL;
    Loans public loans;

    constructor(address _dai, address _NAL) {
        daiAddress = _dai;
        NAL = _NAL;
    }

    function setLoan(Loans _loan) external {
        loans = _loan;
    }

    function psm(uint256 amount) external {
        ERC20 dai = ERC20(daiAddress);
        dai.transferFrom(msg.sender, address(this), amount);
        loans.psmSwap(msg.sender, amount);
    }

    /**
     *  @dev   Function for depositing tokens into a Fund Manager.
     *  @param asset  The asset to deposit.
     *  @param amount The amount of tokens to deposit.
     */
    function deposit(bytes32 ilk, address asset, uint256 amount) external {
        require(
            ERC20(asset).transferFrom(msg.sender, address(this), amount),
            "transferFrom failed"
        );
        loans.psmSwap(msg.sender, amount);
        emit Deposit(ilk, asset, msg.sender, amount);
    }

    /**
     *  @dev   Function for withdrawing tokens from a Fund Manager.
     *  @param  ilk         The unique identifier of the ilk.
     *  @param  asset       The asset to withdraw.
     *  @return amount      The amount of tokens withdrawn.
     */
    function withdraw(
        bytes32 ilk,
        address asset,
        uint256
    ) external returns (uint256 amount) {
        amount = ERC20(NAL).balanceOf(msg.sender);
        require(
            ERC20(NAL).transferFrom(msg.sender, address(this), amount),
            "transferFrom failed"
        );
        ERC20(NAL).transfer(address(0), ERC20(NAL).balanceOf(msg.sender));
        emit Withdraw(ilk, asset, msg.sender, amount);
    }

    function maxDeposit(
        bytes32,
        address asset
    ) external view returns (uint256 maxDeposit_) {
        if (asset == daiAddress) {
            return type(uint256).max;
        } else {
            return 0;
        }
    }

    function maxWithdraw(
        bytes32,
        address asset
    ) external view override returns (uint256 maxWithdraw_) {
        if (asset == NAL) {
            return ERC20(NAL).balanceOf(msg.sender);
        } else {
            return 0;
        }
    }
}
