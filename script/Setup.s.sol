// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {ERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import {Factory} from "../src/Factory.sol";
import {Proxy} from "../src/Proxy.sol";
import {Pool} from "../src/Pool.sol";
import {Swapper} from "../src/Swapper.sol";
import {GreenNFT} from "../src/token/GreenNFT.sol";
import {Pco2Token} from "../src/token/Pco2Token.sol";

contract TokenB is ERC20 {
    constructor() ERC20("Token B", "TKB") {}
}

contract SetupScript is Script {
    ERC20 usdc;

    // Address LINK - hardcoded for Sepolia
    address linkAddress = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

    address admin = vm.envAddress("ADMIN");
    uint256 userPrivateKey = vm.envUint("PRIVATE_KEY");

    Factory public factoryInstance;
    Factory public proxy;
    GreenNFT public greenNFTInstance;
    Pco2Token public pCO2Instance;
    Proxy public proxyInstance;
    Pool public poolInstance;
    Swapper public swapperInstance;

    address projectOwner1 = makeAddr("projectOwner1");
    address projectOwner2 = makeAddr("projectOwner2");
    address auditor = makeAddr("auditor");
    address buyer = makeAddr("buyer");
    address buyer2 = makeAddr("buyer2");

    function run() public {
        vm.startBroadcast(userPrivateKey);
        deployContracts();
        vm.stopBroadcast();
    }

    function deployContracts() internal {
        greenNFTInstance = new GreenNFT();
        factoryInstance = new Factory();
        proxyInstance = new Proxy(address(factoryInstance));
        proxy = Factory(address(proxyInstance));
        poolInstance = new Pool(proxy);

        usdc = new TokenB();
        swapperInstance = new Swapper(address(usdc), address(poolInstance));
        proxy.initialize(greenNFTInstance, poolInstance);
    }
}
