// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.6.9;

interface IImplementationProxy {
    function getImplementation() external view returns(address);
}
