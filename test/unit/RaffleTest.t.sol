// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    Raffle raffle;
    HelperConfig helperConfig;
    uint256 entranceFee;
    uint256 raffleDuration;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address public participant = makeAddr("participant");
    uint256 public constant STARTING_USER_BALANCE = 100 ether;

    /** Events */
    event EnteredRaffle(address indexed participant);
    event PickedWinner(address indexed winner);

    function setUp() external {
        (raffle, helperConfig) = new DeployRaffle().run();
        (
            entranceFee,
            raffleDuration,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            ,

        ) = helperConfig.activeNewtorkConfig();
        vm.deal(participant, STARTING_USER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    // ----------------- enterRaffle ----------------- //
    function testRaffleRevertWhenYouDontPayEnough() public {
        vm.prank(participant);
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.prank(participant);
        raffle.enterRaffle{value: entranceFee}();
        assert(raffle.getNumberOfParticipants() == 1);
        assert(raffle.getParticipantAtIndex(0) == participant);
    }

    function testRaffleBalanceIncreasesWhenParticipantEnters() public {
        uint256 initialBalance = address(raffle).balance;
        vm.prank(participant);
        raffle.enterRaffle{value: entranceFee}();
        uint256 finalBalance = address(raffle).balance;
        assert(finalBalance == initialBalance + entranceFee);
    }

    function testEnteredRaffleEventEmitOnEnter() public {
        vm.prank(participant);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(participant);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterRaffleWhenCalculating() public {
        vm.prank(participant);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + raffleDuration + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(participant);
        raffle.enterRaffle{value: entranceFee}();
    }

    modifier raffleEnteredAndTimePassed() {
        vm.prank(participant);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + raffleDuration + 1);
        vm.roll(block.number + 1);
        _;
    }

    // ----------------- checkUpkeep ----------------- //
    function testCheckUpkeepReturnsFalseWhenItHasNoBalance()
        public
        raffleEnteredAndTimePassed
    {
        vm.deal(address(raffle), 0);
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded == false);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen()
        public
        raffleEnteredAndTimePassed
    {
        raffle.performUpkeep("");
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded == false);
    }

    function testCheckUpkeepReturnsFalseIfDurationHasntPassed() public {
        vm.prank(participant);
        raffle.enterRaffle{value: entranceFee}();
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded == false);
    }

    function testCheckUpkeepReturnsTrueIfAllConditionsAreMet()
        public
        raffleEnteredAndTimePassed
    {
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded == true);
    }

    // ----------------- performUpkeep ----------------- //
    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        uint256 balance = address(raffle).balance;
        uint256 numberOfParticipants = 0;
        uint256 raffleState = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                balance,
                numberOfParticipants,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeepIsExecutedIfCheckupkeepIsTrue()
        public
        raffleEnteredAndTimePassed
    {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        uint256 raffleState = uint256(raffle.getRaffleState());

        assert(requestId > 0);
        assert(raffleState == uint256(Raffle.RaffleState.CALCULATING));
    }

    // ----------------- fulfillRandomWords ----------------- //
    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFullfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEnteredAndTimePassed skipFork {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFullfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEnteredAndTimePassed
        skipFork
    {
        uint256 numberOfAdditionalParticipants = 5;
        uint256 startingIndex = 1;
        for (
            uint256 i = startingIndex;
            i < numberOfAdditionalParticipants + startingIndex;
            i += 1
        ) {
            address newParticipant = address(uint160(i));
            hoax(newParticipant, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        vm.recordLogs();
        // Emit requestId
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // Retrieve requestId from logs
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimeStamp = raffle.getLastTimestamp();

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        assert(raffle.getLastTimestamp() > previousTimeStamp);
        assert(raffle.getNumberOfParticipants() == 0);
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        assert(address(raffle).balance == 0);
        assert(
            raffle.getMostRecentWinner().balance ==
                (STARTING_USER_BALANCE - entranceFee) +
                    entranceFee *
                    (numberOfAdditionalParticipants + 1)
        );
    }
}
