//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscription(
        address vrfCoordinator,
        uint256 deployerKey
    ) public returns (uint64) {
        console.log("creating subscription on chainid:", block.chainid);
        vm.startBroadcast(deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Created subscription with id:", subId);
        console.log(
            "Please update your subscribtion id inside script/HelperConfig.s.sol"
        );
        return subId;
    }

    function createSubscriptionUsingConfig(
        uint256 deployerKey
    ) public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, , , , , ) = helperConfig
            .activeNewtorkConfig();
        return createSubscription(vrfCoordinator, deployerKey);
    }

    function run(uint256 deployerKey) external returns (uint64) {
        return createSubscriptionUsingConfig(deployerKey);
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscription(
        address vrfCoordinator,
        uint64 subscriptionId,
        address linkContract,
        uint256 deployerKey
    ) public {
        console.log("funding subscription", subscriptionId);
        console.log("On chainid:", block.chainid);
        console.log("Using vrfCoordinator:", vrfCoordinator);
        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subscriptionId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerKey);
            LinkToken(linkContract).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subscriptionId)
            );
            vm.stopBroadcast();
        }
    }

    function fundSubscriptionUsingConfig(uint256 deployerKey) public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subscriptionId,
            ,
            address linkContract,

        ) = helperConfig.activeNewtorkConfig();
        fundSubscription(
            vrfCoordinator,
            subscriptionId,
            linkContract,
            deployerKey
        );
    }

    function run(uint256 deployerKey) external {
        fundSubscriptionUsingConfig(deployerKey);
    }
}

contract AddConsumer is Script {
    function addConsumer(
        address raffle,
        address vrfCoordinator,
        uint64 subscriptionId,
        uint256 deployerKey
    ) public {
        console.log("adding consumer to raffle", raffle);
        console.log("On chainid:", block.chainid);
        console.log("Using vrfCoordinator:", vrfCoordinator);
        console.log("Using subscriptionId:", subscriptionId);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(
            subscriptionId,
            raffle
        );
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subscriptionId,
            ,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNewtorkConfig();
        addConsumer(raffle, vrfCoordinator, subscriptionId, deployerKey);
    }

    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(raffle);
    }
}
