// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IAutomaticStaking.sol";

/// @custom:security-contact info@3air.io
contract Vesting is Ownable {

    using SafeERC20 for IERC20;

    event TermAdded(address indexed userAddress, VestingType indexed vestingType, uint256 vestedAmount);
    event TokensClaimed(address indexed userAddress, uint256 indexed termId, bool indexed automaticallyStake, uint256 tokenAmount);

    enum VestingType {
        VESTING_0,
        VESTING_1,
        VESTING_2,
        VESTING_3,
        VESTING_4,
        VESTING_5,
        VESTING_6,
        VESTING_7,
        VESTING_8,
        VESTING_9,
        VESTING_10
    }

    struct VestingTerm {
        uint256 initiallyClaimable;
        uint256 vestedAmount;
        uint256 tokensClaimed;
        uint256 creationTime;
        uint256 vestingStart;
        uint256 vestingEnd;
        VestingType vestingType;
        bool initialTokensClaimed;
    }

    struct NewVestingTerm {
        VestingType vestingType;
        uint256 vestedAmount;
        uint256 creationTime;
        address userAddress;
    }

    mapping(address => mapping(uint256 => VestingTerm)) public vestingTerms;
    mapping(address => uint256) public totalVestingTerms;

    uint256 public totalAmountVested;
    bool public claimEnabled;

    IAutomaticStaking public stakingContract;

    IERC20 public AIR;

    constructor(IERC20 _AIR) {
        AIR = _AIR;
        totalAmountVested = 0;
        claimEnabled = false;
    }

    function getActiveTerms(address userAddress) public view returns (VestingTerm[] memory terms) {

        terms = new VestingTerm[](totalVestingTerms[userAddress]);
        for (uint256 x = 0; x < totalVestingTerms[userAddress]; x++) {
            terms[x] = vestingTerms[userAddress][x];
        }

        return terms;
    }

    function claimTokens(uint256 termId, bool automaticallyStake) external {

        require(claimEnabled, "Claiming disabled");

        require(termId < totalVestingTerms[msg.sender], "Term does not exist");

        uint256 totalTokens;
        uint256 initialTokens;
        uint256 releasableTokens;

        (totalTokens, initialTokens, releasableTokens) = claimableTokensForTerm(msg.sender, termId);

        if (initialTokens > 0) {
            vestingTerms[msg.sender][termId].initialTokensClaimed = true;
        }

        vestingTerms[msg.sender][termId].tokensClaimed += releasableTokens;
        totalAmountVested -= totalTokens;

        if (!automaticallyStake) {
            AIR.safeTransfer(msg.sender, totalTokens);
        } else {

            require(address(stakingContract) != address(0), "Staking contract not available");

            uint256 initialBalance = AIR.balanceOf(address(this));

            AIR.approve(address(stakingContract), totalTokens);
            stakingContract.stakeForAddress(msg.sender, totalTokens);

            uint256 finalBalance = AIR.balanceOf(address(this));
            require(initialBalance - finalBalance == totalTokens, "Staking contract error");
        }

        emit TokensClaimed(msg.sender, termId, automaticallyStake, totalTokens);
    }

    function claimableTokensForTerm(address userAddress, uint256 termId) public view returns (uint256 totalTokens, uint256 initialTokens, uint256 releasableTokens) {

        require(termId < totalVestingTerms[msg.sender], "Term does not exist");

        VestingTerm memory term = vestingTerms[userAddress][termId];

        if (block.timestamp < term.creationTime) {
            return (0, 0, 0);
        }

        initialTokens = 0;
        if (!term.initialTokensClaimed) {
            initialTokens = term.initiallyClaimable;
        }

        releasableTokens = 0;
        if (block.timestamp >= term.vestingEnd) {

            releasableTokens = term.vestedAmount - term.tokensClaimed;

        } else if (block.timestamp > term.vestingStart) {

            uint256 vestingPeriod = term.vestingEnd - term.vestingStart;
            uint256 passedTime = block.timestamp - term.vestingStart;
            uint256 releasableVestingTokens = term.vestedAmount * passedTime / vestingPeriod;
            releasableTokens = releasableVestingTokens - term.tokensClaimed;

        }

        totalTokens = initialTokens + releasableTokens;

        return (totalTokens, initialTokens, releasableTokens);
    }

    function addVestingTerm(NewVestingTerm calldata newTerm) external onlyOwner {
        _addVestingTerm(newTerm);
    }

    function addVestingTerms(NewVestingTerm[] calldata newTerms) external onlyOwner {

        for (uint256 x = 0; x < newTerms.length; x++) {
            _addVestingTerm(newTerms[x]);
        }
    }

    function _addVestingTerm(NewVestingTerm calldata newTerm) internal {

        require(totalAmountVested + newTerm.vestedAmount <= AIR.balanceOf(address(this)), "Smart contract doesn't have enough tokens to cover new term");
        totalAmountVested += newTerm.vestedAmount;

        (uint256 startDelay, uint256 vestingPeriod, uint256 initiallyReleasedPercentage) = getVestingDataByType(newTerm.vestingType);

        uint256 initiallyClaimable = newTerm.vestedAmount * initiallyReleasedPercentage / 100;
        uint256 vestedTokens = newTerm.vestedAmount - initiallyClaimable;

        uint256 creationTime = newTerm.creationTime;
        if (block.timestamp > newTerm.creationTime) {
            creationTime = block.timestamp;
        }

        uint256 newTermId = totalVestingTerms[newTerm.userAddress];
        totalVestingTerms[newTerm.userAddress]++;

        vestingTerms[newTerm.userAddress][newTermId] = VestingTerm(
            initiallyClaimable,
            vestedTokens,
            0,
            creationTime,
            creationTime + startDelay,
            creationTime + startDelay + vestingPeriod,
            newTerm.vestingType,
            false
        );

        emit TermAdded(newTerm.userAddress, newTerm.vestingType, newTerm.vestedAmount);
    }

    function getVestingDataByType(VestingType vestingType) public pure returns (uint256 vestingStartDelay, uint256 vestingPeriod, uint256 initiallyReleasedPercentage) {

        if (vestingType == VestingType.VESTING_0) {

            //Release all immediately
            return (0, 1, 100);
        } else if (vestingType == VestingType.VESTING_1) {

            //20% on TGE, 1 month cliff, then continuously for 6 months
            return (30 days, 182 days, 20);
        } else if (vestingType == VestingType.VESTING_2) {

            //20% on TGE, 1 month cliff, then continuously for 4 months
            return (30 days, 122 days, 20);
        } else if (vestingType == VestingType.VESTING_3) {

            //5% on TGE, 1 month cliff, then continuously for 12 months
            return (30 days, 365 days, 5);
        } else if (vestingType == VestingType.VESTING_4) {

            //continuously for 18 months
            return (0, 547 days, 0);
        } else if (vestingType == VestingType.VESTING_5) {

            //6 months cliff, then continuously for 18 months
            return (182 days, 547 days, 0);
        } else if (vestingType == VestingType.VESTING_6) {

            //10 months cliff, then continuously for 12 months
            return (305 days, 365 days, 0);
        } else if (vestingType == VestingType.VESTING_7) {

            //12 months cliff, then continuously for 12 months
            return (365 days, 365 days, 0);
        } else if (vestingType == VestingType.VESTING_8) {

            //5 months cliff, then continuously for 20 months
            return (152 days, 609 days, 0);
        } else if (vestingType == VestingType.VESTING_9) {

            //1 month cliff, then continuously for 25 months
            return (30 days, 760 days, 0);
        } else if (vestingType == VestingType.VESTING_10) {

            //1 month cliff, then continuously for 40 months
            return (30 days, 1217 days, 0);
        } else {
            revert("UNKNOWN VESTING TYPE");
        }
    }

    function enableVesting() external onlyOwner {
        claimEnabled = true;
    }

    function disableVesting() external onlyOwner {
        claimEnabled = false;
    }

    function setStakingContract(address stakingContractAddress) external onlyOwner {
        stakingContract = IAutomaticStaking(stakingContractAddress);
    }
}
