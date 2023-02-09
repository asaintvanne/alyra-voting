// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.18;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract ERC20Token is ERC20 {

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        
    }

    function mint(address _address, uint amount) external {
        _mint(_address, amount);
    }

}
