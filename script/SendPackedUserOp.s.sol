// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;

    function run() public {}

    function generateSignedUserOperation(
        bytes memory callData,
        HelperConfig.NetworkConfig memory config
    ) public view returns (PackedUserOperation memory) {
        //1. Generate the unsigned data
        uint256 nounce = vm.getNonce(config.account);
        PackedUserOperation memory userOp = _generateSignedUserOperation(
            callData,
            config.account,
            nounce
        );
        //2.Get the userOp hash
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(
            userOp
        );
        bytes32 digest = userOpHash.toEthSignedMessageHash(); // this is now the CORRECTLY formatted hash
        //3 Sign it.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(config.account, digest); //here usually the private key goes, and the hash, however this current config.account is unlocked , foundry has its private key unlocked
        userOp.signature = abi.encodePacked(r, s, v); // note the order

        return userOp;
    }

    function _generateSignedUserOperation(
        bytes memory callData,
        address sender,
        uint256 nounce
    ) internal pure returns (PackedUserOperation memory) {
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;
        return
            PackedUserOperation({
                sender: sender,
                nonce: nounce,
                initCode: hex"",
                callData: callData,
                accountGasLimits: bytes32(
                    (uint256(verificationGasLimit) << 128) | callGasLimit
                ),
                preVerificationGas: verificationGasLimit,
                gasFees: bytes32(
                    (uint256(maxPriorityFeePerGas) << 128) | maxFeePerGas
                ),
                paymasterAndData: hex"",
                signature: hex""
            });
    }
}
