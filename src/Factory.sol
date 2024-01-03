// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/Strings.sol";
import {console2} from "forge-std/Test.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import {Pool} from "./Pool.sol";
import {Pco2Token} from "./token/Pco2Token.sol";
import {GreenNFT} from "./token/GreenNFT.sol";

contract Factory {
    // ==== STORAGE ==== //

    address admin;
    uint256 currentProjectId;
    uint256 currentClaimId;

    mapping(address => bool) public allAuditors;
    mapping(uint256 => Project) public allProjects;
    mapping(uint256 => ProjectData) public allProjectData;

    mapping(uint256 => Claim) public allClaims;

    mapping(address => bool) public pCO2WhiteList;

    address[] public pCO2Addr;

    GreenNFT greenNFT;
    Pool public pool;

    // ==== OBJECT ==== //

    struct Project {
        uint256 projectId;
        string projectName;
        address projectOwner;
    }

    struct ProjectData {
        address projectOwner;
        uint256 projectId;
        uint256 totalEmission;
        uint256 totalReduction;
        uint256 emission;
        uint256 reduction;
    }

    struct Claim {
        uint256 claimId;
        uint256 projectId;
        uint256 claimedReduction;
        uint256 claimedEmission;
    }

    // ==== EVENT ==== //

    event RegisterProject(uint256 indexed projectId, string projectName);
    event ProposeClaim(
        uint256 indexed currentClaimId, uint256 indexed projectId, uint256 co2Reductions, uint256 co2Emissions
    );

    // ==== CONSTRUCTOR ==== //

    function initialize(GreenNFT _greenNFT, Pool _pool) external {
        admin = msg.sender;
        greenNFT = _greenNFT;
        pool = _pool;
    }

    // ==== MODIFIERS ==== //

    modifier isAuditor() {
        require(allAuditors[msg.sender] == true, "Only auditor can call!");
        _;
    }

    modifier isAdmin() {
        require(msg.sender == admin, "Only admin can call!");
        _;
    }

    modifier isProjectOwner(uint256 projectId) {
        require(msg.sender == getProject(projectId).projectOwner, "Only project owner can call!");
        _;
    }

    // ==== GETTERS ==== //

    function getProject(uint256 projectId) public view returns (Project memory) {
        Project memory project = allProjects[projectId];
        return project;
    }

    function getProjectData(uint256 projectId) public view returns (ProjectData memory) {
        ProjectData memory projectData = allProjectData[projectId];
        return projectData;
    }

    function getClaim(uint256 claimId) public view returns (Claim memory) {
        Claim memory claim = allClaims[claimId];
        return claim;
    }

    function checkIsPCO2WhiteList(address _pCO2Addr) public view returns (bool) {
        return pCO2WhiteList[_pCO2Addr];
    }

    function getpCO2AddrLength() public view returns (uint256 count) {
        return pCO2Addr.length;
    }

    // ==== FUNCTIONS ==== //

    /// @notice - Admin register a auditor
    function registerAuditor(address auditor) public isAdmin returns (bool) {
        allAuditors[auditor] = true;
        return true;
    }

    /// @notice - register a project
    function registerProject(string memory _projectName) public returns (bool, uint256) {
        currentProjectId++;
        Project memory project =
            Project({projectId: currentProjectId, projectOwner: msg.sender, projectName: _projectName});
        allProjects[currentProjectId] = project;
        emit RegisterProject(currentProjectId, _projectName);
        return (true, currentProjectId);
    }

    /// @notice - Claim reduction / emission
    function claim(uint256 _projectId, uint256 _claimedReduction, uint256 _claimedEmission)
        public
        isProjectOwner(_projectId)
        returns (bool, uint256)
    {
        currentClaimId++;
        Claim memory claim = Claim({
            claimId: currentClaimId,
            projectId: _projectId,
            claimedReduction: _claimedReduction,
            claimedEmission: _claimedEmission
        });
        allClaims[currentClaimId] = claim;
        emit ProposeClaim(currentProjectId, _projectId, _claimedReduction, _claimedEmission);
        return (true, currentClaimId);
    }

    /// @notice - An auditor audit a CO2 reduction claim & mint a NFT to project owner
    function auditClaim(uint256 claimId) public isAuditor returns (address) {
        Claim memory claim = getClaim(claimId);
        Project memory project = getProject(claim.projectId);
        // ProjectData memory projectData = getProjectData(claim.projectId);

        address _projectOwner = project.projectOwner;
        uint256 reductionAmount = claim.claimedReduction;
        uint256 emissionAmount = claim.claimedEmission;

        allProjectData[project.projectId].reduction += reductionAmount;
        allProjectData[project.projectId].emission += emissionAmount;
        allProjectData[project.projectId].totalReduction += reductionAmount;
        allProjectData[project.projectId].totalEmission += emissionAmount;

        // Pco2Token pCO2;
        if (reductionAmount > 0) {
            Pco2Token pCO2 = new Pco2Token("pCO2-1", "pCO2-1");
            pCO2WhiteList[address(pCO2)] = true;
            pCO2Addr.push(address(pCO2));
            pCO2.mint(_projectOwner, reductionAmount);
            greenNFT.mint(_projectOwner, project.projectId);
            return address(pCO2);
        }
    }

    function offset(uint256 projectId, uint256 amount) public {
        allProjectData[projectId].emission -= amount;
        allProjectData[projectId].totalEmission -= amount;
    }
}
