// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "chainlink/vrf/VRFV2WrapperConsumerBase.sol";
import {console2} from "forge-std/Test.sol";
import {ERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Factory} from "./Factory.sol";
import {GreenNFT} from "./token/GreenNFT.sol";
import {Pco2Token} from "./token/Pco2Token.sol";
import {OffsetCertificate} from "./token/OffsetCertificate.sol";

contract Pool is VRFV2WrapperConsumerBase, ERC20 {
    // ==== Chainlink ==== //

    // Address LINK - hardcoded for Sepolia
    address linkAddress = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

    // address WRAPPER - hardcoded for Sepolia
    address wrapperAddress = 0xab18414CD93297B0d12ac29E63Ca20f515b3DB46;

    uint32 callbackGasLimit = 2_000_000;
    uint32 numWords = 3;
    uint16 requestConfirmations = 3;

    struct RequestStatus {
        uint256 paid; // amount paid in link
        bool fulfilled; // whether the request has been successfully fulfilled
        uint256[] randomWords;
    }

    mapping(uint256 => RequestStatus) public s_requests; /* requestId --> requestStatus */

    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    // ==== STORAGE ==== //

    uint256 handleFeeRate = 10;
    uint256 randomHandleFeeRate = 8;
    uint256 autoHandleFeeRate = 5;
    uint256 offsetCount;

    Factory factory;
    OffsetCertificate offsetCertificate;

    // ==== CONSTRUCTOR ==== //

    constructor(Factory _factory, OffsetCertificate _offsetCertificate)
        ERC20("CCO2", "CCO2")
        VRFV2WrapperConsumerBase(linkAddress, wrapperAddress)
    {
        factory = _factory;
        offsetCertificate = _offsetCertificate;
    }

    // ==== GETTERS ==== //

    function getRandonData(uint256 requestId) public view returns (address[3] memory randomAddrs) {
        // 1. Get requestId random words
        uint256[] memory randomWords = s_requests[requestId].randomWords;

        // 2. calculate 3 random index in pCO2Addr array
        uint256 randomAddrIdx1 = randomWords[0] % factory.getpCO2AddrLength();
        uint256 randomAddrIdx2 = randomWords[1] % factory.getpCO2AddrLength();
        uint256 randomAddrIdx3 = randomWords[2] % factory.getpCO2AddrLength();

        // 3. Get 3 random address in pCO2Addr array
        randomAddrs = [
            factory.pCO2AddrList(randomAddrIdx1),
            factory.pCO2AddrList(randomAddrIdx2),
            factory.pCO2AddrList(randomAddrIdx3)
        ];
    }

    // ==== FUNCTIONS ==== //

    function deposit(address pCO2Addr, uint256 amount) public {
        // 1. check if pCO2Addr in white list
        (bool isInWhiteList) = factory.checkIsPCO2WhiteList(pCO2Addr);
        require(isInWhiteList);

        // 2. tranfer pCO2 token to this contract (need approve)
        ERC20(pCO2Addr).transferFrom(msg.sender, address(this), amount);

        // 3. 1:1 mint CCO2 token
        _mint(msg.sender, amount);
    }

    function redeem(address pCO2Addr, uint256 amount) public returns (uint256 redeemAmount) {
        // 1. 檢查 pCO2Addr 餘額是否足夠
        require(amount <= ERC20(pCO2Addr).balanceOf(address(this)), "");

        // 2. 計算能夠獲得多少 pCO2Addr 要扣掉手續費
        redeemAmount = amount * (100 - handleFeeRate) / 100;

        // 3. transfer pCO2 to msg.sender
        Pco2Token(pCO2Addr).transfer(msg.sender, redeemAmount);
    }

    function randomRedeem(address pCO2Addr, uint256 amount) public returns (uint256 redeemAmount) {}

    function autoRedeem(uint256 amount) public returns (uint256 redeemAmount) {
        for (uint256 j; j < factory.getpCO2AddrLength() - 1; ++j) {
            address poc2 = factory.pCO2AddrList(j);

            uint256 balance = ERC20(poc2).balanceOf(address(this));

            if (balance < amount) continue;
            redeem(poc2, balance);
            return balance;
        }
    }

    function offset(address pCO2Addr, uint256 amount, uint256 projectId) public {
        // 1. 檢查 pCO2Addr 餘額是否足夠
        require(amount <= ERC20(pCO2Addr).balanceOf(address(msg.sender)), "");

        // 2. Update Project Data for offset
        factory.offset(projectId, amount);

        // 3. burn pCO2 from msg.sender
        Pco2Token(pCO2Addr).burn(msg.sender, amount);

        // 4. mint offset certificate
        offsetCount += 1;
        offsetCertificate.mint(msg.sender, offsetCount);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        // 1. Store random words
        RequestStatus storage request = s_requests[requestId];
        request.fulfilled = true;
        request.randomWords = randomWords;
    }

    function randomPCO2Addr() public returns (uint256 requestId) {
        // 1. check fee for chainlink
        uint256 vrfFee = VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit);
        console2.log("link", vrfFee, IERC20(linkAddress).balanceOf(msg.sender));
        require(IERC20(linkAddress).balanceOf(msg.sender) >= vrfFee, "Not enough LINK!");

        // 2. tranfer fee and request random
        IERC20(linkAddress).transferFrom(msg.sender, address(this), vrfFee);
        requestId = requestRandomness(callbackGasLimit, requestConfirmations, numWords);
    }
}
