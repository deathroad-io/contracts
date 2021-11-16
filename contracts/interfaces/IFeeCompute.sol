pragma solidity ^0.8.0;
interface IFeeCompute {
    function getTransferFees(address sender, address recipient, uint256 amount) external view returns (uint256 liquidityFee, uint256 burnFee);
}