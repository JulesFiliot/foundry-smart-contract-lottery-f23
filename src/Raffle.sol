// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title Sample Raffle Contract
 * @author Jules FILIOT
 * @notice This contract is for creating a sample raffle.
 * @dev Implements Chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2 {
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 contractBalance,
        uint256 participantsNumber,
        uint256 raffleState
    );

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    // @dev Duration of the lottery in seconds
    uint256 private immutable i_raffleDuration;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    address payable[] private s_participants;
    address payable private s_mostRecentWinner;
    uint256 private s_lastTimestamp;
    RaffleState private s_raffleState;

    /** Events */
    event EnteredRaffle(address indexed participant);
    event PickedWinner(address indexed winner);
    event RdWordsRequested(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 raffleDuration,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_raffleDuration = raffleDuration;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimestamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_participants.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    /**
     * @dev This function is called by the Chainlink Automation to check if it is time to perform an upkeep.
     * It returns true if the following conditions are satisfied:
     * 1. The time raffle duration has passed since the last upkeep
     * 2. The contract has participants => it has ETH
     * 3. The raffle is open
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = block.timestamp - s_lastTimestamp >=
            i_raffleDuration;
        bool hasParticipants = s_participants.length > 0;
        bool hasBalance = address(this).balance > 0;
        bool raffleIsOpen = s_raffleState == RaffleState.OPEN;
        upkeepNeeded =
            timeHasPassed &&
            hasParticipants &&
            hasBalance &&
            raffleIsOpen;
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool isUpkeepNeeded, ) = checkUpkeep("");
        if (!isUpkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_participants.length,
                uint256(s_raffleState)
            );
        }
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        // this event is redundant but I emit it to learn how to test events
        emit RdWordsRequested(requestId);
    }

    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] memory randomWords
    ) internal override {
        uint256 winnerIndex = randomWords[0] % s_participants.length;
        address payable winner = s_participants[winnerIndex];
        s_mostRecentWinner = winner;
        s_raffleState = RaffleState.OPEN;
        s_participants = new address payable[](0);
        s_lastTimestamp = block.timestamp;
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
        emit PickedWinner(winner);
    }

    /** Getter functions */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getParticipantAtIndex(
        uint256 index
    ) external view returns (address payable) {
        return s_participants[index];
    }

    function getNumberOfParticipants() external view returns (uint256) {
        return s_participants.length;
    }

    function getMostRecentWinner() external view returns (address) {
        return s_mostRecentWinner;
    }

    function getLastTimestamp() external view returns (uint256) {
        return s_lastTimestamp;
    }
}
