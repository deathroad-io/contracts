pragma solidity ^0.8.0;
import "./IFeeCompute.sol";
interface ILiquidityAdder is IFeeCompute {
    function addLiquidity() external;
}