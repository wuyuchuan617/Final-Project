// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "chainlink/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {Test, console2} from "forge-std/Test.sol";
import {ERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import {SetupScript} from "../script/Setup.s.sol";
import {Factory} from "../src/Factory.sol";
import {Proxy} from "../src/Proxy.sol";
import {Pool} from "../src/Pool.sol";
import {GreenNFT} from "../src/token/GreenNFT.sol";

contract FactoryTest is Test, SetupScript {
    uint256 projectId;
    uint256 projectId2;
    uint256 reductionAmount = 2 * 10 ** 18;
    uint256 claimId;
    uint256 claimId2;
    address pCO2;

    Factory.ProjectData projectData2;
    Factory.Project project2;

    function setUp() public {
        string memory rpc = vm.envString("MAINNET_RPC_URL");
        vm.createSelectFork(rpc);
        vm.startPrank(admin);
        deployContracts();
    }

    // ==== FACTORY ==== //

    function test_registerAuditor() internal {
        vm.startPrank(admin);
        proxy.registerAuditor(auditor);
        vm.stopPrank();
    }

    function test_proposeProjectA() internal {
        vm.startPrank(projectOwner1);

        // 1. TEST: proposeProject()
        (, projectId) = proxy.registerProject("Amazone Zone A");

        (Factory.Project memory project) = proxy.getProject(projectId);
        console2.log("project.projectId", project.projectId);
        assertEq(project.projectId, projectId);

        vm.stopPrank();
    }

    function test_proposeProjectB() internal {
        vm.startPrank(projectOwner2);

        // 1. TEST: proposeProject()
        (, projectId2) = proxy.registerProject("Gooogle");

        (project2) = proxy.getProject(projectId2);
        console2.log("project2.projectId", project2.projectId);
        assertEq(project2.projectId, projectId2);

        vm.stopPrank();
    }

    function test_claim_reduction() internal {
        vm.startPrank(projectOwner1);

        // reductionAmount = 2 * 10 ** 18;
        (, claimId) = proxy.claim(projectId, reductionAmount, 0);

        (Factory.Claim memory claim) = proxy.getClaim(claimId);
        console2.log("claim.claimedReduction", claim.claimedReduction);
        assertEq(claim.claimedReduction, reductionAmount);

        vm.stopPrank();
    }

    function test_claim_emission() internal {
        vm.startPrank(projectOwner2);

        // 2. TEST: claim()
        uint256 emissionAmount = 500000;
        (, claimId2) = proxy.claim(projectId2, 0, emissionAmount);
        (Factory.Claim memory claim2) = proxy.getClaim(claimId2);
        console2.log("claim2.claimedEmission", claim2.claimedEmission);
        assertEq(claim2.claimedEmission, emissionAmount);

        vm.stopPrank();
    }

    function test_auditClaim_Reduction() internal {
        vm.startPrank(auditor);

        // 3. TEST: auditClaim()
        // uint256 reportId = 1;
        (pCO2) = proxy.auditClaim(claimId);
        assertEq(ERC20(pCO2).balanceOf(projectOwner1), reductionAmount);
        console2.log("ERC20(pCO2).balanceOf(projectOwner1)", ERC20(pCO2).balanceOf(projectOwner1));
        assertEq(greenNFTInstance.balanceOf(projectOwner1), 1);
        assertEq(greenNFTInstance.ownerOf(projectId), projectOwner1);

        vm.stopPrank();
    }

    function test_auditClaim_Emission() internal {
        vm.startPrank(auditor);

        // 3. TEST: auditClaim()
        proxy.auditClaim(claimId2);
        (projectData2) = proxy.getProjectData(projectId2);
        console2.log("project2", projectData2.emission);

        vm.stopPrank();
    }

    // ==== POOL ==== //

    function test_deposit() internal returns (uint256 depositAmount) {
        vm.startPrank(projectOwner1);

        // 4. TEST: Pool deposit()
        depositAmount = 1 * 10 ** 18;
        ERC20(pCO2).approve(address(poolInstance), depositAmount);
        poolInstance.deposit(pCO2, depositAmount);
        assertEq(ERC20(pCO2).balanceOf(projectOwner1), reductionAmount - depositAmount);
        assertEq(ERC20(pCO2).balanceOf(address(poolInstance)), depositAmount);
        assertEq(ERC20(poolInstance).balanceOf(projectOwner1), depositAmount);

        console2.log("tokenA", swapperInstance.tokenA()); // USDC
        console2.log("tokenB", swapperInstance.tokenB()); // Pool Token

        vm.stopPrank();
    }

    function test_addLiquidity(uint256 _depositAmount) internal {
        vm.startPrank(projectOwner1);

        // 5. TEST: swapper addLiquidity()
        uint256 usdcAmount = 2 * 10 ** 18;
        deal(address(usdc), projectOwner1, usdcAmount);
        ERC20(usdc).approve(address(swapperInstance), usdcAmount);
        ERC20(poolInstance).approve(address(swapperInstance), _depositAmount);
        swapperInstance.addLiquidity(_depositAmount, usdcAmount);

        console2.log("reserveA", swapperInstance.reserveA());
        console2.log("reserveB", swapperInstance.reserveB());

        vm.stopPrank();
    }

    function test_swap() internal returns (uint256 amountOut) {
        vm.startPrank(projectOwner2);

        // TEST: swapper swap()
        uint256 swapAmount = 10 ** 6;
        deal(address(usdc), projectOwner2, swapAmount);
        ERC20(usdc).approve(address(swapperInstance), swapAmount);
        (amountOut) = swapperInstance.swap(address(usdc), address(poolInstance), swapAmount);
        console2.log("amountOut", amountOut);
        vm.stopPrank();
    }

    function test_redeem(uint256 _amountOut) internal returns (uint256 offsetAmount) {
        vm.startPrank(projectOwner2);

        uint256 redeemAmount = _amountOut; // 499999
        // uint256 orgBalance = ERC20(pCO2).balanceOf(address(poolInstance));
        ERC20(poolInstance).approve(address(poolInstance), redeemAmount);
        (offsetAmount) = poolInstance.redeem(pCO2, 200000);
        (uint256 autoOffsetAmount) = poolInstance.autoRedeem(redeemAmount - 200000);
        console2.log("offsetAmount", offsetAmount, autoOffsetAmount);

        vm.stopPrank();
    }

    function test_offset(uint256 _offsetAmount) internal {
        vm.startPrank(projectOwner2);

        // TEST: pool offset()
        ERC20(pCO2).approve(address(poolInstance), _offsetAmount);

        console2.log("projectOwner2 balance", ERC20(pCO2).balanceOf(projectOwner2));
        poolInstance.offset(pCO2, _offsetAmount, 2);
        // assertEq(ERC20(pCO2).balanceOf(address(poolInstance)), orgBalance - offsetAmount);
        console2.log("projectOwner2 balance", ERC20(pCO2).balanceOf(projectOwner2));
        (projectData2) = proxy.getProjectData(projectId2);
        console2.log("project2", projectData2.emission);

        // 檢查 projectOwner2 是否有拿到 OffsetCertificate
        assertEq(offsetCertificateInstance.balanceOf(projectOwner2), 1);

        vm.stopPrank();
    }

    function test_randomPCO2Addr() internal {
        vm.startPrank(admin);
        ERC20(linkAddress).approve(address(poolInstance), 250000000000000000);
        (uint256 requestId) = poolInstance.randomPCO2Addr();
        console2.log("requestId", requestId);
        vm.stopPrank();
    }

    // ==== TEST ==== //

    function test_Factory() public {
        test_registerAuditor();

        test_proposeProjectA();
        test_claim_reduction();
        test_auditClaim_Reduction();

        test_proposeProjectB();
        test_claim_emission();
        test_auditClaim_Emission();
    }

    function test_Pool() public {
        test_Factory();

        (uint256 depositAmount) = test_deposit();
        test_addLiquidity(depositAmount);
        (uint256 amountOut) = test_swap();
        (uint256 offsetAmount) = test_redeem(amountOut);
        test_offset(offsetAmount);

        test_randomPCO2Addr();
    }
}
