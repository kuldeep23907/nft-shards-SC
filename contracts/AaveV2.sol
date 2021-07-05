pragma solidity ^0.7.0;


interface IWETHGateway {
  function depositETH(
    address lendingPool,
    address onBehalfOf,
    uint16 referralCode
  ) external payable;

  function withdrawETH(
    address lendingPool,
    uint256 amount,
    address onBehalfOf
  ) external;

  function repayETH(
    address lendingPool,
    uint256 amount,
    uint256 rateMode,
    address onBehalfOf
  ) external payable;

  function borrowETH(
    address lendingPool,
    uint256 amount,
    uint256 interesRateMode,
    uint16 referralCode
  ) external;
}

contract AaveV2 {

    address lendingPool = 0xE0fBa4Fc209b4948668006B2bE61711b7f465bAe;
    address wethGatewayAddr = 0xA61ca04DF33B72b235a8A28CfB535bb7A5271B70;
    IWETHGateway wethGateway;
    
    constructor() public {
        wethGateway = IWETHGateway(wethGatewayAddr);
    }
    
    function supplyETH(uint256 amount) internal {
        wethGateway.depositETH{value:amount}(lendingPool, address(this), 0);
    }
    
    function redeemETh(uint amount) internal {
        wethGateway.withdrawETH(lendingPool,amount,address(this));
    }
      
}