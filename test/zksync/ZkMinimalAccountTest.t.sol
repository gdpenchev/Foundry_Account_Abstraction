// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ZkMinimalAccount} from "src/zksync/ZkMinimalAccount.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Era Imports
import {Transaction, MemoryTransactionHelper} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {BOOTLOADER_FORMAL_ADDRESS} from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {ACCOUNT_VALIDATION_SUCCESS_MAGIC} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";

// OZ Imports
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// Foundry Devops
import {ZkSyncChainChecker} from "lib/foundry-devops/src/ZkSyncChainChecker.sol";

    

contract ZkMinimalAccountTest is Test, ZkSyncChainChecker {
    using MessageHashUtils for bytes32;

    ZkMinimalAccount zkMinimalAccount;
    ERC20Mock usdc;
    bytes32 constant EMPTY_BYTES32 = bytes32(0);
    uint256 constant AMOUNT = 1e18;
    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function setUp() public {
        zkMinimalAccount = new ZkMinimalAccount();
        zkMinimalAccount.transferOwnership(ANVIL_DEFAULT_ACCOUNT);
        usdc = new ERC20Mock();
        vm.deal(address(zkMinimalAccount),AMOUNT);
    }

    function testZkOwnerCanExecuteCommands() {
        //Arrange
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(zkMinimalAccount), AMOUNT);

        Transaction memory tranaction = createUnsignedTransaction(zkMinimalAccount.owner(),113,dest,value,functionData);

        //Act
        vm.prank(zkMinimalAccount.owner());
        zkMinimalAccount.executeTransaction(EMPTY_BYTES32,EMPTY_BYTES32,tranaction); // we are calling mint function from the ERC20MOCK (see functionData)

        //Assert
        assertEq(usdc.balanceOf(address(zkMinimalAccount),AMOUNT));
    }

    function testZkValidateTransaction() public {
        //Arrange
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(zkMinimalAccount), AMOUNT);

        Transaction memory tranaction = createUnsignedTransaction(zkMinimalAccount.owner(),113,dest,value,functionData);
        tranaction = signedTransaction(tranaction);
        //Act
        vm.prank(BOOTLOADER_FORMAL_ADDRESS);
        bytes4 magic = zkMinimalAccount.validateTransaction(EMPTY_BYTES32, EMPTY_BYTES32, tranaction);
        //Assert
        assertEq(magic, ACCOUNT_VALIDATION_SUCCESS_MAGIC);
    }

    function signTransaction(Transaction memory tranaction) internal view returns(Transaction memory) {
       bytes32 unsignedTransactionHash = MemoryTransactionHelper.encodeHash(tranaction);
       bytes32 digest = unsignedTransactionHash.toEthSignedMessageHash(); //need the using at the top   
       uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, unsignedTransactionHash);
        Transaction memory signedTransaction = tranaction;
        signedTransaction.signature = abi.encodePacked(r,s,v);

        return signedTransaction;
    }   

    function createUnsignedTransaction(address from, uint8 tranactionType, address to, uint256 value, bytes memory data) internal view returns(Transaction memory){
        uint256 nonce = vm.getNonce(address(zkMinimalAccount));
        bytes32[] memory factoryDeps = new bytes32[](0);
        return Transaction({
            txType: tranactionType, //for us it will be type 113 (0x71) could be type 0, 1 ,2 -- 113 i for acc abstraction
            from: uint256(uint160(from)), // this is how conversion from address to uint256 is done
            to: uint256(uint160(to)),
            gasLimit: 16777216,
            gasPerPubdataByteLimit: 16777216,
            maxFeePerGas: 16777216,
            maxPriorityFeePerGas: 16777216,
            paymaster: 0,
            nonce: nonce,
            value: value,
            reserved: [uint256(0),uint256(0),uint256(0),uint256(0)]
            data:data,
            signature: hex"",
            factoryDeps:factoryDeps,
            paymasterInput:hex"",
            reservedDynamic: hex""
        })
    }

}
