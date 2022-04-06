// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @custom:security-contact info@3air.io
contract Vesting is Ownable {

    using SafeERC20 for IERC20;

    event TermAdded(address indexed userAddress, uint256 indexed vestingType, uint256 vestedAmount);
    event TokensClaimed(address indexed userAddress, uint256 indexed termId, uint256 tokenAmount);

    enum VestingType {
        SEED_SALE,
        PRIVATE_VESTING_1,
        PRIVATE_VESTING_2,
        PRIVATE_VESTING_3,
        PRIVATE_VESTING_4,
        PUBLIC_VESTING_1,
        PUBLIC_VESTING_2,
        PUBLIC_VESTING_3,
        LAUNCHPAD,
        FARMING_STAKING,
        AIRDROPS_1,
        AIRDROPS_2,
        TEAM,
        MARKETING,
        ADVISORS,
        ECOSYSTEM
    }

    struct VestingTerm {
        VestingType vestingType;
        uint256 initiallyClaimable;
        uint256 vestedAmount;
        bool initialTokensClaimed;
        uint256 tokensClaimed;
        uint256 creationTime;
        uint256 vestingStart;
        uint256 vestingEnd;
    }

    struct NewVestingTerm {
        VestingType vestingType;
        uint256 vestedAmount;
        uint256 creationTime;
        address userAddress;
    }

    mapping(address => mapping(uint256 => VestingTerm)) public vestingTerms;
    mapping(address => uint256) public totalVestingTerms;

    uint256 totalAmountVested;

    IERC20 public AIR;

    constructor(IERC20 _AIR) {
        AIR = _AIR;
        totalAmountVested = 0;
    }

    function getActiveTerms(address userAddress) public view returns (VestingTerm[] memory terms) {

        terms = new VestingTerm[](totalVestingTerms[userAddress]);
        for (uint256 x = 0; x < totalVestingTerms[userAddress]; x++) {
            terms[x] = vestingTerms[userAddress][x];
        }

        return terms;
    }

    function claimTokens(uint256 termId) public {

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

        AIR.transfer(msg.sender, totalTokens);

        emit TokensClaimed(msg.sender, termId, totalTokens);
    }

    function claimableTokensForTerm(address userAddress, uint256 termId) public view returns (uint256 totalTokens, uint256 initialTokens, uint256 releasableTokens) {

        require(termId < totalVestingTerms[msg.sender], "Term does not exist");

        VestingTerm memory term = vestingTerms[userAddress][termId];

        initialTokens = 0;
        if (!term.initialTokensClaimed) {
            initialTokens = term.initiallyClaimable;
        }

        releasableTokens = 0;
        if (block.timestamp > term.vestingEnd) {

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

    function addVestingTerm(NewVestingTerm calldata newTerm) public onlyOwner {
        _addVestingTerm(newTerm);
    }

    function addVestingTerms(NewVestingTerm[] calldata newTerms) public onlyOwner {

        for (uint256 x = 0; x < newTerms.length; x++) {
            _addVestingTerm(newTerms[x]);
        }
    }

    function _addVestingTerm(NewVestingTerm calldata newTerm) internal {

        require(totalAmountVested + newTerm.vestedAmount <= AIR.balanceOf(address(this)), "Smart contract doesn't have enough tokens to cover new term");
        totalAmountVested += newTerm.vestedAmount;

        uint256 startDelay;
        uint256 vestingPeriod;
        uint256 initiallyReleasedPercentage;

        (startDelay, vestingPeriod, initiallyReleasedPercentage) = getVestingDataByType(newTerm.vestingType);

        uint256 initiallyClaimable = newTerm.vestedAmount * initiallyReleasedPercentage / 100;
        uint256 vestedTokens = newTerm.vestedAmount - initiallyClaimable;

        uint256 creationTime = newTerm.creationTime;
        if (block.timestamp > newTerm.creationTime) {
            creationTime = block.timestamp;
        }

        uint256 newTermId = totalVestingTerms[newTerm.userAddress];
        totalVestingTerms[newTerm.userAddress]++;

        vestingTerms[newTerm.userAddress][newTermId] = VestingTerm(
            newTerm.vestingType,
            initiallyClaimable,
            vestedTokens,
            false,
            0,
            creationTime,
            creationTime + startDelay,
            creationTime + startDelay + vestingPeriod
        );

        emit TermAdded(newTerm.userAddress, uint256(newTerm.vestingType), newTerm.vestedAmount);
    }

    function getVestingDataByType(VestingType vestingType) public pure returns (uint256 vestingStartDelay, uint256 vestingPeriod, uint256 initiallyReleasedPercentage) {

        if (vestingType == VestingType.SEED_SALE) {

            //6 months cliff, then continuously for 18 months
            return (183 days, 548 days, 0);
        } else if (vestingType == VestingType.PRIVATE_VESTING_1) {

            //6 months cliff, then continuously for 18 months
            return (183 days, 548 days, 0);
        } else if (vestingType == VestingType.PRIVATE_VESTING_2) {

            //20% on TGE, 1 month cliff then continuously for 12 months
            return (30 days, 365 days, 20);
        } else if (vestingType == VestingType.PRIVATE_VESTING_3) {

            //continuously for 18 months
            return (0, 548 days, 0);
        } else if (vestingType == VestingType.PRIVATE_VESTING_4) {

            //5% on TGE, 1 month cliff then continuously for 12 months
            return (30 days, 365 days, 5);
        } else if (vestingType == VestingType.PUBLIC_VESTING_1) {

            //20% on TGE, 1 month cliff then continuously for 4 months
            return (30 days, 123 days, 20);
        } else if (vestingType == VestingType.PUBLIC_VESTING_2) {

            //continuously for 18 months
            return (0, 548 days, 0);
        } else if (vestingType == VestingType.PUBLIC_VESTING_3) {

            //6 months cliff, then continuously for 18 months
            return (183 days, 548 days, 0);
        } else if (vestingType == VestingType.LAUNCHPAD) {

            //10% on TGE, 1 month cliff then continuously for 12 months
            return (30 days, 365 days, 10);
        } else if (vestingType == VestingType.FARMING_STAKING) {

            //2,5% per month starting 3 months after TGE
            return (91 days, 1217 days, 0);
        } else if (vestingType == VestingType.AIRDROPS_1) {

            //Release all immediately
            return (0, 1, 0);
        } else if (vestingType == VestingType.AIRDROPS_2) {

            //continuously for 18 months
            return (0, 548 days, 0);
        } else if (vestingType == VestingType.TEAM) {

            //linear for 12 months starting 12 months after TGE
            return (365 days, 365 days, 0);
        } else if (vestingType == VestingType.MARKETING) {

            //5% per month starting 5 months after TGE
            return (153 days, 609 days, 5);
        } else if (vestingType == VestingType.ADVISORS) {

            //continuously for 12 months starting 10 months after TGE
            return (306 days, 365 days, 0);
        } else if (vestingType == VestingType.ECOSYSTEM) {

            //4% per month continuously, starting 1 month after TGE
            return (30 days, 760 days, 0);
        } else {
            revert("UNKNOWN VESTING TYPE");
        }
    }
}
