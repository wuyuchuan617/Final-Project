// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

contract Proxy {
    bytes32 constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    constructor(address _implementation) {
        _setSlotToAddress(IMPLEMENTATION_SLOT, _implementation);
    }

    function _upgradeToAndCall(address newImplementation, bytes memory data) internal {
        _setSlotToAddress(IMPLEMENTATION_SLOT, newImplementation);
        if (data.length > 0) {
            (bool success,) = newImplementation.delegatecall(data);
            require(success, "Transparent: upgradeToAndCall failed");
        }
    }

    function _delegate(address _implementation) internal virtual {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), _implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function _setSlotToUint256(bytes32 _slot, uint256 value) internal {
        assembly {
            sstore(_slot, value)
        }
    }

    function _setSlotToAddress(bytes32 _slot, address value) internal {
        assembly {
            sstore(_slot, value)
        }
    }

    function _getSlotToAddress(bytes32 _slot) internal view returns (address value) {
        assembly {
            value := sload(_slot)
        }
    }

    fallback() external payable {
        _delegate(_getSlotToAddress(IMPLEMENTATION_SLOT));
    }

    receive() external payable {}
}
