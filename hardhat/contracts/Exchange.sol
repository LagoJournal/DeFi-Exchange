// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Exchange is ERC20 {
    address public cryptoDevTokenAddress;

    constructor(address _CryptoDevToken) ERC20("CryptoDev LP Token", "CDLP") {
        require(
            _CryptoDevToken != address(0),
            "Token address passed is a null address"
        );
        cryptoDevTokenAddress = _CryptoDevToken;
    }

    //getReserve returns the amount of CryptoDev tokens held by the contract
    function getReserve() public view returns (uint256) {
        return ERC20(cryptoDevTokenAddress).balanceOf(address(this));
    }

    //addLiquidity will add liquidity to the contract (ETH & CryptoDev tokens)
    function addLiquidity(uint256 _amount) public payable returns (uint256) {
        uint256 liquidity;
        uint256 ethBalance = address(this).balance;
        uint256 cryptoDevTokenReserve = getReserve();
        ERC20 cryptoDevToken = ERC20(cryptoDevTokenAddress);
        //if the reserve is empty, takes any ratio because there isnt one fixed yet
        if (cryptoDevTokenReserve == 0) {
            cryptoDevToken.transferFrom(msg.sender, address(this), _amount);
            //takes the current amount of ETH and mint ethBalance amount of LP tokens,
            //liquidity will be this amount of ETH sent by the user,
            liquidity = ethBalance;
            _mint(msg.sender, liquidity);
        }
        //if reserve is not empty, acording to the ratio, determinates how much Crypto Dev tokens
        //needs to be supplied to prevent price impact
        else {
            uint256 ethReserve = ethBalance - msg.value;
            //ratio always should be maintained => (cryptoDevTokenAmount user can add/cryptoDevTokenReserve in the contract) = (Eth Sent by the user/Eth Reserve in the contract)
            //or (cryptoDevTokenAmount user can add) = (Eth Sent by the user * cryptoDevTokenReserve /Eth Reserve)
            uint256 cryptoDevTokenAmount = (msg.value * cryptoDevTokenReserve) /
                (ethReserve);
            require(
                _amount >= cryptoDevTokenAmount,
                "Amount of tokens sent is less than the minimum required"
            );
            cryptoDevToken.transferFrom(
                msg.sender,
                address(this),
                cryptoDevTokenAmount
            );
            //amount of LP tokens that would be sent should be proportional to the liquidity of ETH added by the user
            //ratio here is => (LP tokens to be sent to the user (liquidity)/ totalSupply of LP tokens in contract) = (Eth sent by the user)/(Eth reserve in the contract)
            //or liquidity =  (totalSupply of LP tokens in contract * (Eth sent by the user))/(Eth reserve in the contract)
            liquidity = (totalSupply() * msg.value) / ethReserve;
            _mint(msg.sender, liquidity);
        }
        return liquidity;
    }

    //removeLiquidity calculates the amount of eth that would be sent back to the user based on this ratio
    //(Eth sent back to the user) / (current Eth reserve) = (amount of LP tokens that user wants to withdraw) / (total supply of LP tokens)
    //and the amount of CryptoDev tokens is based on this ratio
    //(Crypto Dev sent back to the user) / (current Crypto Dev token reserve) = (amount of LP tokens that user wants to withdraw) / (total supply of LP tokens)
    //and the LP Token used would be burnt
    function removeLiquidity(uint256 _amount)
        public
        returns (uint256, uint256)
    {
        require(_amount > 0, "amount should be more than 0");
        uint256 ethReserve = address(this).balance;
        uint256 _totalSupply = totalSupply();
        //amount of ETH to send back is (Eth sent back to the user) = (current Eth reserve * amount of LP tokens that user wants to withdraw) / (total supply of LP tokens)
        uint256 ethAmount = (ethReserve * _amount) / _totalSupply;
        //amount of CDT to send back is (Crypto Dev sent back to the user) = (current Crypto Dev token reserve * amount of LP tokens that user wants to withdraw) / (total supply of LP tokens)
        uint256 cryptoDevTokenAmount = (getReserve() * _amount) / _totalSupply;
        _burn(msg.sender, _amount);
        payable(msg.sender).transfer(ethAmount);
        ERC20(cryptoDevTokenAddress).transfer(msg.sender, cryptoDevTokenAmount);
        return (ethAmount, cryptoDevTokenAmount);
    }

    //this function calculates the 1% fee & amount of tokens to returns given their amount of the pair
    function getAmountOfTokens(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) public pure returns (uint256) {
        require(inputReserve > 0 && outputReserve > 0, "Invalid reserves");
        //we charge the 1% fee here
        uint256 inputAmountWithFee = inputAmount * 99;
        //here we will follow the concept of XY = k curve, knowing that (x + Δx) * (y - Δy) = x * y then Δy = (y * Δx) / (x + Δx)
        //being Δy tokens to be received, Δx = (input amount*99)/100, x = inputReserve & y = outputReserve
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * 100) + inputAmountWithFee;
        return numerator / denominator;
    }

    //this function allows to swap eth to CD tokens
    function ethToCryptoDevToken(uint256 _minTokens) public payable {
        uint256 tokenReserve = getReserve();
        uint256 tokensBought = getAmountOfTokens(
            msg.value,
            address(this).balance - msg.value,
            tokenReserve
        );
        require(tokensBought >= _minTokens, "insufficient output amount");
        ERC20(cryptoDevTokenAddress).transfer(msg.sender, tokensBought);
    }

    //this function allows to swap CD tokens to eth
    function cryptoDevTokenToEth(uint256 _tokensSold, uint256 _minEth) public {
        uint256 tokenReserve = getReserve();
        uint256 ethBought = getAmountOfTokens(
            _tokensSold,
            tokenReserve,
            address(this).balance
        );
        require(ethBought >= _minEth, "Insufficient output amount");
        ERC20(cryptoDevTokenAddress).transferFrom(
            msg.sender,
            address(this),
            _tokensSold
        );
        payable(msg.sender).transfer(ethBought);
    }
}
